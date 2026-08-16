# install.ps1 - bootstrap a fresh Windows machine from winfiles.
# Links configs (directory junctions), then installs the coding toolchain
# (choco + winget) and the PowerShell modules the profile needs. Idempotent:
# safe to re-run after every git pull.
#
# Run once, from an elevated PowerShell 7:
#   pwsh -ExecutionPolicy RemoteSigned -File .\install.ps1

#Requires -RunAsAdministrator
#Requires -Version 7

$ErrorActionPreference = 'Stop'

$Repo = Split-Path -Parent $MyInvocation.MyCommand.Path

function New-ConfigJunction {
    param(
        [Parameter(Mandatory = $true)][string]$Link,
        [Parameter(Mandatory = $true)][string]$Target
    )

    $resolved = (Resolve-Path (Join-Path $Repo $Target)).Path

    if (Test-Path $Link) {
        $item = Get-Item $Link -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            $existing = $item.Target
            if ($existing -and $existing -eq $resolved) {
                Write-Host "already linked: $Link"
                return
            }
            Write-Host "replacing junction: $Link"
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

    New-Item -ItemType Junction -Path $Link -Target $resolved | Out-Null
    Write-Host "linked $Link -> $resolved"
}

Write-Host "linking configs (from $Repo)"

$junctions = @(
    @{ Link = "$env:LOCALAPPDATA\nvim";                Target = 'nvim' },
    @{ Link = "$env:APPDATA\bat";                      Target = 'bat' },
    @{ Link = "$env:APPDATA\lazygit";                  Target = 'lazygit' },
    @{ Link = "$env:APPDATA\starship";                 Target = 'starship' },
    @{ Link = "$env:USERPROFILE\.config\opencode";     Target = 'opencode' },
    @{ Link = "$env:USERPROFILE\Documents\PowerShell"; Target = 'windows\PowerShell' }
)

foreach ($j in $junctions) {
    New-ConfigJunction -Link $j.Link -Target $j.Target
}

$wtLocalStates = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal"
)

foreach ($wt in $wtLocalStates) {
    if (Test-Path $wt) {
        Write-Host "linking Windows Terminal settings"
        New-ConfigJunction -Link $wt -Target 'windows\WindowsTerminal'
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
    'zoxide'
)

foreach ($pkg in $chocoPackages) {
    choco install $pkg -y --no-progress --limit-output
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

Write-Host ''
Write-Host 'done. notes:'
Write-Host '  - if ArchWSL was just installed: launch "Arch" once (admin) to register the distro, then'
Write-Host '    git clone https://github.com/bymaul/winfiles ~/winfiles && ~/winfiles/install-wsl.sh'
Write-Host '  - Windows Terminal writes state files into the repo dir; they are gitignored.'
Write-Host '  - restart PowerShell and Windows Terminal to pick up the new config.'
