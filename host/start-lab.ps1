# Start the lab: OEM24 first (repository DB -> OMS/agent -> observer), then the Data Guard pair.
# DBs, EM and the observer start through systemd inside the VMs.
param([switch]$EmOnly, [switch]$DataGuardOnly)
Import-Module (Join-Path $PSScriptRoot 'lab.psm1') -Force

if (-not $DataGuardOnly) {
    Write-LabStep 'Start OEM24'
    if ((Get-LabVMState OEM24) -ne 'running') { VBoxManage startvm OEM24 --type headless | Out-Null }
    Wait-LabSsh oem24
}
if (-not $EmOnly) {
    # standby before primary, so the primary finds its redo destination ready
    foreach ($vm in 'stb1', 'prm1') {
        Write-LabStep "Start $vm"
        if ((Get-LabVMState $vm) -ne 'running') { VBoxManage startvm $vm --type headless | Out-Null }
    }
    Wait-LabSsh stb1; Wait-LabSsh prm1
}
if (-not $DataGuardOnly) {
    Write-LabStep 'Wait for EM console'
    for ($i = 0; $i -lt 60; $i++) {
        $c = curl.exe -k -s -o NUL -w '%{http_code}' -L https://localhost:7803/em
        if ($c -eq '200') { break }
        Start-Sleep 10
    }
    "EM console https://localhost:7803/em -> HTTP $c"
}
& (Join-Path $PSScriptRoot 'status.ps1')
