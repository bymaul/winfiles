# ---------------------------------------------------------------------------
# PowerShell profile
# ---------------------------------------------------------------------------

$ProfileDir = Join-Path $PSScriptRoot 'Profile'

. $ProfileDir/Aliases.ps1
. $ProfileDir/Readline.ps1
. $ProfileDir/Functions.ps1
. $ProfileDir/ShellIntegration.ps1
