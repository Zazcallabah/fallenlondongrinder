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
	#"veilgarden,archaeology,1" persuasive 31 shreik
	#"veilgarden,literary,1" persuasive 5 gets rusty/glim/jade also
	#"veilgarden,rescue,publisher" persuasive 47, proscribed material

	#"ladybones,warehouse,1" - nevercold

	#"carnival,games,high"

	#"carnival,big,?"
	#"carnival,sideshows,?"

	#"empresscourt,Matters,artistically"
	#"spite,casing,gather"
	#"writing"
	"cascade,Goods,Supplies,80"
	"cascade,Progress,Casing...,5,PrepBaseborn"
	"cascade,Elder,Presbyterate Passphrase,9"
	"cascade,Basic,Persuasive,100,GrindPersuasive" #95
	"cascade,Basic,Dangerous,100,GrindDangerous" # 39
	"cascade,Basic,Shadowy,100,GrindShadowy" #63
	"cascade,Basic,Watchful,100,GrindWatchful" # 66
)




function Get-Action
{
	param($now, [int]$index)
	$selector = $now.DayOfYear
	if( $index -ne $null )
	{
		$selector += $index
	}
	return $script:actions[$selector%($script:actions.Length)]
}

if($script:runTests)
{
	$script:actions =@( 0, 1, 2, 3, 4, 5, 6 )
	Describe "Get-Action" {
		It "selects based on day of year" {
			Get-Action (new-object datetime 2018, 1, 1, 0, 0, 0) | should be 1
			Get-Action (new-object datetime 2018, 1, 1, 0, 10, 0) | should be 1
		}
		It "cycles" {
			Get-Action (new-object datetime 2018, 1, 6, 2, 0, 0) | should be 6
			Get-Action (new-object datetime 2018, 1, 7, 2, 0, 0) | should be 0
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

function EarnestPayment
{
	return Require "Curiosity" "An Earnest of Payment" "<1" "Payment"
}

function EnsureTickets
{
	return Require "Curiosity" "Carnival Ticket" 2
}

function LowerWounds
{
	HandleMenaces -upperbound 5 -lowerbound 2 -actionstr "require,Menaces,Wounds,<3" -marker "Invite someone to a Sparring Bout" -menace "Wounds"
}

function LowerSuspicion
{
	HandleMenaces -upperbound 6 -lowerbound 2 -actionstr "require,Menaces,Suspicion,<3" -marker "Invite someone to a spot of Suspicious Loitering" -menace "Suspicion"
}

function LowerNightmares
{
	HandleMenaces -upperbound 5 -lowerbound 2 -actionstr "require,Menaces,Nightmares,<3" -marker "Invite someone to a Game of Chess" -menace "Nightmares"
}

function LowerScandal
{
	HandleMenaces -upperbound 5 -lowerbound 2 -actionstr "require,Menaces,Scandal,<3" -marker "Meet someone for a Coffee at Caligula's" -menace "Scandal"
}

function HandleMenaces
{
	param( $upperbound, $lowerbound, $actionstr, $marker, $menace )

	$planstr = "lodgings,$($menace),$marker"
	$planname = $marker
	$plan = Get-Plan $planname

	if( $plan -ne $null )
	{
		$result = DoAction $actionstr
		$script:myself = $null
		$pos = GetPossession "Menaces" $menace
		if($pos.effectiveLevel -le $lowerbound)
		{
			DeleteExistingPlan $planName
		}
		return $false
	}

	$pos = GetPossession "Menaces" $menace
	if($pos.effectiveLevel -ge $upperbound )
	{
		$result = CreatePlanFromActionString $planstr
		$result = DoAction $actionstr
		return $false
	}
	return $true
}

function CheckMenaces
{
	$hasActionsLeft = LowerScandal
	if( !$hasActionsLeft )
	{
		return $false
	}

	$hasActionsLeft = LowerWounds
	if( !$hasActionsLeft )
	{
		return $false
	}

	$hasActionsLeft = LowerNightmares
	if( !$hasActionsLeft )
	{
		return $false
	}

	$hasActionsLeft = LowerSuspicion
	if( !$hasActionsLeft )
	{
		return $false
	}

	return $true
}



function DoAction
{
	param($actionString, [int]$index = 1)

	$action = ParseActionString $actionString

	Write-host "doing action $($action.location) $($action.first) $($action.second) $($action.third)"

	if( (User).setting -ne $null -and !(User).setting.canTravel )
	{
		# canTravel false means you are in a locked storylet
		# also user.setting.itemsUsableHere
		return
	}

	# bazaar can usually be done even in storylet, i think?
	# require is best done doing its inventory checks before doing goback and move, to aviod extra liststorylet calls
	# inventory just needs to make sure we do gobackifinstorylet first
	if( $action.location -eq "buy" )
	{
		BuyPossession $action.first $action.second $action.third
		return
	}
	elseif( $action.location -eq "sell" )
	{
		SellPossession $action.first $action.second
		return
	}
	elseif( $action.location -eq "cascade" )
	{
		$hasActionsLeft = Require $action.first $action.second $action.third[0] $action.third[1]
		if($hasActionsLeft)
		{
			if( $index -ge $script:actions.Length )
			{
				return
			}
			DoAction (Get-Action ([DateTime]::UtcNow) $index) ($index+1)
		}
		return
	}
	elseif( $action.location -eq "require" )
	{
		$hasActionsLeft = Require $action.first $action.second $action.third[0] $action.third[1]
		return
	}
	elseif( $action.location -eq "inventory" )
	{
		DoInventoryAction $action.first $action.second $action.third
		return
	}
	elseif( $action.location -eq "writing" )
	{
		Writing
		return
	}

	$list = GoBackIfInStorylet

	# $canTravel = $list.Phase -eq "Available" # property is storylets
	# $isInStorylet = $list.Phase -eq "In" -or $list.Phase -eq "InItemUse" # property is storylet
	# phase "End" probably doesnt happen here?

	if( $list.storylet -ne $null )
	{
		# cangoback was false
		# we cant travel or do anything except handle our current situation

		# add handling for menace grinding areas here?

		# only allow it if name of storylet matches first action
		if( $list.storylet.name -match $action.first )
		{
			PerformActions $list (@($action.second)+$action.third)
			return
		}
		else
		{
			Write-Warning "In a locked storylet named $($list.storylet.name)"
			return
		}
	}

	$list = MoveIfNeeded $list $action.location

	if( $action.location -eq "carnival" -and $action.first -ne "Buy" )
	{
		$hasActionsLeft = EnsureTickets
		if( !$hasActionsLeft )
		{
			return
		}
	}

	$event = EnterStorylet $list $action.first
	if( $event -eq $null )
	{
		write-warning "storylet $($action.first) not found"
		return
	}

	PerformActions $event (@($action.second)+$action.third)
}

if($script:runTests)
{
	$list = ListStorylet
	if( $list.Phase -ne "Available"  )
	{
		if( $list.storylet.canGoBack )
		{
			$b = GoBack
		}
		else
		{
			write-warning "locked in a storylet, cant run final tests"
			return
		}
	}
	Describe "MoveTo" {
		It "can move to well known area" {
			if( GetUserLocation -eq 7 )
			{
				$testlocation = "Veilgarden"
			}
			else
			{
				$testlocation = "Spite"
			}
			$result = MoveTo $testlocation
			$result.area.name | should be $testlocation
		}
		It "can move to lodgings" {
			$result = MoveTo "lodgings"
			$result.area.name | should be "Your Lodgings"
		}
	}
	Describe "GetUserLocation" {
		It "can get current location" {
			GetUserLocation | should be 2
		}
	}

	Describe "GetStoryletId" {
		It "can get storylet id by name" {
			GetStoryletId "Society" | should be 276092
		}
	}

	Describe "GoBackIfInStorylet" {
		It "returns regular list when not in storylet" {
			$list = GoBackIfInStorylet
			$list.Phase | should be "Available"
			$list.actions | should not be $null
			$list.storylets | should not be $null
			$list.isSuccess | should be $true
		}
		It "returns same list when in a storylet" {
			UseQuality 377
			$list = GoBackIfInStorylet
			$list.Phase | should be "Available"
			$list.actions | should not be $null
			$list.storylets | should not be $null
			$list.isSuccess | should be $true
		}
	}

	Describe "BeginStorylet" {
		It "can begin storylet" {
			$result = BeginStorylet 276092
			$result.isSuccess | should be $true
			$result.storylet | should not be $null
			$result.storylet.cangoback | should be $true
		}
	}

	Describe "EnterStorylet" {
		It "can enter storylet by name" {
			$list = GoBackIfInStorylet
			$result = EnterStorylet $list "Society"
			$result.isSuccess | should be $true
			$result.storylet | should not be $null
			$result.storylet.cangoback | should be $true
		}
		It "returns null if not valid storylet name" {
			$list = GoBackIfInStorylet
			$result = EnterStorylet $list "Not A Storylet Name"
			$result | should be $null
		}
	}


	Describe "PerformAction" {
		It "can perform one action" {
			$event = EnterStorylet $null "write letters"
			$result = PerformAction $event "arrange"
			$result.Phase | should be "End"
			$result.actions | should not be $null
		}
	}

	# Describe "PerformActions" {
	# It "can perform multiple actions" {
	# $result = PerformActions $null "preparing for your burglary" @("choose your target","preparing for your burglary","choose your target")
	# $result.Phase | should be "In"
	# $result.actions | should not be $null
	# $result.storylet | should not be $null
	# $result.storylet.canGoBack | should be $true
	# $result.storylet.id | should be 223811
	# }
	# }
}

function FilterFor
{
	param($name)
	$o = Opportunity

	if( $o.isInAStorylet )
	{
		$result = GoBack
	}

	if($o.displayCards.length -ge 2 )
	{
		$o.displayCards | ?{ $_.stickiness -eq "Discardable" -and $_.name -ne $name } | %{
			write-host "discarding $($_.name)"
			$result = DiscardOpportunity $_.eventId
		}
	}
	$o = Opportunity
	if( $o.eligibleForCardsCount -ge 6 )
	{
		write-host "Drawing card"
		$result = DrawOpportunity
		write-host "found: $($result.displayCards.name)"
	}
}

if(!$script:runTests)
{
#	FilterFor "The Demi-Monde: Bohemians"
	if( HasActionsToSpare )
	{
		$hasActionsLeft = EarnestPayment

		if( !$hasActionsLeft )
		{
			return
		}

		$hasActionsLeft = CheckMenaces
		if( !$hasActionsLeft )
		{
			return
		}

		DoAction (Get-Action ([DateTime]::UtcNow))
	}
}
