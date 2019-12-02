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

			location = spl[0];
			if( spl.Length > 1)
				first = spl[1];

			if( spl.Length > 2)
				second = spl[2];

			if (spl.Length <= 3)
				third = null;
			else
				third = spl.Skip(3).ToArray();
		}
	}
}