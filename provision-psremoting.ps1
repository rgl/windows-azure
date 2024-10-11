Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    Write-Host "ERROR: $_"
    ($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1' | Write-Host
    ($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1' | Write-Host
    Exit 1
}

# enable PowerShell 5 remoting.
PowerShell -Command @'
Write-Host 'Enabling Windows PowerShell 5 remoting...'
Enable-PSRemoting -SkipNetworkProfileCheck
Get-PSSessionConfiguration
'@

# enable PowerShell 7 remoting.
&'C:\Program Files\PowerShell\7\pwsh.exe' -Command @'
Write-Host 'Enabling PowerShell 7 remoting...'
Enable-PSRemoting -SkipNetworkProfileCheck
Get-PSSessionConfiguration
'@
