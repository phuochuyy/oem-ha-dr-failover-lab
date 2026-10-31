# Alerting drill: stop redo apply on the standby while redo keeps flowing, wait for EM to raise the
# Apply Lag alert -> incident -> OS Command notification (DG_LAB_LOG), then restart apply and wait for
# the incident to clear. Requires guest/em/dg_alerting_setup.sh to have been run.
param([string]$Standby = 'stb1', [int]$MaxMinutes = 10)
Import-Module (Join-Path $PSScriptRoot 'lab.psm1') -Force

Write-LabStep "Stop redo apply on $Standby"
Invoke-LabScript oem24 -Script 'dataguard\apply_state.sh' -Arguments $Standby, 'APPLY-OFF'

Write-LabStep 'Generate redo on the primary (background, in oem24)'
Copy-LabFile oem24 -Path (Join-Path $RepoRoot 'guest\dataguard\gen_redo.sh') -Destination '/tmp/gen_redo.sh'
$secs = $MaxMinutes * 60
Invoke-LabSsh oem24 -Command "sed -i 's/\r$//' /tmp/gen_redo.sh; set -a; . ~/.lab.env; nohup bash /tmp/gen_redo.sh $secs > /tmp/gen_redo.out 2>&1 < /dev/null & echo started"

$t0 = Get-Date
do {
    Start-Sleep 30
    $s = (Invoke-LabScript oem24 -Script 'em\alert_status.sh' -Arguments 15) -join "`n"
    # success = the OS Command notification wrote a Critical line for the standby to events.log
    $hit = $s -match "(?m)\|\s*Critical\s*\|\s*orcl_$Standby\s*\|"
    '{0,4:N0}s  incident/notification seen: {1}' -f ((Get-Date) - $t0).TotalSeconds, $hit
} until ($hit -or ((Get-Date) - $t0).TotalMinutes -gt $MaxMinutes)
$s

Write-LabStep "Restart redo apply on $Standby"
Invoke-LabSsh oem24 -Command 'pkill -f [g]en_redo.sh; true' | Out-Null   # [g] so pkill does not match this ssh command itself
Invoke-LabScript oem24 -Script 'dataguard\apply_state.sh' -Arguments $Standby, 'APPLY-ON'
Start-Sleep 150
Write-LabStep 'After apply restart'
Invoke-LabScript oem24 -Script 'em\alert_status.sh' -Arguments 20
