param([switch]$runTests)

$script:actions = @(
	"spite,Alleys,Cats,Black",
	"ladybones,sketch,clandestine",
	"ladybones,courier,search",
	"ladybones,courier,1",
	"ladybones,courier,search",
	"veilgarden,writer,rapidly",
	"veilgarden,writer,rapidly",
	"veilgarden,writer,rework,daring",
	"watchmakers,Rowdy,unruly",
	"watchmakers,Rowdy,unruly"
)

$script:uastring = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:63.0) Gecko/20100101 Firefox/63.0"

function Get-Action
{
	param($now)
	$selector = $now.DayOfYear
	return $script:actions[$selector%($script:actions.Length)]
}
if($runTests)
{
	$script:actions =@( 0,1,2,3,4,5,6 )
	Describe "Get-Action" {
		It "selects based on day of year" {
			Get-Action (new-object datetime 2018,1,1,0,0,0) | should be 1
			Get-Action (new-object datetime 2018,1,1,0,10,0) | should be 1
		}
		It "cycles" {
			Get-Action (new-object datetime 2018,1,6,2,0,0) | should be 6
			Get-Action (new-object datetime 2018,1,7,2,0,0) | should be 0
		}
	}
}


function Get-Blob
{
	$accountContext = New-AzureStorageContext -SasToken $env:BLOB_SAS -storageaccountname "fallenlondongrinder"
	return Get-AzureStorageBlob -Context $accountContext -Container persist -blob "credentials.json"
}

function Save-Blob
{
	param($obj)
	$blob = Get-Blob
	$blob.ICloudBlob.UploadText( ($obj | ConvertTo-Json) )
}

if($runTests)
{
	Describe "Get-Blob" {
		It "gets blob object" {
			$blob = Get-Blob
			$blob | should not be $null
			$blob.GetType().Name | should be "AzureStorageBlob"
		}
	}
}


function Download-CredentialsCache
{
	$blob = Get-Blob
	$blobcontent = $blob.ICloudBlob.DownloadText()
	if( [string]::isNullOrWhitespace( $blobcontent ) )
	{
		Write-Error "invalid blob"
		return $null
	}
	return $blobcontent | ConvertFrom-Json
}

function Get-CredentialsObject
{
	if( $script:credentials -eq $null )
	{
		$script:credentials = Download-CredentialsCache
	}
	return $script:credentials
}

if( $runTests )
{
	Describe "Get-CredentialsObject" {
		It "sets scriptcredentials if null" {
			$script:credentials = $null
			$obj = Get-CredentialsObject
			$script:credentials | should not be $null
		}
	}
}


function Get-CachedToken
{
	$cached = Get-CredentialsObject

	if( $cached -ne $null -and $cached.timeout -ne $null -and $cached.token -ne $null -and $cached.timeout -gt [DateTime]::UtcNow.Ticks )
	{
		return $cached.token
	}
	return $null
}

if( $runTests )
{
	$onesecond = 10000000
	Describe "Get-CachedToken" {
		It "returns null if timed out" {
			$script:credentials = @{"timeout"=[DateTime]::UtcNow.Ticks - $onesecond; "token" = "notused" }
			Get-CachedToken | should be $null
		}
		It "returns token if not timed out" {
			$script:credentials = @{"timeout"=[DateTime]::UtcNow.Ticks + $onesecond; "token" = "secrettoken" }
			Get-CachedToken | should be "secrettoken"
		}
		$script:credentials = $null
	}
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
	Write-Warning "Doing explicit login"
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
	param($href,$payload)
	$headers = Get-Headers
	$uri = "https://api.fallenlondon.com/api/$href"
	if($payload -ne $null )
	{
		$content = $payload | ConvertTo-Json -Depth 99 | Invoke-Webrequest -UseBasicParsing -Uri $uri -Headers $headers -UserAgent $script:uastring -Method POST | select -ExpandProperty Content
	}
	else
	{
		$content = Invoke-Webrequest -UseBasicParsing -Uri $uri -Headers $headers -Method POST | select -ExpandProperty Content
	}
	$result = $content | ConvertFrom-Json
	return $result
}

function MoveTo
{
	param($id)

	if($id -eq "lodgings"){ $id = 2 }
	if($id -eq "ladybones"){ $id = 4 }
	if($id -eq "watchmakers"){ $id = 5 }
	if($id -eq "veilgarden"){ $id = 6 }
	if($id -eq "spite"){ $id = 7 }
	if($id -eq "carnival"){ $id = 18 }

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

function IsNumber
{
	param($str)
	
	return $str -match "^\d+$"
}

function GetStoryletId
{
	param($name)
	$result = ListStorylet
	if( IsNumber $name )
	{
		return $result.storylets | select -first 1 -skip ($name-1) -expandproperty id
	}
	return $result.storylets | ?{ $_.name -match $name } | select -first 1 -expandproperty id
}

function GetBranchId
{
	param($result,$name)
	if( IsNumber $name )
	{
		return $result.storylet.childBranches | select -first 1 -skip ($name-1) -expandproperty id
	}
	return $result.storylet.childBranches | ?{ $_.name -match $name } | select -first 1 -expandproperty id
}

function DoAction
{
	param($location,$storyletname,$branchname,$secondbranch)
	
	if( $storyletname -eq $null )
	{
		$spl = $location -split ","
		$location = $spl[0]
		$storyletname = $spl[1]
		$branchname = $spl[2]
		if($spl.length -gt 3)
		{
			$secondbranch = $spl[3]
		}
	}
	Write-Output "doing action $location $storyletname $branchname $secondbranch"
	
	$result	= ListStorylet
	if( $result.actions -lt 19 )
	{
		write-warning "not enough actions left"
		return
	}
	if( $result.storylet -ne $null )
	{
		if( $result.storylet.canGoBack )
		{
			$result = GoBack
		}
	}
	if( $result.storylets -ne $null )
	{
		$storyletid = GetStoryletId $storyletname
		if( $storyletid -eq $null )
		{
			$l = MoveTo $location
			$storyletid = GetStoryletId $storyletname
		}
		
		$result = BeginStorylet $storyletid
		$branchid = GetBranchId -result $result -name $branchname
		if( $branchid -ne $null )
		{
			ChooseBranch $branchid
			if( $secondbranch -ne $null )
			{
				$result = ListStorylet
				$branchid = GetBranchId -result $result -name $secondbranch
				if( $branchid -ne $null )
				{
					ChooseBranch $branchid
				}
				else
				{
					write-warning "second $secondbranch not found"
				}
			}
		}
		else
		{
			write-warning "$branchname not found"
		}
	}
}

if(!$runTests)
{
	DoAction (Get-Action ([DateTime]::UtcNow))
}
