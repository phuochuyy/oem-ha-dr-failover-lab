# Health monitoring drills. A threshold is lowered for the drill, the alert must reach the incident rule
# and DG_LAB_LOG, then the cause is removed, the alert must clear, and the threshold is restored.
# Times are host clock times seen by polling every 15 s, on top of the 5-minute collection interval.
# The repository timestamps printed in each line are the exact ones.
param([ValidateSet('backup', 'txn')][string]$Drill = 'backup', [string]$Primary = 'prm1', [int]$MaxMinutes = 12)
Import-Module (Join-Path $PSScriptRoot 'lab.psm1') -Force
Assert-LabDisk
Initialize-LabNodeEnv oem24
$target = "orcl_$Primary"

if ($Drill -eq 'backup') {
    $metric = 'ME$BACKUP_AGE'; $column = 'BACKUP_AGE_HOURS'; $label = 'Backup Age'
    $warn = '0.2'; $crit = '100'; $normalWarn = '26'; $normalCrit = '50'
} else {
    $metric = 'ME$LONG_TXN'; $column = 'OLDEST_TXN_MINUTES'; $label = 'Oldest Transaction'
    $warn = '1'; $crit = '500'; $normalWarn = '30'; $normalCrit = '60'
}
$alertBase = "^ALERT\|$target\|$([regex]::Escape($metric))\|"

function Get-StatusLines { @((Invoke-LabScript oem24 -Script 'monitoring\status.sh' -Arguments 90, 60)) }

function Wait-NewLine {
    param([string]$Pattern, [string]$What, [datetime]$From, [string[]]$Known)
    do {
        Start-Sleep 15
        $new = @(Get-StatusLines | Where-Object { $_ -match $Pattern -and $Known -notcontains $_ })
    } until ($new.Count -gt 0 -or ((Get-Date) - $From).TotalMinutes -gt $MaxMinutes)
    if ($new.Count -gt 0) { '{0}  +{1,4:N0}s  {2}: {3}' -f (Get-Date -Format 'HH:mm:ss'), ((Get-Date) - $From).TotalSeconds, $What, $new[0] }
    else { "NOT SEEN within $MaxMinutes min: $What" }
}

$known = Get-StatusLines
$t0 = Get-Date
$os = Get-CimInstance Win32_OperatingSystem
'Drill {0} on {1}, start {2:HH:mm:ss}, host RAM free {3:N1} GB' -f $Drill, $target, $t0, ($os.FreePhysicalMemory / 1MB)

try {
    if ($Drill -eq 'txn') {
        Write-LabStep 'Open a transaction on the primary'
        Copy-LabFile $Primary -Path (Join-Path $RepoRoot 'guest\monitoring\drill\hold_txn.sh') -Destination '/tmp/hold_txn.sh'
        Invoke-LabSsh $Primary -Command "sed -i 's/\r$//' /tmp/hold_txn.sh; nohup bash /tmp/hold_txn.sh > /tmp/hold_txn.out 2>&1 < /dev/null & echo started"
    }
    Write-LabStep "Threshold for the drill: warning $warn"
    Invoke-LabScript oem24 -Script 'monitoring\drill\threshold.sh' -Arguments $target, $metric, $column, $warn, $crit

    Write-LabStep 'Wait for the alert, the incident and the notification'
    Wait-NewLine ($alertBase + 'Warning') 'alert' $t0 $known
    Wait-NewLine "^INCIDENT\|.*\|$target\|.*$column" 'incident' $t0 $known
    Wait-NewLine "^EVENT\|.*$target.*$label" 'notification' $t0 $known

    Write-LabStep 'Remove the cause'
    $t1 = Get-Date
    if ($Drill -eq 'backup') {
        Invoke-LabScript $Primary -Script 'monitoring\backup\rman_backup.sh' | Select-String 'RMAN-0|ORA-|^[0-9.]+[GM]\s'
    } else {
        Invoke-LabSsh $Primary -Command "pkill -f '^sleep 3000$'; sleep 5; cat /tmp/hold_txn.out; rm -f /tmp/hold_txn.sh /tmp/hold_txn.out"
    }
    Wait-NewLine ($alertBase + 'Clear') 'clear' $t1 $known
}
finally {
    Write-LabStep "Restore threshold $normalWarn / $normalCrit"
    Invoke-LabScript oem24 -Script 'monitoring\drill\threshold.sh' -Arguments $target, $metric, $column, $normalWarn, $normalCrit
    if ($Drill -eq 'txn') { Invoke-LabSsh $Primary -Command "pkill -f '^sleep 3000$'; true" }
}
Write-LabStep 'Result'
Get-StatusLines
Assert-LabDisk
