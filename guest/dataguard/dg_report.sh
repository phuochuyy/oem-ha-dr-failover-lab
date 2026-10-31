#!/bin/bash
# Data Guard state for the status report (oracle on oem24, observer wallet). Sections are delimited by
# "### <title>" lines; host/report.ps1 wraps each section in a Markdown code block.
export ORACLE_HOME=/u01/app/oracle/product/23.0.0/dbhome_1
export TNS_ADMIN=/u01/app/oracle/dgobs/network
DG="$ORACLE_HOME/bin/dgmgrl -silent"
SQL="$ORACLE_HOME/bin/sqlplus -s -L"

CONN=""
for a in prm1 stb1; do $DG /@$a "show configuration" >/dev/null 2>&1 && CONN=$a && break; done
[ -z "$CONN" ] && { echo "### Error"; echo "no Data Guard member reachable"; exit 1; }

echo "### Broker configuration"
$DG /@$CONN "show configuration verbose" | grep -vE '^\s*$|^Connected'
echo "### Fast-Start Failover"
$DG /@$CONN "show fast_start failover" | grep -vE '^\s*$|^Connected'
for db in prm1 stb1; do
  echo "### Broker member $db"
  $DG /@$CONN "show database $db" | grep -vE '^\s*$|^Connected'
done

for db in prm1 stb1; do
  echo "### Database $db"
  $SQL /@$db as sysdba <<'EOF' 2>&1
set lines 160 pages 100 feedback off
col db_unique_name for a8
col database_role for a17
col open_mode for a21
col protection_mode for a20
col flashback_on for a6 heading FLASHBK
col force_logging for a7 heading FORCE
select db_unique_name, database_role, open_mode, protection_mode, flashback_on, force_logging from v$database;
col name for a14
col value for a16
col time_computed for a20
select name, value, time_computed from v$dataguard_stats where name in ('transport lag','apply lag','apply finish time');
col con_name for a10
col service for a28
select p.name con_name, s.network_name service
from v$active_services s join v$pdbs p on p.con_id = s.con_id
where s.name like 'orclpdb%' order by 2;
EOF
done

echo "### Application probe (dg_probe via ORCLPDB_RW / ORCLPDB_RO)"
$SQL "system/${LAB_PWD}@ORCLPDB_RW" <<'EOF' 2>&1
set lines 150 pages 100 feedback off
select 'RW served by: '||sys_context('USERENV','DB_UNIQUE_NAME') as rw from dual;
EOF
$SQL "system/${LAB_PWD}@ORCLPDB_RO" <<'EOF' 2>&1
set lines 150 pages 100 feedback off
col note for a32
col written_on for a10
col ts for a28
select 'RO served by: '||sys_context('USERENV','DB_UNIQUE_NAME') as ro from dual;
select count(*) total_rows from dg_probe;
select id, note, written_on, to_char(ts,'YYYY-MM-DD HH24:MI:SS') ts from dg_probe order by id;
EOF

echo "### Observer service (oem24)"
systemctl is-active dg-observer.service
grep -vE '^\s*$' /u01/app/oracle/dgobs/observer.log | grep -E 'Failover succeeded|Initiating|reinstat|Observer .* started|ERROR|ORA-' | tail -10
