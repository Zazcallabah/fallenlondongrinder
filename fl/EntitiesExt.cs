using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace fl
{
	public static class StringExt
	{
		public static int? AsNumber(this string s)
		{
			int i;
			if (int.TryParse(s, out i))
			{
				return i;
			}
			return null;
		}
	}
	public static class CardExt
	{
		public static bool IsCommonCard(this Card card)
		{
			// 	# categories
			// 	#  Gold
			// 	#  Unspecialized
			// 	#  (im guessing bronze, silver, red)
			// 	# Episodic
			return card.category == "Unspecialised" && card.stickiness == "Discardable";
		}

		public static bool CollectionHasCard(this List<CardAction> collection, Card card)
		{
			var r = new Regex(card.name, RegexOptions.IgnoreCase);
			return collection.Any(c => r.IsMatch(c.name) || c.name.AsNumber() == card.eventId);
			// 	$hit = $collection | ?{
			// 		if($_.name -ne $null)
			// 		{
			// 			return $card.name -match $_.name -or $_.name -eq $card.eventId
			// 		}
			// 		else
			// 		{
			// 			return $card.name -match $_ -or $_ -eq $card.eventId
			// 		}
			// 	}
			// 	return $hit -ne $null
		}

		// public static T LookupBestMatch<T>(this IDictionary<string,T> dict, string keyname)
		// {
		// 	var r = new Regex(keyname, RegexOptions.IgnoreCase);
		// 	var key = dict.Keys.FirstOrDefault(k => r.IsMatch(k));
		// 	if (key == null)
		// 		return default(T);
		// 	return dict[key];
		// }

		public static bool CollectionHasCard(this List<string> collection, Card card)
		{
			var r = new Regex(card.name, RegexOptions.IgnoreCase);
			return collection.Any(c => r.IsMatch(c) || c.AsNumber() == card.eventId);
		}

		public static IEnumerable<CardAction> GetOptions(this Opportunity opp, IEnumerable<CardAction> cardActions )
		{
			return opp.displayCards
					.Select(c => cardActions.GetCardFromUseListByName(c.name, c.eventId))
					.Where(c => c != null);
		}

		public static CardAction GetCardFromUseListByName(this IEnumerable<CardAction> use, string name, long eventId)
		{
			var card = use.FirstOrDefault(c =>
			{
				if (string.IsNullOrWhiteSpace(c.name))
					return false;

				if (c.name[0] == '~')
				{
					var r = new Regex(c.name.Substring(1), RegexOptions.IgnoreCase);
					return r.IsMatch(name);
				}
				var n = c.name;
				if(n[0] == '!' ) {
					n = n.Substring(1);
				}
				return eventId.ToString() == n || name.Equals(n, StringComparison.InvariantCultureIgnoreCase);
			});
			if (card == null)
				return null;
			card.eventId = eventId;
			card.name = name;
			return card;
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

		public static Friend SelectFriend(this Friend[] friends, string name )
		{
			if (name == "?")
			{
				return friends[_R.Next(friends.Length)];
			}
			var n = name.AsNumber();
			if (n != null)
			{
				return friends[n.Value - 1];
			}
			return friends.FirstOrDefault(b => string.Equals(name,b.name,StringComparison.InvariantCultureIgnoreCase));
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
			return null;
		}

		// for testing
		public static StoryletList AsDryrun(this StoryletList list, string message)
		{
			return new StoryletList { phase = message, isSuccess = list.isSuccess };
		}

		public static void LogMessages(this StoryletList list)
		{
			if( list.endStorylet != null )
				fl.Log.Info($"EndStorylet: {list.endStorylet.eventValue.name} -> {list.endStorylet.eventValue.description}");
			if( list.messages != null && list.messages.defaultMessages != null )
				foreach (var m in list.messages.defaultMessages)
					fl.Log.Info($"message: {m.message}");
		}
	}
}