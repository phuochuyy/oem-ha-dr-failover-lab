# Corrective action drill for the FRA metric (Recovery Area Used Space, non-reclaimable part).
# Real archive logs raise the value slightly and the Warning threshold is set just below it, so the host disk
# is not filled. Default case: the FRA relief rule must submit the job, which lowers the value and clears the alert.
# -FailCase: /u01/backup is made read-only, the job must fail and the alert must stay open.
# Thresholds and the directory are always restored. Times come from polling every 15 s, on top of the
# 5-minute collection interval; the repository timestamps printed in each line are the exact ones.
param([switch]$FailCase, [string]$Primary = 'prm1', [int]$MaxMinutes = 14)
Import-Module (Join-Path $PSScriptRoot 'lab.psm1') -Force
Assert-LabDisk
Initialize-LabNodeEnv oem24
$target = "orcl_$Primary"
$alertBase = "^ALERT\|$target\|Recovery_Area\|"

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

# The threshold must sit above the floor the relief can reach (after - arch), not above the value before the
# raise: the raise also adds flashback logs, which the relief cannot remove. Whole numbers only: the database
# rejects a decimal threshold for this server-generated metric (ORA-13900). Raise again until one fits.
$margin = 0.2   # room for flashback logs written between the raise and the relief
for ($round = 1; $round -le 3; $round++) {
    Write-LabStep "Raise FRA usage with real archive logs (round $round)"
    $raised = (Invoke-LabScript $Primary -Script 'monitoring\drill\fra_raise.sh') -join ' '
    $raised
    if ($raised -notmatch 'before=([\d.]+) after=([\d.]+) arch=([\d.]+)') { throw 'Could not read FRA usage' }
    $after = [double]$Matches[2]; $arch = [double]$Matches[3]
    $floor = $after - $arch
    $warnValue = [math]::Ceiling($floor + $margin)
    if ($warnValue -lt $after) { break }
}
if ($warnValue -ge $after) { throw "No whole number between floor $floor (+$margin) and $after after 3 rounds" }
$warn = [string][int]$warnValue
'Floor the relief can reach {0:N2}%, value now {1:N2}%, warning threshold {2}' -f $floor, $after, $warn

$t0 = Get-Date
$os = Get-CimInstance Win32_OperatingSystem
'Drill on {0}, FailCase={1}, start {2:HH:mm:ss}, host RAM free {3:N1} GB' -f $target, [bool]$FailCase, $t0, ($os.FreePhysicalMemory / 1MB)

try {
    if ($FailCase) {
        Write-LabStep 'Make /u01/backup read-only'
        Invoke-LabSsh $Primary -User root -Command 'chmod 555 /u01/backup; ls -ld /u01/backup'
    }
    Write-LabStep "Threshold for the drill: warning $warn"
    Invoke-LabScript oem24 -Script 'monitoring\drill\threshold.sh' -Arguments $target, 'Recovery_Area', 'Free_Space', $warn, '97', ' ;'
    if ($LASTEXITCODE -ne 0) { throw 'The threshold was not changed' }

    Write-LabStep 'Wait for the alert and the corrective action'
    Wait-NewLine ($alertBase + 'Warning') 'alert' $t0 $known
    Wait-NewLine '^JOB\|FRA_RELIEF_.*\|(Succeeded|Failed|Error|Problems)' 'relief job' $t0 $known
    Wait-NewLine "^EVENT\|.*$target.*Recovery Area" 'notification' $t0 $known

    if ($FailCase) {
        Write-LabStep 'The alert must stay open for one more collection'
        Start-Sleep 330
        Get-StatusLines | Where-Object { $_ -match ($alertBase + '(Warning|Clear)') -or $_ -match "^INCIDENT.*$target.*open=1" }
        Invoke-LabSsh $Primary -Command 'tail -3 /u01/backup/fra_relief.log'
    } else {
        Wait-NewLine ($alertBase + 'Clear') 'clear' $t0 $known
        Invoke-LabSsh $Primary -Command 'tail -2 /u01/backup/fra_relief.log'
    }
}
finally {
    if ($FailCase) {
        Write-LabStep 'Restore /u01/backup, clean the logs that were kept'
        Invoke-LabSsh $Primary -User root -Command 'chmod 750 /u01/backup; ls -ld /u01/backup'
        Invoke-LabSsh $Primary -Command '/u01/app/oracle/lab/ca/fra_relief.sh'
    }
    Write-LabStep 'Restore threshold 85 / 97'
    Invoke-LabScript oem24 -Script 'monitoring\drill\threshold.sh' -Arguments $target, 'Recovery_Area', 'Free_Space', '85', '97', ' ;'
}
Write-LabStep 'Result'
Get-StatusLines
Invoke-LabScript oem24 -Script 'dataguard\dg_status.sh' | Select-String 'Primary database|SUCCESS|WARNING|ERROR'
Assert-LabDisk
