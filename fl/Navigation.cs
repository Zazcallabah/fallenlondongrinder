using System;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace fl
{
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
			if( await s.IsLockedArea())
				return true;
			var id = await s.GetLocationId(location);
			return await s.IsInLocation(id);
		}

		public static async Task<bool> IsInLocation(this Session s, int location)
		{
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
			{"Connected","Contacts"},
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
			if( category == "Special" && name == "Airs" ) {
				var a = await s.Airs();
				return new Possession{
					name = "Airs",
					level = a.Value,
					effectiveLevel = a.Value
				};
			}
			var possessions = await s.GetPossessionCategory(category);
			var r = new Regex(name, RegexOptions.IgnoreCase);
			return possessions.FirstOrDefault(p => r.IsMatch(p.name));
		}
		public static async Task<int> GetPossessionLevel(this Session s, string category, string name)
		{
			var p = await s.GetPossession(category, name);
			return p.effectiveLevel;
		}

		public static async Task SellIfMoreThan(this Session s, string category, string name, int amount)
		{
			var pos = await s.GetPossession(category, name);
			if (pos != null && pos.effectiveLevel > amount)
			{
				await s.SellPossession(name, pos.effectiveLevel - amount);
			}
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

		static int? GetAirsFromPlans(IEnumerable<Plan> plans, string location = "London")
		{
			var r = new Regex($"\\(you have (?<airs>\\d+)\\)|The Airs of {location}</span> (?<airs>\\d+)<em>");
			var airs = plans.SelectMany(p => p.branch.qualityRequirements).FirstOrDefault(q => q.qualityName == $"The Airs of {location}");
			if (airs != null)
			{
				var message = r.Match(airs.tooltip);
				if (message.Success)
				{
					return int.Parse(message.Groups[1].Value);
				}
				else return 0;
			}
			return null;
		}

		static async Task<int?> _GetAirs(this Session s, string location = "London" )
		{
			var plans = await s.ListPlans();
			return GetAirsFromPlans(plans,location);
		}

		public static async Task<int?> Airs(this Session s,string location = "London",int id = 4346, string key = "f9c8d1dde5bee056cfab1123f9e0e9a0" )
		{
			var airs = await _GetAirs(s,location);
			if (airs.HasValue)
				return airs;
			var result = await s.CreatePlan(id, key);
			if (!result.isSuccess)
				return null;
			return GetAirsFromPlans(new[] { result.plan },location);
		}

		public static async Task<int?> AirsForgottenQuarter(this Session s)
		{
			return await Airs(s,"the Forgotten Quarter",4653,"56ff8f90a87789481ea90de9d2d0ee36");
		}

		public static async Task<int> GetAvailableActions(this Session s)
		{
			var myself = await s.Myself();
			return myself.character.actions;
		}

		public static async Task<bool> HasActionsToSpare(this Session s)
		{
			var actions = await s.GetAvailableActions();
			Log.Info($"remaining actions: {actions}");
			if (actions < 19)
			{
				Log.Warning("not enough actions left");
				return false;
			}

			return true;
		}
	}
}
