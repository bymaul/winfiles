function Invoke-Starship-TransientFunction { &starship module character }

Invoke-Expression (&starship init powershell)
Enable-TransientPrompt

Invoke-Expression (& zoxide init powershell | Out-String)

(&mise activate pwsh) | Out-String | Invoke-Expression

if (Get-Module -ListAvailable Microsoft.WinGet.CommandNotFound) {
    Import-Module -Name Microsoft.WinGet.CommandNotFound
}
if (Get-Module -ListAvailable syntax-highlighting) {
    Import-Module syntax-highlighting
}
