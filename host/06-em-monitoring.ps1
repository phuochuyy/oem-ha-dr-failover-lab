# Monitoring as code: Metric Extensions and the incident rule set from config/em/monitoring.
Import-Module (Join-Path $PSScriptRoot 'lab.psm1') -Force
Assert-LabDisk

Initialize-LabNodeEnv oem24
Write-LabStep 'Copy config/em/monitoring to oem24'
$o = Get-LabSshArgs
Invoke-LabSsh oem24 -Command 'rm -rf /tmp/em_monitoring'
scp @o -r -P $LabNodes.oem24.Port (Join-Path $RepoRoot 'config\em\monitoring') 'oracle@127.0.0.1:/tmp/em_monitoring'

Write-LabStep 'FRA relief scripts'
foreach ($n in 'prm1', 'stb1') {
    Invoke-LabSsh $n -Command 'mkdir -p /u01/app/oracle/lab/ca'
    Copy-LabFile $n -Path (Join-Path $RepoRoot 'guest\monitoring\ca\fra_relief.sh') -Destination '/u01/app/oracle/lab/ca/fra_relief.sh'
    Invoke-LabSsh $n -Command "sed -i 's/\r$//' /u01/app/oracle/lab/ca/fra_relief.sh; chmod 750 /u01/app/oracle/lab/ca/fra_relief.sh"
}
Copy-LabFile oem24 -Path (Join-Path $RepoRoot 'guest\monitoring\ca\fra_relief_dispatch.sh') -Destination '/u01/app/oracle/em_notify/fra_relief_dispatch.sh'
Invoke-LabSsh oem24 -Command "sed -i 's/\r$//' /u01/app/oracle/em_notify/fra_relief_dispatch.sh; chmod 750 /u01/app/oracle/em_notify/fra_relief_dispatch.sh"

Write-LabStep 'Metric Extensions and rule set'
Invoke-LabScript oem24 -Script 'monitoring\setup.sh'
