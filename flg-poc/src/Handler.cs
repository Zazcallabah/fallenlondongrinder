
using System.Linq;
using System.Threading.Tasks;
using System.Collections.Generic;
using System;

namespace fl
{
	public class Handler
	{
		Session _session;
		GameState _state;
		AcquisitionEngine _engine;

		public Handler(Session session, GameState state, AcquisitionEngine engine)
		{
			_session = session;
			_state = state;
			_engine = engine;
			_engine.Handler = this;

			LoadLockedAreaData();

			// cards
			FileHandler.ForEachFile("cards", MergeCardFile);
		}

		public async Task RunActions(IEnumerable<ActionString> actions)
		{

			await FilterCards();

			if (await _state.HasActionsToSpare())
			{
				var hasActionsLeft = await HandleLockedArea();
				if (hasActionsLeft != HasActionsLeft.Available)
				{
					return;
				}

				hasActionsLeft = await EarnestPayment();
				if (hasActionsLeft != HasActionsLeft.Available)
				{
					return;
				}

				hasActionsLeft = await CheckMenaces();
				if (hasActionsLeft != HasActionsLeft.Available)
				{
					return;
				}

				hasActionsLeft = await HandleRenown();
				if (hasActionsLeft != HasActionsLeft.Available)
				{
					return;
				}

				hasActionsLeft = await TryOpportunity();
				if (hasActionsLeft != HasActionsLeft.Available)
				{
					return;
				}
				foreach (var action in actions)
				{
					hasActionsLeft = await DoAction(action);
					if (hasActionsLeft != HasActionsLeft.Available)
					{
						return;
					}
					Log.Info("still has actions left");
				}
			}
		}

		void LoadLockedAreaData()
		{
			foreach (var area in ParseString(FileHandler.ReadFile("lockedareas.json")))
			{
				_lockedAreas.Add(area.name, area);
			}
		}

		IEnumerable<LockedAreaData> ParseString(string filecontents)
		{
			var jobject = Newtonsoft.Json.Linq.JObject.Parse(filecontents);
			foreach (Newtonsoft.Json.Linq.JProperty property in jobject.Properties())
			{
				LockedAreaData a = property.Value.ToObject<LockedAreaData>();
				a.name = property.Name;
				yield return a;
			}
		}

		public class LockedAreaData
		{
			public string name;
			public string[] require;
			public bool? forced;
		}

		IDictionary<string, LockedAreaData> _lockedAreas = new Dictionary<string, LockedAreaData>();

		LockedAreaData LookupLockedAreaData(string name)
		{
			if (!_lockedAreas.ContainsKey(name))
				return null;
			return _lockedAreas[name];
		}

		private async Task<HasActionsLeft> HandleLockedArea()
		{
			if (await _state.HasForcedAction())
			{
				Log.Info("in forced storylet");
				return await _state.HandleForcedAction();
			}

			if (!await _session.IsLockedArea())
			{
				return HasActionsLeft.Available;
			}

			// 		# canTravel false means you are in a locked area i think
			// 		# also user.setting.itemsUsableHere
			// 		# $canTravel = $list.Phase -eq "Available" # property is storylets
			// # $isInStorylet = $list.Phase -eq "In" -or $list.Phase -eq "InItemUse" # property is storylet
			// # phase "End" probably doesnt happen here?

			// 		# todo add handling of special circumstances here
			// 		# like tomb colonies, prison, sailing, etc

			// 		# user.area.id/name or user.setting.name?
			// 		# Imprisoned - New Newgate Prison

			var user = await _session.User();
			var areaData = LookupLockedAreaData(user.setting.name);

			if (areaData == null)
			{
				Log.Error("Stuck in locked area without instructions");
				return HasActionsLeft.Faulty;
			}
			if (areaData.forced.HasValue && areaData.forced.Value)
			{
				Log.Info("relying on forced action data");
				await _state.GoBackIfInStorylet();
				return HasActionsLeft.Consumed; // todo wait shouldnt this trigger earlier than this?
			}
			if (areaData.require == null)
				return HasActionsLeft.Faulty;
			foreach (var action in areaData.require.Select(a => new ActionString(a)))
			{
				string level = null;
				string tag = null;
				if (action.third != null)
				{
					level = action.third[0];
					if (action.third.Length > 1)
						tag = action.third[2];
				}
				var hasactionsleft = await _engine.Require(action.first, action.second, level, tag);
				if (hasactionsleft == HasActionsLeft.Faulty || hasactionsleft == HasActionsLeft.Consumed)
				{
					return hasactionsleft;
				}
			}
			return HasActionsLeft.Consumed;
		}

		private async Task<HasActionsLeft> EarnestPayment()
		{
			var hasActionsLeft = await HandleProfession();
			if (hasActionsLeft != HasActionsLeft.Available)
			{
				return hasActionsLeft;
			}
			return await _engine.Require("Curiosity", "An Earnest of Payment", "<1", "Payment");
		}

		private async Task<HasActionsLeft> HandleRenown()
		{
			if (!await _state.PossessionSatisfiesLevel("Route", "Route: Mrs Plenty's Most Distracting Carnival", "1"))
			{
				return HasActionsLeft.Available;
			}

			var isPosi = await _state.PossessionSatisfiesLevel("Accomplishments", "A Person of Some Importance", "1");
			var mapper = new Dictionary<string, string>{
				{"Church", "The Church"},
				{"Docks", "The Docks"},
				{"GreatGame", "The Great Game"},
				{"TombColonies", "Tomb-Colonies"},
				{"RubberyMen", "Rubbery Men"}
			};
			var factions = new[]{
				"Church",
		//		"Bohemians",
				"Constables",
				"Criminals",
				"Hell",
				"Revolutionaries",
				"Society",
		//		"Docks",
				"Urchins",
				"GreatGame",
				"TombColonies",
				"RubberyMen"
			};
			foreach (var faction in factions)
			{
				var fullname = $"Renown: {faction}";

				if (mapper.ContainsKey(faction))
				{
					fullname = $"Renown: {mapper[faction]}";
				}

				if (await _state.PossessionSatisfiesLevel("Contacts", fullname, "5"))
				{
					if (isPosi)
					{
						var hasActionsLeft = await _engine.Require("Contacts", fullname, "15", $"Renown{faction}8");
						if (hasActionsLeft == HasActionsLeft.Consumed)
						{
							return hasActionsLeft;
						}
					}
					else
					{
						var hasActionsLeft = await _engine.Require("Contacts", fullname, "8", $"Renown{faction}5");
						if (hasActionsLeft == HasActionsLeft.Consumed)
						{
							return hasActionsLeft;
						}
					}
				}
			}
			return HasActionsLeft.Available;
		}
		private async Task<HasActionsLeft> CheckMenaces()
		{
			var hasActionsLeft = await LowerScandal();
			if (hasActionsLeft != HasActionsLeft.Available)
			{
				return hasActionsLeft;
			}

			hasActionsLeft = await LowerWounds();
			if (hasActionsLeft != HasActionsLeft.Available)
			{
				return hasActionsLeft;
			}

			hasActionsLeft = await LowerNightmares();
			if (hasActionsLeft != HasActionsLeft.Available)
			{
				return hasActionsLeft;
			}

			hasActionsLeft = await LowerSuspicion();
			if (hasActionsLeft != HasActionsLeft.Available)
			{
				return hasActionsLeft;
			}
			return HasActionsLeft.Available;
		}

		public async Task<HasActionsLeft> LowerWounds()
		{
			var id = 206852;
			var plankey = "f06ed3289029f70378a428d6910b511b";
			return await LowerGenericMenace("Wounds", 5, 3, id, plankey);
		}

		public async Task<HasActionsLeft> LowerSuspicion()
		{
			var id = 206850;
			var plankey = "932806bdcdaf7e02a31953c9a440d604";
			return await LowerGenericMenace("Suspicion", 6, 3, id, plankey);
		}

		public async Task<HasActionsLeft> LowerNightmares()
		{
			var id = 206851;
			var plankey = "e65514f6f0f061495e2eb93f27fcb79c";
			return await LowerGenericMenace("Nightmares", 5, 3, id, plankey);
		}

		public async Task<HasActionsLeft> LowerScandal()
		{
			var id = 204544;
			var plankey = "f7952b8800ef52f240156a3c4c6940a6";

			return await LowerGenericMenace("Scandal", 5, 3, id, plankey);
		}


		public async Task<HasActionsLeft> LowerGenericMenace(string menace, int trigger, int clear, int planId, string planKey)
		{

			var triggerstr = new ActionString($"Menaces,{menace},{trigger}");
			var exitc = new ActionString($"Menaces,{menace},<{clear}");
			var action = new ActionString($"require,Menaces,{menace},<1");
			return await DoStateBasedAction(triggerstr, exitc, action, planId, planKey);
		}
		public async Task<HasActionsLeft> DoStateBasedAction(
			ActionString trigger,
			ActionString exitCondition,
			ActionString action,
			int planId,
			string planKey
		)
		{
			if (await _session.ExistsPlan(planId))
			{
				if (await _state.PossessionSatisfiesLevel(exitCondition.location, exitCondition.first, exitCondition.second))
				{
					await _session.DeletePlan(planId);
					return HasActionsLeft.Available;
				}

				var hasActionsLeft = await DoAction(action);
				return hasActionsLeft;
			}

			if (await _state.PossessionSatisfiesLevel(trigger.location, trigger.first, trigger.second))
			{
				await _session.CreatePlan(planId, planKey);
				return await DoAction(action);
			}

			return HasActionsLeft.Available;
		}

		public async Task<HasActionsLeft> DoAction(ActionString action)
		{
			Log.Info($"doing action {action}");

			//  bazaar can usually be done even in storylet, i think?
			//  require is best done doing its inventory checks before doing goback and move, to aviod extra liststorylet calls
			//  inventory just needs to make sure we do gobackifinstorylet first
			if (action.location == "buy")
			{
				if (action.third == null)
				{
					throw new Exception($"invalid buy action {action}");
				}
				var n = action.third[0].AsNumber();
				if (!n.HasValue)
				{
					throw new Exception($"invalid buy action {action}");
				}
				await _session.BuyPossession(action.first, action.second, n.Value);
				return HasActionsLeft.Mismatch;
			}
			else if (action.location == "sell")
			{
				var n = action.second.AsNumber();
				if (!n.HasValue)
				{
					throw new Exception($"invalid sell action {action}");
				}
				await _session.SellPossession(action.first, n.Value);
				return HasActionsLeft.Mismatch;
			}
			else if (action.location == "equip")
			{
				await _session.Equip(action.first);
				return HasActionsLeft.Mismatch;
			}
			else if (action.location == "unequip")
			{
				await _session.Unequip(action.first);
				return HasActionsLeft.Mismatch;
			}
			else if (action.location == "require")
			{
				string level = null;
				string tag = null;
				if (action.third != null)
				{
					level = action.third[0];
					if (action.third.Length > 1)
						tag = action.third[2];
				}
				var hasActionsLeft = await _engine.Require(action.first, action.second, level, tag);
				return hasActionsLeft;
			}
			else if (action.location == "inventory")
			{
				if (action.third == null)
				{
					throw new Exception($"invalid inventory action {action}");
				}
				var hasActionsLeft = await _state.DoInventoryAction(action.first, action.second, action.third[0]);
				return hasActionsLeft;
			}
			else if (action.location == "grind_money")
			{
				return await GrindMoney();
			}
			else if (action.location == "handle_profession")
			{
				return await HandleProfession();
			}
			return await _state.NavigateIntoAction(action);
		}

		private async Task<HasActionsLeft> HandleProfession()
		{
			var hasActionsLeft = await _engine.Require("Route", "Route: Lodgings", "1", "RentLodgings");
			if (hasActionsLeft == HasActionsLeft.Consumed)
			{
				return hasActionsLeft;
			}

			var profession = await _session.GetPossession("Major Laterals", "Profession");

			if (profession != null && (profession.level < 7 || profession.level > 10))
			{
				return HasActionsLeft.Available;
			}

			var filterLevels = new Dictionary<int, string>{
				{7, "Dangerous"},
				{8 ,"Persuasive"},
				{9 ,"Shadowy"},
				{10, "Watchful"}
			};

			var levelsBelow70 = new List<Possession>();
			foreach (var item in filterLevels.Values)
			{
				var p = await _session.GetPossession("Basic", item);
				if (p.effectiveLevel <= 70)
					levelsBelow70.Add(p);
			}

			if (!levelsBelow70.Any())
				return HasActionsLeft.Available;

			if (profession != null)
			{
				var basicAbility = await _session.GetPossession("Basic", filterLevels[profession.level]);
				if (basicAbility.effectiveLevel <= 70)
				{
					return HasActionsLeft.Available;
				}
				var result = await DoAction(new ActionString("lodgings,Write Letters,Choose a new Profession"));
			}

			var professions = new Dictionary<string, string>{
				{"Dangerous","Tough"},
				{"Persuasive", "Minor Poet"},
				{"Shadowy","Pickpocket"},
				{"Watchful","Enquirer"}
			};

			foreach (var stat in professions.Keys)
			{
				var basic = await _session.GetPossession("Basic", stat);
				if (basic.effectiveLevel <= 70)
				{
					var jobname = professions[stat];
					return await DoAction(new ActionString($"lodgings,Adopt a Training Profession,{jobname}"));
				}
			}

			return HasActionsLeft.Available;
		}

		private async Task<HasActionsLeft> GrindMoney()
		{
			if (await _state.PossessionSatisfiesLevel("Route", "Route: The Forgotten Quarter", "1") && await _state.PossessionSatisfiesLevel("Stories", "Archaeologist", "2"))
			{
				var hasmoreActions = await _engine.Require("Progress", "Archaeologist's Progress", "99"); // infinite grind for money
				return HasActionsLeft.Consumed;
			}

			await _session.SellIfMoreThan("Curiosity", "Competent Short Story", 0);
			await _session.SellIfMoreThan("Curiosity", "Compelling Short Story", 1);
			await _session.SellIfMoreThan("Curiosity", "Exceptional Short Story", 1);
			bool exceptional = false;
			var hasMoreActions = await _engine.Require("Progress", "Potential", "61", "Daring Edit");
			if (hasMoreActions == HasActionsLeft.Consumed)
			{
				return hasMoreActions;
			}
			if (await _state.PossessionSatisfiesLevel("Stories", "A Name Scrawled in Blood", "3"))
			{
				hasMoreActions = await _engine.Require("Progress", "Potential", "71", "Touch of darkness");
				if (hasMoreActions == HasActionsLeft.Consumed)
				{
					return hasMoreActions;
				}

				if (await _state.PossessionSatisfiesLevel("Accomplishments", "A Person of Some Importance", "1"))
				{
					hasMoreActions = await _engine.Require("Progress", "Potential", "81", "something exotic");
					if (hasMoreActions == HasActionsLeft.Consumed)
					{
						return hasMoreActions;
					}
					hasMoreActions = await _engine.Require("Curiosity", "Exceptional Short Story", "2");
					exceptional = true;
				}
			}
			if (!exceptional)
			{
				hasMoreActions = await _engine.Require("Curiosity", "Compelling Short Story", "1");
			}

			await _session.SellIfMoreThan("Curiosity", "Competent Short Story", 0);
			await _session.SellIfMoreThan("Curiosity", "Compelling Short Story", 1);
			await _session.SellIfMoreThan("Curiosity", "Exceptional Short Story", 1);
			return hasMoreActions;
		}


		// cards

		List<CardAction> _use = new List<CardAction>();
		List<string> _keep = new List<string>();
		List<string> _trash = new List<string>();
		Opportunity _cachedOpportunity;

		public async Task<CardAction> GetCardInUseList()
		{
			if (_cachedOpportunity == null)
				_cachedOpportunity = await _session.DrawOpportunity();

			var options = _cachedOpportunity.displayCards
				.Select(c => _use.GetCardFromUseListByName(c.name, c.eventId))
				.Where(c => c != null);

			if (!options.Any())
				return null;

			return options.FirstOrDefault(c => c.require == null) ?? options.FirstOrDefault();
		}

		public async Task<HasActionsLeft> TryOpportunity()
		{
			if (await _session.IsLockedArea())
				return HasActionsLeft.Mismatch;


			var card = await GetCardInUseList();

			if (card == null)
				return HasActionsLeft.Mismatch;

			if (card.require != null)
			{
				foreach (var action in card.require.Select(r => new ActionString(r)))
				{
					HasActionsLeft hasActionsLeft = HasActionsLeft.Consumed; // TODO Require $action.location $action.first $action.second $action.third
					if (hasActionsLeft != HasActionsLeft.Available)
						return hasActionsLeft;
				}
			}

			HasActionsLeft result = await _state.ActivateOpportunityCard(card, _cachedOpportunity.isInAStorylet);
			return result;
		}

		void MergeCardFile(string batch, string filecontents)
		{
			var jobject = Newtonsoft.Json.Linq.JObject.Parse(filecontents);
			var use = jobject["use"]?.ToObject<CardAction[]>();
			var keep = jobject["keep"]?.ToObject<string[]>();
			var trash = jobject["trash"]?.ToObject<string[]>();
			if (use != null)
				_use.AddRange(use);
			if (keep != null)
				_keep.AddRange(keep);
			if (trash != null)
				_trash.AddRange(trash);
		}

		public async Task FilterCards()
		{
			if (await _session.IsLockedArea())
			{
				Log.Info("In locked area, won't filter cards");
				return;
			}
			_cachedOpportunity = await _session.DrawOpportunity();
			foreach (var cardobj in _cachedOpportunity.displayCards)
			{
				if (!ShouldKeepCard(cardobj))
				{
					Log.Info($"Discarding {cardobj.name}");
					await _session.DiscardOpportunity(cardobj.eventId);
					_cachedOpportunity = null;
				}
			}
		}

		bool ShouldKeepCard(Card card)
		{
			if (_use.CollectionHasCard(card))
			{
				return true;
			}
			if (_keep.CollectionHasCard(card))
			{
				return true;
			}
			if (_trash.CollectionHasCard(card))
			{
				return false;
			}
			return !card.IsCommonCard();
		}
	}
}
