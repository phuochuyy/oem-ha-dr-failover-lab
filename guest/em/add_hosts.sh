#!/bin/bash
# Push EM 24.1 agents to prm1 and stb1 from the OMS (oracle on oem24). Then run the agent root.sh on each node.
EMCLI=/u01/app/oracle/middleware/oms_home/bin/emcli
$EMCLI login -username=sysman -password="$LAB_PWD" >/dev/null 2>&1
$EMCLI sync >/dev/null
$EMCLI get_named_credential -cred_name=DG_HOST_ORACLE >/dev/null 2>&1 || \
  $EMCLI create_named_credential -cred_name=DG_HOST_ORACLE -auth_target_type=host -cred_type=HostCreds \
    -cred_scope=Global -attributes="HostUserName:oracle;HostPassword:${LAB_PWD}"
# host list separator is ';' (a ',' list is rejected as one invalid host name)
$EMCLI submit_add_host -host_names="prm1.localdomain;stb1.localdomain" -platform=226 \
  -installation_base_directory=/u01/app/oracle/agent -credential_name=DG_HOST_ORACLE \
  -session_name="dg_agents_$(date +%Y%m%d%H%M)" -wait_for_completion
