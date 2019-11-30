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
		public void TestDepluralize()
		{
			Assert.AreEqual("Stories", Navigation.Depluralize("Story"));
			Assert.AreEqual("Stories", Navigation.Depluralize("Stories"));
		}
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
			Assert.AreEqual("Dangerous", (await SessionHolder.Session.GetPossession("Dangerous")).name);
			Assert.AreEqual("Dangerous", (await SessionHolder.Session.GetPossession("Basic","Dangerous")).name);
			Assert.AreEqual("A Constables' Pet", (await SessionHolder.Session.GetPossessionCategory("Stories"))[0].name);
		}

		[Test]
		public async Task CanDeleteAndCreatePlansAndAirs()
		{
			// var s = SessionHolder.Session;
			// if(await .ExistsPlan(4346,"f9c8d1dde5bee056cfab1123f9e0e9a0"))
			// {
			// 	var r = await s.DeletePlan(4346);
			// 	Assert.IsTrue( r.isSuccess );
			// }
			// // can get airs
			// var a = await s.Airs();
			// Assert.IsNotNull( a );
		}

		// [Test]
		// public async Task TestSuite()
		// {
		// 	var s = SessionHolder.Session;

		// 	// start by resetting position
		// 	var list = await s.GoBackIfInStorylet();
		// 	if (!await s.IsInLocation("Veilgarden"))
		// 	{
		// 		await s.MoveTo("Veilgarden");
		// 	}

		// 	// can move to area
		// 	var nomove = await s.MoveIfNeeded(list, "Veilgarden");
		// 	Assert.AreSame(nomove,list);

		// 	var result = await s.MoveIfNeeded(list, "lodgings");
		// 	Assert.AreEqual("Available", result.phase);
		// 	Assert.AreEqual(2, await s.GetUserLocation());
		// 	Assert.IsTrue(await SessionHolder.Session.IsInLocation("Lodgings"));

		// 	// can equip and unequip
		// 	var outfits = await s.Outfit();
		// 	var item = await s.GetPossession("ragged clothing");
		// 	if( !outfits.IsEquipped(item.id) )
		// 	{
		// 		var eqres = await s.Equip("ragged clothing");
		// 		Assert.AreEqual(item.id,eqres.EquippedAt("Clothing"));
		// 	}
		// 	var uqres = await s.Unequip("ragged clothing");
		// 	Assert.IsNull(uqres.EquippedAt("Clothing"));



		// 	// can enter storylet and choose free-action-branch, then goback
		// 	list = await s.ListStorylet();
		// 	var id = await s.GetStoryletId("Society", list);
		// 	Assert.AreEqual(276092, id);
		// 	var storylet = await s.EnterStorylet(list,"society");
		// 	Assert.IsTrue(storylet.isSuccess);
		// 	Assert.AreEqual("In", storylet.phase);
		// 	Assert.IsNull(storylet.storylets);
		// 	Assert.IsNotNull(storylet.storylet);

		// 	var choice = await s.PerformActions(new []{"Private Supper"},storylet);
		// 	Assert.AreEqual("In", choice.phase);
		// 	Assert.AreEqual("Preparing Dinner", choice.storylet.name);
		// 	list = await s.GoBackIfInStorylet();
		// 	Assert.AreEqual(276092, await s.GetStoryletId("Society", list));
		// 	var firstst = list.storylets.First();
		// 	Assert.AreEqual(firstst.id, await s.GetStoryletId("1", list));

		// 	// can use item
		// 	await s.UseQuality(377);
		// 	list = await s.ListStorylet();

		// 	Assert.AreEqual("InItemUse", list.phase);
		// 	Assert.AreEqual("Sell your Jade Fragments", list.storylet.name);

		// 	var o1 = await s.DrawOpportunity();
		// 	var o2 = await s.Opportunity();

		// 	Assert.AreEqual(o1.displayCards[0].name, o2.displayCards[0].name);

		// 	// can buy and sell
		// 	var r = await s.BuyPossession("Merrigans","Jade Fragment",1);
		// 	Assert.IsTrue(r.isSuccess);
		// 	var r2 = await s.SellPossession("Jade Fragment",1);
		// 	Assert.IsTrue(r2.isSuccess);
		// }
	}

}