using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.WebSockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

// CmdPal is ignored by GlazeWM, so its dismissal bypasses GlazeWM's
// normal close-window focus restoration. Observe only native window events.
public static class WorkspaceFocusGuard
{
    delegate void WinEvent(IntPtr hook, uint eventType, IntPtr window,
        int objectId, int childId, uint threadId, uint eventTime);
    [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint min, uint max,
        IntPtr module, WinEvent callback, uint process, uint thread, uint flags);
    [DllImport("user32.dll")] static extern bool UnhookWinEvent(IntPtr hook);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);

    static Thread worker;
    static IntPtr palette;
    static string workspace;
    static HashSet<string> previousWindows;
    static WinEvent callback;
    static System.Windows.Forms.Timer restoreTimer;
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
        var hide = SetWinEventHook(0x8001, 0x8003, IntPtr.Zero, callback, 0, 0, 0);
        restoreTimer = new System.Windows.Forms.Timer { Interval = 120 };
        restoreTimer.Tick += delegate { restoreTimer.Stop(); Restore(); };
        try { Application.Run(); }
        finally { UnhookWinEvent(foreground); UnhookWinEvent(hide); }
    }

    static bool UserIsSwitching()
    {
        // Mouse clicks and Alt+Tab are explicit focus choices, not launcher
        // restoration. Do not undo those choices.
        return GetAsyncKeyState(1) < 0 || GetAsyncKeyState(2) < 0 ||
            GetAsyncKeyState(9) < 0;
    }

    static void Observe(IntPtr hook, uint eventType, IntPtr window,
        int objectId, int childId, uint threadId, uint eventTime)
    {
        if (window == IntPtr.Zero) return;
        try
        {
            if (eventType == 3)
            {
                uint process;
                GetWindowThreadProcessId(window, out process);
                string name;
                try { name = Process.GetProcessById((int)process).ProcessName; }
                catch (ArgumentException) { return; }
                if (name == "Microsoft.CmdPal.UI")
                {
                    if (palette == window) return;
                    restoreTimer.Stop();
                    palette = window;
                    var focused = Map(Request("query focused")["focused"]);
                    workspace = focused["type"].ToString() == "workspace" &&
                        ((object[])focused["children"]).Length == 0
                        ? focused["name"].ToString() : null;
                    previousWindows = new HashSet<string>();
                    if (workspace != null)
                        foreach (var item in (object[])Request("query windows")["windows"])
                            previousWindows.Add(Map(item)["id"].ToString());
                }
                else if (palette != IntPtr.Zero && UserIsSwitching())
                {
                    workspace = null;
                    restoreTimer.Stop();
                }
            }
            else if (window == palette && objectId == 0 &&
                (eventType == 0x8001 || eventType == 0x8003) && !IsWindowVisible(window))
            {
                palette = IntPtr.Zero;
                if (workspace != null && !UserIsSwitching()) restoreTimer.Start();
                else workspace = null;
            }
        }
        catch (Exception error) { Log(error); Reset(); }
    }

    static void Restore()
    {
        var target = workspace;
        workspace = null;
        if (target == null || UserIsSwitching()) return;
        try
        {
            var focused = Map(Request("query focused")["focused"]);
            // A workspace shortcut used while the palette was open is an
            // explicit selection; do not restore the previous workspace.
            if (focused["type"].ToString() == "workspace" &&
                focused["name"].ToString() != target) return;
            // A fast launcher can create its window before the dismiss event.
            // Relocate only windows created during this palette invocation.
            string launched = null;
            foreach (var item in (object[])Request("query windows")["windows"])
            {
                var window = Map(item);
                var id = window["id"].ToString();
                if (previousWindows.Contains(id)) continue;
                Request("command --id " + id + " move --workspace " + target);
                if ((bool)window["hasFocus"]) launched = id;
            }
            Request("command focus --workspace " + target);
            if (launched != null) Request("command focus --container-id " + launched);
        }
        catch (Exception error) { Log(error); Reset(); }
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

    static void Reset()
    {
        workspace = null;
        palette = IntPtr.Zero;
        if (socket != null) { socket.Dispose(); socket = null; }
    }

    static void Log(Exception error)
    {
        try { File.AppendAllText(logPath, DateTime.Now.ToString("s") + " " + error + Environment.NewLine); }
        catch (IOException) { }
    }
}
