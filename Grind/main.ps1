param([switch]$force,[switch]$noaction)

if( $env:LOGIN_EMAIL -eq $null -or $env:LOGIN_PASS -eq $null )
{
	throw "missing login information"
}

. $PSScriptRoot/acquisitions.ps1
$script:LockedAreas = gc -Raw $PSScriptRoot/lockedareas.json | ConvertFrom-Json
$automaton = gc $PSScriptRoot/automaton.csv

function MergeCardActionsObject
{
	param([parameter(ValueFromPipelineByPropertyName)]$FullName)

	process {
		$inputobject = gc -Raw $FullName | ConvertFrom-Json
		if( $inputobject.use )
		{
			$script:CardActions.use += $inputobject.use
		}
		if( $inputobject.keep )
		{
			$script:CardActions.keep += $inputobject.keep
		}
		if( $inputobject.trash )
		{
			$script:CardActions.trash += $inputobject.trash
		}
	}
}

$script:CardActions = new-object PSObject -Property @{"use"=@();"keep"=@();"trash"=@()}
Get-ChildItem "$PSScriptRoot/cards" | MergeCardActionsObject


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
#	"require,Stories,A Fearsome Duelist,5,Duel Fencing"

#	"require,Progress,Casing...,5,PrepBaseborn"
#	"require,Basic,Persuasive,200,GrindPersuasive"
	"require,Basic,Shadowy,200,GrindShadowy"
#	"require,Contacts,Renown: The Church,8,Renown: The Church up to 8"
	"require,Nostalgia,Bazaar Permit,5"
	"require,Basic,Watchful,200,GrindWatchful"
	"require,Progress,Archaeologist's Progress,31"

	"require,Academic,Volume of Collated Research,15"
	"require,Basic,Dangerous,200,GrindDangerous"
#	"require,Progress,Casing...,13"
	"require,Stories,A Procurer of Savage Beasts,4,HuntGoat"
#	"require,Progress,The Hunt is on,19"
	"require,Stories,Tales of Mahogany Hall,22"
	"require,Elder,Presbyterate Passphrase,9"
	"require,Progress,Running Battle,20"
	"require,Nostalgia,Bazaar Permit,1"
	"require,Curiosity,First City Coin,77"
	"require,Currency,Penny,10000,Penny"
	"require,Stories,A Survivor of the Affair of the Box,16,KeyAtLast"
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
		$result = SellPossession $name ($pos.effectiveLevel - $amount)
	}
	return $true
}

function GrindMoney
{
	if( (PossessionSatisfiesLevel "Route" "Route: The Forgotten Quarter" "1") -and (PossessionSatisfiesLevel "Stories" "Archaeologist" "2") )
	{
		$hasmoreActions = Require "Progress" "Archaeologist's Progress" "99"
		return $false
	}

	$result = SellIfMoreThan "Curiosity" "Competent Short Story" 0
	$result = SellIfMoreThan "Curiosity" "Compelling Short Story" 1
	$result = SellIfMoreThan "Curiosity" "Exceptional Short Story" 1

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
	$result = SellIfMoreThan "Curiosity" "Competent Short Story" 0
	$result = SellIfMoreThan "Curiosity" "Compelling Short Story" 1
	$result = SellIfMoreThan "Curiosity" "Exceptional Short Story" 1
	return $false
}

function GetCardInUseList
{
	param( $opportunity )

	foreach( $cardobj in $opportunity.displayCards )
	{
		$result = $script:CardActions.use | ?{ ![string]::IsNullOrWhitespace($_.name) -and ($cardobj.eventId -eq $_.name -or $cardobj.name -match $_.name )}
		if($result -ne $null)
		{
			$result | Add-Member -Membertype NoteProperty -name "eventId" -value $cardobj.eventid
			return $result
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

function CollectionHasCard
{
	param( $collection, $card )
	$hit = $collection | ?{
		if($_.name -ne $null)
		{
			return $card.name -match $_.name -or $_.name -eq $card.eventId
		}
		else
		{
			return $card.name -match $_ -or $_ -eq $card.eventId
		}
	}
	return $hit -ne $null
}

function ShouldKeepCard
{
	param( $card )

	if( CollectionHasCard $script:CardActions.use $card )
	{
		return $true
	}
	if( CollectionHasCard $script:CardActions.keep $card )
	{
		return $true
	}
	if( CollectionHasCard $script:CardActions.trash $card )
	{
		return $false
	}

	return !(IsCommonCard $card)
}

function FilterCards
{
	if( IsLockedArea )
	{
		# dont filter if locked area
		return
	}

	# is there a second type of locked area we should be aware of?

	$opportunity = DrawOpportunity
	foreach( $cardobj in $opportunity.displayCards )
	{
		if( !(ShouldKeepCard $cardobj) )
		{
			write-host "discarding $($cardobj.name)"
			$result = DiscardOpportunity $cardobj.eventId
		}
	}
}

function ActivateOpportunityCard
{
	param($opportunity, $card, $actionStr)

	if( $card.eventId -eq $null )
	{
		throw "$card is not a card"
	}
	if( $opportunity.isInAStorylet )
	{
		$result = GoBack
	}
	Write-Host "doing card $($card.name) action $($actionStr)"
	$storylet = BeginStorylet $card.eventId
	if( $actionStr )
	{
		$actions = $actionStr -split ","
		$result = PerformActions $storylet $actions
		if( $result -eq $null )
		{
			return $null
		}
	}
	return $false
}

function TryOpportunity
{
	if( IsLockedArea )
	{
		return
	}
	$o = DrawOpportunity

	$card = GetCardInUseList $o
	if( $card -ne $null )
	{
		foreach( $req in $card.require )
		{
			$action = ParseActionString $req
			$hasActionsLeft = Require $action.location $action.first $action.second $action.third
			if( $hasActionsLeft -eq $null )
			{
				return $true
			}
			if(!$hasActionsLeft)
			{
				return $false
			}
		}

		$result = ActivateOpportunityCard $o $card $card.action
		if( $result -ne $null )
		{
			return $false
		}
	}

	return $true
}

function EarnestPayment
{
	$hasActionsLeft = HandleProfession
	if( !$hasActionsLeft )
	{
		return $false
	}
	return Require "Curiosity" "An Earnest of Payment" "<1" "Payment"
}

function EnsureTickets
{
	return Require "Curiosity" "Carnival Ticket" 2 "Carnival Ticket Pearl"
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


function HandleProfession
{
	$profession = GetPossession "Major Laterals" "Profession"

	if( $profession -ne $null -and ($profession.level -lt 7 -or $profession.level -gt 10) )
	{
		return $true
	}

	$filterLevels = @{
		7 = "Dangerous";
		8 = "Persuasive";
		9 = "Shadowy";
		10 = "Watchful";
	}

	$levelsBelow70 = 7..10 | %{ $filterLevels[$_] } | %{ GetPossession "Basic" $_ } | ?{ $_.effectiveLevel -le 70 }

	if( $levelsBelow70.length -eq 0 )
	{
		return $true
	}

	if( $profession -ne $null )
	{
		$basicAbility = GetPossession "Basic" $filterLevels[$profession.level]
		if( $basicAbility.effectiveLevel -le 70 )
		{
			return $true
		}
		$result = DoAction "lodgings,Write Letters,Choose a new Profession"
	}

	$professions = @{
		"Dangerous" = "Tough";
		"Persuasive" = "Minor Poet";
		"Shadowy" = "Pickpocket";
		"Watchful" = "Enquirer";
	}

	ForEach( $statName in $professions.Keys )
	{
		$basic = GetPossession "Basic" $statName
		if( $basic.effectiveLevel -le 70 )
		{
			$jobname = $professions[$statName]
			$result = DoAction "lodgings,Adopt a Training Profession,$($jobname)"
			return $false
		}
	}

	return $true
}

function HandleLockedArea
{
	if( IsLockedArea )
	{
		# canTravel false means you are in a locked area i think
		# also user.setting.itemsUsableHere
		# $canTravel = $list.Phase -eq "Available" # property is storylets
# $isInStorylet = $list.Phase -eq "In" -or $list.Phase -eq "InItemUse" # property is storylet
# phase "End" probably doesnt happen here?

		# todo add handling of special circumstances here
		# like tomb colonies, prison, sailing, etc

		# user.area.id/name or user.setting.name?
		# Imprisoned - New Newgate Prison

		$areaData = $script:LockedAreas."$((User).setting.name)"

		if($areaData -eq $null)
		{
			Write-warning "Stuck in locked area without instructions"
			return $false
		}
		if($areaData.forced)
		{
			Write-Verbose "relying on forced action data"
			$result = GoBackIfInStorylet
			return $false
		}
		ForEach( $actionstr in $areaData.require )
		{
			$action = ParseActionString $actionstr
			$hasActionsLeft = Require $action.first $action.second $action.third[0] $action.third[1]
			if( $hasActionsLeft -ne $null -and !$hasActionsLeft )
			{
				return $false
			}
		}

		return $true
	}
	return $true
}



function DoAction
{
	param($actionString, [int]$index = 1)

	$action = ParseActionString $actionString

	Write-host "doing action $($action.location) $($action.first) $($action.second) $($action.third)"

	# bazaar can usually be done even in storylet, i think?
	# require is best done doing its inventory checks before doing goback and move, to aviod extra liststorylet calls
	# inventory just needs to make sure we do gobackifinstorylet first
	if( $action.location -eq "buy" )
	{
		$result = BuyPossession $action.first $action.second $action.third[0]
		return $true
	}
	elseif( $action.location -eq "sell" )
	{
		$result = SellPossession $action.first $action.second
		return $true
	}
	elseif( $action.location -eq "equip" )
	{
		$result = Equip $action.first
		return $true
	}
	elseif( $action.location -eq "unequip" )
	{
		$result = Unequip $action.first
		return $true
	}
	elseif( $action.location -eq "require" )
	{
		$hasActionsLeft = Require $action.first $action.second $action.third[0] $action.third[1]
		return $hasactionsleft
	}
	elseif( $action.location -eq "inventory" )
	{
		$result = DoInventoryAction $action.first $action.second $action.third
		return $false
	}
	elseif( $action.location -eq "grind_money" )
	{
		$result = GrindMoney
		return $false
	}
	elseif( $action.location -eq "handle_profession" )
	{
		$result = HandleProfession
		return $result
	}

	$list = GoBackIfInStorylet

	if( $list -eq $null )
	{
		return $false
	}

	$list = MoveIfNeeded $list $action.location

	if( $action.location -eq "carnival" -and $action.first -ne "Buy" )
	{
		$hasActionsLeft = EnsureTickets
		if( !$hasActionsLeft )
		{
			return $false
		}
	}

	$event = EnterStorylet $list $action.first
	if( $event -eq $null )
	{
		write-warning "storylet $($action.first) not found"
		return $false
	}

	$result = PerformActions $event (@($action.second)+$action.third)
	return $false
}

function CycleArray
{
	param($arr,[int]$ix)
	if( $arr -eq $null)
	{
		return @()
	}
	$length = $arr.length
	if( $length -eq 0 )
	{
		return $arr
	}
	$ix = $ix % $length
	if( $ix -eq 0 )
	{
		return $arr
	}
	$tail = $arr[(-1*($length-$ix))..-1]
	$head = $arr[0..($ix-1)]
	return @($tail)+@($head)
}

function RunActions
{
	param($actions,$startIndex)

	$result = FilterCards

	if( HasActionsToSpare )
	{
		$hasActionsLeft = HandleLockedArea
		if( !$hasActionsLeft )
		{
			return
		}

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

		$hasActionsLeft = TryOpportunity
		if( !$hasActionsLeft )
		{
			return
		}

		$actionsOrder = CycleArray $actions $startIndex
		ForEach( $action in $actionsOrder )
		{
			$hasActionsLeft = DoAction $action
			write-host "has actions left: $hasactionsleft"
			if( !$hasActionsLeft )
			{
				return
			}
		}
	}
}

if( $noaction )
{
	return
}

Register $env:LOGIN_EMAIL $env:LOGIN_PASS
RunActions $script:actions ([DateTime]::UtcNow.DayOfYear)

if( $env:SECOND_EMAIL -ne $null -and $env:SECOND_PASS -ne $null )
{

# equip blemmigan
# grind to what, 10? in each stat
# handle payment, get a job - this probably needs to be a separate function
# find carneval, unlock all renown possible, avoid unlocking favours yet?
# start adding grinds for all making your name stuff
# make sure menaces grinding is available
# find early money grind, make sure menaces are covered

	Register $env:SECOND_EMAIL $env:SECOND_PASS
	RunActions $automaton
}

