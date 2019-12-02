using Newtonsoft.Json;
using NUnit.Framework;
using System.Linq;
using System;
using System.Threading.Tasks;
using fl;

namespace test
{

	//filehandler
	//entitiesext
	// forcedactionfile
	//engine + csvstuff
	//state
	// handler
	//log?
	// navigation
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
		public async Task CanGetUserAndMyself()
		{
			var s = SessionHolder.Session;

			var m = await s.Myself();
			Assert.IsNotNull(m.character.name);
			Assert.IsNotNull(m.character.actions);
			Assert.IsNotNull(m.possessions);

			var u = await s.User();
			Assert.IsNotNull(u.user.name);
			Assert.IsNotNull(u.area.name);
			Assert.IsNotNull(u.area.id);
			Assert.AreEqual("ClankingAutomaton",u.user.name);
		}

		[Test]
		public async Task CanGetPossession()
		{
			Assert.AreEqual("Dangerous", (await SessionHolder.Session.GetPossession("Dangerous")).name);
			Assert.AreEqual(211, (await SessionHolder.Session.GetPossession("Dangerous")).id);
			Assert.AreEqual("Dangerous", (await SessionHolder.Session.GetPossession("Basic","Dangerous")).name);
			Assert.AreEqual("A Constables' Pet", (await SessionHolder.Session.GetPossessionCategory("Stories"))[0].name);
			Assert.AreEqual(380, (await SessionHolder.Session.GetPossession("Mysteries","Whispered Hint")).id);
			Assert.AreEqual(380, (await SessionHolder.Session.GetPossession("Whispered Hint")).id);
			Assert.AreEqual(380, (await SessionHolder.Session.GetPossession("Mysteries", "Whispered")).id);
		}

		[Test]
		public async Task CanDrawCards(){

			var s = SessionHolder.Session;
			// can draw cards
			var o1 = await s.DrawOpportunity();
			var o2 = await s.Opportunity();
			Assert.AreEqual(o1.displayCards[0].name, o2.displayCards[0].name);
		}

		[Test]
		public async Task CanReadAirsDespiteDeletedPlan()
		{
			var s = SessionHolder.Session;
			if(await s.ExistsPlan(4346))
			{
				var r = await s.DeletePlan(4346);
				Assert.IsTrue( r.isSuccess );
			}

			var a = await s.Airs();
			Assert.IsNotNull( a );
		}

		[Test]
		public async Task CanGetShopItem()
		{
			Assert.AreEqual(211,await SessionHolder.Session.GetShopItemId("Nikolas", "Absolution"));
		}
	}
}


// $script:myself = $null
// Describe "CollectionHasCard function" {
// 	It "can detect card" {
// 		CollectionHasCard @("a","b") @{"name"="b"} | should be $true
// 	}
// 	It "can detect no card" {
// 		CollectionHasCard @("a","b") @{"name"="c"} | should be $false
// 	}
// 	It "collection is regex" {
// 		CollectionHasCard @("$a") @{"name"="abcd"} | should be $true
// 	}
// 	It "collection can be objects" {
// 		CollectionHasCard @(@{"name"="$a"}) @{"name"="abcd"} | should be $true
// 	}
// }


// Describe "GetCardInUseList" {
// 	It "returns a single card" {
// 		$script:CardActions = @{"use"=@( @{"name"=3},@{"name"=4})}
// 		$r = GetCardInUseList @{"displayCards"=@(@{"eventid"=3},@{"eventid"=14})}
// 		$r.name | should be 3
// 	}
// 	It "returns one card even if two matches" {
// 		$script:CardActions = @{"use"=@( @{"name"=3},@{"name"=4})}
// 		$r = GetCardInUseList @{"displayCards"=@(@{"eventid"=3},@{"eventid"=4})}
// 		$r.name | should be 3
// 	}
// 	It "returns no cards if none matches" {
// 		$script:CardActions = @{"use"=@( @{"name"=3},@{"name"=4})}
// 		$r = GetCardInUseList @{"displayCards"=@(@{"eventid"=13},@{"eventid"=14})}
// 		$r | should be $null
// 	}
// 	It "returns eventid as well as name cards" {
// 		$script:CardActions = new-object psobject -property @{"use"=@(@{"name"="hej";"action"="one"})}
// 		$r = GetCardInUseList (new-object psobject -property @{"displayCards"=@(@{"eventid"=13;"name"="hej"})})
// 		$r.name | should be "hej"
// 		$r.eventid | should be 13
// 		$r.action | should be "one"
// 	}
// }
