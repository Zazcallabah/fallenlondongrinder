using System;
using System.Threading.Tasks;
using System.Collections.Generic;

namespace fl
{
	public class GameState
	{
		Session _session;
		StoryletList _cachedList;

		public GameState(Session s)
		{
			_session = s;
		}

		public StoryletList GetCached()
		{
			return _cachedList;
		}

		public async Task<string> GetStoryletName(){
			if (_cachedList == null)
				_cachedList = await _session.ListStorylet();
			return _cachedList.storylet?.name;
		}

		public async Task<bool> HasForcedAction()
		{
			if (_cachedList == null)
				_cachedList = await _session.ListStorylet();
			return _cachedList.phase != "Available" && _cachedList.storylet != null && (_cachedList.storylet.canGoBack.HasValue && !_cachedList.storylet.canGoBack.Value);
		}

		public async Task DiscardOpportunityCard(Card card)
		{
			await _session.DiscardOpportunity(card.eventId);
		}

		public async Task<HasActionsLeft> ActivateOpportunityCard(CardAction card, bool inStoryletHint)
		{
			if (card.eventId == null)
				throw new Exception("card has no eventId set");
			if (inStoryletHint)
				await _session.GoBack();


			Log.Info($"doing card {card.name} action {card.action}");
			_cachedList = await _session.BeginStorylet(card.eventId.Value);
			if (!string.IsNullOrWhiteSpace(card.action))
			{
				return await PerformActions(card.action.Split(','));
			}

			return HasActionsLeft.Consumed;
		}
		public async Task<HasActionsLeft> NavigateIntoAction(ActionString action)
		{

			await GoBackIfInStorylet();

			if (_cachedList == null)
			{
				// was return false <- hasmoreactions?
				throw new Exception("invalid state after goback");
			}

			await MoveIfNeeded(action.location);

			// this is a remnant from before the time of prereq in the acq engine
			// if (action.location == "carnival" && action.first != "Buy")
			// {
			// 	var hasActionsLeft = await EnsureTickets()
			// 	if (!hasActionsLeft)
			// 	{
			// 		return false;
			// 	}
			// }

			bool success = await EnterStorylet(action.first);

			if (_cachedList == null)
			{
				Log.Warning($"storylet {action.first} not found");
				return HasActionsLeft.Faulty;
			}

			var ac = new List<string> { action.second };
			if (action.third != null)
				ac.AddRange(action.third);

			return await PerformActions(ac);
		}

		public async Task GoBackIfInStorylet()
		{
			if (_cachedList == null || _cachedList.phase == "End")
				_cachedList = await _session.ListStorylet();
			if (_cachedList.phase == "Available")
				return;

			if (_cachedList.storylet == null)
				return;

			if (_cachedList.storylet.canGoBack.HasValue && _cachedList.storylet.canGoBack.Value)
			{
				Log.Debug("DEBUG: exiting storylet");
				_cachedList = await _session.GoBack();
				return;
			}
			else
			{
				// 			# we check for this much earlier, this is redundant
				// 			$done = HandleLockedStorylet $list
				// 			return $null
				throw new Exception("called GoBackIfInStorylet on what looks like locked storylet");
			}
		}

		public async Task<Opportunity> DrawOpportunity()
		{
			return await _session.DrawOpportunity();
		}

		public async Task<Possession> GetPossession(string category, string name)
		{
			return await _session.GetPossession(category,name);
		}

		public async Task<HasActionsLeft> PerformAction(string name)
		{
			if (_cachedList == null || _cachedList.phase == "End")
			{
				_cachedList = await _session.ListStorylet();
			}
			if (_cachedList.phase == "Available")
			{
				throw new Exception($"Trying to perform action {name} while phase: Available");
			}
			var branch = _cachedList.storylet.childBranches.GetChildBranch(name);

			if (branch == null)
			{
				return HasActionsLeft.Faulty;
			}

			var branchResult = await _session.ChooseBranch(branch.id);
			if( branchResult != null )
				_cachedList = branchResult;
			return HasActionsLeft.Available; // can technically be consumed, but until we figure out list.phase and stuff, we have to depend on upstream calls knowing what they are doing
		}

		public async Task<HasActionsLeft> PerformActions(IEnumerable<string> actions)
		{
			if (actions == null)
				return HasActionsLeft.Faulty; // todo throw exception here?

			foreach (var action in actions)
			{
				if (!string.IsNullOrWhiteSpace(action))
				{
					if (_cachedList.phase == "End")
						_cachedList = await _session.ListStorylet();
					var result = await PerformAction(action);
					if (_cachedList == null || result == HasActionsLeft.Faulty)
					{
						return HasActionsLeft.Faulty;
					}
				}
			}
			return HasActionsLeft.Consumed;
		}

		// returned bool here is an IsSuccess flag, not hasactionsleft
		// it isnt used afaict, so just throw on error?
		public async Task<bool> EnterStorylet(string storyletname)
		{
			var sid = await _session.GetStoryletId(storyletname, _cachedList);
			if (sid != null)
			{
				_cachedList = await _session.BeginStorylet(sid.Value);
				return true;
			}
			else
			{
				_cachedList = null;
				return false;
			}
		}

		public async Task MoveIfNeeded(string location)
		{
			if (await _session.IsInLocation(location))
				return;

			if (await _session.GetLocationId(location) == await _session.GetLocationId("empress court"))
			{
				await _session.MoveTo("shutteredpalace");
				_cachedList = await _session.ListStorylet();
				await EnterStorylet("spend");
				await PerformAction("1");
				return;
			}

			// todo test if race condition since we throw away result from moveto?
			await _session.MoveTo(location);
			_cachedList = await _session.ListStorylet();
		}

		public async Task<HasActionsLeft> DoInventoryAction(string category, string name, string action, bool dryRun = false)
		{
			await GoBackIfInStorylet();
			var item = await _session.GetPossession(category, name);
			if (item != null && item.effectiveLevel >= 1)
			{
				var result = await _session.UseQuality(item.id);
				if (result.isSuccess && !dryRun )
				{
					_cachedList = null;
					return await PerformAction(action);
				}
				// todo the following two could possibly be thrown instead
				return HasActionsLeft.Faulty; // usequality failed
			}
			return HasActionsLeft.Faulty; // we don't actually have that possession, some prereq failed
		}

	}
}