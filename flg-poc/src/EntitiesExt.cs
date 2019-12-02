using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace fl
{
	static class StringExt
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
	static class CardExt
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

		public static bool CollectionHasCard(this List<string> collection, Card card)
		{
			var r = new Regex(card.name, RegexOptions.IgnoreCase);
			return collection.Any(c => r.IsMatch(c) || c.AsNumber() == card.eventId);
		}

		public static CardAction GetCardFromUseListByName(this List<CardAction> use, string name, long eventId)
		{
			var r = new Regex(name, RegexOptions.IgnoreCase);
			var card = use.FirstOrDefault(c =>
			{
				if (string.IsNullOrWhiteSpace(c.name))
					return false;

				if (c.name[0] == '~')
				{
					return r.IsMatch(c.name.Substring(1));
				}
				return eventId.ToString() == c.name || c.name == name;
			});
			if (card == null)
				return null;
			card.eventId = eventId;
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
	}
}