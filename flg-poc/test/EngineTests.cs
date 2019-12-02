using Newtonsoft.Json;
using NUnit.Framework;
using System.Linq;
using System;
using System.Threading.Tasks;
using fl;

namespace test
{
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
			_engine = new AcquisitionEngine(_state);
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
		public async Task PossessionSatisfiesLevel()
		{
			await SetPossession("Mysteries","Extraordinary Implication",21);

			Assert.IsFalse( await _engine.PossessionSatisfiesLevel( "Mysteries", "Extraordinary Implication", "<3"));
			Assert.IsTrue( await _engine.PossessionSatisfiesLevel( "Mysteries", "Extraordinary Implication", "3"));
			Assert.IsTrue( await _engine.PossessionSatisfiesLevel( "Mysteries", "Extraordinary Implication", "=21"));
			Assert.IsFalse( await _engine.PossessionSatisfiesLevel( "Mysteries", "Extraordinary Implication", "22"));
			Assert.IsFalse( await _engine.PossessionSatisfiesLevel( "Mysteries", "Extraordinary Implication", "=20"));
		}

		[Test]
		public void TestAcquisitions()
		{
			var acq = _engine.Acquisitions["GrindPersuasive"];
			Assert.IsNotNull(acq);
			Assert.AreEqual( "empresscourt,attend,perform", acq.Action );
			Assert.IsNotNull(_engine.Acquisitions["Scandal"]);
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
			Assert.AreEqual("inventory,Curiosity,Ablution Absolution,1", _engine.LookupAcquisition("Suspicion").Action);
			Assert.AreEqual("Cryptic Clue", _engine.LookupAcquisition("clue").Result);
			Assert.AreEqual("StartShortStory", _engine.LookupAcquisition("Working on...").Name);
		}

		[Test]
		public async Task TestRequire()
		{
			var oldp = JsonConvert.SerializeObject((await _session.Myself()).possessions);
			await ClearPossessions();
			await SetPossession("","Dangerous",100);
			await SetPossession("Mysteries","Cryptic Clue",10);
			await SetPossession("Menaces","Nightmares",5);

			var r = await _engine.Require("Menaces","Wounds",null,null,true);
			Assert.AreEqual(1,_engine.ActionHistory.Count);
			Assert.AreEqual("lodgings,wounds,time,1",_engine.ActionHistory[0].ToString());
			_engine.ActionHistory.Clear();

			r = await _engine.Require("Circumstance","Working on...","100","StartShortStory",true);
			Assert.AreEqual( HasActionsLeft.Consumed, r);
			Assert.AreEqual(1,_engine.ActionHistory.Count);
			Assert.AreEqual("veilgarden,begin a work,short story",_engine.ActionHistory[0]);
			_engine.ActionHistory.Clear();

			r = await _engine.Require("Mysteries","Cryptic Clue","5",null,true);
			Assert.AreEqual( HasActionsLeft.Available, r);
			Assert.AreEqual(0,_engine.ActionHistory.Count);

			r = await _engine.Require("Mysteries","Cryptic Clue","=10",null,true);
			Assert.AreEqual( HasActionsLeft.Available, r);
			Assert.AreEqual(0,_engine.ActionHistory.Count);

			r = await _engine.Require("Menaces","Nightmares", "<8",null,true);
			Assert.AreEqual( HasActionsLeft.Available, r);
			Assert.AreEqual(0,_engine.ActionHistory.Count);

			r = await _engine.Require("Mysteries","Cryptic Clue","15","Cryptic Clue",true);
			Assert.AreEqual( HasActionsLeft.Consumed, r);
			Assert.AreEqual(1,_engine.ActionHistory.Count);
			Assert.AreEqual("spite,Alleys,Cats,grey",_engine.ActionHistory[0]);
			_engine.ActionHistory.Clear();

			r = await _engine.Require("Menaces","Scandal","15",null,true);
			Assert.AreEqual( HasActionsLeft.Consumed, r);
			Assert.AreEqual(1,_engine.ActionHistory.Count);
			Assert.AreEqual("lodgings,scandal,service",_engine.ActionHistory[0]);
			_engine.ActionHistory.Clear();

			r = await _engine.Require("Mysteries","Cryptic Clue","15",null,true);
			Assert.AreEqual( HasActionsLeft.Consumed, r);
			Assert.AreEqual(1,_engine.ActionHistory.Count);
			Assert.AreEqual("flit,its king,meeting,understand",_engine.ActionHistory[0]);
			_engine.ActionHistory.Clear();

			r = await _engine.Require("Menaces","Nightmares","<5",null,true);
			Assert.AreEqual( HasActionsLeft.Consumed, r);
			Assert.AreEqual(1,_engine.ActionHistory.Count);
			Assert.AreEqual("flit,its king,meeting,understand",_engine.ActionHistory[0]);
			_engine.ActionHistory.Clear();
			(await _session.Myself()).possessions = JsonConvert.DeserializeObject<PossessionCategory[]>(oldp);
		}
	}
}
