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
	return $actionResult;
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
		throw "no way to get $category $name found in acquisitions list"
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

	if( $acq.Cards -ne $null )
	{
		$opportunity = DrawOpportunity
		foreach( $card in $acq.Cards )
		{
			$c = ParseActionString $card

			$card = $opportunity.displayCards | ?{ $_.name -match $c.location -or $_.eventId -eq $c.location } | select -first 1
			if( $card )
			{
				$result = ActivateOpportunityCard $opportunity $card $c.first
				if( $result -ne $null )
				{
					return $result
				}
			}
		}
	}

	$result = Acquire $acq.Action -dryRun:$dryRun

	return $result
}

function TestPossessionData
{
	param( $category, $name, $level )
	return new-object psobject -property @{
		"name" = $category
		"possessions" = @(new-object psobject -property @{ "name" = $name; "effectiveLevel" = $level })
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
