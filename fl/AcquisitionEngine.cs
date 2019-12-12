using System;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.IO;

namespace fl
{
	public class AcquisitionEngine
	{
		GameState _state;
		AcquisitionsHandler _acqs;

		public Handler Handler { get; set; }
		public AcquisitionEngine(GameState state, AcquisitionsHandler testAcqs)
		{
			_state = state;
			_acqs = testAcqs;
		}

		public AcquisitionEngine(GameState state)
		{
			_state = state;
			_acqs = new AcquisitionsHandler();
			_acqs.LoadFromFile();
		}

		public readonly List<ActionString> ActionHistory = new List<ActionString>();

		public void RecordAction(ActionString action)
		{
			ActionHistory.Add(action);
		}

		public async Task<HasActionsLeft> Acquire(ActionString actionstr, bool dryRun = false)
		{
			if (dryRun)
			{
				RecordAction(actionstr);
				return HasActionsLeft.Consumed;
			}
			return await Handler.DoAction(actionstr);
		}

		public Acquisition LookupAcquisition(string name)
		{
			if (string.IsNullOrWhiteSpace(name))
				return null;

			if (_acqs.Acquisitions.ContainsKey(name))
				return _acqs.Acquisitions[name];
			var r = new Regex(name, RegexOptions.IgnoreCase);
			var matching = _acqs.Acquisitions.Values.FirstOrDefault(a => r.IsMatch(a.Name));
			if (matching != null)
				return matching;
			var resultmatching = _acqs.Acquisitions.Values.Where(a => !string.IsNullOrWhiteSpace(a.Result) && r.IsMatch(a.Result)).ToArray();

			var exactmatch = resultmatching.Where(a => a.Result == name).OrderByDescending(a => a.Reward).FirstOrDefault();
			if (exactmatch != null)
				return exactmatch;
			return resultmatching.OrderByDescending(a => a.Reward).FirstOrDefault();

		}

		public async Task<bool> PossessionSatisfiesLevel(string category, string name, string level)
		{
			var pos = await _state.GetPossession(category, name);

			if (string.IsNullOrWhiteSpace(level))
			{
				return pos != null && pos.effectiveLevel > 0;
			}

			var opNum = level.Substring(1).AsNumber();

			if (level[0] == '<')
			{
				if (pos == null || (opNum.HasValue && pos.effectiveLevel < opNum.Value))
				{
					return true;
				}
			}
			else if (level[0] == '=')
			{
				if (pos == null && (opNum.HasValue && opNum.Value == 0))
				{
					return true;
				}
				else if (pos != null && (opNum.HasValue && pos.effectiveLevel == opNum.Value))
				{
					return true;
				}
			}
			else if (pos != null && pos.effectiveLevel >= level.AsNumber())
			{
				return true;
			}
			return false;
		}

		public async Task<HasActionsLeft> Require(string category, string name, string level, string tag = null, bool dryRun = false)
		{
			if (await PossessionSatisfiesLevel(category, name, level))
			{
				return HasActionsLeft.Available;
			}

			Log.Debug($"    REQ: {category} {name} {level} ({tag})");

			var acq = LookupAcquisition(tag);
			if (acq == null)
			{
				acq = LookupAcquisition(name);
			}
			if (acq == null)
			{
				Log.Warning($"no way to get {category} {name} found in acquisitions list");
				return HasActionsLeft.Faulty;
			}

			if( acq.Prerequisites != null )
				foreach (var action in acq.Prerequisites.Select(p => new ActionString(p)))
				{
					var t = action.third?.FirstOrDefault();
					var hasActionsLeft = await Require(action.location, action.first, action.second, t, dryRun);

					if( hasActionsLeft == HasActionsLeft.Mismatch )
					{
						// mismatch means we didnt consume, but we got the thing
						// either the thing was a prereq for this require, (this is the normal case), continue with prereq as usual
						if( action.alternate )
							// or, this was an alternate mean to get our current require, in which case return available
							return HasActionsLeft.Available;
					}
					else if (hasActionsLeft != HasActionsLeft.Available)
						return hasActionsLeft;
				}

			if (acq.Cards != null)
			{
				var opp = await _state.DrawOpportunity();

				var options = opp.GetOptions(acq.Cards);

				foreach (var cardreq in options )
				{
					var result = await AttemptOpportunityCard(cardreq);
					if(result == HasActionsLeft.Faulty)
						Log.Warning($"failed to activate card {cardreq.name}, proceeding with acquisition");
					else if (result == HasActionsLeft.Consumed)
						return result;
				}
			}
			return await Acquire(new ActionString(acq.Action), dryRun);
		}

		public async Task<HasActionsLeft> AttemptOpportunityCard(CardAction card)
		{

			if (card == null)
				return HasActionsLeft.Available;

			if( card.eventId == null )
				return HasActionsLeft.Available;

			if (card.require != null)
			{
				foreach (var action in card.require.Select(r => new ActionString(r)))
				{
					string tag = action.third?.FirstOrDefault();
					HasActionsLeft hasActionsLeft = await Require(action.location, action.first, action.second, tag);
					if (hasActionsLeft == HasActionsLeft.Faulty)
					{
						Log.Warning($"Missing prereq path for card {card.name}, discarding.");
						await _state.DiscardOpportunityCard(card.eventId.Value);
					}
					if (hasActionsLeft != HasActionsLeft.Available)
						return hasActionsLeft;
				}
			}

			if( card.name[0] == '!' )
			{
				Log.Info($"Discarding {card.name}");
				await _state.DiscardOpportunityCard(card.eventId.Value);
				return HasActionsLeft.Available;
			}
			else
			{
				return await _state.ActivateOpportunityCard(card);
			}
		}
	}
}
