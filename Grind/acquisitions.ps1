function MergeAcquisitionsObject
{
	param([parameter(ValueFromPipelineByPropertyName)]$FullName)

	process {
		$inputobject = gc -Raw $FullName | ConvertFrom-Json
		$inputobject.psobject.Properties | %{
			$script:Acquisitions | Add-Member -Membertype NoteProperty -Name $_.Name -Value $_.Value -Force
		}
	}
}

$script:Acquisitions = new-object PSObject

if($env:Home -eq $null)
{
	. $PSScriptRoot/navigation.ps1
	Get-ChildItem "$PSScriptRoot/acquisitions" | MergeAcquisitionsObject
	$script:ItemData = gc $PSScriptRoot/items.csv | ConvertFrom-Csv
}
else
{
	. ${env:HOME}/site/wwwroot/Grind/navigation.ps1
	Get-ChildItem ${env:HOME}/site/wwwroot/Grind/acquisitions | MergeAcquisitionsObject
	$script:ItemData = gc ${env:HOME}/site/wwwroot/Grind/items.csv | ConvertFrom-Csv
}

if($script:runTests)
{
	Describe "Basic acquisitions" {
		It "has grindpersuasive" {
			$script:Acquisitions.GrindPersuasive | should not be $null
			$script:Acquisitions.GrindPersuasive.Action| should be "empresscourt,attend,perform"
		}
		It "has menaces " {
			$script:Acquisitions.Scandal | should not be $null
		}
	}
}

function AddAcquisition
{
	param($name, $result, $action, [int]$reward, $prereq=@())
	$obj = new-object psobject -Property @{
		"Name" = $name;
		"Result" = $result;
		"Prerequisites" = $prereq;
		"Action" = $action;
		"Reward" = $reward;
	}
	$script:Acquisitions | Add-Member -MemberType NoteProperty -Name $name -Value $obj
}

$script:ItemData | %{
	$name = "Default$($_.Economy)$($_.Level)$($_.BoughtItem)"
	$result = $_.BoughtItem
	$p = "$($_.Economy),$($_.Item),$($_.Cost)"
	$action = "inventory,$($_.Economy),$($_.Item),$($_.action)"
	$reward = $_.Gain
	$done = AddAcquisition $name $result $action $reward @($p)
}

$done = AddAcquisition "DefaultMysteries3bJournals" "Journal of Infamy" "inventory,Mysteries,Appalling Secret,duchess" 105 @("Mysteries,Appalling Secret,333", "Contacts,Connected: The Duchess,5")
$done = AddAcquisition "DefaultMysteries4bCorrespondance" "Correspondence Plaque" "inventory,Mysteries,Journal of Infamy,Blackmail" 51 @("Mysteries,Journal of Infamy,50")


function ParseActionString
{
	param($actionString)
	$spl = $actionString -split ","
	return @{
		"location" = $spl[0];
		"first" = $spl[1];
		"second" = $spl[2];
		"third" = if($spl.length -ge 4){@(, $spl[3..($spl.length-1)])}else{$null};
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
	param( $name )

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
			$a.Result | should be "Cryptic Clue"
		}
		It "can find specific result match" {
			$a = LookupAcquisition "Working on..."
			$a.Name | should be "StartNovel"
		}
	}
}


function Sources
{
	param( $name )

	return $script:Acquisitions.PSObject.Properties | ?{ $_.Value.Result -match $name } | select -ExpandProperty Value
}

function GetPossessionLevel
{
	param( $category, $name )
	return GetPossession $category $name | select -ExpandProperty effectiveLevel
}

function GetCostForSource
{
	param( $source, $amountNeeded, [switch]$force )
	if( $amountNeeded -le 0 )
	{
		return 0
	}
	if( !$source.Reward )
	{
		write-warning "no reward for $($source.name)"
		return 10000
	}

	$actionsRequired = [Math]::Ceiling( $amountNeeded / $source.Reward )

	if( !$source.Prerequisites )
	{
		return $actionsRequired
	}

	$prereqCost = $source.Prerequisites | %{
		$split = ParseActionString $_
		$preReqCategory = $split.location
		$preReqItem = $split.first
		$amountPerAction = $split.second
		if( !(IsNumber $amountPerAction) )
		{
			return 0
		}

		$totalAmount = [int]$amountPerAction * $actionsRequired

		$pos = GetPossession $preReqCategory $preReqItem
		$level = $pos.effectiveLevel
		$nature = $pos.nature

		if( $nature -eq "Status" )
		{
			if( $level -ge [int]$amountPerAction )
			{
				return 0
			}
			else
			{
				return 1
			}
		}

		if( $level -ge $totalAmount )
		{
			return 0
		}

		$preReqSources = Sources $preReqItem

		if( !$preReqSources )
		{
			write-warning "no sources for $name"
			return 10000
		}
		$preReqSources | %{
			if( $_.Cost -eq $null -or $force )
			{
				[int]$cost = GetCostForSource $_ ($totalAmount-$level)
				$_ | Add-Member -MemberType NoteProperty -Name Cost -Value $cost -Force
			}
		}
		$preferredSource = $preReqSources | Sort-Object -Property Cost | Select -First 1
		return $preferredSource.Cost
	} | measure -sum | select -expandproperty sum

	return $actionsRequired + $prereqCost
}

function GetAcquisitionByCost
{
	param( $category, $name, $amount, [switch]$force )
	if( !(IsNumber $amount) )
	{
		return LookupAcquisition $name
	}

	$sources = Sources $name

	if( !$sources )
	{
		write-warning "no sources for $name"
		return LookupAcquisition $name
	}

	$level = GetPossessionLevel $category $name
	$amountNeeded = $amount-$level

	$sources | %{
		if($_.Cost -eq $null -or $force )
		{
			[int]$cost = GetCostForSource $_ $amountNeeded
			$_ | Add-Member -MemberType NoteProperty -Name Cost -Value $cost -Force
		}
	}
	return $sources | Sort-Object -Property Cost | Select -First 1
}

function ActionCost
{
	param( $category, $name, $amount, [switch]$force )

	return GetAcquisitionByCost $category $name $amount -force:$force
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
		$acq = GetAcquisitionByCost $category $name $level
	}

	if( $acq -eq $null )
	{
		throw "no way to get $category $name found in acquisitions.json"
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
		"possessions" = @(new-object psobject -property @{ "name" = $name; "effectiveLevel" = $level })
	}
}

if( $script:runtests )
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
			$script:actionHistory[0] | should be "lodgings,wounds,time,1"
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

			$result = Require "Mysteries" "Cryptic Clue" 15 "Cryptic Clue" -dryRun
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


function SetPossessionLevel
{
	param( $category, $name, [int]$level )
	$p = GetPossession $category $name
	if( $p )
	{
		$p.effectiveLevel = $level
		return
	}
	$category = $script:myself.possessions | ?{ $_.name -match $category } | select -first 1
	if( $category )
	{
		$category.possessions += new-object psobject -Property @{
			"name" = $name;
			"category" = $category;
			"effectiveLevel" = $level;
			"level" = $level;
		}
	}
}

if($script:runTests)
{
	Describe "GetCostforSource" {
		It "knows how to get 1000 romantic notions" {
			SetPossessionLevel "Nostalgia" "Romantic Notion" 0
			SetPossessionLevel "Nostalgia" "Drop of Prisoner's Honey" 0
			$sources = Sources "Romantic Notion"
			GetCostForSource $sources[0] 1000 -force | should be 110
		}
		It "knows how to get 500 hints" {
			SetPossessionLevel "Mysteries" "Whispered hint" 0
			$sources = Sources "Whispered Hint"
			GetCostForSource $sources[0] 500 -force | should be 8
		}
		It "includes prereq cost" {
			SetPossessionLevel "Mysteries" "Whispered hint" 0
			$sources = Sources "Cryptic Clue"
			GetCostForSource $sources[0] 1 -force | should be 1
			GetCostForSource $sources[1] 1 -force | should be 9
		}
		It "accounts for existing inventory" {
			SetPossessionLevel "Mysteries" "Whispered hint" 499
			$sources = Sources "Cryptic Clue"
			GetCostForSource $sources[0] 1 -force | should be 1
			GetCostForSource $sources[1] 1 -force | should be 2
		}
	}
}

if($script:runTests)
{
	Describe "ActionCost" {
		It "returns 1 if not in inventory and missing exactly reward" {
			SetPossessionLevel "Mysteries" "Whispered hint" 0
			$c = ActionCost "Mysteries" "Whispered Hint" 66 -force
			$c.Cost | should be 1
			$c.Action | should be "flit,its king,meeting,understand"
		}
		It "returns 2 if not in inventory and requesting exactly one more than reward" {
			SetPossessionLevel "Mysteries" "Whispered hint" 0
			$c = ActionCost "Mysteries" "Whispered Hint" 67 -force
			$c.Cost | should be 2
			$c.Action | should be "flit,its king,meeting,understand"
		}
		It "returns 1 if one in inventory and requesting exactly one more than reward" {
			SetPossessionLevel "Mysteries" "Whispered hint" 1
			$c = ActionCost "Mysteries" "Whispered Hint" 67 -force
			$c.Cost | should be 1
			$c.Action | should be "flit,its king,meeting,understand"
		}
	}
	Describe "Sources" {
		It "can get sources for item" {
			$sources = Sources "Cryptic Clue"
			$sources.Count | should be 2
			$sources[0].Name | should be "Cryptic Clue"
			$sources[1].Name | should be "DefaultMysteries1Cryptic Clue"
		}
	}

	Describe "ActionCost with Sources" {
		It "uses the fastest source to get answer" {
			SetPossessionLevel "Mysteries" "Cryptic Clue" 0
			SetPossessionLevel "Mysteries" "Whispered hint" 499
			$c = ActionCost "Mysteries" "Cryptic Clue" 1 -force
			$c.Cost | should be 1
			$c.Action | should be "spite,Alleys,Cats,Grey"

			$c = ActionCost "Mysteries" "Cryptic Clue" 200 -force
			$c.Cost | should be 2
			$c.Action | should be "inventory,Mysteries,Whispered Hint,combine"
		}
		It "gives correct cost when prereq is partially fulfilled" {
			AddAcquisition "Hand" "Hand" "get hand" 1 @("Curiosity,Finger,5")
			AddAcquisition "Finger" "Finger" "get finger" 1
			SetPossessionLevel "Curiosity" "Finger" 3
			$c = ActionCost "Curiosity" "Hand" 2 -force
			$c.Cost | should be 9
		}
	}
}
