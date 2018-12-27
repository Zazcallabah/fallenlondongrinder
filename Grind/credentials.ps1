param([switch]$runTests)

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


