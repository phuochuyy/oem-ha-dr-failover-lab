#!/bin/bash
# EM alerting for the Data Guard pair (oracle on oem24). Idempotent. Expects /tmp/DG_Lab_Rules.xml
# (copied from config/em/ by host/05-em-alerting.ps1).
#  1  thresholds + 1-minute collection for Data Guard Performance           (emcli)
#  2  OS Command notification method DG_LAB_LOG -> em_notify/dg_event_log.sh (repository API, see below)
#  3  incident rule set "DG Lab Rules" from the exported XML                 (emcli import_incident_rule_set)
source ~/.bash_profile
EMCLI=/u01/app/oracle/middleware/oms_home/bin/emcli
$EMCLI login -username=sysman -password="$LAB_PWD" >/dev/null 2>&1
$EMCLI sync >/dev/null

echo "== 1 thresholds + collection schedule"
# Data Guard Performance (apply/transport lag) exists only on a target EM classified as a standby when it
# was discovered; the other target answers "Metric Group ... does not exist" and is skipped. Re-run after
# that database has become a standby.
for t in orcl_prm1 orcl_stb1; do
  for col in dg_lag dg_pdl; do      # Apply Lag / Transport Lag (seconds)
    out=$($EMCLI modify_threshold -target_name=$t -target_type=oracle_database -metric=dataguard_sperf_112 \
      -column=$col -warning_threshold=30 -critical_threshold=60 -occurrences=1 -force 2>&1 | grep -v '^\s*$' | tail -1)
    echo "  $t $col: $out"
  done
  # collection item dataguard_11gR2 collects the dataguard_sperf_112 metric group (default every 5 minutes)
  $EMCLI modify_collection_schedule -targetType=oracle_database -targetNames=$t \
    -collectionName=dataguard_11gR2 -freqType=MINUTE -freqValue=1 -preview=N -force 2>&1 | grep -v '^\s*$' | tail -1
done

echo "== 2 notification method DG_LAB_LOG"
# EM 24.1 has no emcli verb for OS Command notification methods; the console page
# (Setup > Notifications > Scripts and SNMP Traps) calls EMD_NOTIFICATION.ADD_PROGRAM_DEVICE.
sqlplus -s "sysman/${LAB_PWD}@oem24.localdomain:1521/empdb.localdomain" <<'EOF'
set serveroutput on feedback off
whenever sqlerror exit failure
declare
  l_cnt number;
begin
  setemusercontext('SYSMAN', mgmt_user.op_set_identifier);
  select count(*) into l_cnt from mgmt_notify_devices where device_name = 'DG_LAB_LOG';
  if l_cnt = 0 then
    emd_notification.add_program_device(
      v_device_name  => 'DG_LAB_LOG',
      v_profile_name => '<SYSTEM>',
      v_program      => '/u01/app/oracle/em_notify/dg_event_log.sh',
      v_description  => 'Log EM events to /u01/app/oracle/em_notify/events.log');
    commit;
    dbms_output.put_line('  created DG_LAB_LOG');
  else
    dbms_output.put_line('  DG_LAB_LOG exists');
  end if;
end;
/
EOF

echo "== 3 incident rule set (import)"
# Imported rule sets come in disabled ("Review it and enable"); enable it explicitly.
$EMCLI import_incident_rule_set -import_file=/tmp/DG_Lab_Rules.xml -overwrite_existing_ruleset 2>&1 | grep -v '^\s*$' | tail -2
$EMCLI modify_incident_rule -action=enable -type=ruleset -rule_set_name="DG Lab Rules" -owner=SYSMAN 2>&1 | grep -v '^\s*$' | tail -1
sqlplus -s "sysman/${LAB_PWD}@oem24.localdomain:1521/empdb.localdomain" <<'EOF'
set lines 200 pages 50 feedback off
col ruleset_name for a14
col rule_name for a18
select s.ruleset_name, s.is_business enterprise, r.rule_name, r.is_enabled,
       nvl(dbms_lob.getlength(r.rl_expression),0) compiled_rl_bytes
from em_rule_sets s join em_rules r on r.ruleset_id = s.ruleset_id where s.ruleset_name = 'DG Lab Rules';
EOF
