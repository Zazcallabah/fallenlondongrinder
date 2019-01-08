param([switch]$runTests,[switch]$force)


if($env:Home -eq $null)
{
	. $PSScriptRoot/navigation.ps1 -runTests:$runTests
}
else
{
	. ${env:HOME}/site/wwwroot/Grind/navigation.ps1 -runTests:$runTests
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
	"empresscourt,quiet,1"
)

function Get-Action
{
	param($now)
	$selector = $now.DayOfYear
	return $script:actions[$selector%($script:actions.Length)]
}

if($runTests)
{
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


function Require
{
	param( $category, $name, $level )
	
	$pos = GetPossession $category $name
	if( $pos -ne $null -and $pos.level -ge $level )
	{
		return $true
	}
	
	#require prerequisites
	#perform required action
	
	return $false
}

function Writing
{
	$potential = GetPossession "Progress" "Potential"
	if( $potential -eq $null )
	{
		# start new?
		return $false
	}
	
	$pages = GetPossession "Curiosity" "Manuscript Page"
	if($pages -eq $null -or $pages.level -le 10 )
	{
		DoAction "lodgings,writer,rapidly"
		return $true
	}
	
	if( $potential.level -le 60 )
	{
		DoAction "lodgings,writer,rework,daring"
		return $true
	}
	
	return $false
}

function EnsureTickets
{
	$tickets = GetPossession "Curiosity" "Carnival Ticket"
	if( $tickets -ne $null -and $tickets.level -ge 2 )
	{
		return $true
	}
	write-host "need tickets for the carnival"
	$clues = GetPossession "Mysteries" "Cryptic Clue"
	
	if( $clues -ne $null -and $clues.level -ge 20 )
	{
		Write-Host "buying tickets using clues"
		EnterStoryletAndPerformAction "Buy" "clues"
	}
	else
	{
		Write-host "catch a grey cat for clues"
		DoAction "spite,Alleys,Cats,Grey"
	}

	return $false
}

# $script:Aquisition = @{
	# "Cryptic Clue" = "inventory"
# }

function LowerNightmares
{
	$secrets = GetPossession "Mysteries" "Appalling Secret"
	if( $secrets -ne $null -and $secrets.level -ge 10 )
	{
		Write-host "using secret to lower nightmares"
		UseItem $secrets.id "1"
		return
	}
	# else "spite,Alleys,Cats,Black"? - no, only 1 secret/action instead of 70/21 actions
	$clues = GetPossession "Mysteries" "Cryptic Clue"
	if( $clues -ne $null -and $clues.level -ge 500 )
	{
		Write-host "converting clues to secrets"
		UseItem $clues.id "great many"
		return
	}
	Write-host "catch a grey cat for clues"
	DoAction "spite,Alleys,Cats,Grey"
}

function HasMenaces
{
	$scandal = GetPossession "Menaces" "Scandal"
	if( $scandal -ne $null -and $scandal.effectiveLevel -ge 3 )
	{
		write-host "lowering scandal"
		DoAction "lodgings,scandal,service"
		return $true
	}
	$wounds = GetPossession "Menaces" "Wounds"
	if( $wounds -ne $null -and $wounds.effectiveLevel -ge 2 )
	{
		write-host "lowering wounds"
		DoAction "lodgings,wounds,time"
		return $true
	}
	$nightmares = GetPossession "Menaces" "Nightmares"
	if( $nightmares -ne $null -and $nightmares.effectiveLevel -ge 5 )
	{
		write-host "has nightmares"
		LowerNightmares
		return $true
	}
	return $false
}

function DoAction
{
	param($location,$storyletname,$branchname,$secondbranch)
	
	if( $storyletname -eq $null )
	{
		$spl = $location -split ","
		$location = $spl[0]
		$storyletname = $spl[1]
		$branchname = $spl[2]
		if($spl.length -gt 3)
		{
			$secondbranch = $spl[3]
		}
	}
	Write-host "doing action $location $storyletname $branchname $secondbranch"
	
	if( $location -eq "writing" )
	{
		Writing
		return
	}
	
	$result = ExitIfInStorylet
	
	if( !(IsInLocation $location) )
	{
		if( $location -eq "inventory" )
		{
			DoInventoryAction $storyletname $branchname $secondbranch
			return
		}
		elseif( $location -eq "empresscourt" )
		{
			DoAction "shutteredpalace,Spend,1"
		}
		else
		{
			$result = MoveTo $location
		}
	}

	if( IsInLocation "carnival" )
	{
		if(!(EnsureTickets))
		{
			return
		}
	}
	
	$result = EnterStoryletAndPerformAction $storyletname $branchname
	if( $result -eq $null )
	{
		write-warning "$branchname not found"
	}

	if( $secondbranch -ne $null )
	{
		$result = PerformActionFromCurrent $secondbranch
		if( $result -eq $null )
		{
			write-warning "second $secondbranch not found"
		}
	}
}


if(!$runTests)
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
