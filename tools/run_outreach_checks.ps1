$ErrorActionPreference='Stop'
$workspace='D:\리스텔라팬게임'
$out=Join-Path $workspace 'artifacts/outreach_20261118'
$exe='C:\Users\dbtmd\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
$suites=@('growth_production_flow','growth_migration','growth_save_routing','operating_day','growth_visitors','library_day_side_effects','library_care_flow','growth_integration','growth_ui_regression','operating_ui_flow','library_speech_bubbles','completeness_promotion','outreach_ui')
$native=@('growth_ui_regression','operating_ui_flow','library_speech_bubbles','completeness_promotion','outreach_ui')
$results=@()
foreach($name in $suites) {
 $log=Join-Path $out ($name+'.log')
 $arguments=@('--path',$workspace,'--script',('res://tests/'+$name+'.gd'),'--log-file',$log,'--audio-driver','Dummy')
 if($name -in $native){$arguments+=@('--rendering-method','gl_compatibility','--position','-4000,-4000')}else{$arguments+='--headless'}
 $p=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru
 $done=$p.WaitForExit(60000)
 if(-not $done){$p.Kill($true);$p.WaitForExit()}
 $lines=@(Get-Content -LiteralPath $log)
 $issues=@($lines|Where-Object{$_ -match '^(ERROR:|SCRIPT ERROR:)' -and $_ -notmatch 'root certificate store'})
 $checks=$null
 foreach($line in $lines){if($line -match '(\d+) checks'){$checks=[int]$Matches[1]}}
 $r=[pscustomobject]@{name=$name;completed=$done;exit=$p.ExitCode;checks=$checks;errors=$issues;passed=($done -and $p.ExitCode -eq 0 -and $issues.Count -eq 0)}
 $results+=$r
 $results|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $out 'regression_results.json') -Encoding utf8
 Write-Output ($name+' passed='+$r.passed+' checks='+$checks)
}
