# Microsoft.PowerShell_profile.ps1 - minimal PowerShell profile (Vague).
# Mirrors the WSL zsh aliases; links starship, zoxide, and fnm.

Set-PSReadLineOption -Colors @{
    Command   = '#6e94b2'
    Keyword   = '#bb9dbd'
    Parameter = '#cdcdcd'
    Operator  = '#9bb4bc'
    Variable  = '#e0a363'
    String    = '#e8b589'
    Number    = '#e0a363'
    Type      = '#f3be7c'
    Comment   = '#878787'
    Error     = '#d8647e'
    Default   = '#cdcdcd'
    Selection = '#252530'
}

Set-Alias vim nvim
Set-Alias cat bat
Set-Alias lg lazygit
Set-Alias nah Reset-GitChanges
Set-Alias opencode Invoke-OpenCodeWSL
Set-Alias oc Invoke-OpenCodeWSL

function Get-ChildItemFormatted {
    eza -a -l --header --icons --hyperlink --time-style relative @args
}
Set-Alias ls Get-ChildItemFormatted

function Find-String {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$Pattern,
        [Parameter(ValueFromPipeline = $true)][AllowEmptyString()][string]$InputObject
    )
    process { if ($InputObject) { $InputObject | Select-String -Pattern $Pattern -AllMatches } }
}
Set-Alias grep Find-String

function New-File {
    param([Parameter(Mandatory = $true, Position = 0)][string]$Path)
    if (Test-Path $Path) { (Get-Item $Path).LastWriteTime = Get-Date }
    else { New-Item -ItemType File -Path $Path | Out-Null }
}
Set-Alias touch New-File

function Reset-GitChanges {
    git reset --hard
    git clean -df
}

function Invoke-OpenCodeWSL {
    wsl zsh -ic "opencode $args"
}

Invoke-Expression (&starship init powershell)
Enable-TransientPrompt

Invoke-Expression (& { (zoxide init powershell | Out-String) })

fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression

Import-Module -Name Microsoft.WinGet.CommandNotFound
