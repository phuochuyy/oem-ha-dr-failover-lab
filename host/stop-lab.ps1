# Clean lab shutdown:
#   OMS + agent (no false alerts) -> observer (no failover during maintenance) ->
#   current primary (archive current log first) -> standby (lag 0) -> repository DB -> power off.
Import-Module (Join-Path $PSScriptRoot 'lab.psm1') -Force
$up = @{}; foreach ($vm in 'OEM24', 'prm1', 'stb1') { $up[$vm] = (Get-LabVMState $vm) -eq 'running' }

$order = @('prm1', 'stb1')
if ($up.OEM24) {
    Write-LabStep 'OEM24: stop OMS + agent'
    Invoke-LabScript oem24 -Script 'oem24\em_stop.sh'
    $dg = Invoke-LabScript oem24 -Script 'dataguard\dg_status.sh'
    if (($dg -join "`n") -match '(?m)^\s*stb1 - Primary database') { $order = @('stb1', 'prm1') }
    Write-LabStep 'OEM24: stop FSFO observer'
    Invoke-LabSsh oem24 -User root -Command 'systemctl stop dg-observer.service; systemctl is-active dg-observer.service'
}

foreach ($n in $order) {
    if (-not $up[$n]) { continue }
    Write-LabStep "${n}: stop agent, DB, listener"
    Invoke-LabScript $n -Script 'dataguard\stop_node.sh'
    Invoke-LabSsh $n -User root -Command 'systemctl poweroff' 2>$null
    Wait-LabVMState $n poweroff
}

if ($up.OEM24) {
    Write-LabStep 'OEM24: stop repository DB, power off'
    Invoke-LabScript oem24 -Script 'oem24\repo_db_stop.sh'
    Invoke-LabSsh oem24 -User root -Command 'systemctl poweroff' 2>$null
    Wait-LabVMState OEM24 poweroff
}
foreach ($vm in 'OEM24', 'prm1', 'stb1') { '{0,-6} {1}' -f $vm, (Get-LabVMState $vm) }
