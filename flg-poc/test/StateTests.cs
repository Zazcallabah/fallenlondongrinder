using Newtonsoft.Json;
using NUnit.Framework;
using System.Linq;
using System;
using System.Threading.Tasks;
using fl;

namespace test
{
	public class StateTests
	{
		GameState _state;
		Session _session;


		[SetUp]
		public void Setup()
		{
			_session = SessionHolder.Session;
			_state = new GameState(_session);
		}
		[Test]
		public async Task TestPerformActions()
		{
			await _state.GoBackIfInStorylet();
			await _state.MoveIfNeeded("Lodgings");
			Assert.AreEqual("Your Lodgings",(await _session.User()).area.name);
			var back = _state.GetCached();
			Assert.AreEqual("Available", back.phase );
			Assert.IsNotNull( back.actions );
			Assert.IsNotNull( back.storylets );
			Assert.IsTrue( back.isSuccess );
			Assert.AreEqual(2,await _session.GetUserLocation());

			await _state.NavigateIntoAction(new ActionString("lodgings,Society,Private Supper"));
			var choice = _state.GetCached();
			Assert.AreEqual("In", choice.phase);
			Assert.AreEqual("Preparing Dinner", choice.storylet.name);

			await _state.GoBackIfInStorylet();

			var list = _state.GetCached();
			Assert.AreEqual(276092, await _session.GetStoryletId("Society", list));
			var firstst = list.storylets.First();
			Assert.AreEqual(firstst.id, await _session.GetStoryletId("1", list));

			var result = _state.DoInventoryAction("Mysteries","Cryptic Clue","1",true);
		}

		[Test]
		public void TestGetChildBranch()
		{
			var branches = new []{
				new Branch{name="wrongname"},
				new Branch{name="aoeu"},
				new Branch{name="AAAA",isLocked=true}
			};

			Assert.AreEqual("aoeu", branches.GetChildBranch("aoeu").name);
			Assert.AreEqual("aoeu", branches.GetChildBranch("2").name);
			Assert.AreEqual("wrongname", branches.GetChildBranch("1").name);
			Assert.IsNull(branches.GetChildBranch("AAAA"));
			Assert.AreEqual("aoeu", branches.GetChildBranch("aoeu/wrongname").name);
			Assert.AreEqual("aoeu", branches.GetChildBranch("AAAA/aoeu").name);
			Assert.AreEqual("aoeu", branches.GetChildBranch("abcd/aoeu").name);

		}

	}

}


// Describe "CreatePlan" {
// 	It "can create plan" {
// 		$result = CreatePlanFromActionString "lodgings,nightmares,1"
// 		$result.isSuccess | should be $true
// 	}
// 	It "can find plan" {
// 		$plan = Get-Plan "Invite someone to a Game of Chess"
// 		$plan | should not be null
// 		$plan.branch.name | should be "Invite someone to a Game of Chess"
// 	}
// 	It "can delete plan" {
// 		$result = DeleteExistingPlan "Invite someone to a Game of Chess"
// 	}
// }

