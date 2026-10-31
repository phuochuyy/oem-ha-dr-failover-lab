#!/bin/bash
# Client-side probe (oracle on oem24): write through ORCLPDB_RW, read through ORCLPDB_RO, show which node served each.
# Arg1: note to insert (optional). Uses the observer's TNS_ADMIN (role-service aliases).
export ORACLE_HOME=/u01/app/oracle/product/23.0.0/dbhome_1
export TNS_ADMIN=/u01/app/oracle/dgobs/network
NOTE=${1:-probe}
$ORACLE_HOME/bin/sqlplus -s -L "system/${LAB_PWD}@ORCLPDB_RW" <<EOF
whenever sqlerror continue
set feedback off lines 150
declare n number;
begin
  select count(*) into n from user_tables where table_name = 'DG_PROBE';
  if n = 0 then
    execute immediate 'create table dg_probe (id number generated always as identity, note varchar2(60), ts timestamp default systimestamp, written_on varchar2(30))';
  end if;
end;
/
insert into dg_probe (note, written_on) values ('${NOTE}', sys_context('USERENV','DB_UNIQUE_NAME'));
commit;
select 'RW served by: '||sys_context('USERENV','DB_UNIQUE_NAME') as rw from dual;
EOF
sleep 3
$ORACLE_HOME/bin/sqlplus -s -L "system/${LAB_PWD}@ORCLPDB_RO" <<'EOF'
set feedback off lines 150 pages 50
col note for a30
col written_on for a10
col ts for a28
select 'RO served by: '||sys_context('USERENV','DB_UNIQUE_NAME') as ro from dual;
select id, note, written_on, ts from dg_probe order by id;
EOF
