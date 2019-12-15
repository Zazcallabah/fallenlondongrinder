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

		public static bool TrimmedStringEquals( string a, string b )
		{
			if( a == null )
				return b == null;
			if( b == null )
				return false;

			var ta = a.Trim(' ','\t','.');
			var tb = b.Trim(' ','\t','.');

			return string.Equals( ta,tb, StringComparison.InvariantCultureIgnoreCase );
		}

		// todo
		// 1 look for ignore case equals name
		// 2 look for ignore case regex match name
		// 3 grab list of ignore case equals result
		// (we should remove any result that isnt open for general availability)
		//	if 0, return faulty
		//	if 1 return that
		//	if > 1
		// 		order by reward
		// 	[possibly innstead order by weight]
		// calculate weight by number of conversions needed
		// weight:= sum weight prereqs
		// prereq weight := 0 if fulfilled
		// prereq weight := 1 + sum weight prereqs (with a marker towards avoiding reference loops)
		public Acquisition LookupAcquisitionByName(string name)
		{
			if (string.IsNullOrWhiteSpace(name))
				return null;

			var equals = _acqs.Acquisitions.Values.Where( a => TrimmedStringEquals( a.Name, name ) );
			if( equals.Any() )
			{
				if( equals.Count() > 1 )
				{
					//todo fix ordering in all results
					Log.Warning($"found multiple acqs matching {name}");
				}
				return equals.First();
			}

			var result = _acqs.Acquisitions.Values.Where(a => !string.IsNullOrWhiteSpace(a.Result) && TrimmedStringEquals(a.Result, name));
			if( !result.Any() )
				return null;
			if( result.Count() == 1 )
				return result.First();

			Log.Warning($"found multiple acqs matching result {name}");

			return result.OrderByDescending(a=>a.Reward).FirstOrDefault();
		}
		public Acquisition LookupAcquisitionByTag(string tag)
		{
			if (string.IsNullOrWhiteSpace(tag))
				return null;

			var equals = _acqs.Acquisitions.Values.Where( a => TrimmedStringEquals( a.Name, tag ) );
			if( equals.Any() )
			{
				if( equals.Count() > 1 )
				{
					Log.Warning($"found multiple acqs matching tag {tag}");
				}
				return equals.First();
			}
			return null;
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

			var acq = LookupAcquisitionByTag(tag);
			if (acq == null)
			{
				acq = LookupAcquisitionByName(name);
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
