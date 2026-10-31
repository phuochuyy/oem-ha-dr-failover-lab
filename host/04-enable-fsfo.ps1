# Fast-Start Failover: role-based services, tnsnames, MaxAvailability + FSFO, observer on oem24 (systemd).
# Idempotent; run with all three VMs up and prm1 as primary.
Import-Module (Join-Path $PSScriptRoot 'lab.psm1') -Force
$tns = Join-Path $RepoRoot 'guest\dataguard\dg_tnsnames.ora'

foreach ($n in 'oem24', 'prm1', 'stb1') { Initialize-LabNodeEnv $n }

Write-LabStep 'tnsnames (role-service aliases) on prm1/stb1'
foreach ($n in 'prm1', 'stb1') {
    Copy-LabFile $n -Path $tns -Destination '/u01/app/oracle/product/23.0.0/dbhome_1/network/admin/tnsnames.ora'
}

Write-LabStep 'Role-based services orclpdb_rw / orclpdb_ro'
Invoke-LabScript prm1 -Script 'dataguard\role_services.sh'
Start-Sleep 10   # let redo apply bring the procedure/triggers to the standby
Invoke-LabScript stb1 -Script 'dataguard\role_services_apply.sh'

Write-LabStep 'MaxAvailability + Fast-Start Failover'
Invoke-LabScript prm1 -Script 'dataguard\fsfo_enable.sh'

Write-LabStep 'Observer on oem24'
Copy-LabFile oem24 -Path $tns -Destination '/tmp/dg_tnsnames.ora'
Invoke-LabScript oem24 -Script 'dataguard\observer_setup.sh'
Invoke-LabScript oem24 -User root -Script 'dataguard\observer_service_root.sh'
Start-Sleep 30
Invoke-LabScript oem24 -Script 'dataguard\dg_status.sh'
