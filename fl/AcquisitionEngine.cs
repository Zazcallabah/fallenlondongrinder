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

					var alternate = false;
					if( action.location.Length > 0 && action.location[0] == '!' )
					{
						alternate = true;
					}
					var hasActionsLeft = await Require(action.location, action.first, action.second, t, dryRun);

					if( hasActionsLeft == HasActionsLeft.Mismatch )
					{
						// mismatch means we didnt consume, but we got the thing
						// either the thing was a prereq for this require, (this is the normal case), continue with prereq as usual
						if( alternate )
							// or, this was an alternate mean to get our current require, in which case return available
							return HasActionsLeft.Available;
					}
					else if (hasActionsLeft != HasActionsLeft.Available)
						return hasActionsLeft;
				}

			if (acq.Cards != null)
			{
				var opportunity = await _state.DrawOpportunity();
				foreach (var c in acq.Cards.Select(c => new ActionString(c)))
				{
					var discard = false;
					if( c.location[0] == '!' ) {
						discard = true;
						c.location = c.location.Substring(1);
					}
					var cId = c.location.AsNumber();
					var r = new Regex(c.location,RegexOptions.IgnoreCase);
					var card = opportunity.displayCards.FirstOrDefault(d => cId == null ? r.IsMatch(d.name) : d.eventId == cId);
					if (card != null)
					{
						if( discard )
						{
// todo check can you discard anytime?
							await _state.DiscardOpportunityCard(card);
						}
						else
						{
							var cardaction = new CardAction { action = c.first, eventId = card.eventId, name = card.name };
							var result = await _state.ActivateOpportunityCard(cardaction, opportunity.isInAStorylet);

							if(result == HasActionsLeft.Faulty)
								Log.Warning($"failed to activate card {card.name}, proceeding with acquisition");
							else if (result == HasActionsLeft.Consumed)
								return result;
						}
					}
				}
			}
			return await Acquire(new ActionString(acq.Action), dryRun);
		}
	}
}
