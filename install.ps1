# install.ps1 - link winfiles configs on native Windows via directory junctions.
# No admin needed (junctions, not symlinks). Idempotent: safe to re-run after
# every git pull.

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

Write-Host "linking shared packages (from $Repo)"

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

Write-Host ""
Write-Host "done. notes:"
Write-Host "  - Windows Terminal writes state files into the repo dir; they are gitignored."
Write-Host "  - restart Windows Terminal and any open PowerShell to pick up the new config."
