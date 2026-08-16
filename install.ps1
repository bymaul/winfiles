# install.ps1 - bootstrap a fresh Windows machine from winfiles.
# Links configs (junctions for dirs, symlinks for files), then installs the
# coding toolchain (choco + winget) and the PowerShell modules the profile
# needs. Idempotent: safe to re-run after every git pull.
#
# Run once, from an elevated PowerShell 7:
#   pwsh -ExecutionPolicy RemoteSigned -File .\install.ps1

#Requires -RunAsAdministrator
#Requires -Version 7

$ErrorActionPreference = 'Stop'

$Repo = Split-Path -Parent $MyInvocation.MyCommand.Path

function New-ConfigLink {
    param(
        [Parameter(Mandatory = $true)][string]$Link,
        [Parameter(Mandatory = $true)][string]$Target
    )

    $resolved = (Resolve-Path (Join-Path $Repo $Target)).Path
    $isDir = (Get-Item $resolved -Force).PSIsContainer

    if (Test-Path $Link) {
        $item = Get-Item $Link -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            $existing = $item.Target
            if ($existing -and $existing -eq $resolved) {
                Write-Host "already linked: $Link"
                return
            }
            Write-Host "replacing link: $Link"
            Remove-Item $Link -Force
        } else {
            $backup = "$Link.bak.$(Get-Date -Format yyyyMMddHHmmss)"
            Write-Host "moving existing $Link -> $backup"
            Move-Item $Link $backup
        }
    }

    $parent = Split-Path -Parent $Link
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $type = if ($isDir) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $type -Path $Link -Target $resolved | Out-Null
    Write-Host "linked $Link -> $resolved"
}

Write-Host "linking configs (from $Repo)"

$links = @(
    @{ Link = "$env:LOCALAPPDATA\nvim";                 Target = 'nvim' },
    @{ Link = "$env:APPDATA\bat";                       Target = 'bat' },
    @{ Link = "$env:LOCALAPPDATA\lazygit";              Target = 'lazygit' },
    @{ Link = "$env:USERPROFILE\.config\starship.toml"; Target = 'starship\starship.toml' },
    @{ Link = "$env:USERPROFILE\.config\fastfetch";     Target = 'fastfetch' },
    @{ Link = "$env:USERPROFILE\Documents\PowerShell";  Target = 'windows\PowerShell' }
)

foreach ($l in $links) {
    New-ConfigLink -Link $l.Link -Target $l.Target
}

$wtLocalStates = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal"
)

foreach ($wt in $wtLocalStates) {
    if (Test-Path $wt) {
        Write-Host "linking Windows Terminal settings"
        New-ConfigLink -Link $wt -Target 'windows\WindowsTerminal'
        break
    }
}

# 1. chocolatey
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host 'installing chocolatey'
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

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
    'SQLite'
    'vcredist140'
    'zig'
)

foreach ($pkg in $chocoPackages) {
    choco upgrade $pkg -y --no-progress --limit-output
}

# register the vendored bat theme (bat reads its cache, not themes/ on disk)
if (Get-Command bat -ErrorAction SilentlyContinue) {
    bat cache --build | Out-Null
    Write-Host 'rebuilt bat cache'
}

# 2. winget packages
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

foreach ($pkg in $wingetPackages) {
    winget install --id $pkg --exact --silent --accept-package-agreements --accept-source-agreements
}

# 3. WSL + Arch distro (skipped if WSL already present with Arch)
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    if (-not (Get-AppxPackage yuk7.archwsl -ErrorAction SilentlyContinue)) {
        Write-Host 'installing ArchWSL (sideload from GitHub)'
        $ver = '26.4.2.0'
        $base = "https://github.com/yuk7/ArchWSL/releases/download/$ver"
        $cert = "$env:TEMP\ArchWSL-$ver.cer"
        $appx = "$env:TEMP\ArchWSL-$ver.appx"
        try {
            Invoke-WebRequest "$base/ArchWSL_Online-AppX_${ver}_x64.cer" -OutFile $cert
            Invoke-WebRequest "$base/ArchWSL_Online-AppX_${ver}_x64.appx" -OutFile $appx
            Import-Certificate -FilePath $cert -CertStoreLocation Cert:\LocalMachine\TrustedPublisher | Out-Null
            Add-AppxPackage -Path $appx
            Remove-Item $cert, $appx -ErrorAction SilentlyContinue
            Write-Host '  first launch "Arch" once (admin) to register the distro.'
        } catch {
            Write-Warning "ArchWSL sideload failed: $_"
        }
    }
}

# 4. PowerShell modules used by the profile
$profileModules = @('syntax-highlighting', 'ps-color-scripts')

foreach ($m in $profileModules) {
    try {
        Install-PSResource -Name $m -Scope CurrentUser -Quiet -TrustRepository -ErrorAction Stop
    } catch {
        Install-Module -Name $m -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    }
}

$wslRepo = ('/mnt/' + [char]::ToLowerInvariant($Repo[0]) + $Repo.Substring(2)) -replace '\\', '/'

Write-Host ''
Write-Host 'done. notes:'
Write-Host "  - WSL: no clone needed - run $wslRepo/install-wsl.sh (installs opencode in WSL)"
Write-Host '  - if ArchWSL was just installed: launch "Arch" once (admin) to register the distro first.'
Write-Host '  - Windows Terminal writes state files into the repo dir; they are gitignored.'
Write-Host '  - restart PowerShell and Windows Terminal to pick up the new config.'
