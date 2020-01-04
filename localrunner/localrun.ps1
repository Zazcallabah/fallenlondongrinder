while($true) {
	write-host "`n`n`n`n`n`n`n`n`n`n"
	$mark = [DateTime]::UtcNow;
	git pull
	dotnet test --filter RunAuto
	date
	while( [DateTime]::UtcNow - $mark -lt "00:10:10" ) {
		$s =  ([DateTime]::UtcNow - $mark).TotalSeconds
		Write-Progress -Activity "waiting" -Status "..." -SecondsRemaining (600-$s) -PercentComplete ($s*100/600)
		Start-Sleep -Seconds 5
	}
}