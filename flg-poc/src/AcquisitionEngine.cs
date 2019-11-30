using System;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.IO;

namespace fl
{
	public class AcquisitionEngine
	{
		public readonly IDictionary<string, Acquisition> Acquisitions = new Dictionary<string, Acquisition>();
		Session _session;
		GameState _state;
		Handler _handler;

		public Handler Handler { get; set; }

		public AcquisitionEngine(Session session, GameState state)
		{
			_session = session;
			_state = state;
			LoadItemsCsv();
			AddAcquisition("DefaultMysteries3bJournals",
				"Journal of Infamy",
				"inventory,Mysteries,Appalling Secret,duchess",
				105,
				new string[] { "Mysteries,Appalling Secret,333", "Contacts,Connected: The Duchess,5" });

			AddAcquisition("DefaultMysteries4bCorrespondance",
				"Correspondence Plaque",
				"inventory,Mysteries,Journal of Infamy,Blackmail",
				51,
				new string[] { "Mysteries,Journal of Infamy,50" });

			FileHandler.ForEachFile("acquisitions", MergeAcquisitionsFile);
		}

		void AddAcquisition(string name, string result, string action, int? reward, string[] prereq)
		{
			Acquisitions.Add(name, new Acquisition
			{
				Name = name,
				Key = name,
				Action = action,
				Prerequisites = prereq ?? new string[0],
				Result = result,
				Reward = reward
			});
		}

		class CsvItem
		{

			static readonly Regex _splitter = new Regex("^\"([^\"]*)\",\"([^\"]*)\",\"([^\"]*)\",\"([^\"]*)\",\"([^\"]*)\",\"([^\"]*)\",\"([^\"]*)\"");
			public static CsvItem FromRow(string row)
			{
				var m = _splitter.Match(row);
				if (!m.Success)
					throw new Exception("invalid items.csv");
				return new CsvItem(
					m.Groups[1].Value,
					m.Groups[2].Value,
					m.Groups[3].Value,
					m.Groups[4].Value,
					m.Groups[5].Value,
					m.Groups[6].Value,
					m.Groups[7].Value
				);
			}
			public Acquisition ToAcq()
			{
				var item = this;
				var name = $"Default{item.Economy}{item.Level}{item.BoughtItem}";
				var result = item.BoughtItem;
				var p = $"{item.Economy},{item.Item},{item.Cost}";
				var action = $"inventory,{item.Economy},{item.Item},{item.Action}";
				var reward = int.Parse(item.Gain);
				return new Acquisition
				{
					Action = action,
					Key = name,
					Name = name,
					Prerequisites = new[] { p },
					Result = result,
					Reward = reward
				};
			}
			CsvItem(
				string e,
				string l,
				string i,
				string c,
				string a,
				string g,
				string b
			)
			{
				Economy = a;
				Level = l;
				Item = i;
				Cost = c;
				Action = a;
				Gain = g;
				BoughtItem = b;
			}
			public string Economy;
			public string Level;
			public string Item;
			public string Cost;
			public string Action;
			public string Gain;
			public string BoughtItem;
		}

		void LoadItemsCsv()
		{
			var f = FileHandler.GetFile("items.csv");
			var filecontents = File.ReadAllLines(f.FullName, System.Text.Encoding.UTF8);
			var items = filecontents.Select(CsvItem.FromRow).Skip(1);
			MergeAcquisitions("items.csv", items.Select(i => i.ToAcq()));
		}

		IEnumerable<Acquisition> ParseString(string filecontents)
		{
			var jobject = Newtonsoft.Json.Linq.JObject.Parse(filecontents);
			foreach (Newtonsoft.Json.Linq.JProperty property in jobject.Properties())
			{
				Acquisition a = property.Value.ToObject<Acquisition>();
				a.Key = property.Name;
				yield return a;
			}
		}

		void MergeAcquisitionsFile(string batch, string input)
		{
			MergeAcquisitions(batch, ParseString(input));
		}

		void MergeAcquisitions(string batch, IEnumerable<Acquisition> input)
		{
			foreach (var item in input)
			{
				if (string.IsNullOrWhiteSpace(item.Name))
					throw new Exception($"acq with bad name in batch {batch}, action: {item.Action}");
				Acquisitions.Add(item.Name, item);
			}
		}

		public readonly List<ActionString> ActionHistory = new List<ActionString>();

		public void RecordAction(ActionString action)
		{
			ActionHistory.Add(action);
		}

		public async Task<HasActionsLeft> Acquire(ActionString actionstr, bool dryRun = false)
		{
			if (dryRun)
			{
				RecordAction(actionstr);
				return HasActionsLeft.Consumed;
			}
			return await _handler.DoAction(actionstr);
		}

		public Acquisition LookupAcquisition(string name)
		{
			if (string.IsNullOrWhiteSpace(name))
				return null;

			if (Acquisitions.ContainsKey(name))
				return Acquisitions[name];
			var r = new Regex(name, RegexOptions.IgnoreCase);
			var matching = Acquisitions.Values.FirstOrDefault(a => r.IsMatch(a.Name));
			if (matching != null)
				return matching;
			var resultmatching = Acquisitions.Values.Where(a => r.IsMatch(a.Result)).ToArray();

			var exactmatch = resultmatching.Where(a => a.Result == name).OrderByDescending(a => a.Reward).FirstOrDefault();
			if (exactmatch != null)
				return exactmatch;
			return resultmatching.OrderByDescending(a => a.Reward).FirstOrDefault();

		}

		public async Task<HasActionsLeft> Require(string category, string name, string level, string tag = null, bool dryRun = false)
		{
			if (await _state.PossessionSatisfiesLevel(category, name, level))
			{
				return HasActionsLeft.Available;
			}

			//todo
			// 	Write-Verbose "Require $category $name $level ($tag)"

			var acq = LookupAcquisition(tag);
			if (acq == null)
			{
				acq = LookupAcquisition(name);
			}
			if (acq == null)
			{
				Log.Warning($"no way to get {category} {name} found in acquisitions list");
				return HasActionsLeft.Faulty;
			}

			foreach (var action in acq.Prerequisites.Select(p => new ActionString(p)))
			{
				var t = action.third?.FirstOrDefault();
				var hasActionsLeft = await Require(action.location, action.first, action.second, t, dryRun);
				// todo find some way to test this mismatch handling
				if (hasActionsLeft != HasActionsLeft.Available)
					return hasActionsLeft;
			}

			if (acq.Cards != null)
			{
				var opportunity = await _session.DrawOpportunity();
				foreach (var c in acq.Cards.Select(c => new ActionString(c)))
				{
					var cId = c.location.AsNumber();
					var r = new Regex(c.location);
					var card = opportunity.displayCards.FirstOrDefault(d => cId == null ? r.IsMatch(d.name) : d.eventId == cId);
					if (card != null)
					{
						var cardaction = new CardAction { action = c.first, eventId = card.eventId, name = card.name };
						var result = await _state.ActivateOpportunityCard(cardaction, opportunity.isInAStorylet);

						if (result != HasActionsLeft.Available && result != HasActionsLeft.Mismatch)
							return result;
					}
				}
			}
			return await Acquire(new ActionString(acq.Action), dryRun);
		}
	}
}
