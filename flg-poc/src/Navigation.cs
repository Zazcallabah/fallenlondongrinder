using System;
using System.Net.Http;
using System.Threading.Tasks;
using System.Collections.Generic;
using Newtonsoft.Json;
using System.Linq;
using System.Text.RegularExpressions;

namespace fl
{
	// instead of extension methods, perhaps a 'state' object? holding an attached session?
	public static class Navigation
	{
		public static async Task<int> GetUserLocation(this Session s)
		{
			User u = await s.User();
			return u.area.id;
		}
		public static async Task<bool> IsLockedArea(this Session s)
		{
			User u = await s.User();
			return u.setting != null && !(bool)u.setting.canTravel;
		}

		public static async Task<bool> IsInLocation(this Session s, string location)
		{
			var id = await s.GetLocationId(location);
			return await s.IsInLocation(id);
		}

		public static async Task<bool> IsInLocation(this Session s, int location)
		{
			// TODO is this a race condition example?
			if( await s.IsLockedArea() )
				return true;
			return await s.GetUserLocation() == location;

			// // if user is uncached,
			// var t1 = s.IsLockedArea();
			// var t2 = s.GetUserLocation();
			// //and we then await both, both of these trigger user download
			// if( await t1 ) return true;
			// return await t2 == location;
		}

		public static async Task<StoryletList> GoBackIfInStorylet(this Session s)
		{
			StoryletList list = await s.ListStorylet();
			if( list.phase == "Available" )
				return list;

			if( list.storylet == null )
				return list;

			if( list.storylet.canGoBack.HasValue && list.storylet.canGoBack.Value )
			{
// todo 			write-verbose "exiting storylet"
				return await s.GoBack();
			}
			else
			{
// 			# we check for this much earlier, this is redundant
// 			$done = HandleLockedStorylet $list
// 			return $null
				throw new Exception("called GoBackIfInStorylet on what looks like locked storylet");
			}
		}

		public static int? AsNumber(this string s){
			int i;
			if( int.TryParse(s, out i) )
			{
				return i;
			}
			return null;
		}

		public static async Task<long?> GetStoryletId(this Session s, string name, StoryletList list = null )
		{
			if( list == null )
				list = await s.ListStorylet();
			var n = name.AsNumber();
			if( n != null )
			{
				return list.storylets[n.Value-1].id;
			}

			var r = new Regex(name);
			foreach( var item in list.storylets )
			{
				if( r.IsMatch(item.name) )
				{
					return item.id;
				}
			}
			return null;
		}

		readonly static IDictionary<string,string> DepluralizationMap = new Dictionary<string,string>{
			{"BasicAbilities", "BasicAbility"},
			{"SidebarAbilities", "Prominence"},
			{"MajorLaterals", "Major Laterals"},
			{"Ambitions", "Ambition"},
			{"Menace", "Menaces"},
			{"Dream", "Dreams"},
			{"Quirk", "Quirks"},
			{"Ventures", "Venture"},
			{"Contact", "Contacts"},
			{"Favour", "Contacts"},
			{"Favours", "Contacts"},
			{"Renown", "Contacts"},
			{"Acquaintance", "Acquaintances"},
			{"Story", "Stories"},
			{"Circumstances", "Circumstance"},
			{"Accomplishment", "Accomplishments"},
			{"Routes", "Route"},
			{"Advantages", "Advantage"},
			{"Cartographies", "Cartography"},
			{"Contrabands", "Contraband"},
			{"Curiosities", "Curiosity"},
			{"Currencies", "Currency"},
			{"Money", "Currency"},
			{"Documents", "Document"},
			{"Good", "Goods"},
			{"The Great Game", "Great Game"},
			{"GreatGame", "Great Game"},
			{"Infernals", "Infernal"},
			{"Influences", "Influence"},
			{"Lodging", "Lodgings"},
			{"Luminosities", "Luminosity"},
			{"Mystery", "Mysteries"},
			{"RagTrade", "Rag Trade"},
			{"Rubberies", "Rubbery"},
			{"Rumours", "Rumour"},
			{"Sustenances", "Sustenance"},
			{"WildWords", "Wild Words"},
			{"Wine", "Wines"},
			{"Zee Treasure", "Zee Treasures"},
			{"ZeeTreasures", "Zee Treasures"},
			{"ZeeTreasure", "Zee Treasures"},
			{"Zee-Treasures", "Zee Treasures"},
			{"Zee-Treasure", "Zee Treasures"},
			{"Hats", "Hat"},
			{"Glove", "Gloves"},
			{"Weapons", "Weapon"},
			{"Boot", "Boots"},
			{"Companions", "Companion"},
			{"Destinies", "Destiny"},
			{"Affiliations", "Affiliation"},
			{"Transportations", "Transportation"},
			{"HomeComfort", "Home Comfort"},
			{"HomeComforts", "Home Comfort"},
			{"Home Comforts", "Home Comfort"},
			{"ConstantCompanion", "Constant Companion"},
			{"Clubs", "Club"}
		};

		public static string Depluralize(this string category )
		{
			if( category != null && DepluralizationMap.ContainsKey(category) )
			{
				return DepluralizationMap[category];
			}
			return category;
		}

		public static async Task<IList<Possession>> GetPossessionCategory(this Session s, string category )
		{
			category = category.Depluralize();

			var myself = await s.Myself();

			if( category == "Basic" || category == "BasicAbility" )
			{
				return myself.possessions[0].possessions.ToList();
			}

			return myself.possessions
				.Where( c => string.IsNullOrWhiteSpace(category) || c.name == category )
				.SelectMany( c => c.possessions )
				.ToList();
		}

		public static async Task<dynamic> GetPossession(this Session s, string name, string category = null )
		{
			var possessions = await s.GetPossessionCategory(category);
			var r = new Regex(name);
			return possessions.FirstOrDefault( p => r.IsMatch(p.name));
		}

		static readonly IDictionary<string,int?> ShopIds = new Dictionary<string,int?>{
	{"Sell my things", null},
	{"Carrow's Steel", 1},
	{"Maywell's Hattery", 2},
	{"Dark & Savage", 3},
	{"Gottery the Outfitter", 4},
	{"Nassos Zoologicals", 5},
	{"MERCURY", 6},
	{"Nikolas Pawnbrokers", 7},
	{"Merrigans Exchange", 8},
	{"Redemptions", 9},
	{"Dauncey's" ,10},
	{"Fadgett & Daughters" ,11},
	{"Crawcase Cryptics" ,12},
	{"Penstock's Land Agency" ,15},
};

public static int? GetShopId(this Session s, string name )
{
		var r = new Regex(name);
		var key = ShopIds.Keys.FirstOrDefault(k=>r.IsMatch(k));
	if( key == null )
	{
		throw new Exception($"Invalid shop name {name}");
	}
	return ShopIds[key];
}

// function GetShopItemId
// {
// 	#how to know which shop has which item?
// 	param($shopname, $itemname)
// 	$shopid = GetShopId $shopname
// 	$inventory = GetShopInventory $shopid
// 	if( IsNumber $itemname )
// 	{
// 		$item = $inventory | ?{ $_.availability.quality.id -eq $itemname } | select -first 1
// 	}
// 	else
// 	{
// 		$item = $inventory | ?{ $_.availability.quality.name -match $itemname } | select -first 1
// 	}
// 	return $item.availability.id
// }

// function BuyPossession
// {
// 	param($shopname, $itemname, [int]$amount)
// 	$shopitemId = GetShopItemId $shopname $itemname
// 	Buy $shopitemid $amount
// }

// function SellPossession
// {
// 	param($item, [int]$amount)
// 	$shopitemid = GetShopItemId "sell" $item
// 	Sell $shopitemid $amount
// }
	}


	}



// function Equip
// {
// 	param( $name )
// 	$item = GetPossession $name
// 	EquipOutfit $item.id
// }

// function Unequip
// {
// 	param( $name )
// 	$item = GetPossession $name
// 	UnequipOutfit $item.id
// }

// function GetChildBranch
// {
// 	param($childBranches, $name)

// 	$names = $name -split "/"

// 	foreach( $n in $names )
// 	{
// 		$r = InnerGetChildBranch $childBranches $n
// 		if( $r -ne $null )
// 		{
// 			return $r
// 		}
// 	}
// 	return $null
// }

// function InnerGetChildBranch
// {
// 	param($childBranches,$name)

// 	$childBranches = $childBranches | ?{ !$_.isLocked }

// 	if( $childBranches -eq $null )
// 	{
// 		return $null
// 	}

// 	if( $name -eq "?" )
// 	{
// 		$name = (random $childBranches.length)+1
// 	}

// 	if( IsNumber $name )
// 	{
// 		return $childBranches[$name-1]
// 	}
// 	else
// 	{
// 		return $childBranches | ?{ $_.name -match $name } | select -first 1
// 	}
// }

// function PerformAction
// {
// 	param($event, [string]$name)

// 	if( $event -eq $null -or $event.Phase -eq "End" )
// 	{
// 		$event = ListStorylet
// 	}
// 	if( $event.Phase -eq "Available" )
// 	{
// 		Write-Warning "Trying to perform action $name while phase: Available"
// 		return $null
// 	}

// 	$branch = GetChildBranch $event.storylet.childBranches $name
// 	if( $branch -eq $null )
// 	{
// 		return $null
// 	}

// 	return ChooseBranch $branch.id
// }

// function PerformActions
// {
// 	param($event, $actions)


// 	if( $actions -eq $null )
// 	{
// 		return $event
// 	}

// 	foreach( $action in $actions )
// 	{
// 		if( $action -ne $null )
// 		{
// 			if( $event.Phase -eq "End" )
// 			{
// 				$event = ListStorylet
// 			}
// 			$event = PerformAction $event $action
// 			if( $event -eq $null )
// 			{
// 				write-warning "branch $($action) in $actions not found"
// 				return
// 			}
// 		}
// 	}

// 	return $event
// }

// function EnterStorylet
// {
// 	param($list, $storyletname)
// 	$storyletid = GetStoryletId $storyletname $list
// 	if($storyletid -eq $null)
// 	{
// 		return $null
// 	}
// 	BeginStorylet $storyletid
// }

// $script:shopIds = @{
// 	"Sell my things" = "null";
// 	"Carrow's Steel" = 1;
// 	"Maywell's Hattery" = 2;
// 	"Dark & Savage" = 3;
// 	"Gottery the Outfitter" = 4;
// 	"Nassos Zoologicals" = 5;
// 	"MERCURY" = 6;
// 	"Nikolas Pawnbrokers" = 7;
// 	"Merrigans Exchange" = 8;
// 	"Redemptions" = 9;
// 	"Dauncey's" = 10;
// 	"Fadgett & Daughters" = 11;
// 	"Crawcase Cryptics" = 12;
// 	"Penstock's Land Agency" = 15;
// }
// function GetShopId
// {
// 	param($name)

// 	$key = $script:shopIds.Keys | ?{ $_ -match $name } | select -first 1
// 	if( $key -eq $null )
// 	{
// 		return $name
// 	}
// 	return $script:shopIds[$key]
// }

// function GetShopItemId
// {
// 	#how to know which shop has which item?
// 	param($shopname, $itemname)
// 	$shopid = GetShopId $shopname
// 	$inventory = GetShopInventory $shopid
// 	if( IsNumber $itemname )
// 	{
// 		$item = $inventory | ?{ $_.availability.quality.id -eq $itemname } | select -first 1
// 	}
// 	else
// 	{
// 		$item = $inventory | ?{ $_.availability.quality.name -match $itemname } | select -first 1
// 	}
// 	return $item.availability.id
// }

// function BuyPossession
// {
// 	param($shopname, $itemname, [int]$amount)
// 	$shopitemId = GetShopItemId $shopname $itemname
// 	Buy $shopitemid $amount
// }

// function SellPossession
// {
// 	param($item, [int]$amount)
// 	$shopitemid = GetShopItemId "sell" $item
// 	Sell $shopitemid $amount
// }

// function Airs
// {
// 	param([switch]$dontRetry)
// 	# this could give outdated value, if we perform an action that changes airs without discarding cached value for plans
// 	$plans = Plans
// 	$airsmessage =  $plans.active+$plans.completed | %{ $_.branch.qualityRequirements | ?{ $_.qualityName -eq "The Airs of London" } | select -first 1 -expandProperty tooltip } | select -first 1
// 	if( $airsmessage -ne $null )
// 	{
// 		$r = [regex]"\(you have (\d+)\)"
// 		$result = $r.Match($airsmessage)
// 		if($result.Success)
// 		{
// 			return [int]$result.Groups[1].Value
// 		}
// 	}

// 	if( !$dontRetry )
// 	{
// 		$result = CreatePlan 4346 f9c8d1dde5bee056cfab1123f9e0e9a0
// 		$script:plans = $null
// 		return Airs -dontRetry
// 	}

// 	return $null
// }


// function UseItem
// {
// 	param($id, $action)
// 	$result = UseQuality $id
// 	if($result.isSuccess)
// 	{
// 		PerformAction $null $action
// 	}
// }

// function HasActionsToSpare
// {
// 	Write-Verbose "remaining actions: $((Myself).character.actions)"
// 	if($force)
// 	{
// 		return $true
// 	}
// 	if( (Myself).character.actions -lt 19 )
// 	{
// 		write-warning "not enough actions left"
// 		return $false
// 	}
// 	return $true
// }

// function DoInventoryAction
// {
// 	param($category, $name, [string]$action)
// 	$list = GoBackIfInStorylet
// 	if( $list -eq $null )
// 	{
// 		return $true
// 	}
// 	$item = GetPossession $category $name
// 	if( $item -ne $null -and $item.effectiveLevel -ge 1 )
// 	{
// 		$result = UseItem $item.id $action
// 		return $false
// 	}
// }

// function MoveIfNeeded
// {
// 	param( $list, $location )

// 	if( IsInLocation $location )
// 	{
// 		return $list;
// 	}

// 	if( $location -eq "empresscourt" )
// 	{
// 		$result = DoAction "shutteredpalace,Spend,1"
// 		return ListStorylet
// 	}

// 	$area = MoveTo $location;
// 	return ListStorylet
// }



// function CreatePlanFromAction
// {
// 	param($location, $storyletname, $branches, $name)

// 	$list = GoBackIfInStorylet
// 	if( $list -eq $null )
// 	{
// 		return
// 	}
// 	$list = MoveIfNeeded $list $location

// 	$event = EnterStorylet $list $storyletname
// 	if( $event -eq $null )
// 	{
// 		write-warning "cant create plan, storylet $($storyletname) not found"
// 		return
// 	}

// 	if( $branches -ne $null )
// 	{
// 		$event = PerformActions $event $branches
// 	}

// 	$branch = GetChildBranch $event.storylet.childBranches $name
// 	if( $branch -eq $null )
// 	{
// 		write-warning "no childbranch named $name"
// 	}
// 	$branchId = $branch.id
// 	$plankey = $branch.plankey
// 	if(!(ExistsPlan $branch.id $branch.planKey))
// 	{
// 		return CreatePlan $branch.id $branch.planKey
// 	}
// 	return $null
// }

// function CreatePlanFromActionString
// {
// 	param($actionstring)
// 	$str = $actionstring -split ","

// 	if( $str.length -gt 0 )
// 	{
// 		$location = $str[0]
// 	}
// 	if( $str.length -gt 1 )
// 	{
// 		$storyletname = $str[1]
// 	}
// 	if( $str.length -gt 2 )
// 	{
// 		$name = $str[-1]
// 	}
// 	if( $str.length -gt 3 )
// 	{
// 		$branches = $str[2,($str.length-2)]
// 	}

// 	return CreatePlanFromAction -location $location -storyletname $storyletname -branches $branches -name $name
// }

// function DeleteExistingPlan
// {
// 	param( $name )
// 	$plan = Get-Plan $name
// 	DeletePlan $plan.branch.id
// }





	// // // // // // // // // // // // public class ForcedActionHandler
	// // // // // // // // // // // // {






// {
// 	"Unpredictable Treasures": "?",
// 	"The Stuff of Song": "Provide a very personal lesson",
// 	"A Kindred Spirit": "snake",
// 	"Unjustly imprisoned!":"1",


// 	"Far Arbor": [
// 		{
// 			"Conditions":[
// 				"Stories,Arbor: Permission to Linger,=0"
// 			],
// 			"Action": "Leave Arbor"
// 		},
// 		{
// 			"Conditions":[
// 				"Curiosity,Attar,<3"
// 			],
// 			"Action": "The city washes away"
// 		}
// 	],
// }



// $script:ForcedActions = gc -Raw $PSScriptRoot/forcedactions.json | ConvertFrom-Json


// function IsSimpleAction
// {
// 	param($action)
// 	return $action.GetType().Name -eq "String"
// }

// function HandleLockedStoryletAction
// {
// 	param( $list, $action, [switch]$dryRun )
// 	if( $dryRun )
// 	{
// 		return $action
// 	}
// 	$result = PerformAction $list $action
// 	return $false
// }

// function HandleLockedStorylet
// {
// 	param($list,[switch]$dryrun)

// 	$action = $script:ForcedActions."$($list.storylet.name)"
// 	if($action -eq $null)
// 	{
// 		throw "stuck in forced action named $($list.storylet.name), can't proceed without manual interaction"
// 	}

// 	if( IsSimpleAction  $action )
// 	{
// 		return HandleLockedStoryletAction $list $action -dryrun:$dryrun
// 	}

// 	foreach( $entry in $action )
// 	{
// 		$conditions = $entry.Conditions | %{
// 			$condition = ParseActionString $_
// 			$result = PossessionSatisfiesLevel $condition.location $condition.first $condition.second
// 			Write-Verbose "checking criteria $_ gave result $result"
// 			return $result
// 		} | ?{ $_ } | measure

// 		if( $conditions.Count -eq @($entry.Conditions).Length )
// 		{
// 			return HandleLockedStoryletAction $list $entry.Action -dryrun:$dryrun
// 		}
// 	}

// 	write-warning "no idea what to do here"
// 	throw "$list"
// }


