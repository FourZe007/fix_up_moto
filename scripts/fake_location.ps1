# Gives the Android emulator a fake position, to check the "nearest workshop"
# features. On its own the emulator gives the app no approximate location, so the
# app falls back to the server's order.
#
#   powershell -ExecutionPolicy Bypass -File scripts\fake_location.ps1
#   ... -File scripts\fake_location.ps1 -Lat -7.3951 -Lng 112.6708    (Gedangan)
#
# The default is near the Darmo branch. Keep it running while you test; Ctrl+C
# stops it and removes the fake position again. Emulators only.
param(
    [string]$Lat = '-7.2700',
    [string]$Lng = '112.6800',
    [string]$Device = 'emulator-5554',
    # Stop by itself after this many seconds (0: run until Ctrl+C).
    [int]$Seconds = 0
)

if ($Device -notlike 'emulator-*') {
    Write-Host "This is for emulators only, not '$Device'."
    exit 1
}
$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) { $adb = 'C:\Android\Sdk\platform-tools\adb.exe' }
function Invoke-Adb { & $adb -s $Device @args }

if ((Invoke-Adb get-state) -ne 'device') {
    Write-Host "$Device is not running."
    exit 1
}

try {
    # Let 'adb shell' provide fake positions.
    Invoke-Adb shell appops set --uid 2000 android:mock_location allow
    Invoke-Adb shell appops set com.android.shell android:mock_location allow
    # Off and on again forgets any older position the phone still remembers.
    Invoke-Adb shell settings put secure location_mode 0
    Start-Sleep -Seconds 3
    Invoke-Adb shell settings put secure location_mode 3
    # Both are needed: with only one of them the app's lookup timed out.
    foreach ($provider in 'network', 'gps') {
        Invoke-Adb shell cmd location providers add-test-provider $provider
        Invoke-Adb shell cmd location providers set-test-provider-enabled $provider true
    }

    Write-Host ''
    Write-Host "Fake position $Lat, $Lng is on. Now, in the app:"
    Write-Host '  - Workshop list: open it, or pull down to refresh.'
    Write-Host '  - Booking page default: hot restart the app first (a chosen'
    Write-Host '    workshop is kept until the app restarts).'
    Write-Host 'Press Ctrl+C here when you are done.'

    # Sent again and again: a fake provider only reports when it is told to.
    $started = Get-Date
    while ($Seconds -le 0 -or ((Get-Date) - $started).TotalSeconds -lt $Seconds) {
        foreach ($provider in 'network', 'gps') {
            Invoke-Adb shell cmd location providers set-test-provider-location $provider --location "$Lat,$Lng" --accuracy 50
        }
        Start-Sleep -Milliseconds 500
    }
}
finally {
    foreach ($provider in 'network', 'gps') {
        Invoke-Adb shell cmd location providers remove-test-provider $provider
    }
    Invoke-Adb shell appops set --uid 2000 android:mock_location default
    Invoke-Adb shell appops set com.android.shell android:mock_location default
    Write-Host 'Fake position removed.'
}
