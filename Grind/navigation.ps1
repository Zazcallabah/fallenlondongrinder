
if($env:Home -eq $null)
{
	. $PSScriptRoot/apicalls.ps1
}
else
{
	. ${env:HOME}/site/wwwroot/Grind/apicalls.ps1
}

function GetUserLocation
{
	return (User).area.id
}

function IsInLocation
{
	param($location)
	$id = GetLocationId $location
	return (GetUserLocation) -eq $id
}

function GoBackIfInStorylet
{
	$list = ListStorylet

	if( $list.Phase -eq "Available" )
	{
		return $list
	}

	if( $list.storylet -ne $null )
	{
		if( $list.storylet.canGoBack )
		{
			write-verbose "exiting storylet"
			return GoBack
		}
	}

	# move handle edge case handle undetected locked area to here?
	return $list
}

function IsNumber
{
	param($str)

	return $str -match "^\d+$"
}

function GetStoryletId
{
	param($name, $list)

	if( $list -eq $null)
	{
		$list = ListStorylet
	}

	if( IsNumber $name )
	{
		return $list.storylets | select -first 1 -skip ($name-1) -expandproperty id
	}
	return $list.storylets | ?{ $_.name -match $name } | select -first 1 -expandproperty id
}

function GetPossessionCategory
{
	param( $category )
	if( $category -eq "Basic" -or $category -eq "BasicAbility" )
	{
		return (Myself).possessions[0].possessions;
	}

	return (Myself).possessions | ?{ $category -eq $null -or $_.name -eq $category } | select -expandproperty possessions
}

function GetPossession
{
	param( $category, $name )
	if( $name -eq $null )
	{
		$name = $category
		$category = $null
	}

	$possessions = GetPossessionCategory $category

	return $possessions | ?{ $_.name -match $name } | select -first 1
}

if($script:runTests)
{
	Describe "GetPossessionCategory" {
		It "can get route" {
			$cat = GetPossessionCategory "Route"
			$cat | ?{ $_.category -eq "Route" } | measure | select -expandproperty count | should be $cat.length
			$cat | ?{ $_.name -eq "Route: Lodgings" } | should not be $null
		}
		It "can get basicability" {
			$cat = GetPossessionCategory "Basic"
			$cat | ?{ $_.category -eq "BasicAbility" } | measure | select -expandproperty count | should be $cat.length
			$cat | ?{ $_.name -eq "Dangerous" } | should not be $null
		}
		It "can get all" {
			$cat = GetPossessionCategory
			$cat | ?{ $_.name -eq "Route: Lodgings" } | should not be $null
			$cat | ?{ $_.name -eq "Dangerous" } | should not be $null
		}
	}

	Describe "GetPossession" {
		It "can get possession" {
			$hints = GetPossession "Mysteries" "Whispered Hint"
			$hints.id | should be 380
		}
		It "can get possession without giving category" {
			$hints = GetPossession "Whispered Hint"
			$hints.id | should be 380
		}
		It "can get possession with partial match" {
			$hints = GetPossession "Mysteries" "Whispered"
			$hints.id | should be 380
		}
		It "can get basic possession" {
			$dangerous = GetPossession "Basic" "Dangerous"
			$dangerous.id = 211
		}
	}
}

function GetChildBranch
{
	param($childBranches, $name)

	$childBranches = $childBranches | ?{ !$_.isLocked }

	if( $childBranches -eq $null )
	{
		return $null
	}

	if( $name -eq "?" )
	{
		$name = (random $childBranches.length)+1
	}

	if( IsNumber $name )
	{
		return $childBranches[$name-1]
	}
	else
	{
		return $childBranches | ?{ $_.name -match $name } | select -first 1
	}
}

function PerformAction
{
	param($event, [string]$name)

	if( $event -eq $null -or $event.Phase -eq "End" )
	{
		$event = ListStorylet
	}
	if( $event.Phase -eq "Available" )
	{
		Write-Warning "Trying to perform action $name while phase: Available"
		return $null
	}

	$branch = GetChildBranch $event.storylet.childBranches $name
	if( $branch -eq $null )
	{
		return $null
	}

	return ChooseBranch $branch.id
}

function PerformActions
{
	param($event, $actions)


	if( $actions -eq $null )
	{
		return $event
	}

	foreach( $action in $actions )
	{
		if( $event.Phase -eq "End" )
		{
			$event = ListStorylet
		}
		$event = PerformAction $event $action
		if( $event -eq $null )
		{
			write-warning "branch $($action) in $actions not found"
			return
		}
	}

	return $event
}

function EnterStorylet
{
	param($list, $storyletname)
	$storyletid = GetStoryletId $storyletname $list
	if($storyletid -eq $null)
	{
		return $null
	}
	BeginStorylet $storyletid
}

$script:shopIds = @{
	"Sell my things" = "null";
	"Carrow's Steel" = 1;
	"Maywell's Hattery" = 2;
	"Dark & Savage" = 3;
	"Gottery the Outfitter" = 4;
	"Nassos Zoologicals" = 5;
	"MERCURY" = 6;
	"Nikolas Pawnbrokers" = 7;
	"Merrigans Exchange" = 8;
	"Redemptions" = 9;
	"Dauncey's" = 10;
	"Fadgett & Daughters" = 11;
	"Crawcase Cryptics" = 12;
	"Penstock's Land Agency" = 15;
}
function GetShopId
{
	param($name)

	$key = $script:shopIds.Keys | ?{ $_ -match $name } | select -first 1
	if( $key -eq $null )
	{
		return $name
	}
	return $script:shopIds[$key]
}

function GetShopItemId
{
	#how to know which shop has which item?
	param($shopname, $itemname)
	$shopid = GetShopId $shopname
	$inventory = GetShopInventory $shopid
	if( IsNumber $itemname )
	{
		$item = $inventory | ?{ $_.availability.quality.id -eq $itemname } | select -first 1
	}
	else
	{
		$item = $inventory | ?{ $_.availability.quality.name -match $itemname } | select -first 1
	}
	return $item.availability.id
}

function BuyPossession
{
	param($shopname, $itemname, $amount)
	$shopitemId = GetShopItemId $shopname $itemname
	Buy $shopitemid $amount
}

function SellPossession
{
	param($item, $amount)
	$shopitemid = GetShopItemId "sell" $item
	Sell $shopitemid $amount
}

if($script:runTests)
{
	Describe "GetShopItemId" {
		It "can get itemid from shop" {
			GetShopItemId "Nikolas" "Absolution" | should be 211
		}
	}
	Describe "BuyPossession" {
		It "can buy" {
			$pennies = GetPossession "Currency" "Penny"
			$jade = GetPossession "Elder" "Jade"
			BuyPossession "Merrigans" "Jade" "1"
			GetPossession "Elder" "Jade" | select -expandproperty effectivelevel | should be ($jade.effectivelevel +1)
			GetPossession "Currency" "Penny" | select -expandproperty effectiveLevel | should be ($pennies.effectiveLevel -2 )
		}
		It "can sell" {
			$pennies = GetPossession "Currency" "Penny"
			$jade = GetPossession "Elder" "Jade"
			SellPossession "Jade" "1"
			GetPossession "Elder" "Jade" | select -expandproperty effectivelevel | should be ($jade.effectivelevel -1)
			GetPossession "Currency" "Penny" | select -expandproperty effectiveLevel | should be ($pennies.effectiveLevel +1 )
		}
	}
}

function Airs
{
	# this could give outdated value, if we perform an action that changes airs without discarding cached value for plans
	$plans = Plans
	$airsmessage =  $plans.active+$plans.completed | %{ $_.branch.qualityRequirements | ?{ $_.qualityName -eq "The Airs of London" } | select -first 1 -expandProperty tooltip } | select -first 1
	if( $airsmessage -ne $null )
	{
		$r = [regex]"\(you have (\d+)\)"
		$result = $r.Match($airsmessage)
		if($result.Success)
		{
			return [int]$result.Groups[1].Value
		}
	}
	return $null
}


if($script:runTests)
{
	Describe "Airs" {
		It "can read airs from plan" {
			Airs | should not be $null
		}
	}
}

function UseItem
{
	param($id, $action)
	$result = UseQuality $id
	if($result.isSuccess)
	{
		PerformAction $null $action
	}
}

function HasActionsToSpare
{
	if($force)
	{
		return $true
	}
	if( (Myself).character.actions -lt 19 )
	{
		write-warning "not enough actions left"
		return $false
	}
	return $true
}

function DoInventoryAction
{
	param($category, $name, [string]$action)
	$list = GoBackIfInStorylet

	$item = GetPossession $category $name
	if( $item -ne $null -and $item.effectiveLevel -ge 1 )
	{
		return UseItem $item.id $action
	}
}

function MoveIfNeeded
{
	param( $list, $location )

	if( IsInLocation $location )
	{
		return $list;
	}

	if( $location -eq "empresscourt" )
	{
		$result = DoAction "shutteredpalace,Spend,1"
		return ListStorylet
	}

	$area = MoveTo $location;
	return ListStorylet
}



function CreatePlanFromAction
{
	param($location, $storyletname, $branches, $name)

	$list = GoBackIfInStorylet
	$list = MoveIfNeeded $list $location

	$event = EnterStorylet $list $storyletname
	if( $event -eq $null )
	{
		write-warning "cant create plan, storylet $($storyletname) not found"
		return
	}

	if( $branches -ne $null )
	{
		$event = PerformActions $event $branches
	}

	$branch = GetChildBranch $event.storylet.childBranches $name
	if( $branch -eq $null )
	{
		write-warning "no childbranch named $name"
	}
	$branchId = $branch.id
	$plankey = $branch.plankey
	if(!(ExistsPlan $branch.id $branch.planKey))
	{
		return CreatePlan $branch.id $branch.planKey
	}
	return $null
}

function CreatePlanFromActionString
{
	param($actionstring)
	$str = $actionstring -split ","

	if( $str.length -gt 0 )
	{
		$location = $str[0]
	}
	if( $str.length -gt 1 )
	{
		$storyletname = $str[1]
	}
	if( $str.length -gt 2 )
	{
		$name = $str[-1]
	}
	if( $str.length -gt 3 )
	{
		$branches = $str[2,($str.length-2)]
	}

	return CreatePlanFromAction -location $location -storyletname $storyletname -branches $branches -name $name
}

function DeleteExistingPlan
{
	param( $name )
	$plan = Get-Plan $name
	DeletePlan $plan.branch.id
}

if($script:runTests)
{
	Describe "CreatePlan" {
		It "can create plan" {
			$result = CreatePlanFromActionString "lodgings,nightmares,1"
			$result.isSuccess | should be $true
		}
		It "can find plan" {
			$plan = Get-Plan "Invite someone to a Game of Chess"
			$plan | should not be null
			$plan.branch.name | should be "Invite someone to a Game of Chess"
		}
		It "can delete plan" {
			$result = DeleteExistingPlan "Invite someone to a Game of Chess"
		}
	}
}

