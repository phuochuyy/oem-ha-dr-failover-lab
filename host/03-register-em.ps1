# Deploy EM agents to prm1/stb1 and register their databases and listeners as targets.
Import-Module (Join-Path $PSScriptRoot 'lab.psm1') -Force

Write-LabStep 'Agents (emcli submit_add_host)'
Initialize-LabNodeEnv oem24
Invoke-LabScript oem24 -Script 'em\add_hosts.sh'
foreach ($n in 'prm1', 'stb1') {
    Invoke-LabSsh $n -User root -Command '/u01/app/oracle/agent/agent_24.1.0.0.0/root.sh >/dev/null 2>&1; echo root.sh rc=$?'
}

Write-LabStep 'Database + listener targets'
Invoke-LabScript oem24 -Script 'em\add_dg_targets.sh'
Invoke-LabScript oem24 -Script 'em\check_dg.sh'
# Broker DbDisplayName -> EM target names is set at the end of 04-enable-fsfo.ps1 (needs the observer wallet).
