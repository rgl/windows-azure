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
# see https://github.com/rgl/windows-sysprep-playground
# see https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-setup-states?view=windows-11
# NB the logs are stored in the following directories:
#         generalize phase: C:\Windows\System32\Sysprep\Panther
#         specialize phase: C:\Windows\Panther
#         oobe phase:       C:\Windows\Panther\UnattendGC
Write-Host 'Syspreping the machine...'
$sysprepSucceededTagPath = 'C:\Windows\System32\Sysprep\Sysprep_succeeded.tag'
# NB although sysprep is supposed to delete this, to be safe (e.g. earlier
#    sysprep errors), delete it.
if (Test-Path $sysprepSucceededTagPath) {
    Remove-Item -Force $sysprepSucceededTagPath
}
C:\Windows\System32\Sysprep\Sysprep.exe `
    /generalize `
    /oobe `
    /quiet `
    /quit `
    | Out-String -Stream

Write-Host 'Checking for sysprep errors...'
if (!(Test-Path $sysprepSucceededTagPath)) {
    Get-Content C:\Windows\System32\Sysprep\Panther\setuperr.log
    throw "sysprep failed because no $sysprepSucceededTagPath file was found. for more details see the C:\Windows\System32\Sysprep\Panther\setupact.log file (and related files)."
}

Write-Host 'Ensuring the windows image state is IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE...'
$imageState = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State).ImageState
if ($imageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
    throw "the windows image state $imageState is not the expected IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE."
}
