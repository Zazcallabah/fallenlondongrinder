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
	"require,Progress,Casing...,5,PrepBaseborn"
	"require,Elder,Presbyterate Passphrase,9"
	"require,Basic,Persuasive,100,GrindPersuasive" #95
	"require,Basic,Dangerous,100,GrindDangerous" # 39
	"require,Basic,Shadowy,100,GrindShadowy" #63
	"require,Basic,Watchful,100,GrindWatchful" # 66
)




function Get-Action
{
	param($now,$index)
	$selector = $now.DayOfYear
	if( $index -ne $null )
	{
		$selector += $index
	}
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

function PerformActions
{
	param($event, $action, $actions)

	$event = PerformAction $event $action
	if( $event -eq $null )
	{
		write-warning "branch $($action) not found"
		return
	}

	if( $actions -eq $null )
	{
		return
	}

	$actions | %{
		if( $event -ne $null ) #return here only exits the loop
		{
			if( $event.Phase -eq "End" )
			{
				$event = ListStorylet
			}
			$event = PerformAction $event $_
			if( $event -eq $null )
			{
				write-warning "action $_ in $actions not found"
			}
		}
	}
	return $event
}

function DoAction
{
	param($actionString,$index = 1)

	$action = ParseActionString $actionString

	Write-host "doing action $($action.location) $($action.first) $($action.second) $($action.third)"

	if( (User).setting -ne $null -and !(User).setting.canTravel )
	{
		# also user.setting.itemsUsableHere
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
			PerformActions $list $action.second $action.third
			return
		}
		else
		{
			Write-Warning "In a locked storylet named $($list.storylet.name)"
			return
		}
	}
	elseif( !(IsInLocation $action.location) )
	{
		if( $action.location -eq "carnival" -and $action.first -ne "Buy" )
		{
			$hasActionsLeft = EnsureTickets
			if( !$hasActionsLeft )
			{
				return
			}
		}
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
		elseif( $action.location -eq "require" )
		{
			$hasActionsLeft = Require $action.first $action.second $action.third[0] $action.third[1]
			if($hasActionsLeft)
			{
				DoAction (Get-Action ([DateTime]::UtcNow) $index) $index+1
			}
			return
		}
		elseif( $action.location -eq "writing" )
		{
			Writing
			return
		}
		elseif( $action.location -eq "empresscourt" )
		{
			$result = DoAction "shutteredpalace,Spend,1"
			$list = GoBackIfInStorylet
		}
		else
		{
			$area = MoveTo $action.location;
			$list = ListStorylet
		}
	}

	$event = EnterStorylet $list $action.first
	if( $event -eq $null )
	{
		write-warning "storylet $($action.first) not found"
		return
	}

	PerformActions $event $action.second $action.third
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
			$result = PerformAction $event "name a pet"
			$result.Phase | should be "In"
			$result.actions | should not be $null
			$result.storylet | should not be $null
			$result.storylet.canGoBack | should be $true
			$result.storylet.id | should be 204639
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



if(!$script:runTests)
{
	if( HasActionsToSpare )
	{
		$hasActionsLeft = CheckMenaces
		if( $hasActionsLeft )
		{
			DoAction (Get-Action ([DateTime]::UtcNow))
		}
	}
}
