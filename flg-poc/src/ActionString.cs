using System;
using System.Linq;

namespace fl
{
	public class ActionString
	{
		public override string ToString()
		{
			var s = $"{location},{first},{second}";
			if (third != null)
			{
				s += "," + string.Join(",", third);
			}
			return s;
		}

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