param([switch]$force)


$script:runTests = $false
$script:runInfraTests = $false

if($env:Home -eq $null)
{
	. $PSScriptRoot/acquisitions.ps1
	$script:CardActions = gc -Raw $PSScriptRoot/cards.json | ConvertFrom-Json
}
else
{
	. ${env:HOME}/site/wwwroot/Grind/acquisitions.ps1
	$script:CardActions = gc -Raw ${env:HOME}/site/wwwroot/Grind/cards.json | ConvertFrom-Json
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
#	"cascade,Stories,A Fearsome Duelist,5,Duel Fencing"
#	"cascade,Goods,Supplies,80"
#	"cascade,Progress,Casing...,5,PrepBaseborn"
	#"cascade,Stories,Embroiled in the Wars of Illusion,3"
	"cascade,Basic,Shadowy,200,GrindShadowy"
#	"cascade,Progress,Casing...,13"
	"cascade,Stories,Tales of Mahogany Hall,10"
	"cascade,Elder,Presbyterate Passphrase,9"
	"cascade,Basic,Persuasive,200,GrindPersuasive"
	"cascade,Basic,Dangerous,200,GrindDangerous"
	"cascade,Basic,Watchful,200,GrindWatchful"
#	"cascade,Nostalgia,Bazaar Permit,1"
	"cascade,Curiosity,First City Coin,77"
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

function SellIfMoreThan
{
	param( $category, $name, $amount )
	$pos = GetPossession $category $name
	if($pos -ne $null -and $pos.effectiveLevel -gt $amount)
	{
		SellPossession $name ($pos.effectiveLevel - $amount)
	}
}

function GrindMoney
{
	SellIfMoreThan "Curiosity" "Competent Short Story" 0
	SellIfMoreThan "Curiosity" "Compelling Short Story" 1
	SellIfMoreThan "Curiosity" "Exceptional Short Story" 1

	$hasMoreActions = Require "Progress" "Potential" 61 "Daring Edit"
	if( !$hasMoreActions )
	{
		return $false
	}
	$hasMoreActions = Require "Progress" "Potential" 71 "Touch of darkness"
	if( !$hasMoreActions )
	{
		return $false
	}
	$hasMoreActions = Require "Progress" "Potential" 81 "something exotic"
	if( !$hasMoreActions )
	{
		return $false
	}
	$hasMoreActions = Require "Curiosity" "Exceptional Short Story" 2
	SellIfMoreThan "Curiosity" "Competent Short Story" 0
	SellIfMoreThan "Curiosity" "Compelling Short Story" 1
	SellIfMoreThan "Curiosity" "Exceptional Short Story" 1
	return $false
}

function GetCardInUseList
{
	param( $opportunity )

	foreach( $cardobj in $opportunity.displayCards )
	{
		$result = $script:CardActions.use | ?{ $cardobj.eventId -eq $_.name -or $cardobj.name -match $_.name }
		if($result -ne $null)
		{
			$result | Add-Member -Membertype NoteProperty -name "eventId" -value $cardobj.eventid
			return $result
		}
	}
}

if($script:runTests)
{
	Describe "GetCardInUseList" {
		It "returns a single card" {
			$script:CardActions = @{"use"=@( @{"name"=3},@{"name"=4})}
			$r = GetCardInUseList @{"displayCards"=@(@{"eventid"=3},@{"eventid"=14})}
			$r.name | should be 3
		}
		It "returns one card even if two matches" {
			$script:CardActions = @{"use"=@( @{"name"=3},@{"name"=4})}
			$r = GetCardInUseList @{"displayCards"=@(@{"eventid"=3},@{"eventid"=4})}
			$r.name | should be 3
		}
		It "returns no cards if none matches" {
			$script:CardActions = @{"use"=@( @{"name"=3},@{"name"=4})}
			$r = GetCardInUseList @{"displayCards"=@(@{"eventid"=13},@{"eventid"=14})}
			$r | should be $null
		}
		It "returns eventid as well as name cards" {
			$script:CardActions = new-object psobject -property @{"use"=@(@{"name"="hej";"action"="one"})}
			$r = GetCardInUseList (new-object psobject -property @{"displayCards"=@(@{"eventid"=13;"name"="hej"})})
			$r.name | should be "hej"
			$r.eventid | should be 13
			$r.action | should be "one"
		}
	}
}

function IsCommonCard
{
	param( $card )

	# categories
	#  Gold
	#  Unspecialized
	#  (im guessing bronze, silver, red)
	# Episodic

	# distribution
	#  Standard
	# (not sure if used)
	# VeryInfrequent

	#urgency	Normal
	return $card.category -eq "Unspecialised" -and $card.distribution -eq "Standard"
}

function IsUncommonTrash
{
	param( $card )
	$trash = $script:CardActions.trash | ?{ $cardobj.name -match $_ -or $_ -eq $cardobj.eventId }
	return $trash -ne $null
}

function IsAlwaysKeep
{
	param( $card )

	$keep = $script:CardActions.keep | ?{ $cardobj.name -match $_ -or $_ -eq $cardobj.eventId }
	return $keep -ne $null
}

function DiscardUnlessKeep
{
	param($opportunity)

	foreach( $cardobj in $opportunity.displayCards )
	{
		if( !(IsAlwaysKeep) )
		{
			if( (IsUnCommonTrash $cardobj) -or (IsCommonCard $cardobj) )
			{
				write-host "discarding $($cardobj.name)"
				$result = DiscardOpportunity $cardobj.eventId
			}
		}
	}
}

function Cards
{
	$o = DrawOpportunity

	$card = GetCardInUseList $o
	if( $card -ne $null )
	{
		$card.require | %{
			$action = ParseActionString $_
			$hasActionsLeft = Require $action.location $action.first $action.second $action.third
			if(!$hasActionsLeft)
			{
				return $false
			}
		}
		if( $o.isInAStorylet )
		{
			$result = GoBack
		}
		Write-Host "doing card $($card.name) action $($card.action)"
		$storylet = BeginStorylet $card.eventId
		if( $card.action )
		{
			$branch = GetChildBranch $storylet.storylet.childBranches $card.action
			$result = ChooseBranch $branch.id
		}
		return $false
	}

	DiscardUnlessKeep $o
	return $true
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
		BuyPossession $action.first $action.second $action.third[0]
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
	elseif( $action.location -eq "grind_money" )
	{
		GrindMoney
		return
	}

	$list = GoBackIfInStorylet
	if( $list -eq $null )
	{
		return
	}
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

if(!$script:runTests)
{
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

		$hasActionsLeft = Cards
		if( !$hasActionsLeft )
		{
			return
		}

		DoAction (Get-Action ([DateTime]::UtcNow))
	}
}
