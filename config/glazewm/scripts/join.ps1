[CmdletBinding()]
param([ValidateSet('left', 'down', 'up', 'right')][string]$Direction, [switch]$Listen)

$ErrorActionPreference = 'Stop'
if ($Listen) {
    $created = $false
    $mutex = [Threading.Mutex]::new($true, 'Local\dotfiles-glazewm-join', [ref]$created)
    if (-not $created) { $mutex.Dispose(); return }
    try {
        Add-Type -Path (Join-Path $PSScriptRoot 'wechat-login.cs') -ReferencedAssemblies System.Windows.Forms, System.Web.Extensions, System, System.Core
        [WeChatLoginGuard]::Start((Join-Path (Split-Path $PSScriptRoot -Parent) 'wechat-login-error.log'))
        while ($true) {
            $pipe = [IO.Pipes.NamedPipeServerStream]::new('dotfiles-glazewm-join', [IO.Pipes.PipeDirection]::In)
            try {
                $pipe.WaitForConnection()
                $reader = [IO.StreamReader]::new($pipe)
                $request = $reader.ReadLine().Trim()
                if ($request -eq 'stop') { break }
                if ($request -in @('left', 'down', 'up', 'right')) {
                    try { & $PSCommandPath -Direction $request }
                    catch { $_ | Out-String | Set-Content (Join-Path (Split-Path $PSScriptRoot -Parent) 'join-error.log') }
                }
            } finally { $pipe.Dispose() }
        }
    } finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
    return
}
if (-not $Direction) { throw 'Specify -Direction or -Listen.' }

function Invoke-Wm {
    param([string[]]$WmArguments)
    $message = $WmArguments -join ' '
    $bytes = [Text.Encoding]::UTF8.GetBytes($message)
    $null = $socket.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, $timeout.Token).GetAwaiter().GetResult()
    $text = [Text.StringBuilder]::new()
    do {
        $received = $socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), $timeout.Token).GetAwaiter().GetResult()
        if ($received.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) { throw 'GlazeWM closed the connection.' }
        $null = $text.Append([Text.Encoding]::UTF8.GetString($buffer, 0, $received.Count))
    } until ($received.EndOfMessage)
    $response = $text.ToString() | ConvertFrom-Json
    if (-not $response.success) {
        throw "GlazeWM command failed: $($WmArguments -join ' '): $($response.error)"
    }
    $response.data
}

$source = $null
$socket = [Net.WebSockets.ClientWebSocket]::new()
$timeout = [Threading.CancellationTokenSource]::new(5000)
$buffer = [byte[]]::new(65536)
try {
    $null = $socket.ConnectAsync([Uri]'ws://127.0.0.1:6123', $timeout.Token).GetAwaiter().GetResult()
    $source = (Invoke-Wm @('query', 'focused')).focused
    if ($source.type -ne 'window' -or $source.state.type -ne 'tiling') { return }

    $null = Invoke-Wm @('command', 'focus', '--direction', $Direction)
    $target = (Invoke-Wm @('query', 'focused')).focused
    if ($target.id -eq $source.id -or $target.type -ne 'window' -or $target.state.type -ne 'tiling') { return }

    # Wrap the neighbor in a perpendicular split so moving into it joins
    # its tile instead of swapping the two windows.
    $splitDirection = if ($Direction -in @('left', 'right')) { 'vertical' } else { 'horizontal' }
    $null = Invoke-Wm @('command', '--id', $target.id, 'set-tiling-direction', $splitDirection)
    $target = (Invoke-Wm @('query', 'focused')).focused
    $null = Invoke-Wm @('command', 'focus', '--container-id', $source.id)

    # Nested source splits may need to be exited before entering the target.
    for ($step = 0; $step -lt 32; $step++) {
        $before = (Invoke-Wm @('query', 'focused')).focused
        if ($before.parentId -eq $target.parentId) { break }
        $null = Invoke-Wm @('command', '--id', $source.id, 'move', '--direction', $Direction)
        $after = (Invoke-Wm @('query', 'focused')).focused
        if ($after.parentId -eq $before.parentId -and $after.x -eq $before.x -and $after.y -eq $before.y) { break }
    }
} finally {
    try {
        if ($source -and $source.type -eq 'window') {
            $null = Invoke-Wm @('command', 'focus', '--container-id', $source.id)
        }
    } finally {
        $socket.Dispose()
        $timeout.Dispose()
    }
}
