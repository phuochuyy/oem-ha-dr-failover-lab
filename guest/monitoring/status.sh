#!/bin/bash
# Health monitoring view (oracle on oem24). Prints one '|' separated row per item.
# Arg1: minutes to look back (default 30). Arg2: lines of events.log (default 8).
source ~/.bash_profile
MIN=${1:-30}
LINES_LOG=${2:-8}
sqlplus -s "sysman/${LAB_PWD}@oem24.localdomain:1521/empdb.localdomain" <<SQL
set lines 240 pages 0 feedback off trimspool on
alter session set time_zone = 'Asia/Ho_Chi_Minh';
select 'ALERT|'||target_name||'|'||metric_name||'|'||alert_state||'|'||to_char(collection_timestamp,'HH24:MI:SS')||'|'||substr(message,1,90)
from mgmt\$alert_history
where target_name in ('orcl_prm1','orcl_stb1') and (metric_name like 'ME\$%' or metric_name = 'Recovery_Area')
and collection_timestamp > sysdate - ${MIN}/1440 order by collection_timestamp;
select 'INCIDENT|'||i.incident_num||'|'||t.target_name||'|'||i.severity||'|open='||i.open_status||'|'||
       to_char(from_tz(cast(i.last_updated_date as timestamp), 'UTC') at time zone sessiontimezone, 'HH24:MI:SS')||'|'||substr(i.summary_msg,1,90)
from mgmt\$incidents i join mgmt\$target t on t.target_guid = i.target_guid
where t.target_name in ('orcl_prm1','orcl_stb1')
and i.last_updated_date > cast(sys_extract_utc(systimestamp) as date) - ${MIN}/1440
and (i.summary_msg like '%BACKUP_AGE_HOURS%' or i.summary_msg like '%OLDEST_TXN_MINUTES%' or i.summary_msg like '%Recovery Area%')
order by i.last_updated_date;
SQL
tail -"$LINES_LOG" /u01/app/oracle/em_notify/events.log | sed 's/^/EVENT|/'
sqlplus -s "sysman/${LAB_PWD}@oem24.localdomain:1521/empdb.localdomain" <<'SQL'
set lines 240 pages 0 feedback off trimspool on
select 'CA|'||ca_name||'|'||target_name||'|'||status||'|'||to_char(start_time,'HH24:MI:SS')||'|'||to_char(end_time,'HH24:MI:SS')
from mgmt$ca_executions where ca_name = 'FRA_RELIEF' and start_time > sysdate - 90/1440 order by start_time;
SQL
EMCLI=/u01/app/oracle/middleware/oms_home/bin/emcli
$EMCLI login -username=sysman -password="$LAB_PWD" >/dev/null 2>&1
$EMCLI sync >/dev/null 2>&1
$EMCLI get_jobs -name='FRA_RELIEF_%' -noheader -script 2>/dev/null | awk -F'\t' '{print "JOB|"$0}' | tr '\t' '|'
tail -4 /u01/app/oracle/em_notify/fra_relief_dispatch.log 2>/dev/null | sed 's/^/DISPATCH|/'
