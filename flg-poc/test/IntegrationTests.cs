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

	[Ignore("")]
	public class IntegrationTests
	{
		[Test]
		public async Task VerifyApiFunctionality()
		{
			var s = SessionHolder.Session;

			// myself
			var m = await s.Myself();
			Assert.IsNotNull(m.character.name);
			Assert.IsNotNull(m.possessions);

			// user
			var u = await s.User();
			Assert.IsNotNull(u.user.name);
			Assert.IsNotNull(u.area.name);

			// list

			// start by resetting position
			var list = await s.GoBack();
			if (!await s.IsInLocation("Veilgarden"))
			{
				await s.MoveTo("Veilgarden");
			}

			// can move to area
			var area = await s.MoveTo("Lodgings");
			Assert.AreEqual("Your Lodgings",area.name);

			// user is updated with new area
			Assert.AreEqual("Your Lodgings",(await s.User()).area.name);

			// can equip and unequip
			var outfits = await s.Outfit();
			var item = await s.GetPossession("ragged clothing");
			if( !outfits.IsEquipped(item.id) )
			{
				var eqres = await s.Equip("ragged clothing");
				Assert.AreEqual(item.id,eqres.EquippedAt("Clothing"));
			}
			var uqres = await s.Unequip("ragged clothing");
			Assert.IsNull(uqres.EquippedAt("Clothing"));

			// can enter storylet and choose free-action-branch, then goback
			list = await s.ListStorylet();
			var id = await s.GetStoryletId("Society", list);
			Assert.AreEqual(276092, id);
			var storylet = await s.BeginStorylet(id.Value);
			Assert.IsTrue(storylet.isSuccess);
			Assert.AreEqual("In", storylet.phase);
			Assert.IsNull(storylet.storylets);
			Assert.IsNotNull(storylet.storylet);
			var branch = storylet.storylet.childBranches.GetChildBranch("Private Supper");
			var choice = await s.ChooseBranch(branch.id);
			Assert.AreEqual("In", choice.phase);
			Assert.AreEqual("Preparing Dinner", choice.storylet.name);
			list = await s.GoBack();
			Assert.AreEqual(276092, await s.GetStoryletId("Society", list));
			var firstst = list.storylets.First();
			Assert.AreEqual(firstst.id, await s.GetStoryletId("1", list));

			// can use item
			await s.UseQuality(377);
			list = await s.ListStorylet();
			Assert.AreEqual("InItemUse", list.phase);
			Assert.AreEqual("Sell your Jade Fragments", list.storylet.name);

			// can draw cards
			var o1 = await s.DrawOpportunity();
			var o2 = await s.Opportunity();
			Assert.AreEqual(o1.displayCards[0].name, o2.displayCards[0].name);

			// can buy and sell
			var r = await s.BuyPossession("Merrigans","Jade Fragment",1);
			Assert.IsTrue(r.isSuccess);
			var r2 = await s.SellPossession("Jade Fragment",1);
			Assert.IsTrue(r2.isSuccess);

			// can get and delete plans
			if(await s.ExistsPlan(4346))
			{
				var success = await s.DeletePlan(4346);
				Assert.IsTrue( success.isSuccess );
			}
			// can get airs
			var a = await s.Airs();
			Assert.IsNotNull(a);
		}
	}
}