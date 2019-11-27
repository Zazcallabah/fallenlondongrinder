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
			if (await s.IsLockedArea())
				return true;
			return await s.GetUserLocation() == location;

			// // if user is uncached,
			// var t1 = s.IsLockedArea();
			// var t2 = s.GetUserLocation();
			// //and we then await both, both of these trigger user download
			// if( await t1 ) return true;
			// return await t2 == location;
		}

		public static int? AsNumber(this string s)
		{
			int i;
			if (int.TryParse(s, out i))
			{
				return i;
			}
			return null;
		}

		public static async Task<long?> GetStoryletId(this Session s, string name, StoryletList list = null)
		{
			if (list == null)
				list = await s.ListStorylet();
			var n = name.AsNumber();
			if (n != null)
			{
				return list.storylets[n.Value - 1].id;
			}

			var r = new Regex(name, RegexOptions.IgnoreCase);
			foreach (var item in list.storylets)
			{
				if (r.IsMatch(item.name))
				{
					return item.id;
				}
			}
			return null;
		}

		readonly static IDictionary<string, string> DepluralizationMap = new Dictionary<string, string>{
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

		public static string Depluralize(this string category)
		{
			if (category != null && DepluralizationMap.ContainsKey(category))
			{
				return DepluralizationMap[category];
			}
			return category;
		}

		public static async Task<IList<Possession>> GetPossessionCategory(this Session s, string category)
		{
			category = category.Depluralize();

			var myself = await s.Myself();

			if (category == "Basic" || category == "BasicAbility")
			{
				return myself.possessions[0].possessions.ToList();
			}

			return myself.possessions
				.Where(c => string.IsNullOrWhiteSpace(category) || c.name == category)
				.SelectMany(c => c.possessions)
				.ToList();
		}

		public static async Task<Possession> GetPossession(this Session s, string name)
		{
			return await s.GetPossession(null, name);
		}


		public static async Task<Possession> GetPossession(this Session s, string category, string name)
		{
			var possessions = await s.GetPossessionCategory(category);
			var r = new Regex(name, RegexOptions.IgnoreCase);
			return possessions.FirstOrDefault(p => r.IsMatch(p.name));
		}
		public static async Task<int> GetPossessionLevel(this Session s, string category, string name)
		{
			var p = await s.GetPossession(category, name);
			return p.effectiveLevel;
		}

		public static async Task<bool> SellIfMoreThan(this Session s, string category, string name, int amount)
		{
			var pos = await s.GetPossession(category, name);
			if (pos != null && pos.effectiveLevel > amount)
			{
				await s.SellPossession(name, pos.effectiveLevel - amount);
			}
			return true;
		}
		static readonly IDictionary<string, int> ShopIds = new Dictionary<string, int>{
			{"Sell my things", 0},
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

		public static int GetShopId(string name)
		{
			var r = new Regex(name, RegexOptions.IgnoreCase);
			var key = ShopIds.Keys.FirstOrDefault(k => r.IsMatch(k));
			if (key == null)
			{
				throw new Exception($"Invalid shop name {name}");
			}
			return ShopIds[key];
		}
		public static async Task<long> GetShopItemId(this Session s, string shopName, string itemName)
		{
			return (await s.GetShopItem(shopName, itemName)).availability.id;
		}
		public static async Task<ShopItem> GetShopItem(this Session s, string shopName, string itemName)
		{
			var shopId = GetShopId(shopName);
			var inventory = await s.GetShopInventory(shopId);
			var itemNumber = itemName.AsNumber();
			if (itemNumber != null)
			{
				return inventory.FirstOrDefault(i => i.availability.quality.id == itemNumber.Value);
			}
			else
			{
				var r = new Regex(itemName, RegexOptions.IgnoreCase);
				return inventory.FirstOrDefault(i => r.IsMatch(i.availability.quality.name));
			}
		}

		public static async Task<TransactionResult> BuyPossession(this Session s, string shopName, string itemName, int amount)
		{
			var shopItemId = await s.GetShopItemId(shopName, itemName);
			return await s.PostBuy(shopItemId, amount);
		}

		public static async Task<TransactionResult> SellPossession(this Session s, string itemName, int amount)
		{
			var shopItemId = await s.GetShopItemId("sell", itemName);
			return await s.PostSell(shopItemId, amount);
		}

		public static async Task<OutfitSlot[]> Equip(this Session s, string name)
		{
			var item = await s.GetPossession(name);
			return await s.PostEquipOutfit(item.id);
		}

		public static async Task<OutfitSlot[]> Unequip(this Session s, string name)
		{
			var item = await s.GetPossession(name);
			return await s.PostUnequipOutfit(item.id);
		}

		static int? GetAirsFromPlans(IEnumerable<Plan> plans)
		{
			var r = new Regex("\\(you have (\\d+)\\)");
			var airs = plans.SelectMany(p => p.branch.qualityRequirements).FirstOrDefault(q => q.qualityName == "The Airs of London");
			if (airs != null)
			{
				var message = r.Match(airs.tooltip);
				if (message.Success)
				{
					return int.Parse(message.Groups[1].Value);
				}
			}
			return null;
		}

		static async Task<int?> GetAirs(this Session s)
		{
			var plans = await s.ListPlans();
			return GetAirsFromPlans(plans);
		}

		public static async Task<int?> Airs(this Session s)
		{
			var airs = await GetAirs(s);
			if (airs.HasValue)
				return airs;
			var result = await s.CreatePlan(4346, "f9c8d1dde5bee056cfab1123f9e0e9a0");
			if (!result.isSuccess)
				return null;
			return GetAirsFromPlans(new[] { result.plan });
		}

		public static async Task<int> GetAvailableActions(this Session s)
		{
			var myself = await s.Myself();
			return myself.character.actions;
		}


		// todo should be moved to more external location, has too much
		public static async Task<bool> HasActionsToSpare(this Session s)
		{
			// 	Write-Verbose "remaining actions: $((Myself).character.actions)"
			if (await s.GetAvailableActions() < 19)
			{
				// 		write-warning "not enough actions left"
				return false;
			}

			return true;
		}

	}

	public static class StoryletExt
	{
		public static long? EquippedAt(this IEnumerable<OutfitSlot> slots, string slotname)
		{
			return slots.FirstOrDefault(s => s.name == slotname)?.qualityId;
		}
		public static bool HasEquipped(this IEnumerable<OutfitSlot> slots, string slotname)
		{
			return slots.FirstOrDefault(s => s.name == slotname && s.qualityId.HasValue) != null;
		}
		public static bool IsEquipped(this IEnumerable<OutfitSlot> slots, long id)
		{
			return slots.FirstOrDefault(s => s.qualityId == id) != null;
		}
		static Random _R = new Random();
		static Branch InnerGetChildBranch(this IEnumerable<Branch> branches, string name)
		{
			var unlocked = branches.Where(b => !b.isLocked).ToArray();
			if (unlocked.Length == 0)
				return null;

			if (name == "?")
			{
				return unlocked[_R.Next(unlocked.Length)];
			}

			var n = name.AsNumber();
			if (n != null)
			{
				return unlocked[n.Value - 1];
			}

			var r = new Regex(name, RegexOptions.IgnoreCase);
			return unlocked.FirstOrDefault(b => r.IsMatch(b.name));
		}

		public static Branch GetChildBranch(this IEnumerable<Branch> branches, string name)
		{
			var names = name.Split('/');
			foreach (var n in names)
			{
				var result = branches.InnerGetChildBranch(n);
				if (result != null)
					return result;
			}
			throw new Exception($"branch {name} not found");
		}

		// for testing
		public static StoryletList AsDryrun(this StoryletList list, string message)
		{
			return new StoryletList { phase = message, isSuccess = list.isSuccess };
		}
	}

	public static class aoeu
	{

		public static async Task<bool?> DoAction(this Session s, ActionString action)
		{
			// todo debug output
			//	Write-host "doing action $($action.location) $($action.first) $($action.second) $($action.third)"


			//  bazaar can usually be done even in storylet, i think?
			//  require is best done doing its inventory checks before doing goback and move, to aviod extra liststorylet calls
			//  inventory just needs to make sure we do gobackifinstorylet first
			if (action.location == "buy")
			{
				if (action.third == null)
				{
					throw new Exception($"invalid buy action {action}");
				}
				var n = action.third[0].AsNumber();
				if (!n.HasValue)
				{
					throw new Exception($"invalid buy action {action}");
				}
				await s.BuyPossession(action.first, action.second, n.Value);
				return false; // technically true, but that screws with prereq chains
			}
			else if (action.location == "sell")
			{
				var n = action.second.AsNumber();
				if (!n.HasValue)
				{
					throw new Exception($"invalid sell action {action}");
				}
				await s.SellPossession(action.first, n.Value);
				return false;// technically true, but that screws with prereq chains
			}
			else if (action.location == "equip")
			{
				await s.Equip(action.first);
				return true;
			}
			else if (action.location == "unequip")
			{
				await s.Unequip(action.first);
				return true;
			}
			else if (action.location == "require")
			{
				var hasActionsLeft = Require(action.first, action.second, action.third[0], action.third[1]);
				return hasActionsLeft;
			}
			else if (action.location == "inventory")
			{
				await s.DoInventoryAction(action.first, action.second, action.third);
				return false;
			}
			else if (action.location == "grind_money")
			{
				await GrindMoney;
				return false;
			}
			else if (action.location == "handle_profession")
			{
				return await HandleProfession();
			}
			return await DoAction2(s,action);
		}
	}

	public class GameState
	{
		Session _session;
		StoryletList _cachedList;


		public GameState(Session s)
		{
			_session = s;
		}

		public async Task<bool?> NavigateIntoAction(ActionString action)
		{

			await GoBackIfInStorylet();

			if (_cachedList == null)
			{
				// was return false <- hasmoreactions?
				throw new Exception("invalid state after goback");
			}

			await MoveIfNeeded(action.location);

			// this is a remnant from before the time of prereq in the acq engine
			// if (action.location == "carnival" && action.first != "Buy")
			// {
			// 	var hasActionsLeft = await EnsureTickets()
			// 	if (!hasActionsLeft)
			// 	{
			// 		return false;
			// 	}
			// }

			bool success = await EnterStorylet(action.first);
			if (_cachedList == null)
			{
				//todo error handle also debug output
				//write-warning "storylet $($action.first) not found"
				return false;
			}

			var ac = new List<string> { action.second };
			if (action.third != null)
				ac.AddRange(action.third);

			bool success = await PerformActions(ac);
			return false;
		}

		public async Task GoBackIfInStorylet()
		{
			_cachedList = await _session.ListStorylet();
			if (_cachedList.phase == "Available")
				return;

			if (_cachedList.storylet == null)
				return;

			if (_cachedList.storylet.canGoBack.HasValue && _cachedList.storylet.canGoBack.Value)
			{
				// todo 			write-verbose "exiting storylet"
				_cachedList = await _session.GoBack();
				return;
			}
			else
			{
				// 			# we check for this much earlier, this is redundant
				// 			$done = HandleLockedStorylet $list
				// 			return $null
				throw new Exception("called GoBackIfInStorylet on what looks like locked storylet");
			}
		}
		public async Task<bool> PerformAction(string name)
		{
			if (_cachedList == null || _cachedList.phase == "End")
			{
				_cachedList = await _session.ListStorylet();
			}
			if (_cachedList.phase == "Available")
			{
				// TODO 		Write-Warning "Trying to perform action $name while phase: Available"
				throw new Exception($"Trying to perform action {name} while phase: Available");
			}
			var branch = _cachedList.storylet.childBranches.GetChildBranch(name);

			if (branch == null)
			{
				return false;
			}
			_cachedList = await _session.ChooseBranch(branch.id);
			return true;
		}

		public async Task<bool> PerformActions(IEnumerable<string> actions)
		{
			if (actions == null)
				return false;

			foreach (var action in actions)
			{
				if (!string.IsNullOrWhiteSpace(action))
				{
					if (_cachedList.phase == "End")
						_cachedList = await _session.ListStorylet();
					var result = await PerformAction(action);
					if (_cachedList == null || !result )
					{
						// 				write-warning "branch $($action) in $actions not found"
						// null or exception?
						throw new Exception($"branch {action} in {string.Join(",", actions.ToArray())} not found");
					}
				}
			}
			return true;
		}

		public async Task<bool> EnterStorylet(string storyletname)
		{
			var sid = await _session.GetStoryletId(storyletname, _cachedList);
			if (sid != null)
			{
				_cachedList = await _session.BeginStorylet(sid.Value);
				return true;
			}
			else
			{
				_cachedList = null;
				return false;
			}
		}

		public async Task MoveIfNeeded(string location)
		{
			if (await _session.IsInLocation(location))
				return;

			if (await _session.GetLocationId(location) == await _session.GetLocationId("empress court"))
			{
				// TODO 		$result = DoAction "shutteredpalace,Spend,1"
				throw new NotImplementedException("TODO: moving to empresscort");
			}

			// todo test if race condition since we throw away result from moveto?
			await _session.MoveTo(location);
			_cachedList = await _session.ListStorylet();
		}

		public async Task<bool> DoInventoryAction(string category, string name, string action)
		{
			await GoBackIfInStorylet();
			var item = await _session.GetPossession(category, name);
			if (item != null && item.effectiveLevel >= 1)
			{
				var result = await _session.UseQuality(item.id);
				if (result.isSuccess)
				{
					return await PerformAction(action);
				}
				return false;
			}
			return true;
		}

	}
}






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


