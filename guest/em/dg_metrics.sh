#!/bin/bash
# Data Guard related metrics EM collects for database targets, their collection interval and the
# thresholds currently set on orcl_prm1 / orcl_stb1 (oracle on oem24)
source ~/.bash_profile
sqlplus -s "sysman/${LAB_PWD}@oem24.localdomain:1521/empdb.localdomain" <<'EOF'
set lines 200 pages 200 feedback off
col metric_group for a42
col metric_column for a40
col metric_name for a32 noprint
col column_name for a32 noprint
break on metric_group skip 1
prompt === Data Guard metrics for oracle_database
select distinct m.metric_label metric_group, m.column_label metric_column, m.metric_name, m.metric_column column_name
from   mgmt_metrics m
where  m.target_type = 'oracle_database'
and    lower(m.metric_label) like 'data guard%'
and    m.column_label is not null
order  by 1, 2;
clear breaks
col target_name for a10
col metric_name for a26 print
col metric_column for a30
col warning_threshold for a8 heading WARN
col critical_threshold for a8 heading CRIT
col frequency_code for a12 heading FREQ
prompt === Thresholds / collection on the DG targets
select c.target_name, c.metric_name, c.metric_column, c.warning_threshold, c.critical_threshold,
       c.collection_frequency frequency_code
from   mgmt$metric_collection c
where  c.target_name in ('orcl_prm1','orcl_stb1')
and    lower(c.metric_name) like '%dataguard%'
order  by 1, 2, 3;
EOF
