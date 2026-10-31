#!/bin/bash
# Generate a steady trickle of redo on the primary for N seconds (oracle on oem24), so that apply lag
# grows while apply is stopped. Writes to SYSTEM.DG_REDO_GEN in orclpdb via the ORCLPDB_RW alias.
export ORACLE_HOME=/u01/app/oracle/product/23.0.0/dbhome_1
export TNS_ADMIN=/u01/app/oracle/dgobs/network
SECS=${1:-300}
$ORACLE_HOME/bin/sqlplus -s -L "system/${LAB_PWD}@ORCLPDB_RW" <<EOF
set feedback off serveroutput on
declare
  n number;
  t_end date := sysdate + ${SECS}/86400;
  i number := 0;
begin
  select count(*) into n from user_tables where table_name = 'DG_REDO_GEN';
  if n = 0 then
    execute immediate 'create table dg_redo_gen (ts timestamp default systimestamp, pad varchar2(400))';
  end if;
  while sysdate < t_end loop
    execute immediate 'insert into dg_redo_gen (pad) values (rpad(''x'', 400, ''x''))';
    commit;
    i := i + 1;
    dbms_session.sleep(5);
  end loop;
  execute immediate 'truncate table dg_redo_gen';
  dbms_output.put_line('redo generator done, '||i||' commits');
end;
/
EOF
