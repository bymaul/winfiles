# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------

Set-Alias -Name vim -Value nvim
Set-Alias -Name open -Value explorer
Set-Alias -Name ls -Value Get-ChildItemFormatted
Set-Alias -Name touch -Value New-File
Set-Alias -Name grep -Value Find-String
Set-Alias -Name cat -Value bat
Set-Alias -Name which -Value Get-CommandDefinition
Set-Alias -Name nah -Value Reset-GitChanges
Set-Alias -Name glog -Value Get-GitLog
Set-Alias -Name art -Value Invoke-LaravelArtisan
Set-Alias -Name us -Value Update-SystemSoftware
Set-Alias -Name lg -Value lazygit
Set-Alias -Name rmrf -Value Remove-ItemForceRecursive
Set-Alias -Name opencode -Value Invoke-OpenCodeWSL
Set-Alias -Name su -Value Update-ShellElevation
Set-Alias -Name oc -Value opencode

# ---------------------------------------------------------------------------
# File operations
# ---------------------------------------------------------------------------

function Get-ChildItemFormatted {
    param([string]$Path = $PWD)
    eza -a -l --header --icons --hyperlink --time-style relative $Path
}

function New-File {
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string[]]$Path
    )
    process {
        foreach ($p in $Path) {
            if (Test-Path $p) { (Get-Item $p).LastWriteTime = Get-Date }
            else { New-Item -ItemType File -Path $p | Out-Null }
        }
    }
}

function Remove-ItemForceRecursive {
    param([Parameter(Mandatory)][string]$Path)
    Remove-Item -Path $Path -Recurse -Force
}

# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------

function Find-String {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Pattern,

        [Parameter(Position = 1, ParameterSetName = 'FileSearch')]
        [string[]]$Path,

        [Parameter(ParameterSetName = 'FileSearch')]
        [switch]$Recurse,

        [switch]$IgnoreCase,

        [Parameter(ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$InputObject
    )

    begin {
        $input_ = [System.Collections.ArrayList]::new()
        $params = @{ Pattern = $Pattern; AllMatches = $true }
        if ($IgnoreCase) { $params['CaseSensitive'] = $false }
    }

    process { if ($InputObject) { $null = $input_.Add($InputObject) } }

    end {
        if ($input_.Count -gt 0) {
            $input_ | Select-String @params
            return
        }
        $childParams = @{ Path = $Path }
        if ($Recurse) { $childParams['Recurse'] = $true }
        Get-ChildItem @childParams |
            Where-Object { $_ -is [System.IO.FileInfo] } |
            Select-String @params
    }
}

# ---------------------------------------------------------------------------
# Git
# ---------------------------------------------------------------------------

function Reset-GitChanges {
    git reset --hard
    git clean -df
}

function Get-GitLog {
    git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
}

# ---------------------------------------------------------------------------
# Dev tools
# ---------------------------------------------------------------------------

function Invoke-LaravelArtisan { php artisan @args }

function Invoke-OpenCodeWSL { wsl zsh -ic "opencode $($args)" }

# ---------------------------------------------------------------------------
# System
# ---------------------------------------------------------------------------

function Get-CommandDefinition {
    param([Parameter(Mandatory)][string]$Name)
    Get-Command $Name | Select-Object -ExpandProperty Definition
}

function Update-ShellElevation {
    sudo -E pwsh -NoLogo -Interactive -NoExit -c "Clear-Host"
}

function Update-SystemSoftware {
    sudo winget upgrade --all --include-unknown --silent --verbose
    winget upgrade --all --include-unknown --silent --verbose
    sudo choco upgrade all -y
}

# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------

function Invoke-Starship-TransientFunction { &starship module character }

# ---------------------------------------------------------------------------
# Shell integration
# ---------------------------------------------------------------------------

Invoke-Expression (&starship init powershell)
Enable-TransientPrompt

Invoke-Expression (& { (zoxide init powershell | Out-String) })

fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression

if (Get-Module -ListAvailable Microsoft.WinGet.CommandNotFound) {
    Import-Module -Name Microsoft.WinGet.CommandNotFound
}
if (Get-Module -ListAvailable syntax-highlighting) {
    Import-Module syntax-highlighting
}
