
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

function ExitIfInStorylet
{
	$result	= ListStorylet
	
	if( $result.storylet -ne $null )
	{
		if( $result.storylet.canGoBack )
		{
			write-verbose "exiting storylet"
			return GoBack
		}
	}
	
	return $result
}

function IsNumber
{
	param($str)
	
	return $str -match "^\d+$"
}

function GetStoryletId
{
	param($name)
	$result = ListStorylet
	if( IsNumber $name )
	{
		return $result.storylets | select -first 1 -skip ($name-1) -expandproperty id
	}
	return $result.storylets | ?{ $_.name -match $name } | select -first 1 -expandproperty id
}

if($script:runTests)
{
	Describe "GetUserLocation" {
		It "can get current location" {
			ExitIfInStorylet
			GetUserLocation | should not be $null
		}
	}
	$location = GetUserLocation
	if( $location -ge 2 -and $location -le 7 )
	{
		Describe "MoveTo" {
			It "can move" {
				if( GetUserLocation -eq "spite" )
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
				GetUserLocation | should be 2
			}
		}
		Describe "GetStoryletId" {
			It "can get storylet id by name" {
				GetStoryletId "Society" | should be 276092
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
		
		Describe "Exit Storylet" {
			It "can back out of chosen storylet" {
				$result = ExitIfInStorylet
				$result.storylet | should be $null
				$result.storylets | should not be $null
			}
			It "does nothing if exiting and no storylet is chosen" {
				$result = ExitIfInStorylet
				$result.storylet | should be $null
				$result.storylets | should not be $null
			}
		}
	}
	
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
	param($result,$name)
	
	$childBranches = $result.storylet.childBranches | ?{ !$_.isLocked }
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
	
	if( $branch -ne $null )
	{
		return ChooseBranch $branch.id
	}
}

function EnterStoryletAndPerformAction
{
	param($storyletname, $name)
	$storyletid = GetStoryletId $storyletname
	$result = BeginStorylet $storyletid
	return PerformAction $result $name
}

function PerformActionFromCurrent
{
	param($name)
	$result = ListStorylet
	return PerformAction $result $name
}

if($script:runTests)
{
	# Describe "EnterStoryletPerformAction" {
		# It "can perform action" {
			# MoveTo "spite"
			# $result = EnterStoryletAndPerformAction "Alleys" "Cats"
			# $result.isSuccess | should be $true
			# $result.endStorylet | should not be $null
		# }
	# }
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
	param($id,$branch)
	$result = UseQuality $id
	if($result.isSuccess)
	{
		PerformActionFromCurrent $branch
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
