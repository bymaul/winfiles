# setup.ps1 - bootstrap a fresh Windows machine from winfiles.
# Links configs (junctions), then installs apps (choco + winget) and the
# PowerShell modules the profile needs. Idempotent: safe to re-run.
#
# Run once, from an elevated (admin) PowerShell:
#   powershell -ExecutionPolicy RemoteSigned -File .\windows\setup.ps1

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo = Split-Path -Parent $ScriptDir

# 1. link configs first, so module installs land in the junctioned profile dir
& (Join-Path $ScriptDir 'install.ps1')

# 2. chocolatey + packages
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
    'vlc'
    'zig'
    'zoxide'
)

foreach ($pkg in $chocoPackages) {
    choco install $pkg -y --no-progress --limit-output
}

# 3. winget packages
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
    'Docker.DockerDesktop'
    'TablePlus.TablePlus'
    'Bruno.Bruno'
    'BeyondCode.Herd'
    'GoLang.Go'
    'AutoHotkey.AutoHotkey'
    'Mozilla.Firefox.en-CA'
    'Obsidian.Obsidian'
    'OBSProject.OBSStudio'
    'Giorgiotani.Peazip'
    'Telegram.TelegramDesktop'
    'Spotify.Spotify'
    'Discord.Discord'
    'Figma.Figma'
    'TheDocumentFoundation.LibreOffice'
    'Valve.Steam'
    'ImputNet.Helium'
)

foreach ($pkg in $wingetPackages) {
    winget install --id $pkg --exact --silent --accept-package-agreements --accept-source-agreements
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
Write-Host '  - WSL needs a distro: install ArchWSL from the Microsoft Store (or manually).'
Write-Host '  - then run the WSL side: git clone https://github.com/bymaul/winfiles ~/winfiles && ~/winfiles/install-wsl.sh'
Write-Host '  - restart PowerShell and Windows Terminal to pick up the new config.'
