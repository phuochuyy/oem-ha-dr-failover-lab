# Unplanned-outage drill: hard power-off the current primary, let the FSFO observer fail over,
# check the application path (role services), restart the old primary, wait for automatic reinstate,
# re-open it as Active Data Guard and (optionally) switch roles back.
param([switch]$SwitchBack)
Import-Module (Join-Path $PSScriptRoot 'lab.psm1') -Force

function Get-Primary {
    $s = (Invoke-LabScript oem24 -Script 'dataguard\dg_status.sh') -join "`n"
    if ($s -match '(?m)^\s*(prm1|stb1) - Primary database') { return @{ Name = $Matches[1]; Text = $s } }
    @{ Name = $null; Text = $s }
}

Write-LabStep 'Before: status + application probe'
$before = Get-Primary
$before.Text
if ($before.Text -notmatch 'Fast-Start Failover:\s+Enabled') { throw 'FSFO is not enabled - run host\04-enable-fsfo.ps1' }
$P = $before.Name; $T = if ($P -eq 'prm1') { 'stb1' } else { 'prm1' }
Invoke-LabScript oem24 -Script 'dataguard\app_probe.sh' -Arguments "before failover (primary $P)"

Write-LabStep "Crash: hard power-off $P"
$t0 = Get-Date
$null = VBoxManage controlvm $P poweroff 2>&1   # progress goes to stderr; must not abort the drill
do {
    Start-Sleep 10
    $now = Get-Primary
    '{0,4:N0}s primary={1}' -f ((Get-Date) - $t0).TotalSeconds, $now.Name
} until ($now.Name -eq $T -or ((Get-Date) - $t0).TotalMinutes -gt 6)
if ($now.Name -ne $T) { throw "No failover to $T within 6 minutes" }
Write-LabStep ('Failover to {0} detected after {1:N0}s' -f $T, ((Get-Date) - $t0).TotalSeconds)
$now.Text

Write-LabStep 'Application probe after failover (RW must be served by the new primary)'
Invoke-LabScript oem24 -Script 'dataguard\app_probe.sh' -Arguments "after failover (primary $T)"

Write-LabStep "Restart $P - observer should reinstate it as standby"
VBoxManage startvm $P --type headless | Out-Null
$t1 = Get-Date
do {
    Start-Sleep 20
    $s = (Invoke-LabScript oem24 -Script 'dataguard\dg_status.sh') -join "`n"
    # "(*)" marks the FSFO target; a member waiting for reinstate shows "(disabled)" + ORA-16661
    $ok = $s -match "(?m)^\s*$P - (\(\*\) )?Physical standby database\s*$" -and $s -match '(?m)^SUCCESS'
    '{0,4:N0}s reinstated={1}' -f ((Get-Date) - $t1).TotalSeconds, $ok
} until ($ok -or ((Get-Date) - $t1).TotalMinutes -gt 15)
$s
if (-not $ok) { throw "$P was not reinstated within 15 minutes" }

Write-LabStep "Active Data Guard on $P"
Invoke-LabScript oem24 -Script 'dataguard\adg_reopen.sh' -Arguments $P, $T

if ($SwitchBack) {
    Write-LabStep "Switchover back to $P"
    Invoke-LabScript oem24 -Script 'dataguard\switchover.sh' -Arguments $P
    Start-Sleep 30
    Invoke-LabScript oem24 -Script 'dataguard\adg_reopen.sh' -Arguments $T, $P
}

Write-LabStep 'After: status + application probe'
# right after a switchover / apply restart the broker briefly reports ORA-16869 / ORA-16810; wait one health cycle
$t2 = Get-Date
do {
    Start-Sleep 20
    $s = (Invoke-LabScript oem24 -Script 'dataguard\dg_status.sh') -join "`n"
} until ($s -match '(?m)^SUCCESS' -or ((Get-Date) - $t2).TotalMinutes -gt 5)
$s
Invoke-LabScript oem24 -Script 'dataguard\app_probe.sh' -Arguments 'after drill'
