
# near arbor:
# Curiosity,Attar,5 &&
# Mysteries,Extraordinary Implications,21 &&
# Stories,Arbor: Permission to Linger,300 or whatever multiple will work out &&
# Stories,The Rose-Red Streets,=3 -> go to far arbor
# -
# Mysteries,Extraordinary Implications,21 &&
# Stories,Arbor: Permission to Linger,300 or whatever multiple will work out &&
# Stories,The Rose-Red Streets,=3 ->
# [we use perm to do these, can it drift below condition?]
# -
# xxxxxxxx Stories,The Rose-Red Streets,=3 -> go south

# xxxxxxxxxxxxxxxMysteries,Extraordinary Implications,21 &&
# xxxxxxxxxxxxStories,Arbor: Permission to Linger,300 or whatever multiple will work out (have buffer for going to far arbor) &&
# xxxxxxxxxxxxxxxStories,The Rose-Red Streets,=4 -> go north
# -
# xxxxxxxxxxxxMysteries,Extraordinary Implications,<3 &&
# xxxxxxxxxxStories,The Rose-Red Streets,=4 -> shortcut north
# -
# xxxxxxxxxxxxxx Stories,The Rose-Red Streets,=4 -> investigate near arbori: gain 3 pemission, cost 3 extraordinary implications

#xxxxxxxxxxxxxxx Mysteries,Extraordinary Implications,21 &&
# xxxxxxxxxxStories,Arbor: Permission to Linger,300 or whatever multiple will work out (have buffer for going to far arbor) &&
# xxxxxxxxxxxxxxStories,The Rose-Red Streets,=2 -> go south
# -
# xxxxxxxxxxxxxxxStories,Arbor: Permission to Linger,<4 &&
# xxxxxxxxxxxxxxxStories,The Rose-Red Streets,=2 -> go south
# [rounding errors, what exactly triggers exit?]
# -
#xxxxxxxxxxxxx Stories,The Rose-Red Streets,=2 -> spy on londons embassy: get 2 extraordinary implications, cost 1 permission


# far arbor:
# Stories,Arbor: Permission to Linger,>12 &&
# Stories,The Rose-Red Streets,=3 -> walk the walls (gives attar)
# Stories,The Rose-Red Streets,=3 -> go south
# Stories,The Rose-Red Streets,=4 -> go south
# Stories,The Rose-Red Streets,=5 -> gift attar to queen


. ./main.ps1 -noaction

function SetupStart
{
	param($impl=21,$street=3,$attar=1,$perm=5)
	$script:myself = @{
		"possessions" = @(
			(TestPossessionData "Stories" "Arbor: Permission to Linger" $perm),
			(TestPossessionData "Stories" "The Rose-Red Streets" $street),
			(TestPossessionData "Curiosity" "Attar" $attar),
			(TestPossessionData "Mysteries" "Extraordinary Implication" $impl),
			(TestPossessionData "Influence" "Favour in High Places" 0)
		)
	}
	$script:actionpoints = 0
}

function SetGetPossessionLevel
{
	param($category,$name,$adjust)

	$pos = GetPossessionLevel $category $name
	if( $adjust -eq $null )
	{
		return $pos
	}
	$return = SetPossessionLevel $category $name ($pos+$adjust)
}

function SetAttar
{
	param($val)
	$r=SetPossessionLevel "Curiosity" "Attar" $val
}
function Attar
{
	param($adjust)
	return SetGetPossessionLevel "Curiosity" "Attar" $adjust
}
function Streets
{
	param($adjust)
	return SetGetPossessionLevel "Stories" "The Rose-Red Streets" $adjust
}
function SetPermission
{
	param($val)
	$r=SetPossessionLevel "Stories" "Arbor: Permission to Linger" $val
}
function Permission
{
	param($adjust)
	return SetGetPossessionLevel "Stories" "Arbor: Permission to Linger" $adjust
}
function Implications
{
	param($adjust)
	return SetGetPossessionLevel "Mysteries" "Extraordinary Implication" $adjust
}
function FiHP
{
	param($adjust)
	return SetGetPossessionLevel "Influence" "Favour in High Places" $adjust
}
function Place
{
	return $script:list.storylet.name
}
function GoNear
{
	$script:list.storylet.name = "Near Arbor"
}
function GoFar
{
	$script:list.storylet.name = "Far Arbor"
}
$script:list = @{"storylet"=@{"name"="Near Arbor"}}

function Handle
{
	$proposedaction = HandleLockedStorylet $script:list -dryrun
	ChangeState $proposedAction
}
$script:rng = new-object -TypeName "System.Random"

function PrintStatus
{
	Write-Host "AP:$($script:actionpoints) >> $(Place), street $(Streets). Perm $(Permission) Impl $(Implications) Attar $(Attar) fihp $(FiHP)"
}
$script:lastaction = ""
$script:xcount = 1
function ChangeState
{
	param($proposedaction)

	$areequal= $proposedaction -eq $script:lastaction

	$script:actionpoints++

	if( $areequal )
	{
		$script:xcount++
	}
	else
	{
		if( $script:xcount -gt 1 )
		{
			write-host "x $($script:xcount)`n"
			$script:xcount = 1
		}
		$script:lastaction = $proposedaction
		Write-Host "doing action $proposedaction, new status:"
	}

	if( (Permission) -eq 0 -and $proposedaction -ne "Leave Arbor")
	{
		throw "invalid action for no permission"
	}
	if( (Permission) -ne 0 -and (Place) -eq "Near Arbor" -and (Attar) -ge 5 -and $proposedaction -ne "Enter Far Arbor" )
	{
		throw "invalid action for near arbor with 5 attar"
	}
	if( (Permission) -ne 0 -and (Place) -eq "Far Arbor" -and (Attar) -lt 3 -and $proposedaction -ne "The City Washes Away" )
	{
		throw "invalid action for far arbor without 3 attar"
	}

	if( $proposedaction -eq "Leave Arbor" )
	{
		if( (Permission) -ne 0 )
		{
			throw "invalid state for Leave Arbor"
		}

		$rate = (FiHP)*12/$script:actionpoints
		write-host "total $($script:actionpoints) AP gave $(FiHP) fihp. $($rate) e/min"
		throw "simulation ended"
	}
	elseif( $proposedaction -eq "The city washes away" )
	{
		if( (Place) -ne "Far arbor" -or (Attar) -ge 3 )
		{
			throw "invalid state for city washes away"
		}

		GoNear
	}
	elseif( $proposedaction -eq "Gift your Attar in tribute to the Roseate Queen" )
	{
		if( (Streets) -ne 5 -or (Place) -ne "Far arbor" )
		{
			throw "invalid state for gift your attar to queen"
		}
		Permission -1

		if( ($script:rng.NextDouble()) -lt 0.21 )
		{

			FiHp ([Math]::Round( (Attar)/3 ) )
			SetAttar 0
		}
		else
		{
			Attar -3
			FiHP 1
		}

	}
	elseif( $proposedaction -eq "Walk the walls" )
	{
		if( (Streets) -ne 3 -or (Place) -ne "Far arbor" )
		{
			throw "invalid state for walk south"
		}
		Permission -1
		Attar 2
	}
	elseif( $proposedaction -eq "Walk south" )
	{
		if( (Streets) -eq 5 )
		{
			throw "invalid state for walk south"
		}
		Permission -1
		Streets 1
	}
	elseif( $proposedaction -eq "Enter Far Arbor" )
	{
		if( (Place) -ne "Near Arbor" )
		{
			throw "invalid state for enter far arbor"
		}
		GoFar
	}
	elseif( $proposedaction -eq "Become a serpent-tender in exchange for Attar" )
	{
		if( (Streets) -ne 5 -or (Place) -ne "Near Arbor" )
		{
			throw "invalid state for serpent-tender"
		}
		Attar (Permission)
		SetPermission 0
	}
	elseif( $proposedaction -eq "Walk north" )
	{
		if( (Streets) -eq 1 )
		{
			throw "invalid state for walk north"
		}
		Permission -1
		Streets -1
	}
	elseif( $proposedaction -eq "Spy on London's Embassy" )
	{
		if( (Streets) -ne 2 -or (Place) -ne "Near Arbor" )
		{
			throw "invalid state for spy embassy"
		}
		Permission -1
		Implications 2
	}
	elseif( $proposedaction -eq "Explore the Gatehouse Market" )
	{
		if( (Streets) -ne 3 -or (Place) -ne "Near Arbor" )
		{
			throw "invalid state for gatehouse market"
		}
		Permission -1
		Attar 2
	}
	elseif( $proposedaction -eq "take a short-cut north" )
	{
		if( (Streets) -ne 4 -or (Place) -ne "Near Arbor" )
		{
			throw "invalid state for shortcut north"
		}
		Permission -1
		Streets -2
	}
	elseif( $proposedaction -eq "Investigate the Near-Arbori" )
	{
		if( (Streets) -ne 4 -or (Place) -ne "Near Arbor" -or (Implications) -lt 3 )
		{
			throw "invalid state for investigate near arbori"
		}
		Permission 3
		Implications -3
	}
	else
	{
		throw "unknown proposed action"
	}
	if( !$areequal )
	{
		PrintStatus
	}
}
# Setupstart
# gave 190 fihp in 785 ap = 3 e/min

#SetupStart -impl 21 -attar 3 -street 5
#gave 191 fihp in 787 ap = 3 e/min

SetupStart -impl 114 -attar 1 -street 2 -perm 16

while($true)
{
	Handle
}

