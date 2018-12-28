param([switch]$runTests)

. $($env:HOME)/site/wwwroot/Grind/apicalls.ps1 -runTests:$runTests



$script:actions = @(
	"ladybones,spirifer,1"
	# "veilgarden,writer,rapidly",
	# "veilgarden,writer,rapidly",
	# "veilgarden,writer,rework,daring",
	"veilgarden,archaeology,1",
	"veilgarden,literary,1",
	"veilgarden,seamstress,1",
	"veilgarden,rescue,publisher",
	"ladybones,warehouse,1"
	"watchmakers,Rowdy,unruly"
)

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



function GetUserLocation
{
	return (User).area.id
}

function IsInLocation
{
	param($location)
	$id = GetLocationId $location
	return (GetUserLocation) -eq $id
}

function IsInForcedStorylet
{
	if( IsInLocation "confusion" )
	{
		write-warning "a state of some confusion"
		#DoAction "13,drink,1"
		return $true
	}
	# if is in newgate prison (missing id)
	# do nonrisk action to lower suspicion
	return $false
}

function ExitIfInStorylet
{
	$result	= ListStorylet
	
	if( $result.storylet -ne $null )
	{
		if( $result.storylet.canGoBack )
		{
			write-verbose "exiting storylet"
			return GoBack
		}
	}
	
	return $result
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

if($runTests)
{
	Describe "GetUserLocation" {
		It "can get current location" {
			ExitIfInStorylet
			GetUserLocation | should not be $null
		}
	}
	$location = GetUserLocation
	if( $location -ge 2 -and $location -le 7 )
	{
		# sanity check, not in forced location (we're not able to detect all forced locations yet)
		Describe "IsinforcedStorylet" {
			It "is false" {
				IsInForcedStorylet | should be $false
			}
		}
		
		Describe "MoveTo" {
			It "can move" {
				$result = MoveTo "spite"
				$result.area.name | should be "Spite"
				GetUserLocation | should be 7
			}
			It "can move to lodgings" {
				$result = MoveTo "lodgings"
				$result.area.name | should be "Your Lodgings"
				GetUserLocation | should be 2
			}
		}
	}
	
	Describe "GetStoryletId" {
		It "can get storylet id by name" {
			GetStoryletId "Society" | should be 276092
		}
	}
	
	Describe "BeginStorylet" {
		It "can begin storylet" {
			$result = BeginStorylet 276092
			$result.isSuccess | should be $true
			$result.storylet | should not be $null
			$result.storylet.cangoback | should be $true
		}
	}
	
	Describe "Exit Storylet" {
		It "can back out of chosen storylet" {
			$result = ExitIfInStorylet
			$result.storylet | should be $null
			$result.storylets | should not be $null
		}
		It "does nothing if exiting and no storylet is chosen" {
			$result = ExitIfInStorylet
			$result.storylet | should be $null
			$result.storylets | should not be $null
		}
	}
}



function GetPossession
{
	param( $category, $name )
	$category = (Myself).possessions | ?{ $_.name -eq $category } | select -first 1
	if( $category -eq $null )
	{
		write-warning "no category $category"
		return $null
	}
	return $category.possessions | ?{ $_.name -eq $name } | select -first 1
}

if($runTests)
{
	Describe "GetPossession" {
		It "can get possession" {
			$hints = GetPossession "Mysteries" "Whispered Hint"
			$hints.id | should be 380
		}
	}
}



function PerformAction
{
	param($result,$name)
	if( IsNumber $name )
	{
		$branch = $result.storylet.childBranches | select -first 1 -skip ($name-1)
	}
	else
	{
		$branch = $result.storylet.childBranches | ?{ $_.name -match $name -and $_.isLocked -eq $false } | select -first 1
	}
	
	if( $branch -ne $null )
	{
		return ChooseBranch $branch.id
	}
}

function EnterStoryletAndPerformAction
{
	param($storyletname, $name)
	$storyletid = GetStoryletId $storyletname
	$result = BeginStorylet $storyletid
	return PerformAction $result $name
}

function PerformActionFromCurrent
{
	param($name)
	$result = ListStorylet
	return PerformAction $result $name
}

if($runTests)
{
	Describe "EnterStoryletPerformAction" {
		It "can perform action" {
			MoveTo "spite"
			$result = EnterStoryletAndPerformAction "Alleys" "Cats"
			$result.isSuccess | should be $true
			$result.endStorylet | should not be $null
		}
	}
}



function UseItem
{
	param($id,$branch)
	$result = UseQuality $id
	if($result.isSuccess)
	{
		PerformActionFromCurrent $branch
	}
}

function HasActionsToSpare
{
	if( (Myself).character.actions -lt 19 )
	{
		write-warning "not enough actions left"
		return $false
	}
	return $true
}



function LowerNightmares
{
	$secrets = GetPossession "Mysteries" "Appalling Secret"
	if( $secrets -ne $null -and $secrets.level -ge 10 )
	{
		Write-host "using secret to lower nightmares"
		UseItem $secrets.id "1"
		return
	}
	# else "spite,Alleys,Cats,Black"? - no, only 1 secret/action instead of 70/21 actions
	$clues = GetPossession "Mysteries" "Cryptic Clues"
	if( $clues -ne $null -and $clues.level -ge 500 )
	{
		Write-host "converting clues to secrets"
		UseItem $clues.id "great many"
		return
	}
	Write-host "catch a grey cat for clues"
	DoAction "spite,Alleys,Cats,Grey"
}

function HasMenaces
{
	write-host "checkeing menaces"
	$scandal = GetPossession "Menaces" "Scandal"
	if( $scandal -ne $null -and $scandal.effectiveLevel -ge 3 )
	{
		write-host "lowering scandal"
		DoAction "lodgings,scandal,service"
		return $true
	}
	$wounds = GetPossession "Menaces" "Wounds"
	if( $wounds -ne $null -and $wounds.effectiveLevel -ge 2 )
	{
		write-host "lowering wounds"
		DoAction "lodgings,wounds,time"
		return $true
	}
	$nightmares = GetPossession "Menaces" "Nightmares"
	if( $nightmares -ne $null -and $nightmares.effectiveLevel -ge 5 )
	{
		write-host "has nightmares"
		LowerNightmares
		return $true
	}
	return $false
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
	
	
	$result = ExitIfInStorylet
	
	if( !(IsInLocation $location) )
	{
		$result = MoveTo $location
	}
	
	if( $result.storylets -ne $null )
	{
		$result = EnterStoryletAndPerformAction $storyletname $branchname
		if( $result -eq  $null )
		{
			write-warning "$branchname not found"
		}

		if( $secondbranch -ne $null )
		{
			$result = PerformActionFromCurrent $secondbranch
			if( $result -eq $null )
			{
				write-warning "second $secondbranch not found"
			}
		}
	}
}


if(!$runTests)
{
	if( HasActionsToSpare )
	{
		if( (IsInForcedStorylet) -or (HasMenaces) )
		{
			return
		}
		DoAction (Get-Action ([DateTime]::UtcNow))
	}
}
