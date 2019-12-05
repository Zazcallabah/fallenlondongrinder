while($true) {
	write-host "`n`n`n`n`n`n`n`n`n`n"
	$mark = [DateTime]::UtcNow;
	dotnet test --filter RunAuto
	while( [DateTime]::UtcNow - $mark -lt "00:10:00" ) {
		$s =  ([DateTime]::UtcNow - $mark).TotalSeconds
		Write-Progress -Activity "waiting" -Status "..." -SecondsRemaining (600-$s) -PercentComplete ($s*100/600)
		Start-Sleep -Seconds 5
	}
}