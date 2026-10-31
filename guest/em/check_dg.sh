#!/bin/bash
# How EM sees the Data Guard pair: role property per database target and target status (oracle on oem24)
source ~/.bash_profile
sqlplus -s "sysman/${LAB_PWD}@oem24.localdomain:1521/empdb.localdomain" <<'EOF'
set lines 160 pages 50 feedback off
col target_name for a12
col property_value for a20
select target_name, property_value as dataguard_role
from   mgmt$target_properties
where  target_type = 'oracle_database' and property_name = 'DataGuardStatus'
order  by 1;
EOF
/u01/app/oracle/middleware/oms_home/bin/emcli login -username=sysman -password="$LAB_PWD" >/dev/null 2>&1
/u01/app/oracle/middleware/oms_home/bin/emcli get_targets -targets="oracle_database;oracle_pdb;oracle_listener" -noheader
