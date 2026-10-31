#!/bin/bash
# EM view of Data Guard alerting (oracle on oem24): recent incidents, Data Guard lag alert history and the
# OS Command notification log. Arg1: minutes to look back (default 30).
# MGMT$INCIDENTS / MGMT$EVENTS store dates in UTC; alert history uses the agent's local time.
source ~/.bash_profile
MIN=${1:-30}
sqlplus -s "sysman/${LAB_PWD}@oem24.localdomain:1521/empdb.localdomain" <<EOF
set lines 220 pages 100 feedback off
alter session set time_zone = 'Asia/Ho_Chi_Minh';
col target_name for a10
col summary_msg for a70
col severity for a9
col open for 9
col updated for a8
prompt === incidents on orcl_prm1 / orcl_stb1 (last ${MIN} min, local time)
select i.incident_num, t.target_name, i.severity, i.open_status open,
       to_char(from_tz(cast(i.last_updated_date as timestamp), 'UTC') at time zone sessiontimezone, 'HH24:MI:SS') updated,
       substr(i.summary_msg,1,70) summary_msg
from mgmt\$incidents i join mgmt\$target t on t.target_guid = i.target_guid
where t.target_name in ('orcl_prm1','orcl_stb1')
and i.last_updated_date > cast(sys_extract_utc(systimestamp) as date) - ${MIN}/1440
order by i.last_updated_date;
col alert for a8
col message for a80
prompt === Data Guard lag alert history (last ${MIN} min)
select target_name, to_char(collection_timestamp,'HH24:MI:SS') ts, alert_state alert, substr(message,1,80) message
from mgmt\$alert_history
where target_name in ('orcl_prm1','orcl_stb1') and metric_name = 'dataguard_sperf_112'
and collection_timestamp > sysdate - ${MIN}/1440
order by collection_timestamp;
EOF
echo "=== /u01/app/oracle/em_notify/events.log (last 10)"
tail -10 /u01/app/oracle/em_notify/events.log
