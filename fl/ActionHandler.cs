using Newtonsoft.Json;
using System.Linq;

namespace fl
{
	public static class ActionHandler
	{
		static ActionList _list;

		static ActionHandler()
		{
			_list = JsonConvert.DeserializeObject<ActionList>(FileHandler.ReadFile("actions.json"));
		}

		public static ActionList List()
		{
			return _list;
		}

		public static ActionString[] Main(int? shiftIndex = null)
		{

			if (shiftIndex == null)
				shiftIndex = System.DateTime.UtcNow.DayOfYear;

			var main = new System.Collections.Generic.List<string>();

			for (var ix = 0; ix < _list.main.Length; ix++)
			{
				main.Add(_list.main[(ix + shiftIndex.Value) % _list.main.Length]);
			}
			return main.Select(s => new ActionString(s)).ToArray();
		}

		public static ActionString[] Automaton()
		{
			return _list.automaton.Select(s => new ActionString(s)).ToArray();
		}
	}
}