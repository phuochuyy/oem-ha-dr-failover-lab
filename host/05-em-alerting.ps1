# EM alerting for the Data Guard pair: notification script on the OMS host, Data Guard lag thresholds,
# OS Command notification method and the "DG Lab Rules" incident rule set (config/em/DG_Lab_Rules.xml).
Import-Module (Join-Path $PSScriptRoot 'lab.psm1') -Force

Initialize-LabNodeEnv oem24
Write-LabStep 'Notification script /u01/app/oracle/em_notify/dg_event_log.sh'
Invoke-LabScript oem24 -Script 'em\notify_script_setup.sh'

Write-LabStep 'Thresholds, notification method, incident rule set'
Copy-LabFile oem24 -Path (Join-Path $RepoRoot 'config\em\DG_Lab_Rules.xml') -Destination '/tmp/DG_Lab_Rules.xml'
Invoke-LabScript oem24 -Script 'em\dg_alerting_setup.sh'
