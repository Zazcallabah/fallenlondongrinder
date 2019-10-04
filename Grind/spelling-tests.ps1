. ./main.ps1 -noaction

$prereqs = @()

$list = $script:CardActions.use | %{ $_.Require }
$list += $script:Acquisitions.PSObject.Properties | %{ $script:Acquisitions."$($_.Name)".Prerequisites }

$oldv = $verbosepreference
$verbosepreference = "SilentlyContinue"
$list | ?{ $_ -ne $null } | %{
	$prereq = $_

	if($prereq.Contains("Whispered Hints,"))
	{
		Describe $_ {
			It "pluralizes hints" {
				$cat | should be "Whispered Hint,"
			}
		}
	}

	if($prereq.Contains("Cryptic Clues,"))
	{
		Describe $_ {
			It "pluralizes clues" {
				$cat | should be "Cryptic Clue,"
			}
		}
	}
}
$verbosepreference = $oldv