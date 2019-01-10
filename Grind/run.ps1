param([switch]$force)


$script:runTests = $false
$script:runInfraTests = $false

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
	"flit,preparing,assistance"
	#"spite,casing,gather"
	#"writing"
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


# function WorkingOn
# {
	# workingon 31
	# action to start
	# require potential 60
	# action to finish
	# competent or compelling results
	# sell result no matter which
# }

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
	"Compelling Short Story" = @("Progress,Potential,60");
	"Competent Short Story" = @("Progress,Potential,60");
	"Appalling Secret" = @("Mysteries,Cryptic Clue,500");
	"Nightmares" = @("Mysteries,Appalling Secret,10");
	"Penny" = @("Curiosity,Competent Short Story,1"); # workking on not null, writing doesnt currently end? push for which level?
	"Suspicion" = @("Curiosity,Ablution Absolution,1")
	"Ablution Absolution" = @("Currency,Penny,150");
	"Fascinating..." = @("Progress,Inspired...,34");
	"Inspired..." = @("Circumstance,Working on...,=2");
}

$script:Acquisitions = @{
	"Cryptic Clue" = "spite,Alleys,Cats,Grey";
	"Carnival Ticket" = "carnival,Buy,clues";
	"Manuscript Page" = "lodgings,writer,rapidly";
	"Potential" = "lodgings,writer,rework,daring";
	"Compelling Short Story" = "lodgings,writer,rework,finish?";
	"Competent Short Story" = "lodgings,writer,rework,finish?";
	"Appalling Secret" = "inventory,Mysteries,Cryptic Clue,great many";
	"Nightmares" = "inventory,Mysteries,Appalling Secret,1";
	"Wounds" = "lodgings,wounds,time";
	"Scandal" = "lodgings,scandal,service";
	"Suspicion" = "inventory,Curiosity,Ablution Absolution,1";
	"Penny" = "sell,Curiosity,Competent Short Story,1";
	"Ablution Absolution" = "buy,Nikolas,Absolution,1";
	"Fascinating..." = "empresscourt,complete,gothic romance" 
	#another fascinating is "empresscourt,attend,perform", more random but not quite as grindy
	"Inspired..." = "empresscourt,quiet,1";
}


# empresscourt,complete,
# 	gothic romance - 6000 moon pearls, fascinating, making waves
#	tale of the future - connected benthic, connected summerset,making waves, 6000 brass silver
# 	patriotic adventure - 6000 moon perals, making waves
# use fascinating to do romance options in empresscourt, which requires fascinating 11? 10?


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
	
	$actionResult = DoAction $actionStr
	return $false;
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

	if( $level[0] -eq "<" )
	{
		# usually menaces, handle state and continue grinding until it passes threshold?
		# for menaces, not having possession means less than, so return true
		if( $pos -eq $null -or $pos.effectivelevel -lt $level.substring(1) )
		{
			return $true
		}
	}
	elseif( $level[0] -eq "=" )
	{
		# usually "working on...", needs handling of special actions to get specific values
		if( $pos -eq $null )
		{
			# not occupied, "switch" action?
			# working on 2 is "empresscourt,next work,novel" [poetry,stage,song,symphony,ballet]
			# working on 31 is "veilgarden,begin a work,short story"
		}
		if( $pos -ne $null -and $pos.effectivelevel -eq $level.substring(1) )
		{
			return $true
		}
	}
	else
	{
		if( $pos -ne $null -and $pos.effectivelevel -ge $level )
		{
			return $true
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
	$hasMoreActions = Require "Progress" "Potential" 62
	if( $hasMoreActions )
	{
		$r=DoAction "veilgarden,literary,1"
	}
	return $false
}

function EnsureTickets
{
	return Require "Curiosity" "Carnival Ticket" 2
}


function CheckMenaces
{
	$hasActionsLeft = Require "Menaces" "Scandal" "<4"
	if( !$hasActionsLeft )
	{
		return $false
	}
	
	$hasActionsLeft = Require "Menaces" "Wounds" "<4"
	if( !$hasActionsLeft )
	{
		return $false
	}

	$hasActionsLeft = Require "Menaces" "Nightmares" "<5"
	if( !$hasActionsLeft )
	{
		return $false
	}
	
	$hasActionsLeft = Require "Menaces" "Suspicion" "<6"
	if( !$hasActionsLeft )
	{
		return $false
	}
	
	return $true
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
		elseif( $action.location -eq "buy" )
		{
			BuyPossession $action.first $action.second $action.third
			return
		}
		elseif( $action.location -eq "sell" )
		{
			SellPossession $action.first $action.second
			return
		}
		elseif( $action.location -eq "writing" )
		{
			Writing
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
		if( (IsInForcedStorylet) )
		{
			return
		}
		$hasActionsLeft = CheckMenaces
		if( $hasActionsLeft )
		{
			DoAction (Get-Action ([DateTime]::UtcNow))
		}
	}
}
