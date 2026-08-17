# install.ps1 - bootstrap a fresh Windows machine from winfiles.
# Run once from an elevated PowerShell 7:
#   pwsh -ExecutionPolicy RemoteSigned -File .\install.ps1
# Safe to re-run after every git pull.

#Requires -RunAsAdministrator
#Requires -Version 7.0

$ErrorActionPreference = 'Stop'
$Repo = (Resolve-Path -LiteralPath $PSScriptRoot).Path

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Test-Command {
    param([Parameter(Mandatory)][string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
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
            $backup = "$Link.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
            Move-Item -LiteralPath $Link -Destination $backup
            Write-Host "  backed up: $Link -> $backup"
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

if (-not (Test-Command 'choco')) {
    Write-Host 'Installing Chocolatey...'
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-RestMethod 'https://community.chocolatey.org/install.ps1' | Invoke-Expression
    Refresh-Path
}

if (-not (Test-Command 'winget')) {
    throw 'winget not found. Install Microsoft App Installer, then re-run.'
}

# ---------------------------------------------------------------------------
# 2. Toolchain
# ---------------------------------------------------------------------------

Write-Host ''

$chocoPackages = @(
    'bat', 'fd', 'fnm', 'fzf', 'lazygit', 'less', 'mingw'
    'nerd-fonts-JetBrainsMono', 'pnpm', 'ripgrep', 'sqlite'
    'vcredist140', 'zig'
)

$wingetPackages = @(
    'Microsoft.PowerShell', 'Microsoft.WindowsTerminal', 'Microsoft.PowerToys'
    'Microsoft.WSL', 'Microsoft.VisualStudioCode', 'Git.Git', 'GitHub.cli'
    'Neovim.Neovim', 'Starship.Starship', 'eza-community.eza'
    'ajeetdsouza.zoxide', 'Fastfetch-cli.Fastfetch', 'GoLang.Go'
)

foreach ($pkg in $chocoPackages) {
    $check = choco list --local-only --exact $pkg --limit-output 2>$null
    if ($check -match "^$([regex]::Escape($pkg))\|") {
        Write-Host "  choco/$pkg (installed)"
    } else {
        Write-Host "  choco/$pkg"
        choco install $pkg --yes --no-progress
    }
}

foreach ($pkg in $wingetPackages) {
    $check = winget list --id $pkg --exact --accept-source-agreements 2>$null | Out-String
    if ($check -match [regex]::Escape($pkg)) {
        Write-Host "  winget/$pkg (installed)"
    } else {
        Write-Host "  winget/$pkg"
        winget install --id $pkg --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    }
}

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
}

# ---------------------------------------------------------------------------
# 5. WSL
# ---------------------------------------------------------------------------

Refresh-Path

if (Test-Command 'wsl') {
    if (-not (Get-AppxPackage 'yuk7.archwsl' -ErrorAction SilentlyContinue)) {
        $ver = '26.4.2.0'
        $base = "https://github.com/yuk7/ArchWSL/releases/download/$ver"
        $cert = Join-Path $env:TEMP "ArchWSL-$ver.cer"
        $appx = Join-Path $env:TEMP "ArchWSL-$ver.appx"
        try {
            Invoke-WebRequest "$base/ArchWSL_Online-AppX_${ver}_x64.cer" -OutFile $cert
            Invoke-WebRequest "$base/ArchWSL_Online-AppX_${ver}_x64.appx" -OutFile $appx
            Import-Certificate -FilePath $cert -CertStoreLocation Cert:\LocalMachine\TrustedPublisher | Out-Null
            Add-AppxPackage -Path $appx
            Write-Host "  installed: ArchWSL $ver"
        } catch {
            Write-Warning "ArchWSL install failed: $_"
        } finally {
            Remove-Item $cert, $appx -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "  ArchWSL (installed)"
    }
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
Write-Host '  Launch "Arch" once if ArchWSL was just installed.'
Write-Host '  Restart PowerShell and Windows Terminal.'
Write-Host ''
