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
			Assert.AreEqual("ClankingAutomaton", (await SessionHolder.Session.User()).user.name);
		}


		[Test]
		public async Task CanGetPossession()
		{
			Assert.AreEqual("Dangerous", (await SessionHolder.Session.GetPossession("Dangerous")).name );
			Assert.AreEqual("Dangerous", (await SessionHolder.Session.GetPossession("Dangerous","Basic")).name );
			Assert.AreEqual("A Constables' Pet", (await SessionHolder.Session.GetPossessionCategory("Stories"))[0].name );
		}

		[Test]
		public async Task TestSuite() {
			var s = SessionHolder.Session;

			// start by resetting position
			var list = await s.GoBackIfInStorylet();
			if( ! await s.IsInLocation("Veilgarden") ){
				await s.MoveTo("Veilgarden");
			}

			// can move to area
			var result = await s.MoveTo("Lodgings");
			Assert.AreEqual("Your Lodgings",result.name);
			Assert.AreEqual(2,await s.GetUserLocation());
			Assert.IsTrue(await SessionHolder.Session.IsInLocation("Lodgings"));

			// can enter storylet and choose free-action-branch, then goback
			list = await s.ListStorylet();
			var id = await s.GetStoryletId("Society",list);
			Assert.AreEqual(276092,id);
			var storylet = await s.BeginStorylet(id.Value);
			Assert.IsTrue(storylet.isSuccess);
			Assert.AreEqual("In",storylet.phase);
			Assert.IsNull(storylet.storylets);
			Assert.IsNotNull(storylet.storylet);
			var branch = storylet.storylet.childBranches.FirstOrDefault(c=>c.id == 206983);
			Assert.IsNotNull( branch );
			var choice = await s.ChooseBranch(branch.id);
			Assert.AreEqual("In",choice.phase);
			Assert.AreEqual("Preparing Dinner",choice.storylet.name);
			list = await s.GoBackIfInStorylet();
			Assert.AreEqual(276092,await s.GetStoryletId("Society",list));
			var firstst = list.storylets.First();
			Assert.AreEqual(firstst.id, await s.GetStoryletId("1",list));

			// can use item
			await s.UseQuality(377);
			list = await s.ListStorylet();

			Assert.AreEqual("InItemUse",list.phase);
			Assert.AreEqual("Sell your Jade Fragments",list.storylet.name);


		}
	}

}