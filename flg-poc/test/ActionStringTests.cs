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

		[Test]
		public void TestLoadItems()
		{



		}

	}

}