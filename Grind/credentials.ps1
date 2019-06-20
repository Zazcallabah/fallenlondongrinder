if( $env:SkipCloudCache -eq $null -and $env:BLOB_SAS -eq $null )
{
	throw "missing blob token"
}


if( $env:SkipCloudCache -eq $null -and !(get-command New-AzureStorageContext -ErrorAction SilentlyContinue))
{
	throw "az ps cmdlets missing, please run 'Install-Module AzureRM -AllowClobber' from an admin powershell cmdline"
}

function Get-Blob
{
	if( $env:SkipCloudCache -eq $null )
	{
		$accountContext = New-AzureStorageContext -SasToken $env:BLOB_SAS -storageaccountname "fallenlondongrinder"
		return Get-AzureStorageBlob -Context $accountContext -Container persist -blob "credentials.json"
	}
}

function Save-Blob
{
	param($obj)
	if( $env:SkipCloudCache -eq $null )
	{
		$blob = Get-Blob
		$blob.ICloudBlob.UploadText( ($obj | ConvertTo-Json) )
	}
}

if($script:runInfraTests)
{
	Describe "Get-Blob" {
		It "gets blob object" {
			$blob = Get-Blob
			$blob | should not be $null
			$blob.GetType().Name | should be "AzureStorageBlob"
		}
	}
}


function DownloadCredentialsCache
{
	if( $env:SkipCloudCache -eq $null )
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
}

function Get-CredentialsObject
{
	if( $script:credentials -eq $null )
	{
		$script:credentials = DownloadCredentialsCache
	}
	return $script:credentials
}

if( $script:runInfraTests )
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

if( $script:runInfraTests )
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


