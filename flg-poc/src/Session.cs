﻿using System;
using System.Net.Http;
using System.Threading.Tasks;
using System.Collections.Generic;
using Newtonsoft.Json;
using System.Linq;
using System.Text.RegularExpressions;

namespace fl
{
	public class Session
	{
		readonly HttpClient _client = new HttpClient();
		bool _loggedin = false;
		string _email;
		string _pass;
		IList<MapEntry> _mapCache = null;
		IDictionary<int, ShopItem[]> _shops = new Dictionary<int, ShopItem[]>();

		// caches
		User _user;
		Myself _myself;
		Plans _plans;

		public Session(string email, string pass)
		{
			_email = email;
			_pass = pass;
			_client.BaseAddress = new System.Uri("https://api.fallenlondon.com/api/");
			_client.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:67.0) Gecko/20100101 Firefox/67.0");
		}

		HttpContent MakeContent(dynamic payload)
		{
			if (payload == null)
				return null;
			return new StringContent(JsonConvert.SerializeObject(payload), System.Text.Encoding.UTF8, "application/json");
		}

		static void EnsureIsSuccess(string href, string verb, HttpResponseMessage response, string data)
		{
			if (!response.IsSuccessStatusCode)
				throw new Exception($"invalid statuscode for {verb} {href} => {response.StatusCode} {data}");

			var msg = JsonConvert.DeserializeObject<SuccessMessage>(data);

			if (!msg.isSuccess.HasValue)
				return;

			if (!msg.isSuccess.Value)
				throw new Exception($"bad response for {verb} {href} => {response.StatusCode} {data}");
		}

		public async Task<T> Post<T>(string href, dynamic payload = null)
		{
			if (!_loggedin)
			{
				await GetToken();
			}

			var response = await _client.PostAsync(href, MakeContent(payload));
			var content = await response.Content.ReadAsStringAsync();
			// todo write debug
			EnsureIsSuccess(href, "POST", response, content);
			T data = JsonConvert.DeserializeObject<T>(content);
			return data;
		}

		public async Task<T> Get<T>(string href)
		{
			if (!_loggedin)
			{
				await GetToken();
			}

			var response = await _client.GetAsync(href);
			var content = await response.Content.ReadAsStringAsync();
			EnsureIsSuccess(href, "GET", response, content);
			T data = JsonConvert.DeserializeObject<T>(content);
			// todo write debug
			return data;
		}

		async Task<string> GetToken()
		{
			var payload = JsonConvert.SerializeObject(new { email = _email, password = _pass });
			var response = await _client.PostAsync("login", new StringContent(payload, System.Text.Encoding.UTF8, "application/json"));
			if (response.Content == null)
			{
				throw new Exception("invalid login");
			}
			var content = await response.Content.ReadAsStringAsync();
			dynamic token = JsonConvert.DeserializeObject(content);
			if (token == null || string.IsNullOrWhiteSpace((string)token.jwt))
			{
				throw new Exception("invalid login");
			}
			_loggedin = true;
			_client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", (string)token.jwt);
			return token.jwt;
		}
		async Task<IList<MapEntry>> GetMap()
		{
			if (_mapCache == null)
			{
				Map response = await Get<Map>("map");
				_mapCache = response.areas;
			}
			return _mapCache;
		}

		readonly static IDictionary<string, int> _locations = new Dictionary<string, int>
		{
			["New Newgate Prison"] = 1,
			["Your Lodgings"] = 2,
			["Ladybones Road"] = 4,
			["Watchmakers Hill"] = 5,
			["WatchmakersHill"] = 5,
			["Watchmaker's Hill"] = 5,
			["Spite"] = 7,
			["Mrs Plenty's Carnival"] = 18,
			["Carneval"] = 18,
			["Side streets"] = 31,
			["The Forgotten Quarter"] = 9,
			["ForgottenQuarter"] = 9,
			["The Shuttered Palace"] = 10,
			["ShutteredPalace"] = 10,
			["The Empress' Court"] = 26,
			["EmpressCourt"] = 26,
			["A State of Some Confusion"] = 1,
		};

		public async Task<int> GetLocationId(string name)
		{
			var r = new Regex(name);
			var key = _locations.Keys.FirstOrDefault(k => r.IsMatch(k));
			if (key != null)
			{
				return _locations[key];
			}
			var map = await GetMap();
			var area = map.FirstOrDefault(k => r.IsMatch(k.name));
			if (area == null)
				throw new Exception($"invalid location name {name}");
			return area.id;
		}

		public async Task<UserArea> MoveTo(string location)
		{
			var id = await GetLocationId(location);
			var move = await Post<Move>("map/move", new { areaId = id });
			this._user.area = move.area;
			return move.area;
		}

		public async Task<StoryletList> ListStorylet()
		{
			return await Post<StoryletList>("storylet");
		}

		public async Task<ShopItem[]> GetShopInventory(int shopId)
		{
			if (!_shops.ContainsKey(shopId))
			{
				string s = shopId==0 ? "null" : shopId.ToString();
				_shops.Add(shopId, await Get<ShopItem[]>($"exchange/availabilities?shopId={s}"));
			}
			return _shops[shopId];
		}

		public async Task<dynamic> PostBuy(long id, int amount)
		{
			_myself = null;
			return await Post<dynamic>("exchange/buy", new { availabilityId = id, amount = amount });
		}
		public async Task<dynamic> PostSell(long id, int amount)
		{
			_myself = null;
			return await Post<dynamic>("exchange/sell", new { availabilityId = id, amount = amount });
		}

		public async Task<SuccessResult> UseQuality(int id)
		{
			return await Post<SuccessResult>($"storylet/usequality", new { qualityId = id });
		}

		public async Task<User> User()
		{
			if (_user == null)
			{
				_user = await Get<User>("login/user");
			}
			return _user;
		}

		public async Task<Myself> Myself()
		{
			if (_myself == null)
			{
				_myself = await Get<Myself>("character/myself");
			}
			return _myself;
		}

		public async Task<Opportunity> Opportunity()
		{
			return await Get<Opportunity>("opportunity");
		}

		public async Task<Opportunity> DrawOpportunity()
		{
			return await Post<Opportunity>("opportunity/draw");
		}

		public async Task<dynamic> DiscardOpportunity(int id)
		{
			return await Post<dynamic>($"opportunity/discard", new { eventId = id });
		}

		public async Task<StoryletList> GoBack()
		{
			return await Post<StoryletList>("storylet/goback");
		}

		public async Task<StoryletList> BeginStorylet(long id)
		{
			StoryletList ev = await Post<StoryletList>("storylet/begin", new { eventId = id });
			// todo
			// 	if( $ev.storylet )
			// 	{
			// 		Write-Verbose "BeginStorylet: $($ev.storylet.name) -> $($ev.storylet.description)"
			// 	}
			return ev;
		}

		public async Task<StoryletList> ChooseBranch(long id)
		{
			StoryletList ev = await Post<StoryletList>("storylet/choosebranch", new { branchId = id, secondChanceIds = new int[0] });
			// todo
			// 	if( $event.endStorylet )
			// 	{
			// 		Write-Verbose "EndStorylet: $($event.endStorylet.event.name) -> $($event.endStorylet.event.description)"
			// 	}
			// 	if( $event.messages )
			// 	{
			// 		if( $event.messages.defaultMessages )
			// 		{
			// 			$event.messages.defaultMessages | %{ Write-Verbose "message: $($_.message)" }
			// 		}
			// 	}
			return ev;
		}

		async Task<Plans> Plans()
		{
			if (_plans == null)
			{
				_plans = await Get<Plans>("plan");
			}
			return _plans;
		}

		public async Task<dynamic> GetPlan(string name)
		{
			var plans = await Plans();
			var pl = new List<dynamic>();
			pl.AddRange(plans.active);
			pl.AddRange(plans.complete);

			var r = new Regex(name);
			return pl.FirstOrDefault(k => r.IsMatch(k.branch.name));
		}

		public async Task<bool> ExistsPlan(int id, string planKey)
		{
			var plans = await Plans();
			var pl = new List<Plan>();
			pl.AddRange(plans.active);
			pl.AddRange(plans.complete);

			return pl.Any(k => k.branch.id == id && k.branch.planKey == planKey);
		}

		// # post plan/update {"branchId":204598,"notes":"do this","refresh":false} to save note
		// # post plan/update {"branchId":204598,"refresh":true} to restart plan
		public async Task<dynamic> CreatePlan(int id, string planKey)
		{
			_plans = null;
			return await Post<dynamic>("plan/create", new { branchId = id, planKey = planKey });
		}

		public async Task<dynamic> DeletePlan(int id)
		{
			_plans = null;
			return await Post<dynamic>($"plan/delete/{id}");
		}
		public async Task<dynamic> PostEquipOutfit(int id)
		{
			return await Post<dynamic>($"outfit/equip", new { qualityId = id });
		}
		public async Task<dynamic> PostUnequipOutfit(int id)
		{
			return await Post<dynamic>($"outfit/unequip", new { qualityId = id });
		}
		public async Task<dynamic> Contacts()
		{
			return await Get<dynamic>("contact");
		}
		public async Task<dynamic> AddContact(string name)
		{
			var encoded = System.Uri.EscapeDataString(name);
			return await Post<dynamic>($"contact/addcontact/{encoded}");
		}
	}
}
