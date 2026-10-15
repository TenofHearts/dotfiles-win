using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.WebSockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

// Only excludes WeChat sign-in windows. Never moves windows or changes focus.
public static class WeChatLoginGuard
{
    delegate void WinEvent(IntPtr hook, uint eventType, IntPtr window,
        int objectId, int childId, uint threadId, uint eventTime);
    [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint min, uint max,
        IntPtr module, WinEvent callback, uint process, uint thread, uint flags);
    [DllImport("user32.dll")] static extern bool UnhookWinEvent(IntPtr hook);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr window);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr window, StringBuilder text, int length);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr window, StringBuilder text, int length);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")] static extern int GetWindowStyle(IntPtr window, int index);
    static readonly Dictionary<IntPtr, int> loginCandidates = new Dictionary<IntPtr, int>();
    static System.Windows.Forms.Timer loginTimer;
    static Thread worker;
    static WinEvent callback;
    static ClientWebSocket socket;
    static readonly JavaScriptSerializer json = new JavaScriptSerializer();
    static string logPath;

    public static void Start(string errorLog)
    {
        if (worker != null) return;
        logPath = errorLog;
        worker = new Thread(Run) { IsBackground = true };
        worker.SetApartmentState(ApartmentState.STA);
        worker.Start();
    }

    static void Run()
    {
        callback = Observe;
        var foreground = SetWinEventHook(3, 3, IntPtr.Zero, callback, 0, 0, 0);
        var creation = SetWinEventHook(0x8000, 0x8002, IntPtr.Zero, callback, 0, 0, 0);
        var nameChange = SetWinEventHook(0x800C, 0x800C, IntPtr.Zero, callback, 0, 0, 0);
        loginTimer = new System.Windows.Forms.Timer { Interval = 50 };
        loginTimer.Tick += delegate { IgnoreLoginCandidates(); };
        try {
            foreach (var item in (object[])Request("query windows")["windows"])
                QueueLogin(new IntPtr(Convert.ToInt64(Map(item)["handle"])));
        } catch (Exception error) { Log(error); ResetConnection(); }
        try { Application.Run(); }
        finally {
            UnhookWinEvent(foreground);
            UnhookWinEvent(creation);
            UnhookWinEvent(nameChange);
        }
    }

    static bool IsLoginWindowShape(string windowClass, string title, int style)
    {
        if (windowClass == "WeChatLoginWndForPC") return true;
        return Regex.IsMatch(windowClass, @"^Qt[0-9]+QWindowIcon$") &&
            (title == "微信" || title == "WeChat" || title == "Weixin") &&
            style != 0 && (style & 0x00030000) == 0;
    }

    static bool IsWeChatLogin(IntPtr window)
    {
        uint pid;
        GetWindowThreadProcessId(window, out pid);
        try {
            string process = Process.GetProcessById((int)pid).ProcessName;
            if (!process.Equals("Weixin", StringComparison.OrdinalIgnoreCase) &&
                !process.Equals("WeChat", StringComparison.OrdinalIgnoreCase)) return false;
        } catch (ArgumentException) { return false; }
        catch (InvalidOperationException) { return false; }
        var name = new StringBuilder(256);
        GetClassName(window, name, name.Capacity);
        if (name.ToString() == "WeChatLoginWndForPC") return true;
        if (!Regex.IsMatch(name.ToString(), @"^Qt[0-9]+QWindowIcon$")) return false;
        var title = new StringBuilder(256);
        GetWindowText(window, title, title.Capacity);
        if (title.ToString() != "微信" && title.ToString() != "WeChat" && title.ToString() != "Weixin") return false;
        int style = GetWindowStyle(window, -16);
        // The observed login window has neither minimize nor maximize controls;
        // the chat window has both, despite sharing the same title and class.
        return IsLoginWindowShape(name.ToString(), title.ToString(), style);
    }

    static void QueueLogin(IntPtr window)
    {
        if (loginCandidates.ContainsKey(window)) return;
        uint pid;
        GetWindowThreadProcessId(window, out pid);
        try {
            using (var process = Process.GetProcessById((int)pid)) {
                if (!process.ProcessName.Equals("Weixin", StringComparison.OrdinalIgnoreCase) &&
                    !process.ProcessName.Equals("WeChat", StringComparison.OrdinalIgnoreCase)) return;
            }
        } catch (ArgumentException) { return; }
        catch (InvalidOperationException) { return; }
        // Creation can precede the title/style initialization and WM management.
        // Keep candidates briefly even when they do not yet match the login shape.
        loginCandidates[window] = 0;
        loginTimer.Start();
    }

    static void IgnoreLoginCandidates()
    {
        loginTimer.Stop();
        try {
            var windows = (object[])Request("query windows")["windows"];
            foreach (var handle in new List<IntPtr>(loginCandidates.Keys)) {
                bool done = !IsWindow(handle);
                if (!done && IsWeChatLogin(handle)) foreach (var item in windows) {
                    var window = Map(item);
                    if (Convert.ToInt64(window["handle"]) != handle.ToInt64()) continue;
                    Request("command --id " + window["id"] + " ignore");
                    done = true;
                    break;
                }
                if (done || ++loginCandidates[handle] >= 40) loginCandidates.Remove(handle);
            }
        } catch (Exception error) { Log(error); ResetConnection(); loginCandidates.Clear(); }
        if (loginCandidates.Count != 0) loginTimer.Start();
    }

    static void Observe(IntPtr hook, uint eventType, IntPtr window,
        int objectId, int childId, uint threadId, uint eventTime)
    {
        if (window == IntPtr.Zero || (eventType != 3 && (objectId != 0 || childId != 0))) return;
        if (eventType == 0x8001) { loginCandidates.Remove(window); return; }
        try { QueueLogin(window); }
        catch (Exception error) { Log(error); }
    }

    static Dictionary<string, object> Map(object value)
    { return (Dictionary<string, object>)value; }

    static Dictionary<string, object> Request(string message)
    {
        using (var timeout = new CancellationTokenSource(2000))
        {
            if (socket == null || socket.State != WebSocketState.Open)
            {
                if (socket != null) socket.Dispose();
                socket = new ClientWebSocket();
                socket.ConnectAsync(new Uri("ws://127.0.0.1:6123"), timeout.Token).GetAwaiter().GetResult();
            }
            var bytes = Encoding.UTF8.GetBytes(message);
            socket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text,
                true, timeout.Token).GetAwaiter().GetResult();
            var buffer = new byte[65536];
            using (var stream = new MemoryStream())
            {
                WebSocketReceiveResult result;
                do
                {
                    result = socket.ReceiveAsync(new ArraySegment<byte>(buffer), timeout.Token).GetAwaiter().GetResult();
                    if (result.MessageType == WebSocketMessageType.Close) throw new IOException("GlazeWM disconnected.");
                    stream.Write(buffer, 0, result.Count);
                } while (!result.EndOfMessage);
                var response = Map(json.DeserializeObject(Encoding.UTF8.GetString(stream.ToArray())));
                if (!(bool)response["success"]) throw new IOException(Convert.ToString(response["error"]));
                return response["data"] == null ? new Dictionary<string, object>() : Map(response["data"]);
            }
        }
    }

    static void ResetConnection()
    {
        if (socket != null) { socket.Dispose(); socket = null; }
    }

    static void Log(Exception error)
    {
        try { File.AppendAllText(logPath, DateTime.Now.ToString("s") + " " + error + Environment.NewLine); }
        catch (IOException) { }
    }
}