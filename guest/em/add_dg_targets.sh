#!/bin/bash
# Register the Data Guard databases and listeners as EM targets (oracle on oem24).
# Primary is monitored as DBSNMP; the standby needs SYSDBA while it is not open.
EMCLI=/u01/app/oracle/middleware/oms_home/bin/emcli
OH=/u01/app/oracle/product/23.0.0/dbhome_1
$EMCLI login -username=sysman -password="$LAB_PWD" >/dev/null 2>&1
$EMCLI sync >/dev/null
for NODE in prm1 stb1; do
  if [ $NODE = prm1 ]; then CRED="UserName:dbsnmp;password:${LAB_PWD};Role:Normal"
  else CRED="UserName:sys;password:${LAB_PWD};Role:SYSDBA"; fi
  $EMCLI add_target -name="orcl_${NODE}" -type=oracle_database -host="${NODE}.localdomain" \
    -credentials="$CRED" \
    -properties="SID:orcl;Port:1521;OracleHome:${OH};MachineName:${NODE}.localdomain"
  $EMCLI add_target -name="LISTENER_${NODE}" -type=oracle_listener -host="${NODE}.localdomain" \
    -properties="LsnrName:LISTENER;ListenerOraDir:${OH}/network/admin;Port:1521;OracleHome:${OH};Machine:${NODE}.localdomain"
done
sleep 90
$EMCLI get_targets -targets="oracle_database;oracle_listener;oracle_pdb;host" -noheader
