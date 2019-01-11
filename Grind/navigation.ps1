
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
	
	return $list
}

function IsNumber
{
	param($str)
	
	return $str -match "^\d+$"
}

function GetStoryletId
{
	param($name,$list)
	
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

function GetPossession
{
	param( $category, $name )
	if( $name -eq $null )
	{
		$name = $category
		$possessions = (Myself).possessions | select -expandproperty possessions
	}
	else
	{
		$possessions = (Myself).possessions | ?{ $_.name -eq $category } | select -expandproperty possessions
	}
	return $possessions | ?{ $_.name -match $name } | select -first 1
}

if($script:runTests)
{
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
	}
}



function PerformAction
{
	param($event,$name)
	
	if( $event -eq $null -or $event.Phase -eq "End" )
	{
		$event = ListStorylet
	}
	if( $event.Phase -eq "Available" )
	{
		Write-Warning "Trying to perform action $name while phase: Available"
		return $null
	}
	
	$childBranches = $event.storylet.childBranches | ?{ !$_.isLocked }
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
		$branch = $childBranches[$name-1]
	}
	else
	{
		$branch = $childBranches | ?{ $_.name -match $name } | select -first 1
	}
	
	if( $branch -eq $null )
	{
		return $null
	}
	
	return ChooseBranch $branch.id
}

function EnterStorylet
{
	param($list,$storyletname)
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
	param($shopname,$itemname)
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
	param($shopname,$itemname,$amount)
	$shopitemId = GetShopItemId $shopname $itemname
	Buy $shopitemid $amount
}

function SellPossession
{
	param($item,$amount)
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


function UseItem
{
	param($id,$action)
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
	param($category,$name,$action)
	
	$item = GetPossession $category $name
	if( $item -ne $null -and $item.effectiveLevel -ge 1 )
	{
		return UseItem $item.id $action
	}
}
