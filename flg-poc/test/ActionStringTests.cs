using Newtonsoft.Json;
using NUnit.Framework;
using System.Linq;
using System;
using System.Threading.Tasks;
using fl;

namespace test
{
	public class ActionStringTests
	{
		[Test]
		public void CreateActionString()
		{
			var s = new ActionString("a,b,c,d,e,f");
			Assert.AreEqual("a",s.location);
			Assert.AreEqual("b",s.first);
			Assert.AreEqual("c",s.second);
			Assert.AreEqual(new []{"d","e","f"},s.third);
			Assert.AreEqual("a b c d,e,f",s.ToString());
		}

		[Test]
		public void ThirdIsNeverEmpty()
		{
			var s = new ActionString("a,b,c");
			Assert.AreEqual("a",s.location);
			Assert.AreEqual("b",s.first);
			Assert.AreEqual("c",s.second);
			Assert.IsNull(s.third);
		}
		[Test]
		public void TestLoadAutomationActions()
		{
			var astr = ActionHandler.Automaton();
			Assert.IsNotNull(astr);
			Assert.AreEqual("require",astr[0].location);
			Assert.AreEqual("Route",astr[0].first);
			Assert.AreEqual("Route: Lodgings",astr[0].second);
			Assert.AreEqual(new[]{"1","RentLodgings"},astr[0].third);
		}

		[Test]
		public void TestLoadMainActions()
		{
			var mstr = ActionHandler.Main(0);
			var shifted = ActionHandler.Main(1);
			var dayshifted = ActionHandler.Main();
			var day = System.DateTime.UtcNow.DayOfYear % dayshifted.Length;

			Assert.AreEqual(mstr[1].ToString(), shifted[0].ToString());
			Assert.AreEqual(mstr[day].ToString(), dayshifted[0].ToString());
		}
	}
}