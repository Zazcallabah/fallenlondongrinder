if( $env:LOGIN_EMAIL -eq $null -or $env:LOGIN_PASS -eq $null )
{
	throw "missing login information"
}

$script:uastring = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:67.0) Gecko/20100101 Firefox/67.0"

function Get-BasicHeaders
{
	return @{
		"Content-Type" = "application/json";
		"Host" = "api.fallenlondon.com";
		"Accept" = "application/json";
	}
}

function Login
{
	$headers = Get-BasicHeaders
	$email = $env:LOGIN_EMAIL
	$password = $env:LOGIN_PASS
	$payload = @{ "email" = $email; "password" = $password; }
	$uri = "https://api.fallenlondon.com/api/login"
	$result = $payload | ConvertTo-Json | Invoke-WebRequest -UseBasicParsing -Uri $uri -Method POST -UserAgent $script:uastring -Headers $headers
	if($result.StatusCode -ne 200)
	{
		throw "login error for $email"
	}
	return $result.Content | convertfrom-json | select -expandproperty jwt

}

function Get-Token
{
	$token = $script:cachedToken
	if($token -ne $null )
	{
		return $token
	}
	$script:cachedToken = Login
	return $script:cachedToken
}

function Get-Headers
{
	$token = Get-Token
	$headers = Get-BasicHeaders
	$headers.Add("Authorization", "Bearer $($token)");
	return $headers
}

function Post
{
	param($href, $payload, $method="POST")
	$headers = Get-Headers
	$uri = "https://api.fallenlondon.com/api/$href"
	if($payload -ne $null )
	{
		$content = $payload | ConvertTo-Json -Depth 99 | Invoke-Webrequest -UseBasicParsing -Uri $uri -Headers $headers -UserAgent $script:uastring -Method $method | select -ExpandProperty Content
	}
	else
	{
		$content = Invoke-Webrequest -UseBasicParsing -Uri $uri -Headers $headers -UserAgent $script:uastring -Method $method | select -ExpandProperty Content
	}
	$result = $content | ConvertFrom-Json
	return $result
}

function GetMap
{
	if( $script:mapCache -eq $null )
	{
		$script:mapCache = Post -href "map" -method "GET" | select -expandproperty areas
	}
	return $script:mapCache
}

$script:locations = @{
	"Your Lodgings" = 2;
	"Ladybones Road" = 4;
	"Watchmakers Hill" = 5;
	"Watchmaker's Hill" = 5;
	"Veilgarden" = 6;
	"Spite" = 7;
	"Mrs Plenty's Carnival" = 18;
	"The Forgotten Quarter" = 9;
	"ForgottenQuarter" = 9;
	"The Shuttered Palace" = 10;
	"ShutteredPalace" = 10;
	# "The Labyrinth of Tigers" = -1;
	# "The University" = -1;
	# "Mahogany Hall" = -1;
	# "Wilmot's End" = -1;
	# "Bazaar Sidestreets" = -1;
	"The Empress' Court" = 26;
	"EmpressCourt" = 26;
	# "Doubt Street" = -1;
	"A State of Some Confusion" = 13;
}

function GetLocationId
{
	param($id)

	$key = $script:locations.Keys | ?{ $_ -match $id } | select -first 1
	if( $key -eq $null )
	{
		$area = GetMap | ?{ $_.name -match $id } | select -first 1
		if( $area -ne $null )
		{
			return $area.id
		}
		return $id
	}
	return $script:locations[$key]
}

function MoveTo
{
	param($id)
	$id = GetLocationId $id
	$script:user = $null # after move, area is different
	$area = Post -href "map/move/$id"
	if($area.isSuccess -ne $true)
	{
		throw "bad result when moving to a new area: $area"
	}
	return $area
}

function ListStorylet
{
	$list = Post -href "storylet"
	if($list.isSuccess -ne $true)
	{
		throw "bad result when listing storylets: $list"
	}
	return $list
}

if( $script:runTests )
{
	Describe "GetLocationId" {
		It "can fetch location not in local cache" {
			GetLocationId "flit" | should be 11
		}
	}
	Describe "List-Storylet" {
		It "can get storylets" {
			ListStorylet | should not be $null
		}
	}
}


function GetShopInventory
{
	param($shopid)
	if( $script:shopInventories -eq $null )
	{
		$script:shopInventories = @{}
	}
	if( !$script:shopInventories.ContainsKey($shopid) )
	{
		$script:shopInventories.Add($shopid, (Post -href "exchange/availabilities?shopId=$($shopid)" -method "GET"))
	}
	return $script:shopInventories[$shopid]
}

function Buy
{
	param($id, $amount)
	$script:myself = $null #after buying, inventory is different
	Post -href "exchange/buy" -payload @{ "availabilityId" = $id; "amount" = [int]$amount }
}

function Sell
{
	param($id, $amount)
	$script:myself = $null #after selling, inventory is different
	Post -href "exchange/sell" -payload @{ "availabilityId" = $id; "amount" = [int]$amount }
}

function UseQuality
{
	param($id)
	$result = Post -href "storylet/usequality/$([int]$id)"
	if($result.isSuccess -ne $true)
	{
		throw "bad result when using quality $($id): $result"
	}
	return $result
}

function User
{
	if( $script:user -eq $null )
	{
		$script:user = Post -href "login/user" -method "GET"
	}
	return $script:user
}

function Plans
{
	if( $script:plans -eq $null )
	{
		$script:plans = Post -href "plan" -method "GET"
	}
	return $script:plans
}

function Get-Plan
{
	param( $name )
	$plans = Plans
	return $plans.active+$plans.complete | ?{ $_.branch.name -eq $name } | select -first 1
}


function ExistsPlan
{
	param( $id, $plankey )
	$plans = Plans
	$hit = $plans.active+$plans.complete | ?{ $_.branch.id -eq $id -and $_.branch.planKey -eq $planKey } | measure
	return $hit.Count -gt 0
}

function Myself
{
	if( $script:myself -eq $null )
	{
		$script:myself = Post -href "character/myself" -method "GET"
	}
	return $script:myself
}

function Opportunity
{
	Post -href "opportunity" -method "GET"
}

function DrawOpportunity
{
	Post -href "opportunity/draw"
}

function DiscardOpportunity
{
	param([int]$id)
	Post -href "opportunity/discard/$id"
}

function GoBack
{
	$list = Post -href "storylet/goback"
	if($list.isSuccess -ne $true)
	{
		throw "bad result when going back: $list"
	}
	return $list
}

function BeginStorylet
{
	param($id)
	$event = Post -href "storylet/begin" -payload @{ "eventId" = $id }
	if($event.isSuccess -ne $true)
	{
		throw "bad result at begin storylet $($id): $event"
	}
	return $event
}

function ChooseBranch
{
	param($id)
	$event = Post -href "storylet/choosebranch" -payload @{"branchId"=$id; "secondChanceIds"=@(); }
	if($event.isSuccess -ne $true)
	{
		throw "bad result at chosebranch $($id): $event"
	}
	return $event
}

if( $script:runTests )
{
	Describe "User" {
		It "can get user object" {
			User | should not be $null
		}
		It "has location" {
			(User).area.id | should not be $null
		}
	}
	Describe "Myself" {
		It "can get character object" {
			Myself | should not be $null
		}
		It "has actions" {
			(Myself).character.actions | should not be $null
		}
		It "has inventory" {
			(Myself).possessions | should not be $null
		}
	}
}
# post plan/update {"branchId":204598,"notes":"do this","refresh":false} to save note
# post plan/update {"branchId":204598,"refresh":true} to restart plan
function CreatePlan
{
	param( $id, $planKey )
	$plan = Post -href "plan/create" -payload @{ "branchId" = $id; "planKey" = $planKey }
	if($plan.isSuccess -ne $true)
	{
		throw "bad result creating plan $($id): $plan"
	}
	$script:plans = $null
	return $plan
}

function DeletePlan
{
	param( $id )
	$script:plans = $null
	$plan = Post -href "plan/delete/$($id)"
	if($plan.isSuccess -ne $true)
	{
		throw "bad result deleting plan $($id): $plan"
	}
}
