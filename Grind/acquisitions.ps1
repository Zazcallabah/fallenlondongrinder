
if($env:Home -eq $null)
{
	. $PSScriptRoot/navigation.ps1
	$script:Acquisitions = gc -Raw $PSScriptRoot/acquisitions.json | ConvertFrom-Json
}
else
{
	. ${env:HOME}/site/wwwroot/Grind/navigation.ps1
	$script:Acquisitions = gc -Raw ${env:HOME}/site/wwwroot/Grind/acquisitions.json | ConvertFrom-Json
}

function ParseActionString
{
	param($actionString)
	$spl = $actionString -split ","
	return @{
		"location" = $spl[0];
		"first" = $spl[1];
		"second" = $spl[2];
		"third" = if($spl.length -ge 4){@(,$spl[3..($spl.length-1)])}else{$null};
	}
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
		It "leaves tail if longer than 4" {
			$action = ParseActionString "1,2,3,4,5"
			$action.location | should be 1
			$action.first | should be 2
			$action.second | should be 3
			$action.third.length | should be 2
			$action.third[0] | should be 4
			$action.third[1] | should be 5
		}
		It "can return exactly four results" {
			$action = ParseActionString "a,b,c,de"
			$action.location | should be "a"
			$action.first | should be "b"
			$action.second | should be "c"
			$action.third | should be "de"
		}
		It "returns null if trying to index nonexistent third entry" {
			$action = ParseActionString "aaa,bbb,ccc,def"
			$action.location | should be "aaa"
			$action.first | should be "bbb"
			$action.second | should be "ccc"
			$action.third[0] | should be "def"
			$action.third[1] | should be $null
		}
	}
}



$script:actionHistory = @()

function RecordAction
{
	param($action)
	$script:actionHistory += $action
}

# consumes an action, assumes all possessions neccessary already exists
function Acquire
{
	param( $actionStr, [switch]$dryRun )
	
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
			Acquire "spite,Alleys,Cats,grey" -dryRun
			$script:actionHistory.length | should be 1
			$script:actionHistory[0] | should be "spite,Alleys,Cats,grey"
			$script:actionHistory = @()
		}
	}
}




function LookupAcquisition
{
	param($name)

	if( $name -eq $null )
	{
		return $null
	}
	
	if($script:Acquisitions."$name" -ne $null )
	{
		return $script:Acquisitions."$name"
	}
	
	$nameMatches = $script:Acquisitions.PSObject.Properties | ?{ $_.Name -match $name } | select -first 1 -expandproperty Value
	if( $nameMatches -ne $null )
	{
		return $nameMatches
	}
	
	return $script:Acquisitions.PSObject.Properties | ?{ $_.Value.Result -match $name } | select -first 1 -ExpandProperty Value
}

if( $script:runtests )
{
	Describe "LookupAcquisition" {
		It "can find exact name" {
			$a = LookupAcquisition "Suspicion"
			$a.Action | should be "inventory,Curiosity,Ablution Absolution,1"
		}
		It "can find partial name match" {
			$a = LookupAcquisition "clue"
			$a.Name | should be "Cryptic Clue"
		}
		It "can find specific result match" {
			$a = LookupAcquisition "Working on..."
			$a.Name | should be "StartNovel"
		}
	}
}





# returns true if named possession is fullfilled
# otherwise an action is consumed trying to work towards fullfillment, which returns false
function Require
{
	param( $category, $name, $level, $tag, [switch]$dryRun )
	
	$pos = GetPossession $category $name

	if( $level -eq $null )
	{
		$level = ""
	}

	if( $level[0] -eq "<" )
	{
		# usually menaces, handle state and continue grinding until it passes threshold?
		# for menaces, not having possession means less than, so return true
		
		# note that if we are in a forced storylet, that would be detected before we get here
		
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
	
	$acq = LookupAcquisition $tag
	
	if( $acq -eq $null )
	{
		$acq = LookupAcquisition $name
	}
	
	foreach( $prereq in $acq.Prerequisites )
	{
		$action = ParseActionString $prereq
		$hasActionsLeft = Require $action.location $action.first $action.second $action.third -dryRun:$dryRun
		if(!$hasActionsLeft)
		{
			return $false
		}
	}

	$result = Acquire $acq.Action -dryRun:$dryRun
	
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
				(TestPossessionData "" "Dangerous" 100),
				(TestPossessionData "Mysteries" "Cryptic Clue" 10),
				(TestPossessionData "Menaces" "Nightmares" 5)
			)
		};
		It "performs action regardless if level is null" {
			$result = Require "Menaces" "Wounds" -dryRun
			$script:actionHistory.Length | should be 1
			$script:actionHistory[0] | should be "lodgings,wounds,time"
			$script:actionHistory = @()
		}
		It "can tag specific acquisition to run in requirements" {
			$result = Require "Circumstance" "Working on..." 100 "StartShortStory" -dryRun
			$script:actionHistory.Length | should be 1
			$script:actionHistory[0] | should be "veilgarden,begin a work,short story"
			$script:actionHistory = @()
		}
		It "can tag another specific acquisition to run in requirements" {
			$result = Require "Circumstance" "Working on..." 100 "StartNovel" -dryRun
			$script:actionHistory.Length | should be 1
			$script:actionHistory[0] | should be "empresscourt,next work,novel"
			$script:actionHistory = @()
		}
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
		It "acquires if possession not found" {
			
			$result = Require "Menaces" "Scandal" 15 -dryRun
			$script:actionHistory.length | should be 1
			$script:actionHistory[0] | should be "lodgings,scandal,service"
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