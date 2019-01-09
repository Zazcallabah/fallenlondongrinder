param([switch]$force)


$script:runTests = $false

if($env:Home -eq $null)
{
	. $PSScriptRoot/navigation.ps1
}
else
{
	. ${env:HOME}/site/wwwroot/Grind/navigation.ps1
}


$script:actions = @(
	#"ladybones,spirifer,1"
	#"veilgarden,archaeology,1"
	#"veilgarden,literary,1"
	#"veilgarden,seamstress,1"
	#"veilgarden,rescue,publisher"
	#"ladybones,warehouse,1"
	#"carnival,games,high"
	#"watchmakers,Rowdy,unruly"
	#"carnival,big,?"
	#"carnival,sideshows,?"
	#"empresscourt,Matters,artistically"
	#"empresscourt,quiet,1"
	"spite,casing,1"
)


function ParseActionString
{
	param($actionString)
	$spl = $actionString -split ","
	return @{
		"location" = $spl[0];
		"first" = $spl[1];
		"second" = $spl[2];
		"third" = $spl[3];
	}
}

function Get-Action
{
	param($now)
	$selector = $now.DayOfYear
	return $script:actions[$selector%($script:actions.Length)]
}

if($script:runTests)
{
	Describe "ParseActionString" {
		It "splits string" {
			$action = ParseActionString "1, aoeu ,tre"
			$action.location | should be 1
			$action.first | should be " aoeu "
			$action.second | should be "tre"
			$action.third | should be $null
		}
	}
	$script:actions =@( 0,1,2,3,4,5,6 )
	Describe "Get-Action" {
		It "selects based on day of year" {
			Get-Action (new-object datetime 2018,1,1,0,0,0) | should be 1
			Get-Action (new-object datetime 2018,1,1,0,10,0) | should be 1
		}
		It "cycles" {
			Get-Action (new-object datetime 2018,1,6,2,0,0) | should be 6
			Get-Action (new-object datetime 2018,1,7,2,0,0) | should be 0
		}
	}
}

$script:actionHistory = @()
function RecordAction
{
	param($action)
	$script:actionHistory += $action
}

$script:PreRequisites = @{
	"Carnival Ticket" = @("Mysteries,Cryptic Clue,20","Route,Route: Mrs plenty,1");
	"Potential" = @("Curiosity,Manuscript Page,10","Circumstance,Working on...,=31");
	"Compelling Short Story" = @("Progress,Potential,50");
	"Appalling Secret" = @("Mysteries,Cryptic Clue,500");
	"Nightmares" = @("Mysteries,Appalling Secret,10")
}

$script:Acquisitions = @{
	"Cryptic Clue" = "spite,Alleys,Cats,Grey";
	"Carnival Ticket" = "carnival,Buy,clues";
	"Manuscript Page" = "lodgings,writer,rapidly";
	"Potential" = "lodgings,writer,rework,daring";
	"Compelling Short Story" = "";
	"Appalling Secret" = "inventory,Mysteries,Cryptic Clue,great many";
	"Nightmares" = "inventory,Mysteries,Appalling Secret,1";
	"Wounds" = "lodgings,wounds,time";
	"Scandal" = "lodgings,scandal,service";
}

# consumes an action, assumes all possessions neccessary already exists
function Acquire
{
	param( $category, $name, [switch]$dryRun )
	
	$actionStr = $script:Acquisitions[$name]
	if( $actionStr -eq $null )
	{
		throw "No aquisition for $category $name"
	}
	if( $dryRun )
	{
		$result = RecordAction $actionStr
		return $false
	}
	
	return DoAction $actionStr
}

if( $script:runTests )
{
	Describe "Acquire" {
		It "performs action to acquire possession" {
			Acquire "" "Cryptic Clue" -dryRun
			$script:actionHistory.length | should be 1
			$script:actionHistory[0] | should be "spite,Alleys,Cats,grey"
			$script:actionHistory = @()
		}
	}
}


# returns true if named possession is fullfilled
# otherwise an action is consumed trying to work towards fullfillment, which returns false
function Require
{
	param( $category, $name, $level, [switch]$dryRun )
	
	$pos = GetPossession $category $name
	if( $pos -ne $null )
	{
		if( $level[0] -eq "<" )
		{
			# usually menaces, handle state and continue grinding until it passes threshold?
			if( $pos.effectivelevel -lt $level.substring(1) )
			{
				return $true
			}
		}
		elseif( $level[0] -eq "=" )
		{
			# usually "working on...", needs handling of special actions to get specific values
			if( $pos.effectivelevel -eq $level.substring(1) )
			{
				return $true
			}
		}
		else
		{
			if( $pos.effectivelevel -ge $level )
			{
				return $true
			}
		}
	}

	foreach( $prereq in $script:PreRequisites[$name] )
	{
		$action = ParseActionString $prereq
		$hasActionsLeft = Require $action.location $action.first $action.second -dryRun:$dryRun
		if(!$hasActionsLeft)
		{
			return $false
		}
	}
	
	$result = Acquire $category $name -dryRun:$dryRun
	
	return $false
}

function TestPossessionData
{
	param( $category, $name, $level )
	return new-object psobject -property @{
		"name" = $category
		"possessions" = @(@{ "name" = $name; "effectiveLevel" = $level })
	}
}
if( $script:runTests )
{
	Describe "Require" {
	
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Mysteries" "Cryptic Clue" 10),
				(TestPossessionData "Menaces" "Nightmares" 5)
			)
		};
		It "noops if you already have the possession" {
			
			$result = Require "Mysteries" "Cryptic Clue" 5 -dryRun
			$script:actionHistory.length | should be 0
			$result | should be $true
		}
		It "noops if you have exact count" {
			
			$result = Require "Mysteries" "Cryptic Clue" "=10" -dryRun
			$script:actionHistory.length | should be 0
			$result | should be $true
		}
		It "noops if you haven't got enough menaces" {
			
			$result = Require "Menaces" "Nightmares" "<8" -dryRun
			$script:actionHistory.length | should be 0
			$result | should be $true
		}
		It "acquires if you dont have enough of the possession" {
			
			$result = Require "Mysteries" "Cryptic Clue" 15 -dryRun
			$script:actionHistory.length | should be 1
			$script:actionHistory[0] | should be "spite,Alleys,Cats,grey"
			$result | should be $false
			$script:actionHistory = @()
		}
		It "acquires if you dont have exact count" {
			
			$result = Require "Mysteries" "Cryptic Clue" 15 -dryRun
			$script:actionHistory.length | should be 1
			$script:actionHistory[0] | should be "spite,Alleys,Cats,grey"
			$result | should be $false
			$script:actionHistory = @()
		}
		
		It "reduces menaces if you have too much, which cascades to getting clues" {
			
			$result = Require "Menaces" "Nightmares" "<5" -dryRun
			$script:actionHistory.length | should be 1
			$script:actionHistory[0] | should be "spite,Alleys,Cats,grey"
			$result | should be $false
			$script:actionHistory = @()
		}
		$script:actionHistory = @()
		$script:myself = $null
	}
}

function IsInForcedStorylet
{
	if( IsInLocation "confusion" )
	{
		write-warning "a state of some confusion"
		#DoAction "13,drink,1"
		return $true
	}
	# if is in newgate prison (missing id)
	# do nonrisk action to lower suspicion
	return $false
}


function Writing
{
	# missing aquisition for working on 31, how to increase potential beyond 60, choices for other stories, aborting existing workingon, 
	Require "Progress" "Potential" 60

	return $false
}

function EnsureTickets
{
	return Require "Curiosity" "Carnival Ticket" 2
}


function HasMenaces
{
	$hasActionsLeft = Require "Menaces" "Scandal" "<3"
	if( !$hasActionsLeft )
	{
		return $false
	}
	
	$hasActionsLeft = Require "Menaces" "Wounds" "<2"
	if( !$hasActionsLeft )
	{
		return $false
	}

	$hasActionsLeft = Require "Menaces" "Nightmares" "<5"
	if( !$hasActionsLeft )
	{
		return $false
	}
	return $true
}

function LowerNightmares
{
	return Require "Menaces" "Nightmares" "<5"
}

function DoAction
{
	param($actionString)
	
	$action = ParseActionString $actionString

	Write-host "doing action $($action.location) $($action.first) $($action.second) $($action.third)"
	
	if( $action.location -eq "writing" )
	{
		Writing
		return
	}
	
	$result = ExitIfInStorylet
	
	if( !(IsInLocation $action.location) )
	{
		if( $action.location -eq "inventory" )
		{
			DoInventoryAction $action.first $action.second $action.third
			return
		}
		elseif( $action.location -eq "empresscourt" )
		{
			DoAction "shutteredpalace,Spend,1"
		}
		else
		{
			$result = MoveTo $action.location
		}
	}

	# if( IsInLocation "carnival" -and)
	# {
		# if(!(EnsureTickets))
		# {
			# return
		# }
	# }
	
	$result = EnterStoryletAndPerformAction $action.first $action.second
	if( $result -eq $null )
	{
		write-warning "$($action.second) not found"
	}

	if( $action.third -ne $null )
	{
		$result = PerformActionFromCurrent $action.third
		if( $result -eq $null )
		{
			write-warning "second $($action.third) not found"
		}
	}
}


if(!$script:runTests)
{
	if( HasActionsToSpare )
	{
		if( (IsInForcedStorylet) -or (HasMenaces) )
		{
			return
		}
		DoAction (Get-Action ([DateTime]::UtcNow))
	}
}
