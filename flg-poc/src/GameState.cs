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

		public async Task<bool> PossessionSatisfiesLevel(string category, string name, string level)
		{
			var pos = await _session.GetPossession(category, name);

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
			else if (pos != null && (opNum.HasValue && pos.effectiveLevel >= opNum.Value))
			{
				return true;
			}
			return false;
		}

		public async Task<HasActionsLeft> HandleForcedAction()
		{
			if (_cachedList == null)
				_cachedList = await _session.ListStorylet();
			if (ForcedActionFile.simple.ContainsKey(_cachedList.storylet.name))
			{
				return await PerformAction(ForcedActionFile.simple[_cachedList.storylet.name]);
			}

			if (ForcedActionFile.complex.ContainsKey(_cachedList.storylet.name))
			{
				foreach (var entry in ForcedActionFile.complex[_cachedList.storylet.name])
				{
					var total = entry.Conditions.Length;
					var satisfied = 0;
					foreach (var cond in entry.Conditions)
					{
						var a = new ActionString(cond);
						if (await PossessionSatisfiesLevel(a.location, a.first, a.second))
							satisfied++;
					}
					if (total == satisfied)
					{
						return await PerformAction(entry.Action);
					}
				}
			}

			throw new Exception($"stuck in forced action named {_cachedList.storylet.name}, can't proceed without manual interaction");
		}

		public async Task<bool> HasForcedAction()
		{
			if (_cachedList != null)
				_cachedList = await _session.ListStorylet();
			return _cachedList.phase != "Available" && _cachedList.storylet != null && (_cachedList.storylet.canGoBack.HasValue && !_cachedList.storylet.canGoBack.Value);
		}

		public async Task<bool> HasActionsToSpare()
		{
			// 	Write-Verbose "remaining actions: $((Myself).character.actions)"
			if (await _session.GetAvailableActions() < 19)
			{
				// 		write-warning "not enough actions left"
				return false;
			}

			return true;
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
				//todo error handle also debug output
				//write-warning "storylet $($action.first) not found"
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
				// todo 			write-verbose "exiting storylet"
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

		public async Task<HasActionsLeft> PerformAction(string name)
		{
			if (_cachedList == null || _cachedList.phase == "End")
			{
				_cachedList = await _session.ListStorylet();
			}
			if (_cachedList.phase == "Available")
			{
				// TODO 		Write-Warning "Trying to perform action $name while phase: Available"
				throw new Exception($"Trying to perform action {name} while phase: Available");
				// should return null;
			}
			var branch = _cachedList.storylet.childBranches.GetChildBranch(name);

			if (branch == null)
			{
				return HasActionsLeft.Faulty;
			}

			_cachedList = await _session.ChooseBranch(branch.id);
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
				// TODO 		$result = DoAction "shutteredpalace,Spend,1"
				throw new NotImplementedException("TODO: moving to empresscort");
			}

			// todo test if race condition since we throw away result from moveto?
			await _session.MoveTo(location);
			_cachedList = await _session.ListStorylet();
		}

		public async Task<HasActionsLeft> DoInventoryAction(string category, string name, string action)
		{
			await GoBackIfInStorylet();
			var item = await _session.GetPossession(category, name);
			if (item != null && item.effectiveLevel >= 1)
			{
				var result = await _session.UseQuality(item.id);
				if (result.isSuccess)
				{
					return await PerformAction(action);
				}
				// todo the following two could possibly be thrown instead
				return HasActionsLeft.Faulty; // usequality failed
			}
			return HasActionsLeft.Faulty; // we don't actually have that possession, some prereq failed
		}

	}
}