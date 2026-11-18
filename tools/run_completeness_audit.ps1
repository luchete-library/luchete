$ErrorActionPreference = 'Stop'
$workspace = 'D:\리스텔라팬게임'
$outDir = Join-Path $workspace 'artifacts/completeness_20261118'
$exe = 'C:\Users\dbtmd\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$old = Get-Content -LiteralPath (Join-Path $workspace 'artifacts/library_care_20261118/final_report.json') -Raw | ConvertFrom-Json
$suites = @($old.suites | Where-Object { $_.checks -gt 0 } | ForEach-Object { [pscustomobject]@{name=$_.name; native=$_.native_render} })
$extra = @('book_discovery','dori_discovery','story_observation_polish','story_trail','map_dressing','polish_modules_smoke','polish_shop_review','polish_reconstruction_review','growth_game_flow','studios','operating_production_balance','promotion_ui_regression','reopening_promotion_flow','fallen_books','neglect_visibility','library_speech_bubbles')
$native = @('book_discovery','dori_discovery','story_observation_polish','polish_shop_review','polish_reconstruction_review','studios','promotion_ui_regression','reopening_promotion_flow','fallen_books','neglect_visibility','library_speech_bubbles')
foreach ($name in $extra) { if ($name -notin $suites.name) { $suites += [pscustomobject]@{name=$name;native=($name -in $native)} } }
$suites | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outDir 'manifest.json') -Encoding utf8
$results = @()
foreach ($suite in $suites) {
 $name = $suite.name
 $log = Join-Path $outDir ($name + '.log')
 $argList = @('--path',$workspace,'--script',('res://tests/' + $name + '.gd'),'--log-file',$log,'--audio-driver','Dummy')
 if ($suite.native) { $argList += @('--rendering-method','gl_compatibility','--position','-4000,-4000') } else { $argList += '--headless' }
 $start = Get-Date
 $p = Start-Process -FilePath $exe -ArgumentList $argList -WindowStyle Hidden -PassThru
 $done = $false
 while (((Get-Date)-$start).TotalSeconds -lt 180) { if ($p.WaitForExit(1000)) { $done=$true;break } }
 if (-not $done) { Stop-Process -Id $p.Id }
 $p.Refresh()
 $lines = @(Get-Content -LiteralPath $log -ErrorAction SilentlyContinue)
 $issues = @($lines | Where-Object { $_ -match '^(SCRIPT ERROR:|ERROR:|FAIL:)' -and $_ -notmatch 'root certificate store' })
 $summaries = @($lines | Where-Object { $_ -match '(checks|COMPLETE|failures|assertions)' })
 $checkCount = 0
 foreach ($line in $summaries) {
  if ($line -match '(\d+) (?:focused )?checks') { $checkCount=[int]$Matches[1] }
  elseif ($line -match 'checks[:=]\s*(\d+)') { $checkCount=[int]$Matches[1] }
 }
 $result = [pscustomobject]@{name=$name;native_render=$suite.native;completed=$done;exit_code=$p.ExitCode;seconds=[math]::Round(((Get-Date)-$start).TotalSeconds,1);checks=$checkCount;issues=$issues;summary=$summaries;passed=($done -and $p.ExitCode -eq 0 -and $issues.Count -eq 0)}
 $results += $result
 $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outDir 'suite_results.json') -Encoding utf8
 Write-Output ($name + ' passed=' + $result.passed + ' checks=' + $checkCount + ' seconds=' + $result.seconds)
}
Write-Output ('COMPLETE ' + $results.Count + ' suites, passed=' + @($results | Where-Object passed).Count)
