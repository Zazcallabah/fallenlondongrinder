using System;
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

		// caches
		dynamic _mapCache = null;


		public Session(string email, string pass)
		{
			_email = email;
			_pass = pass;
			_client.BaseAddress = new System.Uri("https://api.fallenlondon.com/api/");
			_client.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:67.0) Gecko/20100101 Firefox/67.0");
		}

		HttpContent MakeContent(dynamic payload) {
			if( payload == null )
				return null;
			return new StringContent( JsonConvert.SerializeObject(payload), System.Text.Encoding.UTF8, "application/json");
		}

		public async Task<dynamic> Post( string href, dynamic payload = null) {
			if(!_loggedin)
			{
				await GetToken();
			}

			var response = await _client.PostAsync(href,MakeContent(payload));
			var content = await response.Content.ReadAsStringAsync();
			dynamic data = JsonConvert.DeserializeObject(content);
			return data;
		}

		public async Task<dynamic> Get( string href ) {
			if(!_loggedin)
			{
				await GetToken();
			}

			var response = await _client.GetAsync(href);
			var content = await response.Content.ReadAsStringAsync();
			dynamic data = JsonConvert.DeserializeObject(content);
			return data;
		}

		async Task<string> GetToken()
		{
			var payload = JsonConvert.SerializeObject(new { email = _email, password = _pass });
			var response = await _client.PostAsync("login",new StringContent(payload, System.Text.Encoding.UTF8, "application/json"));
			if (response.Content == null) {
				throw new Exception("invalid login");
			}
			var content = await response.Content.ReadAsStringAsync();
			dynamic token = JsonConvert.DeserializeObject(content);
			_loggedin = true;
			_client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", (string)token.jwt);
			return token.jwt;
		}
		public async Task<dynamic> GetMap()
		{
			if( _mapCache == null )
			{
				dynamic response = await Get("map");
				_mapCache = response.areas;
			}
			return _mapCache;
		}

		readonly static IDictionary<string,int> _locations = new Dictionary<string,int>{
			["New Newgate Prison"] = 1,
			["Your Lodgings"] = 2,
			["Ladybones Road"] = 4,
			["Watchmakers Hill"] = 5,
			["WatchmakersHill"] = 5,
			["Watchmaker's Hill"] = 5,
			["Spite"] = 7,
			["Mrs Plenty's Carnival" ]= 18,
			["Carneval"] = 18,
			["Side streets" ]= 31,
			["The Forgotten Quarter"] = 9,
			["ForgottenQuarter"] = 9,
			["The Shuttered Palace" ]= 10,
			["ShutteredPalace"] = 10,
			["The Empress' Court" ]= 26,
			["EmpressCourt"] = 26,
			["A State of Some Confusion"] = 1,
		};



		public async Task<int> GetLocationId(string name)
		{
			var r = new Regex(name);
			var key = _locations.Keys.FirstOrDefault( k => r.IsMatch(k) );
			if( key != null )
			{
				return _locations[key];
			}
			var map = await GetMap();
			var area = map.FirstOrDefault(k=>r.IsMatch(k));
		}
	}


// 	$key = $script:locations.Keys | ?{ $_ -match $id } | select -first 1
// 	if( $key -eq $null )
// 	{
// 		$area = GetMap | ?{ $_.name -match $id } | select -first 1
// 		if( $area -ne $null )
// 		{
// 			return $area.id
// 		}
// 		return $id
// 	}
// 	return $script:locations[$key]
// }	}
}



// function MoveTo
// {
// 	param($id)
// 	$id = GetLocationId $id
// 	$script:user = $null # after move, area is different
// 	$area = Post -href "map/move/$id"
// 	if($area.isSuccess -ne $true)
// 	{
// 		throw "bad result when moving to a new area: $area"
// 	}
// 	return $area
// }

// function ListStorylet
// {
// 	$list = Post -href "storylet"
// 	if($list.isSuccess -ne $true)
// 	{
// 		throw "bad result when listing storylets: $list"
// 	}
// 	return $list
// }

// function GetShopInventory
// {
// 	param($shopid)
// 	if( $script:shopInventories -eq $null )
// 	{
// 		$script:shopInventories = @{}
// 	}
// 	if( !$script:shopInventories.ContainsKey($shopid) )
// 	{
// 		$script:shopInventories.Add($shopid, (Post -href "exchange/availabilities?shopId=$($shopid)" -method "GET"))
// 	}
// 	return $script:shopInventories[$shopid]
// }

// function Buy
// {
// 	param($id, $amount)
// 	$script:myself = $null #after buying, inventory is different
// 	Post -href "exchange/buy" -payload @{ "availabilityId" = $id; "amount" = [int]$amount }
// }

// function Sell
// {
// 	param($id, $amount)
// 	$script:myself = $null #after selling, inventory is different
// 	Post -href "exchange/sell" -payload @{ "availabilityId" = $id; "amount" = [int]$amount }
// }

// function UseQuality
// {
// 	param($id)
// 	$result = Post -href "storylet/usequality/$([int]$id)"
// 	if($result.isSuccess -ne $true)
// 	{
// 		throw "bad result when using quality $($id): $result"
// 	}
// 	return $result
// }

// $script:user = $null
// function User
// {
// 	if( $script:user -eq $null )
// 	{
// 		$script:user = Post -href "login/user" -method "GET"
// 	}
// 	return $script:user
// }

// $script:plans = $null
// function Plans
// {
// 	if( $script:plans -eq $null )
// 	{
// 		$script:plans = Post -href "plan" -method "GET"
// 	}
// 	return $script:plans
// }

// function Get-Plan
// {
// 	param( $name )
// 	$plans = Plans
// 	return $plans.active+$plans.complete | ?{ $_.branch.name -eq $name } | select -first 1
// }


// function ExistsPlan
// {
// 	param( $id, $plankey )
// 	$plans = Plans
// 	$hit = $plans.active+$plans.complete | ?{ $_.branch.id -eq $id -and $_.branch.planKey -eq $planKey } | measure
// 	return $hit.Count -gt 0
// }

// $script:myself = $null
// function Myself
// {
// 	if( $script:myself -eq $null )
// 	{
// 		$script:myself = Post -href "character/myself" -method "GET"
// 	}
// 	return $script:myself
// }

// function Opportunity
// {
// 	Post -href "opportunity" -method "GET"
// }

// function DrawOpportunity
// {
// 	Post -href "opportunity/draw"
// }

// function DiscardOpportunity
// {
// 	param([int]$id)
// 	Post -href "opportunity/discard/$id"
// }

// function GoBack
// {
// 	$list = Post -href "storylet/goback"
// 	if($list.isSuccess -ne $true)
// 	{
// 		throw "bad result when going back: $list"
// 	}
// 	return $list
// }

// function BeginStorylet
// {
// 	param($id)
// 	$event = Post -href "storylet/begin" -payload @{ "eventId" = $id }
// 	if($event.isSuccess -ne $true)
// 	{
// 		throw "bad result at begin storylet $($id): $event"
// 	}
// 	if( $event.storylet )
// 	{
// 		Write-Verbose "BeginStorylet: $($event.storylet.name) -> $($event.storylet.description)"
// 	}
// 	return $event
// }

// function ChooseBranch
// {
// 	param($id)
// 	$event = Post -href "storylet/choosebranch" -payload @{"branchId"=$id; "secondChanceIds"=@(); }
// 	if($event.isSuccess -ne $true)
// 	{
// 		throw "bad result at chosebranch $($id): $event"
// 	}
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
// 	return $event
// }

// # post plan/update {"branchId":204598,"notes":"do this","refresh":false} to save note
// # post plan/update {"branchId":204598,"refresh":true} to restart plan
// function CreatePlan
// {
// 	param( $id, $planKey )
// 	$plan = Post -href "plan/create" -payload @{ "branchId" = $id; "planKey" = $planKey }
// 	if($plan.isSuccess -ne $true)
// 	{
// 		throw "bad result creating plan $($id): $plan"
// 	}
// 	$script:plans = $null
// 	return $plan
// }

// function DeletePlan
// {
// 	param( $id )
// 	$script:plans = $null
// 	$plan = Post -href "plan/delete/$($id)"
// 	if($plan.isSuccess -ne $true)
// 	{
// 		throw "bad result deleting plan $($id): $plan"
// 	}
// }

// function EquipOutfit
// {
// 	param( [int]$id )
// 	Post -href "outfit/equip/$($id)"
// }

// function UnequipOutfit
// {
// 	param( [int]$id )
// 	Post -href "outfit/unequip/$($id)"
// }

// function AddContact
// {
// 	param( $name )
// 	$encoded = [uri]::EscapeDataString($name)
// 	Post -href "contact/addcontact/$($encoded)"
// }

// function Contacts
// {
// 	Post -href "contact" -method "GET"
// }