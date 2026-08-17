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
# Helpers
# ---------------------------------------------------------------------------

function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Path $Path | Out-Null
    Set-Location $Path
}

function extract {
    param([Parameter(Mandatory)][string]$Path)
    switch -Regex ($Path) {
        '\.tar\.gz$|\.tgz$' { tar xzf $Path }
        '\.tar$'            { tar xf $Path }
        '\.zip$'            { Expand-Archive -Path $Path -DestinationPath '.' }
        '\.7z$'             { 7z x $Path }
        '\.rar$'            { unrar x $Path }
    }
}

function Get-CommandStats {
    Get-Content (Get-PSReadLineOption).HistorySavePath |
        Where-Object { $_ -notmatch '^\s' } |
        ForEach-Object { ($_ -split '\s+')[0] } |
        Group-Object |
        Sort-Object Count -Descending |
        Select-Object -First 20 Count, Name
}

function Get-Path { $env:PATH -split [System.IO.Path]::PathSeparator }


function f {
	__pr_main suggest
}

function __pr_main {
	param(
			[string]$mode
			)

		$Command = (Get-History -Count 1).CommandLine
		__pr_base $mode $Command | Invoke-Expression
}

function __pr_base {
	param(
			[string]$mode,
			[string]$Command
			)

	try {
		$env:_PR_PREFIX = (prompt)
		$env:_PR_MODE = $mode
		$env:_PR_LAST_COMMAND = $Command
		$env:_PR_ALIAS = (Get-Alias | Out-String)
		$env:_PR_SHELL = "pwsh"

		& 'C:\Users\Maulana\AppData\Roaming\pay-respects\pay-respects.exe'

	} finally {
		$env_PR_PREFIX = $null;
		$env:_PR_MODE = $null;
		$env:_PR_LAST_COMMAND = $null;
		$env:_PR_ALIAS = $null;
		$env:_PR_SHELL = $null;
	}
}

function __pr_inline {
	$line = $null
		$cursor = $null
		[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

		$mode = 'inline'
		$command = $line

	$output = __pr_base $mode $command

		if (-not [string]::IsNullOrWhiteSpace($output)) {
			[Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $output)
			[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($output.Length)
		}
	if ($env:_PR_MODE -eq 'inline') {
		$env:_PR_MODE = $null;
	}
}

Set-PSReadLineKeyHandler -Chord Ctrl+x,Ctrl+x -ScriptBlock { __pr_inline }

# Uncomment this block to enable command not found hook
# It's not very useful as we can't retrieve arguments,
# function __pr_invoke {
# 	try {
# 		&'C:\Users\Maulana\AppData\Roaming\pay-respects\pay-respects.exe' | Invoke-Expression;
# 	} finally {
# 		$env:_PR_MODE = $env:null;
# 		$env:_PR_LAST_COMMAND = $env:null;
# 		$env:_PR_SHELL = $env:null;
# 	}
# }

# $ExecutionContext.InvokeCommand.CommandNotFoundAction = {
# 	param($commandName, $eventArgs)

# 	$env:_PR_LAST_COMMAND = $commandName -replace '^get-|\.\\','';
# 	$env:_PR_SHELL = 'pwsh';
# 	$env:_PR_MODE = 'cnf';

# 	$eventArgs.Command = (Get-Command __pr_invoke);
# 	$eventArgs.StopSearch = $True;
# }

