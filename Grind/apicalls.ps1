
$script:uastring = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:63.0) Gecko/20100101 Firefox/63.0"

if($env:Home -eq $null)
{
	. $PSScriptRoot/credentials.ps1
}
else
{
	. ${env:HOME}/site/wwwroot/Grind/credentials.ps1
}

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
	$token = $payload | ConvertTo-Json | Invoke-WebRequest -UseBasicParsing -Uri $uri -Method POST -UserAgent $script:uastring -Headers $headers | Select -Expandproperty Content | convertfrom-json | select -expandproperty jwt
	return $token
}

if( $script:runTests )
{
	Describe "Login" {
		It "returns token" {
			$token = Login
			$token | should not be $null
		}
	}
}


function Get-Token
{
	$token = Get-CachedToken
	if($token -ne $null )
	{
		return $token
	}
	$token = Login
	$timeout = ([datetime]::UtcNow).addhours(47).Ticks
	$script:credentials = @{"timeout" = $timeout; "token" = $token}
	Save-Blob $script:credentials
	return $token
}

if( $script:runTests )
{
	Describe "Get-Token" {
		It "login with no cached token, caches token" {
			Save-Blob @{}
			$script:credentials = $null
			$token = Get-Token
			$token | should not be $null
			$token | should not be ""
			$cc = Download-CredentialsCache
			$cc | should not be $null
			$cc.token | should be $script:credentials.token
			$cc.timeout | should be $script:credentials.timeout
			$cc.token | should be $token
			
		}
		It "calling twice returns same token" {
			$token = Get-Token
			Get-Token | should be $token
		}
		It "calling twice clearing cache between each returns same token" {
			$token = Get-Token
			$script:credentials = $null
			Get-Token | should be $token
		}
		It "calling twice clearing cache and blob between each returns different tokens" {
			$token = Get-Token
			$token | should not be $null
			$token | should not be ""
			Save-Blob @{}
			$script:credentials = $null
			$token2 = Get-Token
			$token2 | should not be $token
			$token2 | should not be $null
			$token2 | should not be ""
		}
	}
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
	param($href,$payload,$method="POST")
	$headers = Get-Headers
	$uri = "https://api.fallenlondon.com/api/$href"
	if($payload -ne $null )
	{
		$content = $payload | ConvertTo-Json -Depth 99 | Invoke-Webrequest -UseBasicParsing -Uri $uri -Headers $headers -UserAgent $script:uastring -Method $method | select -ExpandProperty Content
	}
	else
	{
		$content = Invoke-Webrequest -UseBasicParsing -Uri $uri -Headers $headers -Method $method | select -ExpandProperty Content
	}
	$result = $content | ConvertFrom-Json
	return $result
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
	"The Flit" = -1;
	"The Shuttered Palace" = 10;
	"ShutteredPalace" = 10;
	"The Labyrinth of Tigers" = -1;
	"The University" = -1;
	"Mahogany Hall" = -1;
	"Wilmot's End" = -1;
	"Bazaar Sidestreets" = -1;
	"The Empress' Court" = 26;
	"EmpressCourt" = 26;
	"Doubt Street" = -1;
	"A State of Some Confusion" = 13;
}
function GetLocationId
{
	param($id)

	$key = $script:locations.Keys | ?{ $_ -match $id } | select -first 1
	if( $key -eq $null )
	{
		return $id
	}
	return $script:locations[$key]
}


function GetShopId
{
	param($name)
	
	$key = $script:shopIds.Keys | ?{ $_ -match $name } | select -first 1
	return $script:shopIds[$key]
}


function MoveTo
{
	param($id)
	$id = GetLocationId $id
	$script:user = $null # after move, area is different
	Post -href "map/move/$id"
}

function ListStorylet
{
	Post -href "storylet"
}

if( $script:runTests )
{
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
	param($id,$amount)
	$script:myself = $null #after buying, inventory is different
	Post -href "exchange/buy" -paylead @{ "availabilityId" = $id; "amount" = $amount }
}

function UseQuality
{
	param($id)
	Post -href "storylet/usequality/$($id)"
}

function User
{
	if( $script:user -eq $null )
	{
		$script:user = Post -href "login/user" -method "GET"
	}
	return $script:user
}

function Myself
{
	if( $script:myself -eq $null )
	{
		$script:myself = Post -href "character/myself" -method "GET"
	}
	return $script:myself
}

function GoBack
{
	Post -href "storylet/goback"
}

function BeginStorylet
{
	param($id)
	Post -href "storylet/begin" -payload @{ "eventId" = $id }
}

function ChooseBranch
{
	param($id)
	Post -href "storylet/choosebranch" -payload @{"branchId"=$id;"secondChanceIds"=@();}
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
