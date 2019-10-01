
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



Describe "PossessionSatisfiesLevel" {
	It "can get possesion" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Mysteries" "Extraordinary Implication" 21)
			)
		};

		PossessionSatisfiesLevel "Mysteries" "Extraordinary Implication" "<3" | should be $false
	}
}

Describe "Far Arbor" {
	$list = @{"storylet"=@{"name"="Far Arbor"}}
	It "walk walls if perm" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 50),
				(TestPossessionData "Stories" "The Rose-Red Streets" 3),
				(TestPossessionData "Curiosity" "Attar" 5),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 2)
			)
		};

		HandleLockedStorylet $list -dryrun | should be "Walk the Walls"
	}
	It "walk south if no perm" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 5),
				(TestPossessionData "Stories" "The Rose-Red Streets" 3),
				(TestPossessionData "Curiosity" "Attar" 50),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 2)
			)
		};

		HandleLockedStorylet $list -dryrun | should be "Walk South"
	}

	It "walk south if at 4" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 5),
				(TestPossessionData "Stories" "The Rose-Red Streets" 4),
				(TestPossessionData "Curiosity" "Attar" 50),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 2)
			)
		};

		HandleLockedStorylet $list -dryrun | should be "Walk South"
	}

	It "gift attar at palace" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 5),
				(TestPossessionData "Stories" "The Rose-Red Streets" 5),
				(TestPossessionData "Curiosity" "Attar" 50),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 2)
			)
		};

		HandleLockedStorylet $list -dryrun | should be "Gift your attar"
	}

	It "can go back to near arbor" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 5),
				(TestPossessionData "Stories" "The Rose-Red Streets" 5),
				(TestPossessionData "Curiosity" "Attar" 0),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 2)
			)
		};

		HandleLockedStorylet $list -dryrun | should be "1"
	}

}

Describe "Near Arbor" {
	$list = @{"storylet"=@{"name"="Near Arbor"}}
	It "entering at palace, goes north" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 5),
				(TestPossessionData "Stories" "The Rose-Red Streets" 5),
				(TestPossessionData "Curiosity" "Attar" 1),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 21)
			)
		};

		HandleLockedStorylet $list -dryrun | should be "walk north"
	}
	It "at palace without implications means you already gifted, quit" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 5),
				(TestPossessionData "Stories" "The Rose-Red Streets" 5),
				(TestPossessionData "Curiosity" "Attar" 1),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 2)
			)
		};

		HandleLockedStorylet $list -dryrun | should be "Become a serpent-tender"
	}
	It "goes south first thing" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 5),
				(TestPossessionData "Stories" "The Rose-Red Streets" 3),
				(TestPossessionData "Curiosity" "Attar" 1),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 21)
			)
		};

		HandleLockedStorylet $list -dryrun | should be "walk south"
	}
	It "grinds perms #1 a" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 4),
				(TestPossessionData "Stories" "The Rose-Red Streets" 4),
				(TestPossessionData "Curiosity" "Attar" 1),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 21)
			)
		};

		HandleLockedStorylet $list -dryrun | should be "Investigate the Near-Arbori"
	}
	It "grinds perms #1 b" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 10),
				(TestPossessionData "Stories" "The Rose-Red Streets" 4),
				(TestPossessionData "Curiosity" "Attar" 1),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 3)
			)
		};

		HandleLockedStorylet $list -dryrun | should be "Investigate the Near-Arbori"
	}
	It "shortcuts north when not enough implications" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 10),
				(TestPossessionData "Stories" "The Rose-Red Streets" 4),
				(TestPossessionData "Curiosity" "Attar" 1),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 0)
			)
		};

		HandleLockedStorylet $list -dryrun | should be "short-cut north"
	}
	It "spies on embassy when north" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 10),
				(TestPossessionData "Stories" "The Rose-Red Streets" 2),
				(TestPossessionData "Curiosity" "Attar" 1),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 0)
			)
		}

		HandleLockedStorylet $list -dryrun | should be "Spy on London's Embassy"
	}
	It "spies on embassy when north 2" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 4),
				(TestPossessionData "Stories" "The Rose-Red Streets" 2),
				(TestPossessionData "Curiosity" "Attar" 1),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 20)
			)
		}

		HandleLockedStorylet $list -dryrun | should be "Spy on London's Embassy"
	}

	It "go south when almost out of perm" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 3),
				(TestPossessionData "Stories" "The Rose-Red Streets" 2),
				(TestPossessionData "Curiosity" "Attar" 1),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 20)
			)
		}

		HandleLockedStorylet $list -dryrun | should be "Walk South"
	}
	It "centre: go south when mid travel" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 2),
				(TestPossessionData "Stories" "The Rose-Red Streets" 3),
				(TestPossessionData "Curiosity" "Attar" 1),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 20)
			)
		}

		HandleLockedStorylet $list -dryrun | should be "Walk South"
	}
	It "exit condition south" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 275),
				(TestPossessionData "Stories" "The Rose-Red Streets" 4),
				(TestPossessionData "Curiosity" "Attar" 1),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 2)
			)
		}

		HandleLockedStorylet $list -dryrun | should be "Walk North"
	}

	It "exit condition north" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 275),
				(TestPossessionData "Stories" "The Rose-Red Streets" 2),
				(TestPossessionData "Curiosity" "Attar" 1),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 2)
			)
		}

		HandleLockedStorylet $list -dryrun | should be "Walk South"
	}
	It "centre, get attar 1" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 274),
				(TestPossessionData "Stories" "The Rose-Red Streets" 3),
				(TestPossessionData "Curiosity" "Attar" 1),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 2)
			)
		}

		HandleLockedStorylet $list -dryrun | should be "Explore the Gatehouse Market"
	}
	It "centre, get attar 2" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 273),
				(TestPossessionData "Stories" "The Rose-Red Streets" 3),
				(TestPossessionData "Curiosity" "Attar" 3),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 2)
			)
		}

		HandleLockedStorylet $list -dryrun | should be "Explore the Gatehouse Market"
	}

	It "centre will go far arbor" {
		$script:myself = @{
			"possessions" = @(
				(TestPossessionData "Stories" "Arbor: Permission to Linger" 272),
				(TestPossessionData "Stories" "The Rose-Red Streets" 3),
				(TestPossessionData "Curiosity" "Attar" 5),
				(TestPossessionData "Mysteries" "Extraordinary Implication" 24)
			)
		}

		HandleLockedStorylet $list -dryrun | should be "Enter Far Arbor"
	}
}
