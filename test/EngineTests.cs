using Newtonsoft.Json;
using NUnit.Framework;
using System.Linq;
using System;
using System.Threading.Tasks;
using fl;
using System.Collections.Generic;

namespace test
{
	[SetUpFixture]
	class AcqHolder
	{
		public static AcquisitionsHandler Acq;
		[OneTimeSetUp]
		public void RunBeforeAnyTests()
		{
			Acq = new AcquisitionsHandler();
			Acq.LoadFromFile();
		}
	}

	public class EngineTests
	{
		AcquisitionEngine _engine;
		GameState _state;
		Session _session;

		[SetUp]
		public void Setup()
		{
			_session = SessionHolder.Session;
			_state = new GameState(_session);
			_engine = new AcquisitionEngine(_state,AcqHolder.Acq);
		}

		PossessionCategory EnsureCategory(Myself myself, string category)
		{
			var c = myself.possessions.FirstOrDefault( p => p.name == category );
			if( c == null )
			{
				var list = myself.possessions.ToList();
				c = new PossessionCategory
				{
					appearance = "Default",
					name = category,
					categories = new []{category},
					possessions = new Possession[0]
				};
				list.Add(c);
				myself.possessions = list.ToArray();
			}
			return c;
		}

		async Task ClearPossessions()
		{
			var myself = await _session.Myself();
			myself.possessions = new PossessionCategory[0];

		}

		async Task SetPossession(string category,string item,int amount)
		{
			var myself = await _session.Myself();
			var cat = EnsureCategory(myself,category);

			var pos = cat.possessions.FirstOrDefault( p => p.name == item );
			if( pos == null )
			{
				pos = new Possession{
							name = item,
							level = amount,
							category = category,
							effectiveLevel = amount
						};
				var list = cat.possessions.ToList();
				list.Add(pos);
				cat.possessions = list.ToArray();
			}
			pos.level = pos.effectiveLevel = amount;
		}

		[Test]
		public void TestCanGetCardActionFromUseList()
		{
			var cards = new []{
				new CardAction{
					action = "1",
					name = "~Take a message to the living world"
				}
			};

			var result = cards.GetCardFromUseListByName("&quot;Take a message to the living world!&quot;",11595);

			Assert.IsNotNull(result);
			Assert.AreEqual(11595,result.eventId);
			Assert.AreEqual("&quot;Take a message to the living world!&quot;", result.name);
			Assert.AreEqual("1",result.action);
		}

		[Test]
		public async Task PossessionSatisfiesLevel()
		{
			await SetPossession("Mysteries","Extraordinary Implication",21);

			Assert.IsFalse( await _engine.PossessionSatisfiesLevel( "Mysteries", "Extraordinary Implication", "<3"));
			Assert.IsTrue( await _engine.PossessionSatisfiesLevel( "Mysteries", "Extraordinary Implication", "3"));
			Assert.IsTrue( await _engine.PossessionSatisfiesLevel( "Mysteries", "Extraordinary Implication", null));
			Assert.IsFalse( await _engine.PossessionSatisfiesLevel( "Mysteries", "Not Found Item", null));
			Assert.IsTrue( await _engine.PossessionSatisfiesLevel( "Mysteries", "Not Found Item", "=0"));
			Assert.IsTrue( await _engine.PossessionSatisfiesLevel( "Mysteries", "Extraordinary Implication", "=21"));
			Assert.IsFalse( await _engine.PossessionSatisfiesLevel( "Mysteries", "Extraordinary Implication", "22"));
			Assert.IsFalse( await _engine.PossessionSatisfiesLevel( "Mysteries", "Extraordinary Implication", "=20"));
		}

		[Test]
		public void TestAcquisitions()
		{
			var acq = AcqHolder.Acq.Acquisitions["GrindPersuasive"];
			Assert.IsNotNull(acq);
			Assert.AreEqual( "empresscourt,attend,perform", acq.Action );
			Assert.IsNotNull(AcqHolder.Acq.Acquisitions["Scandal"]);
		}

		[Test]
		public async Task TestAcquire()
		{
			var r = await _engine.Acquire(new ActionString("spite,Alleys,Cats,grey"),true);
			Assert.AreEqual(1,_engine.ActionHistory.Count);
			Assert.AreEqual("spite,Alleys,Cats,grey", _engine.ActionHistory[0].ToString() );
		}

		[Test]
		public void TestLookup()
		{
			Assert.AreEqual("inventory,Curiosity,Ablution Absolution,1", _engine.LookupAcquisitionByName("Suspicion").Action);
			Assert.AreEqual("StartShortStory", _engine.LookupAcquisitionByName("Working on...").Name);
		}

		[Test]
		public async Task RequireNothingIfAlreadySatisfied()
		{
			await SetPossession("Mysteries","Test Cryptic Clue",10);
			await SetPossession("Menaces","TestNightmares",5);

			var r = await _engine.Require("Mysteries","Test Cryptic Clue","5",null,true);
			Assert.AreEqual( HasActionsLeft.Available, r);
			Assert.AreEqual(0,_engine.ActionHistory.Count);

			r = await _engine.Require("Mysteries","Test Cryptic Clue","=10",null,true);
			Assert.AreEqual( HasActionsLeft.Available, r);
			Assert.AreEqual(0,_engine.ActionHistory.Count);

			r = await _engine.Require("Menaces","TestNightmares", "<8",null,true);
			Assert.AreEqual( HasActionsLeft.Available, r);
			Assert.AreEqual(0,_engine.ActionHistory.Count);
		}


		[Test]
		public async Task RequireWillFirstDoPrereq()
		{
			AcqHolder.Acq.AddTestAcquisition(new Acquisition{
				Name = "Test1Prereq",
				Prerequisites = new []{"Mysteries,Testaoeu,11,Test2Prereq"},
				Action = "Test1,Prereq,b,3",
			});
			AcqHolder.Acq.AddTestAcquisition(new Acquisition{
				Name = "Test2Prereq",
				Action = "Test Cryptic Clue,Prereq,b,3"
			});

			await SetPossession("Mysteries","Test Cryptic Clue",10);
			var r = await _engine.Require("Mysteries","Test Cryptic Clue","15","Test1Prereq",true);
			Assert.AreEqual( HasActionsLeft.Consumed, r);
			Assert.AreEqual(1,_engine.ActionHistory.Count);
			Assert.AreEqual("Test Cryptic Clue,Prereq,b,3",_engine.ActionHistory[0].ToString());
		}

		[Test]
		public async Task RequireByTagHasPriorityOverNameMatch()
		{
			AcqHolder.Acq.AddTestAcquisition(new Acquisition{
				Name = "Test1",
				Action = "Test1,a,b,3",
			});
			AcqHolder.Acq.AddTestAcquisition(new Acquisition{
				Name = "Test Cryptic Clue",
				Action = "Test Cryptic Clue,a,b,3",
				Result = "Test Cryptic Clue"
			});

			await SetPossession("Mysteries","Test Cryptic Clue",10);
			var r = await _engine.Require("Mysteries","Test Cryptic Clue","15","Test1",true);
			Assert.AreEqual( HasActionsLeft.Consumed, r);
			Assert.AreEqual(1,_engine.ActionHistory.Count);
			Assert.AreEqual("Test1,a,b,3",_engine.ActionHistory[0].ToString());
		}

		[Test]
		public async Task RequireByNameLookupWhenTagNotmatching()
		{
			AcqHolder.Acq.AddTestAcquisition(new Acquisition{
				Name = "Test Cryptic Clue",
				Action = "Test Cryptic Clue,a,b,c",
				Result = "Test Cryptic Clue"
			});

			await SetPossession("Mysteries","Test Cryptic Clue",10);
			var r = await _engine.Require("Mysteries","Test Cryptic Clue","15","NotUsedTag",true);
			Assert.AreEqual( HasActionsLeft.Consumed, r);
			Assert.AreEqual(1,_engine.ActionHistory.Count);
			Assert.AreEqual("Test Cryptic Clue,a,b,c",_engine.ActionHistory[0].ToString());
		}

		[Test]
		public async Task RequireByNameLookupWhenTagNull()
		{
			AcqHolder.Acq.AddTestAcquisition(new Acquisition{
				Name = "Test Cryptic Clue",
				Action = "Test Cryptic Clue,a,aoeu",
				Result = "Test Cryptic Clue"
			});

			await SetPossession("Mysteries","Test Cryptic Clue",10);
			var r = await _engine.Require("Mysteries","Test Cryptic Clue","15",null,true);
			Assert.AreEqual( HasActionsLeft.Consumed, r);
			Assert.AreEqual(1,_engine.ActionHistory.Count);
			Assert.AreEqual("Test Cryptic Clue,a,aoeu",_engine.ActionHistory[0].ToString());
		}

		[Test]
		public async Task RequireByNameLookupWhenTagNull_PrefersPerfectMatch()
		{
			AcqHolder.Acq.AddTestAcquisition(new Acquisition{
				Name = "Test Cryptic Clue 388292398",
				Action = "Test Cryptic Clue,a,c",
				Result = "Test Cryptic Clue"
			});
			AcqHolder.Acq.AddTestAcquisition(new Acquisition{
				Name = "Test Cryptic Clue",
				Action = "Test Cryptic Clue,a,b,b",
				Result = "Test Cryptic Clue"
			});
			await SetPossession("Mysteries","Test Cryptic Clue",10);
			var r = await _engine.Require("Mysteries","Test Cryptic Clue","15",null,true);
			Assert.AreEqual( HasActionsLeft.Consumed, r);
			Assert.AreEqual(1,_engine.ActionHistory.Count);
			Assert.AreEqual("Test Cryptic Clue,a,b,b",_engine.ActionHistory[0].ToString());
		}

		[Test]
		public async Task Require_PrioritizesTag()
		{
			AcqHolder.Acq.AddTestAcquisition(new Acquisition{
				Name = "Test Cryptic Clue AOEUHTNS",
				Action = "Test Cryptic Clue,a,c,1",
				Result = "Test Cryptic Clue"
			});
			AcqHolder.Acq.AddTestAcquisition(new Acquisition{
				Name = "Test Cryptic Clue",
				Action = "Test Cryptic Clue,a,b,1",
				Result = "Test Cryptic Clue"
			});
			await SetPossession("Mysteries","Test Cryptic Clue",10);
			var r = await _engine.Require("Mysteries","Test Cryptic Clue","15","Test Cryptic Clue aoeuhtns",true);
			Assert.AreEqual( HasActionsLeft.Consumed, r);
			Assert.AreEqual(1,_engine.ActionHistory.Count);
			Assert.AreEqual("Test Cryptic Clue,a,c,1",_engine.ActionHistory[0].ToString());
		}

		[Test]
		public async Task RequireByResultLookupWhenTagNullAndNoNameMatch()
		{
			AcqHolder.Acq.AddTestAcquisition(new Acquisition{
				Name = "TestCluenomatch",
				Action = "Test Cryptic Clue,1,2",
				Result = "Test Cryptic Clue match"
			});

			await SetPossession("Mysteries","Test Cryptic Clue",10);
			var r = await _engine.Require("Mysteries","Test Cryptic Clue match","15",null,true);
			Assert.AreEqual( HasActionsLeft.Consumed, r);
			Assert.AreEqual(1,_engine.ActionHistory.Count);
			Assert.AreEqual("Test Cryptic Clue,1,2",_engine.ActionHistory[0].ToString());
		}

		[Test]
		public async Task RequireWithEmptyLevelWillAcquireNoItemsInPossession()
		{
			AcqHolder.Acq.AddTestAcquisition(new Acquisition{
				Name = "Test1",
				Action = "Test1,a,b",
			});

			await SetPossession("Mysteries","Test Cryptic Clue",10);
			var r = await _engine.Require("Mysteries","Test Cryptic Clue",null,"Test1",true);
			Assert.AreEqual( HasActionsLeft.Available, r);
			Assert.AreEqual(0,_engine.ActionHistory.Count);

			r = await _engine.Require("Mysteries","Test Cryptic Clue Not Found",null,"Test1",true);
			Assert.AreEqual( HasActionsLeft.Consumed, r);
			Assert.AreEqual(1,_engine.ActionHistory.Count);
			Assert.AreEqual("Test1,a,b",_engine.ActionHistory[0].ToString());
		}

	}
}
