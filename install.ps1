# install.ps1 - bootstrap a fresh Windows machine from winfiles.
#
# Run once from an elevated PowerShell 7:
#   pwsh -ExecutionPolicy RemoteSigned -File .\install.ps1
#
# Safe to re-run after every git pull.

#Requires -RunAsAdministrator
#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

$Repo = (Resolve-Path -LiteralPath $PSScriptRoot).Path

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
}

function Test-Command {
    param([Parameter(Mandatory)][string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function New-ConfigLink {
    param(
        [Parameter(Mandatory)][string]$Link,
        [Parameter(Mandatory)][string]$Target
    )

    $targetPath = Join-Path $Repo $Target
    if (-not (Test-Path -LiteralPath $targetPath)) {
        throw "Config target does not exist: $targetPath"
    }

    $resolvedTarget = (Resolve-Path -LiteralPath $targetPath).Path
    $targetItem = Get-Item -LiteralPath $resolvedTarget -Force

    if (Test-Path -LiteralPath $Link) {
        $existing = Get-Item -LiteralPath $Link -Force

        if ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $existingTarget = @($existing.Target)
            if ($existingTarget -contains $resolvedTarget) {
                Write-Host "already linked: $Link"
                return
            }

            Write-Host "replacing link: $Link"
            Remove-Item -LiteralPath $Link -Force -Recurse
        }
        else {
            $backup = "$Link.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
            Write-Host "moving existing $Link -> $backup"
            Move-Item -LiteralPath $Link -Destination $backup
        }
    }

    $parent = Split-Path -Parent $Link
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $type = if ($targetItem.PSIsContainer) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $type -Path $Link -Target $resolvedTarget -Force | Out-Null
    Write-Host "linked $Link -> $resolvedTarget"
}

function Install-ChocoPackage {
    param([Parameter(Mandatory)][string]$Name)

    $installed = choco list --local-only --exact $Name --limit-output 2>$null
    if ($installed -match "^$([regex]::Escape($Name))\|") {
        Write-Host "already installed: choco/$Name"
        return
    }

    Write-Host "installing: choco/$Name"
    choco install $Name --yes --no-progress
}

function Install-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)

    $installed = winget list --id $Id --exact --accept-source-agreements 2>$null | Out-String
    if ($installed -match [regex]::Escape($Id)) {
        Write-Host "already installed: winget/$Id"
        return
    }

    Write-Host "installing: winget/$Id"
    winget install `
        --id $Id `
        --exact `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements `
        --disable-interactivity
}

# ---------------------------------------------------------------------------
# 1. Package managers
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '==> Package managers'

Refresh-Path

if (-not (Test-Command 'choco')) {
    Write-Host 'installing Chocolatey'
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-RestMethod 'https://community.chocolatey.org/install.ps1' | Invoke-Expression
    Refresh-Path
}

if (-not (Test-Command 'winget')) {
    throw 'winget is not available. Install/update Microsoft App Installer, then run install.ps1 again.'
}

# ---------------------------------------------------------------------------
# 2. Windows toolchain
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '==> Chocolatey packages'

$chocoPackages = @(
    'bat'
    'fd'
    'fnm'
    'fzf'
    'lazygit'
    'less'
    'mingw'
    'nerd-fonts-JetBrainsMono'
    'pnpm'
    'ripgrep'
    'sqlite'
    'vcredist140'
    'zig'
)

foreach ($package in $chocoPackages) {
    Install-ChocoPackage $package
}

Write-Host ''
Write-Host '==> WinGet packages'

$wingetPackages = @(
    'Microsoft.PowerShell'
    'Microsoft.WindowsTerminal'
    'Microsoft.PowerToys'
    'Microsoft.WSL'
    'Microsoft.VisualStudioCode'
    'Git.Git'
    'GitHub.cli'
    'Neovim.Neovim'
    'Starship.Starship'
    'eza-community.eza'
    'ajeetdsouza.zoxide'
    'Fastfetch-cli.Fastfetch'
    'GoLang.Go'
)

foreach ($package in $wingetPackages) {
    Install-WingetPackage $package
}

Refresh-Path

# ---------------------------------------------------------------------------
# 3. Config links
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host "==> Linking configs from $Repo"

$links = @(
    @{ Link = "$env:LOCALAPPDATA\nvim";                 Target = 'nvim' }
    @{ Link = "$env:APPDATA\bat";                       Target = 'bat' }
    @{ Link = "$env:LOCALAPPDATA\lazygit";              Target = 'lazygit' }
    @{ Link = "$env:USERPROFILE\.config\starship.toml"; Target = 'starship\starship.toml' }
    @{ Link = "$env:USERPROFILE\.config\fastfetch";     Target = 'fastfetch' }
    @{ Link = "$env:USERPROFILE\Documents\PowerShell";  Target = 'windows\PowerShell' }
)

foreach ($link in $links) {
    New-ConfigLink -Link $link.Link -Target $link.Target
}

# Windows Terminal must be installed before its LocalState directory exists.
$wtLocalStates = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState"
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal"
)

$wtLinked = $false
foreach ($wt in $wtLocalStates) {
    if (Test-Path -LiteralPath $wt) {
        Write-Host 'linking Windows Terminal settings'
        New-ConfigLink -Link $wt -Target 'windows\WindowsTerminal'
        $wtLinked = $true
        break
    }
}

if (-not $wtLinked) {
    Write-Warning 'Windows Terminal has not created its LocalState directory yet.'
    Write-Warning 'Launch Windows Terminal once, close it, then re-run install.ps1.'
}

# ---------------------------------------------------------------------------
# 4. bat theme cache
# ---------------------------------------------------------------------------

if (Test-Command 'bat') {
    Write-Host ''
    Write-Host '==> Updating bat cache'
    bat cache --build | Out-Null
}

# ---------------------------------------------------------------------------
# 5. PowerShell modules
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '==> PowerShell modules'

$profileModules = @('syntax-highlighting')

foreach ($module in $profileModules) {
    if (Get-Module -ListAvailable -Name $module) {
        Write-Host "already installed: $module"
        continue
    }

    Write-Host "installing: $module"

    try {
        Install-PSResource `
            -Name $module `
            -Scope CurrentUser `
            -Repository PSGallery `
            -TrustRepository `
            -Quiet `
            -ErrorAction Stop
    }
    catch {
        Install-Module `
            -Name $module `
            -Scope CurrentUser `
            -Force `
            -AllowClobber `
            -Repository PSGallery `
            -ErrorAction Stop
    }
}

# ---------------------------------------------------------------------------
# 6. WSL + ArchWSL
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '==> WSL'

Refresh-Path

if (-not (Test-Command 'wsl')) {
    Write-Warning 'wsl.exe is not available yet. Restart Windows, then run install.ps1 again.'
}
else {
    $arch = Get-AppxPackage -Name 'yuk7.archwsl' -ErrorAction SilentlyContinue

    if ($arch) {
        Write-Host 'ArchWSL already installed'
    }
    else {
        # ArchWSL latest is currently 26.4.2.0. Keep the version explicit so
        # bootstrap installs are reproducible; update it when a new release is needed.
        $ver = '26.4.2.0'
        $base = "https://github.com/yuk7/ArchWSL/releases/download/$ver"
        $cert = Join-Path $env:TEMP "ArchWSL-$ver.cer"
        $appx = Join-Path $env:TEMP "ArchWSL-$ver.appx"

        Write-Host "installing ArchWSL $ver"

        try {
            Invoke-WebRequest `
                "$base/ArchWSL_Online-AppX_${ver}_x64.cer" `
                -OutFile $cert

            Invoke-WebRequest `
                "$base/ArchWSL_Online-AppX_${ver}_x64.appx" `
                -OutFile $appx

            Import-Certificate `
                -FilePath $cert `
                -CertStoreLocation Cert:\LocalMachine\TrustedPublisher | Out-Null

            Add-AppxPackage -Path $appx
        }
        catch {
            Write-Warning "ArchWSL installation failed: $_"
        }
        finally {
            Remove-Item $cert, $appx -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# 7. Finish
# ---------------------------------------------------------------------------

$wslRepo = $null
if ($Repo -match '^([A-Za-z]):\\(.*)$') {
    $drive = $matches[1].ToLowerInvariant()
    $path = $matches[2] -replace '\\', '/'
    $wslRepo = "/mnt/$drive/$path"
}

Write-Host ''
Write-Host '========================================'
Write-Host 'Bootstrap complete'
Write-Host '========================================'
Write-Host ''

if ($wslRepo) {
    Write-Host "WSL setup:"
    Write-Host "  $wslRepo/install-wsl.sh"
}

Write-Host ''
Write-Host 'Next steps:'
Write-Host '  - If ArchWSL was just installed, launch "Arch" once to initialize it.'
Write-Host '  - Run install-wsl.sh inside Arch.'
Write-Host '  - If Windows Terminal was not linked, launch it once and re-run install.ps1.'
Write-Host '  - Restart PowerShell and Windows Terminal.'
Write-Host ''
