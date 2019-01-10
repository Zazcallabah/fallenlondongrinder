param([switch]$force)


$script:runTests = $false
$script:runInfraTests = $false

if($env:Home -eq $null)
{
	. $PSScriptRoot/acquisitions.ps1
}
else
{
	. ${env:HOME}/site/wwwroot/Grind/acquisitions.ps1
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
	#"spite,casing,1"
	#"spite,casing,gather"
	"writing"
)



function Get-Action
{
	param($now)
	$selector = $now.DayOfYear
	return $script:actions[$selector%($script:actions.Length)]
}

if($script:runTests)
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

	$action.third | %{
		$result = PerformActionFromCurrent $_
		if( $result -eq $null )
		{
			write-warning "action $_ in $actionstring not found"
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
