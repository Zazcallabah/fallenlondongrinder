using Newtonsoft.Json;
using NUnit.Framework;
using System.Linq;
using System;
using System.Threading.Tasks;
using fl;
namespace test
{
	[SetUpFixture]
	class SessionHolder
	{
		public static Session Session;
			[OneTimeSetUp]
		public void RunBeforeAnyTests()
		{
			Session = new fl.Session("automaton@prefect.se", "aoeu1234");
		}
	}

	public class SessionTests
	{
		[Test]
		public async Task CanGetLocationId()
		{
			Assert.AreEqual(5, await SessionHolder.Session.GetLocationId("Watchmakers"));
			Assert.AreEqual(5, await SessionHolder.Session.GetLocationId("Watchmakers Hill"));
			Assert.AreEqual(5, await SessionHolder.Session.GetLocationId("WatchmakersHill"));
			Assert.AreEqual(5, await SessionHolder.Session.GetLocationId("Watchmaker's Hill"));
			Assert.AreEqual(6, await SessionHolder.Session.GetLocationId("Veilgarden"));
		}

		[Test]
		public async Task CanGetUser()
		{
			Assert.AreEqual("ClankingAutomaton", (string)(await SessionHolder.Session.User()).user.name);
		}

		[Test]
		public async Task CanGetLocation()
		{
			Assert.IsTrue(await SessionHolder.Session.IsInLocation("Lodgings"));
		}

		[Test]
		public async Task CanGetPossession()
		{
			Assert.AreEqual("Dangerous", (string)(await SessionHolder.Session.GetPossession("Dangerous")).name );
			Assert.AreEqual("Dangerous", (string)(await SessionHolder.Session.GetPossession("Dangerous","Basic")).name );
			Assert.AreEqual("Dangerous", (string)(await SessionHolder.Session.GetPossessionCategory("Stories"))[0].name );
		}
	}

}