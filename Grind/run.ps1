param([switch]$force,[switch]$noaction)

if( $env:LOGIN_EMAIL -eq $null -or $env:LOGIN_PASS -eq $null )
{
	throw "missing login information"
}

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


Register $env:LOGIN_EMAIL $env:LOGIN_PASS

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

#	"cascade,Progress,Casing...,5,PrepBaseborn"
#	"cascade,Basic,Persuasive,200,GrindPersuasive"
	"cascade,Basic,Shadowy,200,GrindShadowy"
	"cascade,Basic,Watchful,200,GrindWatchful"
	"cascade,Basic,Dangerous,200,GrindDangerous"
#	"cascade,Progress,Casing...,13"
	"cascade,Progress,Archaeologist's Progress,31"
	"cascade,Stories,A Procurer of Savage Beasts,4,HuntGoat"
#	"cascade,Progress,The Hunt is on,19"
	"cascade,Stories,Tales of Mahogany Hall,22"
	"cascade,Elder,Presbyterate Passphrase,9"
	"cascade,Progress,Running Battle,20"
	"cascade,Nostalgia,Bazaar Permit,1"
	"cascade,Curiosity,First City Coin,77"
	"cascade,Currency,Penny,10000,Penny"
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

function HandleLockedArea
{
	if( (User).setting -ne $null -and !(User).setting.canTravel )
	{
		# canTravel false means you are in a locked area i think
		# also user.setting.itemsUsableHere
		# $canTravel = $list.Phase -eq "Available" # property is storylets
# $isInStorylet = $list.Phase -eq "In" -or $list.Phase -eq "InItemUse" # property is storylet
# phase "End" probably doesnt happen here?

		# todo add handling of special circumstances here
		# like tomb colonies, prison, sailing, etc

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
	elseif( $action.location -eq "cascade" )
	{
		$hasActionsLeft = Require $action.first $action.second $action.third[0] $action.third[1]
		if($hasActionsLeft)
		{
			if( $index -ge $script:actions.Length )
			{
				return $false
			}
			$result = DoAction (Get-Action ([DateTime]::UtcNow) $index) ($index+1)
			return $result
		}
		return $false
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

	$list = GoBackIfInStorylet

	if( $list -eq $null )
	{
		return
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

if(!$noAction)
{
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

		$hasActionsLeft = Cards
		if( !$hasActionsLeft )
		{
			return
		}

		DoAction (Get-Action ([DateTime]::UtcNow))
	}
}
