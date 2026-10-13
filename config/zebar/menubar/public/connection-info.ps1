# Read-only WinRT queries. Windows PowerShell 5.1 provides the WinRT bridge.
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.Runtime.WindowsRuntime
function Wait-WinRT($Operation, [Type]$ResultType) {
    $method = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetGenericArguments().Count -eq 1 -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    } | Select-Object -First 1
    $task = $method.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    if (-not $task.Wait(5000)) { throw 'Device query timed out.' }
    return $task.Result
}
$result = @{wifi=@();bluetooth=@()}
try {
    $null = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]
    $result.wifi = @([Windows.Networking.Connectivity.NetworkInformation]::GetConnectionProfiles() | Where-Object {
        $_.IsWlanConnectionProfile -and $_.GetNetworkConnectivityLevel().ToString() -ne 'None'
    } | ForEach-Object { $_.WlanConnectionProfileDetails.GetConnectedSsid() } | Sort-Object -Unique)
} catch { $result.wifiError = $_.Exception.Message }
try {
    $null = [Windows.Devices.Bluetooth.BluetoothDevice,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]
    $null = [Windows.Devices.Bluetooth.BluetoothLEDevice,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]
    $null = [Windows.Devices.Enumeration.DeviceInformation,Windows.Devices.Enumeration,ContentType=WindowsRuntime]
    $null = [Windows.Devices.Enumeration.DeviceInformationCollection,Windows.Devices.Enumeration,ContentType=WindowsRuntime]
    $connected = [Windows.Devices.Bluetooth.BluetoothConnectionStatus]::Connected
    $selectors = @([Windows.Devices.Bluetooth.BluetoothDevice]::GetDeviceSelectorFromConnectionStatus($connected), [Windows.Devices.Bluetooth.BluetoothLEDevice]::GetDeviceSelectorFromConnectionStatus($connected))
    $names = foreach ($selector in $selectors) {
        $devices = Wait-WinRT ([Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync($selector)) ([Windows.Devices.Enumeration.DeviceInformationCollection])
        foreach ($device in $devices) { $device.Name }
    }
    $result.bluetooth = @($names | Where-Object { $_ } | Sort-Object -Unique)
} catch { $result.bluetoothError = $_.Exception.Message }
$result | ConvertTo-Json -Compress
