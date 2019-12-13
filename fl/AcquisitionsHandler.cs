using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

namespace fl
{
	public class AcquisitionsHandler
	{
		public readonly IDictionary<string, Acquisition> Acquisitions = new Dictionary<string, Acquisition>();

		public void LoadFromFile()
		{
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
		public void AddAcquisition(string name, string result, string action, int? reward, string[] prereq)
		{
			Acquisitions.Add(name, new Acquisition
			{
				Name = name,
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
				a.Name = property.Name;
				yield return a;
			}
		}


		public void AddTestAcquisition(Acquisition a)
		{
			if( Acquisitions.ContainsKey(a.Name) )
				Acquisitions[a.Name] = a;
			else
				Acquisitions.Add(a.Name, a);
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
	}
}