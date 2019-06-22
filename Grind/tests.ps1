. ./run.ps1 -noaction

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

Describe "GetPossessionCategory" {
	It "can get route" {
		$cat = GetPossessionCategory "Route"
		$cat | ?{ $_.category -eq "Route" } | measure | select -expandproperty count | should be $cat.length
		$cat | ?{ $_.name -eq "Route: Lodgings" } | should not be $null
	}
	It "can get basicability" {
		$cat = GetPossessionCategory "Basic"
		$cat | ?{ $_.category -eq "BasicAbility" } | measure | select -expandproperty count | should be $cat.length
		$cat | ?{ $_.name -eq "Dangerous" } | should not be $null
	}
	It "can get all" {
		$cat = GetPossessionCategory
		$cat | ?{ $_.name -eq "Route: Lodgings" } | should not be $null
		$cat | ?{ $_.name -eq "Dangerous" } | should not be $null
	}
}

Describe "GetPossession" {
	It "can get possession" {
		$hints = GetPossession "Mysteries" "Whispered Hint"
		$hints.id | should be 380
	}
	It "can get possession without giving category" {
		$hints = GetPossession "Whispered Hint"
		$hints.id | should be 380
	}
	It "can get possession with partial match" {
		$hints = GetPossession "Mysteries" "Whispered"
		$hints.id | should be 380
	}
	It "can get basic possession" {
		$dangerous = GetPossession "Basic" "Dangerous"
		$dangerous.id = 211
	}
}


Describe "GetChildBranch" {
	It "can get branch by name" {
		$cat = GetChildBranch @(@{"name"="wronngname"},@{"name"="aoeu"}) "aoeu"
		$cat.name | should be "aoeu"
	}
	It "can get branch by number" {
		$cat = GetChildBranch @(@{"name"="wronngname"},@{"name"="aoeu"}) 2
		$cat.name | should be "aoeu"
	}
	It "can get branch by string number" {
		$cat = GetChildBranch @(@{"name"="1234"},@{"name"="aoeu"}) "1"
		$cat.name | should be "1234"
	}
	It "returns null if not found" {
		$cat = GetChildBranch @(@{"name"="wronngname"},@{"name"="aoeu"}) "asdf"
		$cat.name | should be $null
	}
	It "returns null if locked" {
		$cat = GetChildBranch @(@{"name"="wronngname"},@{"name"="aoeu";"isLocked"=$true}) "aoeu"
		$cat.name | should be $null
	}
	It "separates choices by slash, prioritizes first choice" {
		$cat = GetChildBranch @(@{"name"="wrongname"},@{"name"="first"},@{"name"="second"}) "first/second"
		$cat.name | should be "first"
	}
	It "separates choices by slash, still ignoring locked" {
		$cat = GetChildBranch @(@{"name"="second";"isLocked"=$true},@{"name"="third"}) "second/third"
		$cat.name | should be "third"
	}
	It "separates choices by slash, only returns one result" {
		$cat = GetChildBranch @(@{"name"="second"},@{"name"="third"}) "second/third"
		$cat.name | should be "second"
	}

}


Describe "GetShopItemId" {
	It "can get itemid from shop" {
		GetShopItemId "Nikolas" "Absolution" | should be 211
	}
}
Describe "BuyPossession" {
	It "can buy" {
		$pennies = GetPossession "Currency" "Penny"
		$jade = GetPossession "Elder" "Jade"
		BuyPossession "Merrigans" "Jade" "1"
		GetPossession "Elder" "Jade" | select -expandproperty effectivelevel | should be ($jade.effectivelevel +1)
		GetPossession "Currency" "Penny" | select -expandproperty effectiveLevel | should be ($pennies.effectiveLevel -2 )
	}
	It "can sell" {
		$pennies = GetPossession "Currency" "Penny"
		$jade = GetPossession "Elder" "Jade"
		SellPossession "Jade" "1"
		GetPossession "Elder" "Jade" | select -expandproperty effectivelevel | should be ($jade.effectivelevel -1)
		GetPossession "Currency" "Penny" | select -expandproperty effectiveLevel | should be ($pennies.effectiveLevel +1 )
	}
}
Describe "Airs" {
	It "can read airs from plan" {
		Airs | should not be $null
	}
}


Describe "CreatePlan" {
	It "can create plan" {
		$result = CreatePlanFromActionString "lodgings,nightmares,1"
		$result.isSuccess | should be $true
	}
	It "can find plan" {
		$plan = Get-Plan "Invite someone to a Game of Chess"
		$plan | should not be null
		$plan.branch.name | should be "Invite someone to a Game of Chess"
	}
	It "can delete plan" {
		$result = DeleteExistingPlan "Invite someone to a Game of Chess"
	}
}



Describe "Basic acquisitions" {
	It "has grindpersuasive" {
		$script:Acquisitions.GrindPersuasive | should not be $null
		$script:Acquisitions.GrindPersuasive.Action| should be "empresscourt,attend,perform"
	}
	It "has menaces " {
		$script:Acquisitions.Scandal | should not be $null
	}
}
Describe "ParseActionString" {
	It "splits string" {
		$action = ParseActionString "1, aoeu ,tre"
		$action.location | should be 1
		$action.first | should be " aoeu "
		$action.second | should be "tre"
		$action.third | should be $null
	}
	It "leaves tail if longer than 4" {
		$action = ParseActionString "1,2,3,4,5"
		$action.location | should be 1
		$action.first | should be 2
		$action.second | should be 3
		$action.third.length | should be 2
		$action.third[0] | should be 4
		$action.third[1] | should be 5
	}
	It "can return exactly four results" {
		$action = ParseActionString "a,b,c,de"
		$action.location | should be "a"
		$action.first | should be "b"
		$action.second | should be "c"
		$action.third | should be "de"
	}
	It "returns null if trying to index nonexistent third entry" {
		$action = ParseActionString "aaa,bbb,ccc,def"
		$action.location | should be "aaa"
		$action.first | should be "bbb"
		$action.second | should be "ccc"
		$action.third[0] | should be "def"
		$action.third[1] | should be $null
	}
}
Describe "Acquire" {
	It "performs action to acquire possession" {
		Acquire "spite,Alleys,Cats,grey" -dryRun
		$script:actionHistory.length | should be 1
		$script:actionHistory[0] | should be "spite,Alleys,Cats,grey"
		$script:actionHistory = @()
	}
}
Describe "LookupAcquisition" {
	It "can find exact name" {
		$a = LookupAcquisition "Suspicion"
		$a.Action | should be "inventory,Curiosity,Ablution Absolution,1"
	}
	It "can find partial name match" {
		$a = LookupAcquisition "clue"
		$a.Result | should be "Cryptic Clue"
	}
	It "can find specific result match" {
		$a = LookupAcquisition "Working on..."
		$a.Name | should be "StartNovel"
	}
}


Describe "Require" {

	$script:myself = @{
		"possessions" = @(
			(TestPossessionData "" "Dangerous" 100),
			(TestPossessionData "Mysteries" "Cryptic Clue" 10),
			(TestPossessionData "Menaces" "Nightmares" 5)
		)
	};
	It "performs action regardless if level is null" {
		$result = Require "Menaces" "Wounds" -dryRun
		$script:actionHistory.Length | should be 1
		$script:actionHistory[0] | should be "lodgings,wounds,time,1"
		$script:actionHistory = @()
	}
	It "can tag specific acquisition to run in requirements" {
		$result = Require "Circumstance" "Working on..." 100 "StartShortStory" -dryRun
		$script:actionHistory.Length | should be 1
		$script:actionHistory[0] | should be "veilgarden,begin a work,short story"
		$script:actionHistory = @()
	}
	It "can tag another specific acquisition to run in requirements" {
		$result = Require "Circumstance" "Working on..." 100 "StartNovel" -dryRun
		$script:actionHistory.Length | should be 1
		$script:actionHistory[0] | should be "empresscourt,next work,novel"
		$script:actionHistory = @()
	}
	It "noops if you already have the possession" {

		$result = Require "Mysteries" "Cryptic Clue" 5 -dryRun
		$script:actionHistory.length | should be 0
		$result | should be $true
	}
	It "noops if you have exact count" {

		$result = Require "Mysteries" "Cryptic Clue" "=10" -dryRun
		$script:actionHistory.length | should be 0
		$result | should be $true
	}
	It "noops if you haven't got enough menaces" {

		$result = Require "Menaces" "Nightmares" "<8" -dryRun
		$script:actionHistory.length | should be 0
		$result | should be $true
	}
	It "acquires if you dont have enough of the possession" {

		$result = Require "Mysteries" "Cryptic Clue" 15 "Cryptic Clue" -dryRun
		$script:actionHistory.length | should be 1
		$script:actionHistory[0] | should be "spite,Alleys,Cats,grey"
		$result | should be $false
		$script:actionHistory = @()
	}
	It "acquires if possession not found" {

		$result = Require "Menaces" "Scandal" 15 -dryRun
		$script:actionHistory.length | should be 1
		$script:actionHistory[0] | should be "lodgings,scandal,service"
		$result | should be $false
		$script:actionHistory = @()
	}
	It "acquires if you dont have exact count" {
		$result = Require "Mysteries" "Cryptic Clue" 15 -dryRun
		$script:actionHistory.length | should be 1
		$script:actionHistory[0] | should be "flit,its king,meeting,understand"
		$result | should be $false
		$script:actionHistory = @()
	}

	It "reduces menaces if you have too much, which cascades to getting clues" {
		$script:actionHistory = @()
		$result = Require "Menaces" "Nightmares" "<5" -dryRun
		$script:actionHistory.length | should be 1
		$script:actionHistory[0] | should be "flit,its king,meeting,understand"
		$result | should be $false
	}
	$script:actionHistory = @()
	$script:myself = $null
}
Describe "GetCostforSource" {
	It "knows how to get 1000 romantic notions" {
		SetPossessionLevel "Nostalgia" "Romantic Notion" 0
		SetPossessionLevel "Nostalgia" "Drop of Prisoner's Honey" 0
		$sources = Sources "Romantic Notion"
		GetCostForSource $sources[0] 1000 -force | should be 110
	}
	It "knows how to get 500 hints" {
		SetPossessionLevel "Mysteries" "Whispered hint" 0
		$sources = Sources "Whispered Hint"
		GetCostForSource $sources[0] 500 -force | should be 8
	}
	It "includes prereq cost" {
		SetPossessionLevel "Mysteries" "Whispered hint" 0
		$sources = Sources "Cryptic Clue"
		GetCostForSource $sources[0] 1 -force | should be 1
		GetCostForSource $sources[1] 1 -force | should be 9
	}
	It "accounts for existing inventory" {
		SetPossessionLevel "Mysteries" "Whispered hint" 499
		$sources = Sources "Cryptic Clue"
		GetCostForSource $sources[0] 1 -force | should be 1
		GetCostForSource $sources[1] 1 -force | should be 2
	}
}
Describe "ActionCost" {
	It "returns 1 if not in inventory and missing exactly reward" {
		SetPossessionLevel "Mysteries" "Whispered hint" 0
		$c = ActionCost "Mysteries" "Whispered Hint" 66 -force
		$c.Cost | should be 1
		$c.Action | should be "flit,its king,meeting,understand"
	}
	It "returns 2 if not in inventory and requesting exactly one more than reward" {
		SetPossessionLevel "Mysteries" "Whispered hint" 0
		$c = ActionCost "Mysteries" "Whispered Hint" 67 -force
		$c.Cost | should be 2
		$c.Action | should be "flit,its king,meeting,understand"
	}
	It "returns 1 if one in inventory and requesting exactly one more than reward" {
		SetPossessionLevel "Mysteries" "Whispered hint" 1
		$c = ActionCost "Mysteries" "Whispered Hint" 67 -force
		$c.Cost | should be 1
		$c.Action | should be "flit,its king,meeting,understand"
	}
}
Describe "Sources" {
	It "can get sources for item" {
		$sources = Sources "Cryptic Clue" | sort-object Name
		$sources.Count | should be 2
		$sources[0].Name | should be "DefaultMysteries1Cryptic Clue"
		$sources[1].Name | should be "more Cryptic Clue"
	}
}

Describe "ActionCost with Sources" {
	It "uses the fastest source to get answer" {
		SetPossessionLevel "Mysteries" "Cryptic Clue" 0
		SetPossessionLevel "Mysteries" "Whispered hint" 499
		$c = ActionCost "Mysteries" "Cryptic Clue" 1 -force
		$c.Cost | should be 1
		$c.Action | should be "spite,unfinished business,Eavesdropping"

		$c = ActionCost "Mysteries" "Cryptic Clue" 200 -force
		$c.Cost | should be 2
		$c.Action | should be "inventory,Mysteries,Whispered Hint,combine"
	}
	It "gives correct cost when prereq is partially fulfilled" {
		AddAcquisition "Hand" "Hand" "get hand" 1 @("Curiosity,Finger,5")
		AddAcquisition "Finger" "Finger" "get finger" 1
		SetPossessionLevel "Curiosity" "Finger" 3
		$c = ActionCost "Curiosity" "Hand" 2 -force
		$c.Cost | should be 9
	}
}


$script:actions =@( 0, 1, 2, 3, 4, 5, 6 )
Describe "Get-Action" {
	It "selects based on day of year" {
		Get-Action (new-object datetime 2018, 1, 1, 0, 0, 0) | should be 1
		Get-Action (new-object datetime 2018, 1, 1, 0, 10, 0) | should be 1
	}
	It "cycles" {
		Get-Action (new-object datetime 2018, 1, 6, 2, 0, 0) | should be 6
		Get-Action (new-object datetime 2018, 1, 7, 2, 0, 0) | should be 0
	}
}
Describe "GetCardInUseList" {
	It "returns a single card" {
		$script:CardActions = @{"use"=@( @{"name"=3},@{"name"=4})}
		$r = GetCardInUseList @{"displayCards"=@(@{"eventid"=3},@{"eventid"=14})}
		$r.name | should be 3
	}
	It "returns one card even if two matches" {
		$script:CardActions = @{"use"=@( @{"name"=3},@{"name"=4})}
		$r = GetCardInUseList @{"displayCards"=@(@{"eventid"=3},@{"eventid"=4})}
		$r.name | should be 3
	}
	It "returns no cards if none matches" {
		$script:CardActions = @{"use"=@( @{"name"=3},@{"name"=4})}
		$r = GetCardInUseList @{"displayCards"=@(@{"eventid"=13},@{"eventid"=14})}
		$r | should be $null
	}
	It "returns eventid as well as name cards" {
		$script:CardActions = new-object psobject -property @{"use"=@(@{"name"="hej";"action"="one"})}
		$r = GetCardInUseList (new-object psobject -property @{"displayCards"=@(@{"eventid"=13;"name"="hej"})})
		$r.name | should be "hej"
		$r.eventid | should be 13
		$r.action | should be "one"
	}
}


$list = ListStorylet
if( $list.Phase -ne "Available"  )
{
	if( $list.storylet.canGoBack )
	{
		$b = GoBack
	}
	else
	{
		write-warning "locked in a storylet, cant run final tests"
		return
	}
}
Describe "MoveTo" {
	It "can move to well known area" {
		if( GetUserLocation -eq 7 )
		{
			$testlocation = "Veilgarden"
		}
		else
		{
			$testlocation = "Spite"
		}
		$result = MoveTo $testlocation
		$result.area.name | should be $testlocation
	}
	It "can move to lodgings" {
		$result = MoveTo "lodgings"
		$result.area.name | should be "Your Lodgings"
	}
}
Describe "GetUserLocation" {
	It "can get current location" {
		GetUserLocation | should be 2
	}
}

Describe "GetStoryletId" {
	It "can get storylet id by name" {
		GetStoryletId "Society" | should be 276092
	}
}

Describe "GoBackIfInStorylet" {
	It "returns regular list when not in storylet" {
		$list = GoBackIfInStorylet
		$list.Phase | should be "Available"
		$list.actions | should not be $null
		$list.storylets | should not be $null
		$list.isSuccess | should be $true
	}
	It "returns same list when in a storylet" {
		UseQuality 377
		$list = GoBackIfInStorylet
		$list.Phase | should be "Available"
		$list.actions | should not be $null
		$list.storylets | should not be $null
		$list.isSuccess | should be $true
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

Describe "EnterStorylet" {
	It "can enter storylet by name" {
		$list = GoBackIfInStorylet
		$result = EnterStorylet $list "Society"
		$result.isSuccess | should be $true
		$result.storylet | should not be $null
		$result.storylet.cangoback | should be $true
	}
	It "returns null if not valid storylet name" {
		$list = GoBackIfInStorylet
		$result = EnterStorylet $list "Not A Storylet Name"
		$result | should be $null
	}
}


# Describe "PerformAction" {
# 	It "can perform one action" {
# 		$event = EnterStorylet $null "write letters"
# 		$result = PerformAction $event "arrange"
# 		$result.Phase | should be "End"
# 		$result.actions | should not be $null
# 	}
# }

# Describe "PerformActions" {
# It "can perform multiple actions" {
# $result = PerformActions $null "preparing for your burglary" @("choose your target","preparing for your burglary","choose your target")
# $result.Phase | should be "In"
# $result.actions | should not be $null
# $result.storylet | should not be $null
# $result.storylet.canGoBack | should be $true
# $result.storylet.id | should be 223811
# }
# }