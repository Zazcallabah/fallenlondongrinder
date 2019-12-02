using System;
using System.Threading.Tasks;
using System.Collections.Generic;

namespace fl
{
	public class ForcedActionFile
	{
		public static IDictionary<string, string> simple = new Dictionary<string, string>();
		public static IDictionary<string, IList<ForcedAction>> complex = new Dictionary<string, IList<ForcedAction>>();

		static ForcedActionFile()
		{
			var jobject = Newtonsoft.Json.Linq.JObject.Parse(FileHandler.ReadFile("forcedactions.json"));
			foreach (Newtonsoft.Json.Linq.JProperty property in jobject.Properties())
			{
				if (property.Value is Newtonsoft.Json.Linq.JArray)
				{
					complex.Add(property.Name, property.Value.ToObject<List<ForcedAction>>());
				}
				else
				{
					simple.Add(property.Name, property.Value.ToObject<string>());
				}
			}
		}
	}

}