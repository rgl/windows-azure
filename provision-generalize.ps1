Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    Write-Host "ERROR: $_"
    ($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$', 'ERROR: $1' | Write-Host
    ($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$', 'ERROR EXCEPTION: $1' | Write-Host
    Exit 1
}

# remove the custom_data.
if (Test-Path C:\AzureData) {
    Write-Host 'Removing the custom_data...'
    Remove-Item -Recurse -Force C:\AzureData
}

# remove the sshd host keys.
Stop-Service sshd
Remove-Item -Force C:\ProgramData\ssh\ssh_host_*

# sysprep the machine.
# see https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-setup-states?view=windows-10
Write-Host 'Syspreping the machine...'
& "$env:SystemRoot\System32\Sysprep\Sysprep.exe" /oobe /generalize /quiet /quit
while ($true) {
    $imageState = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State).ImageState
    Write-Output $imageState
    if ($imageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
        Start-Sleep -Seconds 10
    } else {
        break
    }
}
