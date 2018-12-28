param([switch]$runTests)

$script:uastring = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:63.0) Gecko/20100101 Firefox/63.0"

if($env:Home -eq $null)
{
	. $PSScriptRoot/credentials.ps1 -runTests:$runTests
}
else
{
	. ${env:HOME}/site/wwwroot/Grind/credentials.ps1 -runTests:$runTests
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

if( $runTests )
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

if( $runTests )
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

function GetLocationId
{
	param($id)

	if($id -eq "lodgings"){ $id = 2 }
	if($id -eq "ladybones"){ $id = 4 }
	if($id -eq "watchmakers"){ $id = 5 }
	if($id -eq "veilgarden"){ $id = 6 }
	if($id -eq "spite"){ $id = 7 }
	if($id -eq "carnival"){ $id = 18 }
	if($id -eq "forgottenquarter"){ $id = 9 }
	if($id -eq "confusion"){ $id = 13 }
	
	return $id
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

if( $runTests )
{
	Describe "List-Storylet" {
		It "can get storylets" {
			ListStorylet | should not be $null
		}
	}
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

if( $runTests )
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
