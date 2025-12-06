<#
	Gww • T1xx1 
#>

param(
	[string] $cmd
)

<#
	gww
#>
$gwwRoot = Join-Path $PSScriptRoot "../";
$gwwInfo = Get-Content (Join-Path $gwwRoot "gww.json") | ConvertFrom-Json

<#
	global
#>
$wt = git branch --show-current 2> $null
$wtRoot = git rev-parse --show-toplevel 2> $null

<# repository #>
if ($null -eq $wtRoot) {
	Write-Host "$PWD is not a .git repository" -ForegroundColor Red

	exit
}

Invoke-Expression "git worktree prune"

$branches = git branch | ForEach-Object {
	($_ -split "\s+")[1]
}
$wts = git worktree list | ForEach-Object {
	(($_ -split "\s+")[2] -replace "\[","" -replace "\]","")
}

<# config #>
$configType
$config

if (Join-Path $wtRoot ".config/gww.json" | Test-Path) {
	$configType = "folder"
	$config = Get-Content (Join-Path $wtRoot ".config/gww.json") | ConvertFrom-Json
}
if (Join-Path $wtRoot "gww.config.json" | Test-Path) {
	$configType = "file"
	$config = Get-Content (Join-Path $wtRoot "gww.config.json") | ConvertFrom-Json
}

$defaultConfig = [PSCustomObject]@{
	mainBranch = "main"
	worktreesDir = "../"
	pathPrefix = ($wtRoot -split "/")[-1] + "-"
}

if (-not $config) {
	$configType = "file"
	$config = $defaultConfig

	Set-Content (Join-Path $wtRoot "gww.config.json") (ConvertTo-Json $config)
	
	Write-Host "Gww config initialized`n" -ForegroundColor Green
}

if ((-not $config.mainBranch) -or (-not $config.worktreesDir) -or (-not $config.pathPrefix)) {
	if (-not $config.mainBranch) {
		$config | Add-Member -MemberType NoteProperty -Name "mainBranch" -Value $defaultConfig.mainBranch
	}
	
	if (-not $config.worktreesDir) {
		$config | Add-Member -MemberType NoteProperty -Name "worktreesDir" -Value $defaultConfig.worktreesDir
	}
	
	if (-not $config.pathPrefix) {
		$config | Add-Member -MemberType NoteProperty -Name "pathPrefix" -Value $defaultConfig.pathPrefix
	}

	Set-Content (Join-Path $wtRoot "gww.config.json") (ConvertTo-Json $config)
	
	Write-Host "Gww config tweaked`n" -ForegroundColor Green
}

<# wt #>
function Get-WtRoot {
	param(
		[string] $w
	)

	git worktree list | ForEach-Object {
		$worktree = $_ -split "\s+"

		if ($w -eq ($worktree[2] -replace "\[","" -replace "\]","")) {
			return $worktree[0]
		}
	}
}

$mainWt = $config.mainBranch
$mainWtRoot	= Get-WtRoot $mainWt

<#
	functions
#>
function Build-WtRoot {
	param(
		[Parameter(Mandatory=$true)]
		[string] $w
	)

	$wr = $w

	<# pathPrefix #>
	$wr = $config.pathPrefix + $wr

	<# worktreesDir #>
	$wr = Join-Path $mainWtRoot $config.worktreesDir $wr

	return $wr
}
function Build-Worktree {
	param(
		[string] $wr
	)

	<# gww.config.json #>
	Copy-Item (Join-Path $wtRoot "gww.config.json") (Join-Path $wr "gww.config.json")

	<# configs #>
	if ($config.configs) {
		foreach ($file in $config.configs) {
			$filePath = Join-Path $wtRoot $file

			if (Test-Path $filePath) {
				Copy-Item $filePath (Join-Path $path $file)
			}
		}

		Write-Host "Configs copied"
	}

	<# submodules #>
	if (Join-Path $wtRoot ".gitmodules" | Test-Path) {
		Invoke-Expression "git submodule update --init --recursive --quiet"

		Write-Host "Submodules initialized"
	}

	<# postCreate #>
	if ($config.postCreate) {
		Write-Host "Running postCreate"

		Invoke-Expression $config.postCreate

		Write-Host "postCreate ran"
	}

	<# checkout #>
	$checkout

	if ($config.checkout) {
		$checkout = $config.checkout
	} else {
		$checkout = "always"
	}

	switch ($checkout) {
		"prompt" {
			if (Read-Host "> Checkout $wr? [y/n]" -eq "y") {
				Set-Location $wr
			}
		}
		"always" {
			Set-Location $wr
		}
	}
}

<#
	main
#>
switch ($cmd) {
	{$_ -in "","help","h"} {
		Get-Content (Join-Path $gwwRoot "src/cmds.txt") | Write-Host
	}

	{$_ -in "info","i","version","v"} {
		Write-Host $gwwInfo.name $gwwInfo.version

		Invoke-Expression "git -v"
	}

	{$_ -in "branches","bs"} {
		if ($mainWt -eq $wt) {
			Write-Host "- $mainWt (main) (current)" -ForegroundColor Green
		} else {
			Write-Host "- $mainWt (main)" -ForegroundColor Blue
		}

		git branch | ForEach-Object {
			$b = ($_ -split "\s+")[1]

			if ($mainWt -ne $b) {
				if ($wt -eq $b) {
					Write-Host "- $b (current)" -ForegroundColor Green
				} else {
					Write-Host "- $b" -ForegroundColor Blue
				}
			}
		}
	}
	{$_ -in "list","ls","worktrees","wts"} {
		if ($mainWt -eq $wt) {
			Write-Host "- $mainWt (main) (current)" -ForegroundColor Green
		} else {
			Write-Host "- $mainWt (main)" -ForegroundColor Blue
		}

		git worktree list | ForEach-Object {
			$b = (($_ -split "\s+")[2] -replace "\[","" -replace "\]","")

			if ($mainWt -ne $b) {
				if ($wt -eq $b) {
					Write-Host "- $b (current)" -ForegroundColor Green
				} else {
					Write-Host "- $b" -ForegroundColor Blue
				}
			}
		}
	}
	{$_ -in "new","n","+"} {
		$w = $Args[0]
		
		if (-not $Args[0]) {
			Write-Host "> gww new <worktree>" -ForegroundColor Red

			exit
		}

		if ($w -in $branches) {
			Write-Host "'$wt' branch already exists" -ForegroundColor Red
			Write-Host "Use 'gww open' to open it in a worktree"

			exit
		}

		$wr = Build-WtRoot $w

		Write-Host "Creating worktree"

		Invoke-Expression "git worktree add $wr -b $w --quiet"
		
		Build-Worktree $wr

		Write-Host "Worktree created" -ForegroundColor Green
	}
	{$_ -in "remove","rm","-"} {
		$w = $Args[0]

		if (-not $w) {
			Write-Host "> gww remove <worktree>" -ForegroundColor Red

			exit
		}

		if (-not ($w -in $wts)) {
			Write-Host "$w worktree does not exists" -ForegroundColor Red

			exit
		}

		Write-Host "Removing worktree"

		<# checkout #>
		if ($wt -eq $w) {
			Set-Location $mainWtRoot

			Write-Host "Checking out"
		}

		$wr = Get-WtRoot $w

		Invoke-Expression "git worktree remove $wr --force"
		Invoke-Expression "git branch -d $w --quiet"

		Write-Host "Worktree removed" -ForegroundColor Green
	}
	{$_ -in "open"} {
		$b = $Args[0]

		if (-not $b) {
			Write-Host "> gww open <branch>" -ForegroundColor Red

			exit
		}

		if (-not ($b -in $branches)) {
			Write-Host "'$b' branch does not exist" -ForegroundColor Red

			exit
		}

		Write-Host "Opening branch"

		$wr = Build-WtRoot $b

		Invoke-Expression "git worktree add $wr $b --quiet"

		Build-Worktree $wr

		Write-Host "Worktree opened" -ForegroundColor Green
	}
	{$_ -in "close"} {
		$w = $Args[0]

		if (-not $w) {
			Write-Host "> gww close <worktree>" -ForegroundColor Red

			exit
		}

		if (-not ($w -in $wts)) {
			Write-Host "'$w' worktree does not exist" -ForegroundColor Red

			exit
		}

		Write-Host "Closing worktree"

		<# checkout #>
		if ($wt -eq $w) {
			Set-Location $mainWtRoot

			Write-Host "Checking out"
		}

		$wr = Get-WtRoot $w

		Invoke-Expression "git worktree remove $wr --force"

		Write-Host "Worktree closed" -ForegroundColor Green
	}
	{$_ -in "checkout"} {
		$w = $Args[0]

		if (-not $w) {
			Write-Host "> gww checkout <worktree>" -ForegroundColor Red

			exit
		}

		if (-not ($w -in $wts)) {
			Write-Host "'$w' worktree does not exist" -ForegroundColor Red

			exit
		}

		Get-WtRoot $w | Set-Location
	}
	{$_ -in "rename","rn"} {
		$w = $Args[0]
		$nw = $Args[1]

		if ((-not $w) -or (-not $nw)) {
			Write-Host "> gww rename <worktree> <name>" -ForegroundColor Red

			exit
		}

		if (-not ($wt -in $wts)) {
			Write-Host "'$wt' worktree does not exist" -ForegroundColor Red

			exit
		}

		if ($mainWt -eq $w) {
			if (-not ((Read-Host "> Warning: You are on the main branch. Are you sure you want to rename the main branch? [y/n]") -eq "y")) {
				exit
			}
		}

		<# checkout #>
		$checkout = $false

		if ($wt -eq $w) {
			$checkout = $true

			Set-Location $mainWtRoot
		}

		$wr = Get-WtRoot $w
		$nwr = Build-WtRoot $nw

		Invoke-Expression "git branch -m $w $nw --quiet"
		Invoke-Expression "git worktree move $wr $nwr"

		if ($checkout) {
			Set-Location $nwr
		}

		Write-Host "Renamed worktree" -ForegroundColor Green
	}

	{$_ -in "config"} {
		switch ($Args[0]) {
			{$_ -in $null,""} {
				ConvertTo-Json $config | Write-Host
			}
			{$_ -in "get"} {
				$property = $Args[1]

				if (-not $property) {
					Write-Host "> gww config get <property>"

					exit
				}

				if (-not $config.$property) {
					Write-Host "'$property' property does not exist" -ForegroundColor Red

					exit
				}

				Write-Host $config.$property
			}
			{$_ -in "set"} {
				$property = $Args[1]
				$value = $Args[2]

				if ((-not $property) -or (-not $value)) {
					Write-Host "> gww config set <property> <value>"

					exit
				}

				if ($config.$property) {
					$config.$property = $value
				} else {
					$config | Add-Member $property $value
				}

				switch ($configType) {
					"folder" {
						ConvertTo-Json $config | Set-Content (Join-Path $wtRoot ".config/gww.json")
					}
					"file" {
						ConvertTo-Json $config | Set-Content (Join-Path $wtRoot "gww.config.json")
					}
				}

				Write-Host "Set '$property' property to '$value'" -ForegroundColor Green
			}
			{$_ -in "remove","rm"} {
				$property = $Args[1]

				if (-not $property) {
					Write-Host "> gww config remove <property>"

					exit
				}

				if (-not $config.$property) {
					Write-Host "'$property' property does not exist" -ForegroundColor Red
				}

				$config.PSObject.Properties.Remove($property)

				switch ($configType) {
					"folder" {
						$config | ConvertTo-Json | Set-Content (Join-Path $wtRoot ".config/gww.json")
					}
					"file" {
						$config | ConvertTo-Json | Set-Content (Join-Path $wtRoot "gww.config.json")
					}
				}

				Write-Host "Removed '$property' property" -ForegroundColor Green
			}
		}
	}
	{$_ -in "postcreate","pc"} {
		if (-not $config.postCreate) {
			Write-Host "Gww config does not define a postCreate script"

			exit
		}

		Write-Host "Running postCreate"

		Invoke-Expression $config.postCreate

		Write-Host "postCreate ran" -ForegroundColor Green
	}

	default {
		Write-Host "'$cmd' is not a Gww command" -ForegroundColor Red
	}
}

exit
