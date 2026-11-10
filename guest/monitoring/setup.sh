#!/bin/bash
# Metric Extensions from config/em/monitoring (oracle on oem24). Idempotent. Expects the config tree in
# /tmp/em_monitoring (copied by host/06-em-monitoring.ps1). Each ME directory is zipped, imported if new,
# saved as a deployable draft, then published. emcli 24.1 has no verb to create or deploy an ME.
source ~/.bash_profile
OMS=/u01/app/oracle/middleware/oms_home
EMCLI=$OMS/bin/emcli
JAR=$OMS/oracle_common/jdk/bin/jar
CFG=/tmp/em_monitoring
$EMCLI login -username=sysman -password="$LAB_PWD" >/dev/null 2>&1
$EMCLI sync >/dev/null

me_status() {   # empty when the ME does not exist
  sqlplus -s "sysman/${LAB_PWD}@oem24.localdomain:1521/empdb.localdomain" <<SQL | tr -d '[:space:]'
set heading off feedback off pages 0
select status from em_mext_versions where name = 'ME\$$1' and version = 1;
SQL
}

for dir in "$CFG"/metric_extensions/*/; do
  n=$(basename "$dir")
  me="ME\$$n"
  echo "== $me"
  if [ -z "$(me_status "$n")" ]; then
    (cd "$dir" && $JAR cMf "/tmp/$n.zip" .)
    $EMCLI import_metric_extension -file_name="/tmp/$n.zip" 2>&1 | grep -v '^\s*$' | tail -2
    rm -f "/tmp/$n.zip"
  fi
  [ "$(me_status "$n")" = "0" ] && $EMCLI save_metric_extension_draft -target_type=oracle_database -name="$me" -version=1 2>&1 | grep -v '^\s*$' | tail -1
  [ "$(me_status "$n")" = "1" ] && $EMCLI publish_metric_extension -target_type=oracle_database -name="$me" -version=1 2>&1 | grep -v '^\s*$' | tail -1
  echo "  status now: $(me_status "$n")"
done

echo "== notification method FRA_RELIEF_DISPATCH"
# No emcli verb for OS Command methods; same repository API as guest/em/dg_alerting_setup.sh.
sqlplus -s "sysman/${LAB_PWD}@oem24.localdomain:1521/empdb.localdomain" <<'SQL'
set serveroutput on feedback off
whenever sqlerror exit failure
declare
  l_cnt number;
begin
  setemusercontext('SYSMAN', mgmt_user.op_set_identifier);
  select count(*) into l_cnt from mgmt_notify_devices where device_name = 'FRA_RELIEF_DISPATCH';
  if l_cnt = 0 then
    emd_notification.add_program_device(
      v_device_name  => 'FRA_RELIEF_DISPATCH',
      v_profile_name => '<SYSTEM>',
      v_program      => '/u01/app/oracle/em_notify/fra_relief_dispatch.sh',
      v_description  => 'Submit the fra_relief.sh job on the host of the alerting database');
    commit;
    dbms_output.put_line('  created FRA_RELIEF_DISPATCH');
  else
    dbms_output.put_line('  FRA_RELIEF_DISPATCH exists');
  end if;
end;
/
SQL

echo "== incident rule set DB Health Rules"
$EMCLI import_incident_rule_set -import_file="$CFG/DB_Health_Rules.xml" -overwrite_existing_ruleset 2>&1 | grep -v '^\s*$' | tail -2
$EMCLI modify_incident_rule -action=enable -type=ruleset -rule_set_name="DB Health Rules" -owner=SYSMAN 2>&1 | grep -v '^\s*$' | tail -1

sqlplus -s "sysman/${LAB_PWD}@oem24.localdomain:1521/empdb.localdomain" <<'SQL'
set lines 180 pages 40 feedback off
col name for a18
col target_name for a12
col ruleset_name for a16
col rule_name for a18
prompt == Metric Extensions on targets (first deployment is done in the console: Deploy To Targets)
select v.name, v.status, t.target_name
from em_mext_versions v left join em_mext_target_assoc a on a.mext_version_id = v.mext_version_id
left join mgmt$target t on t.target_guid = a.target_guid order by 1, 3;
prompt == rule set
select s.ruleset_name, s.is_business enterprise, r.rule_name, r.is_enabled, nvl(dbms_lob.getlength(r.rl_expression), 0) compiled_rl_bytes
from em_rule_sets s join em_rules r on r.ruleset_id = s.ruleset_id where s.ruleset_name = 'DB Health Rules';
SQL

echo "== FRA metric every 5 minutes (default 15)"
for t in orcl_prm1 orcl_stb1; do
  $EMCLI modify_collection_schedule -targetType=oracle_database -targetNames=$t -collectionName=Recovery_Area_18c \
    -freqType=MINUTE -freqValue=5 -preview=N -force 2>&1 | grep 'updated successfully'
done
