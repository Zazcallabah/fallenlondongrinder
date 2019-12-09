using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace fl
{
	public static class SocialEventsHandler
	{
		static IDictionary<string, string> _responses;

		static SocialEventsHandler()
		{
			_responses = Newtonsoft.Json.JsonConvert.DeserializeObject<Dictionary<string, string>>(FileHandler.ReadFile("socialevents.json"));
		}
		public static string GetActionFor(string name)
		{
			var key = _responses.Keys.FirstOrDefault(k =>
			{
				var r = new Regex(k, RegexOptions.IgnoreCase);
				return r.IsMatch(name);
			});
			if (key == null)
				return null;
			return _responses[key];
		}
	}

}