using System;
using System.Net.Http;
using System.Threading.Tasks;
using System.Collections.Generic;
using Newtonsoft.Json;
using System.Linq;
using System.Text.RegularExpressions;
using System.IO;

namespace fl
{
	public class AcquisitionEngine
	{
		public readonly IDictionary<string, Acquisition> Acquisitions = new Dictionary<string, Acquisition>();
		Session _session;

		public AcquisitionEngine(Session s)
		{
			_session = s;
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

		public IEnumerable<Acquisition> ReadFile(FileInfo file)
		{
			var filecontents = File.ReadAllText(file.FullName, System.Text.Encoding.UTF8);
			var jobject = Newtonsoft.Json.Linq.JObject.Parse(filecontents);
			foreach (Newtonsoft.Json.Linq.JProperty property in jobject.Properties())
			{
				Acquisition a = property.Value.ToObject<Acquisition>();
				a.Key = property.Name;
				yield return a;
			}
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
			var f = GetFile("items.csv");
			var filecontents = File.ReadAllLines(f.FullName, System.Text.Encoding.UTF8);
			var items = filecontents.Select(CsvItem.FromRow).Skip(1);
			//"Economy","Level","Item","Cost","Action","Gain","BoughtItem"
			// 	$name = "Default$($_.Economy)$($_.Level)$($_.BoughtItem)"
			// 	$result = $_.BoughtItem
			// 	$p = "$($_.Economy),$($_.Item),$($_.Cost)"
			// 	$action = "inventory,$($_.Economy),$($_.Item),$($_.action)"
			// 	$reward = $_.Gain
			// 	$done = AddAcquisition $name $result $action $reward @($p)
			// }
			MergeAcquisitions("items.csv", items.Select(i => i.ToAcq()));
		}

		static string GetWorkingDirectory()
		{
			var assembly = new System.IO.FileInfo(System.Reflection.Assembly.GetExecutingAssembly().Location);
			return assembly.Directory.FullName;
		}
		static DirectoryInfo GetDir(string name)
		{
			var target = System.IO.Path.Combine(GetWorkingDirectory(), name);
			return new System.IO.DirectoryInfo(target);
		}
		static FileInfo GetFile(string name)
		{
			var target = System.IO.Path.Combine(GetWorkingDirectory(), name);
			return new System.IO.FileInfo(target);
		}

		public void MergeFolder(string foldername)
		{
			var files = GetDir(foldername).GetFiles("*.json");
			foreach (var file in files)
			{
				MergeAcquisitions(file.Name, ReadFile(file));
			}
		}
		public void MergeAcquisitions(string batch, IEnumerable<Acquisition> input)
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

		// # consumes an action, assumes all possessions neccessary already exists
		// public async bool Acquire(ActionString actionstr, bool dryRun = false )
		// {
		// 	if( dryRun )
		// 	{
		// 		RecordAction(actionstr);
		// 		return false;
		// 	}
		// 	return DoAction( actionstr ); <<<< ------ TODO how will we handle the callback?
		// }

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

			var exactmatch = resultmatching.Where( a => a.Result == name ).OrderByDescending( a => a.Reward ).FirstOrDefault();
			if( exactmatch != null )
				return exactmatch;
			return resultmatching.OrderByDescending( a => a.Reward ).FirstOrDefault();

		}





		public async Task<bool> PossessionSatisfiesLevel(string category, string name, string level)
		{
			var pos = await _session.GetPossession(category, name);

			if (string.IsNullOrWhiteSpace(level))
			{
				return pos != null && pos.effectiveLevel > 0;
			}

			var opNum = level.Substring(1).AsNumber();

			if (level[0] == '<')
			{
				if (pos == null || (opNum.HasValue && pos.effectiveLevel < opNum.Value))
				{
					return true;
				}
			}
			else if (level[0] == '=')
			{
				if (pos == null && (opNum.HasValue && opNum.Value == 0))
				{
					return true;
				}
				else if (pos != null && (opNum.HasValue && pos.effectiveLevel == opNum.Value))
				{
					return true;
				}
			}
			else if (pos != null && (opNum.HasValue && pos.effectiveLevel >= opNum.Value))
			{
				return true;
			}
			return false;
		}

		// # returns true if named possession is fullfilled
		// # otherwise an action is consumed trying to work towards fullfillment, which returns false
		// # returns null if requirement is impossile - e.g. no acquisition can be found
		public async Task<bool?> Require(string category, string name, string level, string tag = null, bool dryRun = false)
		{
			if (await PossessionSatisfiesLevel(category, name, level))
			{
				return true;
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
				// 		Write-Warning "no way to get $category $name found in acquisitions list"
				return null;
			}

			foreach (var action in acq.Prerequisites.Select(p => new ActionString(p)))
			{
				var t = action.third?.FirstOrDefault();
				var hasActionsLeft = await Require(action.location, action.first, action.second, t, dryRun);
				if (hasActionsLeft == null)
					return null;

				if (!hasActionsLeft.Value)
					return false;
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
						//TODO
						// bool? result = ActivateOpportunityCard(opportunity,card,c.first);
						// if( result != null )
						// {
						// 	return result;
						// }
					}
				}
			}
			//	return Acquire(acq.Action,dryRun);
			return null;
		}
	}

	public class Acquisition
	{
		public string Key;
		public string Name;
		public string Result;
		public string[] Prerequisites;
		public string Action;
		public int? Reward;
		public string[] Cards;
	}

	public class ActionString
	{
		public string location;
		public string first;
		public string second;
		public string[] third;
		public ActionString(string s)
		{
			var spl = s.Split(',');
			if (spl.Length < 3)
				throw new ArgumentException("invalid action string");

			location = spl[0];
			first = spl[1];
			second = spl[2];

			if (spl.Length == 3)
				third = null;
			else
				third = spl.Skip(3).ToArray();
		}
	}

}




// function TestPossessionData
// {
// 	param( $category, $name, $level )
// 	return new-object psobject -property @{
// 		"name" = $category
// 		"possessions" = @(new-object psobject -property @{ "name" = $name; "effectiveLevel" = $level })
// 	}
// }

// function SetPossessionLevel
// {
// 	param( $category, $name, [int]$level )
// 	$p = GetPossession $category $name
// 	if( $p )
// 	{
// 		$p.effectiveLevel = $level
// 		return
// 	}
// 	$category = $script:myself.possessions | ?{ $_.name -match $category } | select -first 1
// 	if( $category )
// 	{
// 		$category.possessions += new-object psobject -Property @{
// 			"name" = $name;
// 			"category" = $category;
// 			"effectiveLevel" = $level;
// 			"level" = $level;
// 		}
// 	}
// }
