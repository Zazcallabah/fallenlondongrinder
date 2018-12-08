$actions = @(
	"spite,Alleys,Cats,Black",
	"ladybones,sketch,clandestine",
        "veilgarden,writer,rapidly",
	"watchmakers,Rowdy,unruly"
)

function Get-Blob
{
    $accountContext = New-AzureStorageContext -SasToken $env:BLOB_SAS -storageaccountname "fallenlondongrinder"
    return Get-AzureStorageBlob -Context $accountContext -Container persist -blob "credentials.json"
}


function Save-Blob
{
    param($obj)
    $script:credentials = $obj
    $str = $obj | ConvertTo-Json
    $blob = Get-Blob
    $blob.ICloudBlob.UploadText( $str )
}

function Get-Headers
{
	$headers = @{
		"Content-Type" = "application/json";
		"Host" = "api.fallenlondon.com";
		"Accept" = "application/json";
	}

	$uastring = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:63.0) Gecko/20100101 Firefox/63.0"

    if( $script:credentials -eq $null )
    {
        $blob = Get-Blob
        $blobcontent = $blob.ICloudBlob.DownloadText()
        if( [string]::isNullOrWhitespace( $blobcontent ) )
        {
            $script:credentials = $blobcontent | ConvertFrom-Json
        }
    }

	$cached = $script:credentials

	if( $cached -ne $null -and $cached.timeout -ne $null -and $cached.token -ne $null -and $cached.timeout -gt [DateTime]::UtcNow.Ticks )
	{
		$headers.Add("Authorization", "Bearer $($cached.token)");
		return $headers
	}

	$email = $env:LOGIN_EMAIL
	$password = $env:LOGIN_PASS
	$payload = @{ "email" = $email; "password" = $password; }
	$uri = "https://api.fallenlondon.com/api/login"
	$token = $payload | ConvertTo-Json | Invoke-WebRequest -UseBasicParsing -Uri $uri -Method POST -UserAgent $uastring -Headers $headers | Select -Expandproperty Content | convertfrom-json | select -expandproperty jwt
	$timeout = ([datetime]::UtcNow).addhours(47).Ticks

	Save-Blob -obj @{"timeout" = $timeout; "token" = $token}

	$headers.Add("Authorization", "Bearer $token")

	return $headers
}


function Post
{
	param($href,$payload)
	$headers = Get-Headers
	$uri = "https://api.fallenlondon.com/api/$href"
	if($payload -ne $null )
	{
		$content = $payload | ConvertTo-Json -Depth 99 | Invoke-Webrequest -UseBasicParsing -Uri $uri -Headers $headers -Method POST | select -ExpandProperty Content
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

	Post -href "map/move/$id"
}

function ListStorylet
{
	Post -href "storylet"
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

function GetStoryletId
{
	param($name)
	$result = ListStorylet
	return $result.storylets | ?{ $_.name -match $name } | select -first 1 -expandproperty id
}

function GetBranchId
{
	param($result,$name)
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
	$result	= ListStorylet
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

$selector = [DateTime]::UtcNow.Hour

$action = $actions[$selector%($actions.Length)]
DoAction $action
