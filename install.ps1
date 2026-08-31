# install.ps1 - bootstrap a fresh Windows machine from winfiles.
# Run once from an elevated PowerShell 7:
#   pwsh -ExecutionPolicy RemoteSigned -File .\install.ps1
# Safe to re-run after every git pull.
#
# Flags:
#   -NoBackup    Replace existing config files/directories instead of backing them up.

#Requires -RunAsAdministrator
#Requires -Version 7.0

param(
    [switch]$NoBackup
)

$ErrorActionPreference = 'Stop'
$Repo = (Resolve-Path -LiteralPath $PSScriptRoot).Path

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Test-Command {
    param([Parameter(Mandatory)][string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-ScoopPackage {
    param([Parameter(Mandatory)][string]$Name)
    if ((scoop list $Name 2>$null | Out-String) -match "(?m)^\s*$([regex]::Escape($Name))\s") {
        Write-Host "  scoop/$Name (installed)"
    } else {
        Write-Host "  scoop/$Name"
        scoop install $Name
    }
}

function Install-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)
    if ((winget list --id $Id --exact --accept-source-agreements 2>$null | Out-String) -match [regex]::Escape($Id)) {
        Write-Host "  winget/$Id (installed)"
    } else {
        Write-Host "  winget/$Id"
        winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    }
}

function New-ConfigLink {
    param([Parameter(Mandatory)][string]$Link, [Parameter(Mandatory)][string]$Target)

    $resolved = (Resolve-Path -LiteralPath (Join-Path $Repo $Target)).Path
    $isDir = (Get-Item -LiteralPath $resolved -Force).PSIsContainer

    if (Test-Path -LiteralPath $Link) {
        $existing = Get-Item -LiteralPath $Link -Force
        if ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            if ((@($existing.Target) -contains $resolved)) {
                Write-Host "  already linked: $Link"
                return
            }
            Remove-Item -LiteralPath $Link -Force -Recurse
        } else {
            if ($NoBackup) {
                Remove-Item -LiteralPath $Link -Force -Recurse
                Write-Host "  removed: $Link"
            } else {
                $backup = "$Link.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
                Move-Item -LiteralPath $Link -Destination $backup
                Write-Host "  backed up: $Link -> $backup"
            }
        }
    }

    $parent = Split-Path -Parent $Link
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $type = if ($isDir) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $type -Path $Link -Target $resolved -Force | Out-Null
    Write-Host "  linked: $Link"
}

# ---------------------------------------------------------------------------
# 1. Package managers
# ---------------------------------------------------------------------------

Refresh-Path

if (-not (Test-Command 'scoop')) {
    Write-Host 'Installing Scoop...'
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    $scoopInstall = Join-Path $env:TEMP 'install-scoop.ps1'
    Invoke-RestMethod 'https://get.scoop.sh' -OutFile $scoopInstall
    & $scoopInstall -RunAsAdmin
    Remove-Item $scoopInstall -Force
    Refresh-Path
}

if (-not (Test-Command 'scoop')) {
    throw 'Scoop installation failed.'
}

if (-not (Test-Command 'winget')) {
    throw 'winget not found. Install Microsoft App Installer, then re-run.'
}

# ---------------------------------------------------------------------------
# 2. Toolchain
# ---------------------------------------------------------------------------

Write-Host ''

$scoopBuckets = @(
    'extras'
    'nerd-fonts'
)

$scoopPackages = @(
    '7zip'
    'bat'
    'eza'
    'fastfetch'
    'fd'
    'fnm'
    'fzf'
    'gh'
    'go'
    'JetBrainsMono-NF'
    'lazygit'
    'less'
    'mingw'
    'neovim'
    'pnpm'
    'ripgrep'
    'sqlite'
    'starship'
    'vcredist2022'
    'zig'
    'zoxide'
)

$wingetPackages = @(
    'Microsoft.PowerShell'
    'Microsoft.WindowsTerminal'
    'Microsoft.PowerToys'
    'Microsoft.WSL'
    'Microsoft.VisualStudioCode'
)

# git first: scoop manages buckets through git
Install-ScoopPackage 'git'

foreach ($bucket in $scoopBuckets) {
    $installed = @(scoop bucket list 2>$null | ForEach-Object { if ($_.name) { $_.name } else { $_ } })

    if ($installed -contains $bucket) {
        Write-Host "  scoop bucket/$bucket (installed)"
    } else {
        Write-Host "  scoop bucket/$bucket"
        scoop bucket add $bucket
    }
}

foreach ($pkg in $scoopPackages) { Install-ScoopPackage $pkg }

foreach ($pkg in $wingetPackages) { Install-WingetPackage $pkg }

Refresh-Path

# ---------------------------------------------------------------------------
# 3. Config links
# ---------------------------------------------------------------------------

Write-Host ''

$links = @(
    @{ Link = "$env:LOCALAPPDATA\nvim";                 Target = 'nvim' }
    @{ Link = "$env:APPDATA\bat";                       Target = 'bat' }
    @{ Link = "$env:LOCALAPPDATA\lazygit";              Target = 'lazygit' }
    @{ Link = "$env:USERPROFILE\.config\starship.toml"; Target = 'starship\starship.toml' }
    @{ Link = "$env:USERPROFILE\.config\fastfetch";     Target = 'fastfetch' }
    @{ Link = "$env:USERPROFILE\Documents\PowerShell";  Target = 'windows\PowerShell' }
)

foreach ($l in $links) { New-ConfigLink @l }

$wtPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState"
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal"
)

foreach ($wt in $wtPaths) {
    if (Test-Path -LiteralPath $wt) {
        New-ConfigLink -Link $wt -Target 'windows\WindowsTerminal'
        break
    }
}

# ---------------------------------------------------------------------------
# 4. Post-install
# ---------------------------------------------------------------------------

Write-Host ''

if (Test-Command 'bat') { bat cache --build | Out-Null }

$module = 'syntax-highlighting'
if (-not (Get-Module -ListAvailable -Name $module)) {
    try {
        Install-PSResource -Name $module -Scope CurrentUser -TrustRepository -Quiet -ErrorAction Stop
    } catch {
        Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    }
    Write-Host "  installed: $module"
} else {
    Write-Host "  $module (installed)"
}

# ---------------------------------------------------------------------------
# 5. WSL
# ---------------------------------------------------------------------------

Refresh-Path

if (Test-Command 'wsl') {
    Write-Host ''

    wsl --update

    $archInstalled = @(wsl -l -q) -contains 'archlinux'

    if ($archInstalled) {
        Write-Host '  Arch Linux (installed)'
    } else {
        Write-Host '  Installing Arch Linux...'
        wsl --install archlinux --no-launch
        Write-Host '  installed: Arch Linux'
    }

    wsl --set-default archlinux
} else {
    Write-Warning 'wsl.exe not found. Restart Windows, then re-run.'
}

# ---------------------------------------------------------------------------
# 6. Done
# ---------------------------------------------------------------------------

$wslRepo = $null
if ($Repo -match '^([A-Za-z]):\\(.*)$') {
    $wslRepo = "/mnt/$($matches[1].ToLowerInvariant())/$($matches[2] -replace '\\','/')"
}

Write-Host ''
Write-Host 'Done.'
Write-Host ''
Write-Host 'Next steps:'
if ($wslRepo) { Write-Host "  $wslRepo/install-wsl.sh" }
Write-Host '  Launch "archlinux" once if Arch Linux was just installed.'
Write-Host '  Run the install-wsl.sh script from inside Arch.'
Write-Host '  Restart PowerShell and Windows Terminal.'
Write-Host ''
