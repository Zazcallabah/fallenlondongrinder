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

		public bool IsEmpty()
		{
			if(!string.IsNullOrWhiteSpace(location))
				return false;
			if(!string.IsNullOrWhiteSpace(first))
				return false;
			if(!string.IsNullOrWhiteSpace(second))
				return false;
			if(third == null)
				return true;
			if(third.Length == 0)
				return true;
			return third.All( s => string.IsNullOrWhiteSpace(s) );
		}

		public string location;
		public string first;
		public string second;
		public string[] third;
		public bool alternate = false;
		public ActionString(string s)
		{
			var spl = s.Split(',');

			if( !string.IsNullOrWhiteSpace(spl[0]) && spl[0][0] == '!' )
			{
				alternate = true;
				location = spl[0].Substring(1);
			}
			else
			{
				location = spl[0];
			}

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