# Aliases
Set-Alias -Name vim -Value nvim
Set-Alias -Name open -Value explorer
Set-Alias -Name ls -Value Get-ChildItemFormatted
Set-Alias -Name touch -Value New-File
Set-Alias -Name grep -Value Find-String
Set-Alias -Name cat -Value bat
Set-Alias -Name which -Value Get-CommandDefinition
Set-Alias -Name nah -Value Reset-GitChanges
Set-Alias -Name glog -Value Get-GitLog
Set-Alias -Name gad -Value Export-GitDiffArchive
Set-Alias -Name art -Value Invoke-LaravelArtisan
Set-Alias -Name us -Value Update-SystemSoftware
Set-Alias -Name lg -Value lazygit
Set-Alias -Name tif -Value Show-ThisIsFine
Set-Alias -Name rmrf -Value Remove-ItemForceRecursive
Set-Alias -Name opencode -Value Invoke-OpenCodeWSL
Set-Alias -Name oc -Value opencode

# Functions
function Get-ChildItemFormatted
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false, Position = 0)]
		[string]$Path = $PWD
	)

	eza -a -l --header --icons --hyperlink --time-style relative $Path
}

function Find-String
{
	[CmdletBinding(DefaultParameterSetName='Default')]
	param(
		[Parameter(Mandatory=$true, Position=0)]
		[string]$Pattern,

		[Parameter(Mandatory=$false, Position=1, ParameterSetName='FileSearch')]
		[string[]]$Path,

		[Parameter(Mandatory=$false, ParameterSetName='FileSearch')]
		[switch]$Recurse,

		[Parameter(Mandatory=$false)]
		[switch]$IgnoreCase,

		[Parameter(Mandatory=$false, ValueFromPipeline=$true)]
		[AllowEmptyString()]
		[string]$InputObject
	)

	begin
	{
		$pipelineInput = [System.Collections.ArrayList]::new()

		$selectStringParams = @{
			Pattern = $Pattern
			AllMatches = $true
		}

		if ($IgnoreCase)
		{
			$selectStringParams['CaseSensitive'] = $false
		}
	}

	process
	{
		if ($InputObject)
		{
			$null = $pipelineInput.Add($InputObject)
		}
	}

	end
	{
		try
		{
			if ($pipelineInput.Count -gt 0)
			{
				$pipelineInput | Select-String @selectStringParams
				return
			}

			if ($Path)
			{
				$searchParams = @{
					Path = $Path
				}

				if ($Recurse)
				{
					$searchParams['Recurse'] = $true
				}

				Get-ChildItem @searchParams | 
					Where-Object { $_ -is [System.IO.FileInfo] } | 
					Select-String @selectStringParams
			} else
			{
				Get-ChildItem | 
					Where-Object { $_ -is [System.IO.FileInfo] } | 
					Select-String @selectStringParams
			}
		} catch
		{
			Write-Error "An error occurred while searching: $_"
		}
	}
}

function New-File
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
		[string[]]$Path
	)

	process
	{
		foreach ($filePath in $Path)
		{
			if (Test-Path $filePath)
			{
				(Get-Item $filePath).LastWriteTime = Get-Date
			} else
			{
				New-Item -ItemType File -Path $filePath | Out-Null
			}
		}
	}
}

function Update-SystemSoftware
{
	Write-Verbose "Updating software installed via Winget & Chocolatey"

	sudo winget upgrade --all --include-unknown --silent --verbose
	# upgrade all packages installed without superuser
	winget upgrade --all --include-unknown --silent --verbose
	sudo choco upgrade all -y
}

function Show-ThisIsFine
{
	Write-Verbose "Running thisisfine.ps1"
	Show-ColorScript -Name thisisfine
}

function Get-CommandDefinition
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string]$Name
	)

	Write-Verbose "Retrieving definition for command '$Name'"
	Get-Command $Name | Select-Object -ExpandProperty Definition
}

function Invoke-LaravelArtisan
{
	php artisan @args
}

function Remove-ItemForceRecursive
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string]$Path
	)

	Write-Verbose "Removing item '$Path' recursively and forcefully"
	Remove-Item -Path $Path -Recurse -Force
}

function Invoke-OpenCodeWSL
{
	wsl zsh -ic "opencode $($args)"
}

function Reset-GitChanges
{
	git reset --hard
	git clean -df
}

function Get-GitLog
{
	git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
}

function Invoke-Starship-TransientFunction
{
	&starship module character
}

# Shell Integration
Invoke-Expression (&starship init powershell)
Enable-TransientPrompt

Invoke-Expression (& { (zoxide init powershell | Out-String) })

fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression

Import-Module -Name Microsoft.WinGet.CommandNotFound
Import-Module syntax-highlighting
