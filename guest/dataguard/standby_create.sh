#!/bin/bash
# Physical standby stb1 from the active primary prm1 (oracle on stb1). orapworcl must already be copied over.
source ~/.bash_profile
mkdir -p /u01/app/oracle/admin/orcl/adump /u01/app/oracle/oradata/STB1/controlfile /u01/app/oracle/fra/STB1/controlfile

cat > $ORACLE_HOME/dbs/initorcl.ora <<'EOF'
db_name=orcl
db_unique_name=stb1
db_domain=localdomain
EOF
sqlplus -s / as sysdba <<'EOF'
startup nomount pfile='?/dbs/initorcl.ora'
EOF

rman target "sys/${LAB_PWD}@prm1" auxiliary "sys/${LAB_PWD}@stb1" <<'EOF'
duplicate target database for standby from active database
  spfile
    set db_unique_name='stb1'
    set control_files='/u01/app/oracle/oradata/STB1/controlfile/control01.ctl','/u01/app/oracle/fra/STB1/controlfile/control02.ctl'
    set local_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=stb1.localdomain)(PORT=1521))'
    set fal_server='prm1'
  dorecover nofilenamecheck;
exit
EOF
rm -f $ORACLE_HOME/dbs/initorcl.ora

sqlplus -s / as sysdba <<'EOF'
alter database flashback on;
alter system set dg_broker_start=TRUE scope=both;
set lines 150
col db_unique_name for a10
select db_unique_name, database_role, open_mode, flashback_on from v$database;
select count(*) srl_groups from v$standby_log;
EOF
