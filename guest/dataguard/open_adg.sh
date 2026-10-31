#!/bin/bash
# Active Data Guard: open the standby read only with real-time apply (oracle on prm1). Arg1: standby name (default stb1)
source ~/.bash_profile
STB=${1:-stb1}
dgmgrl -silent "sys/${LAB_PWD}@prm1" "edit database ${STB} set state='APPLY-OFF'"
sqlplus -s "sys/${LAB_PWD}@${STB}" as sysdba <<'EOF'
alter database open read only;
alter pluggable database all open read only;
EOF
dgmgrl -silent "sys/${LAB_PWD}@prm1" "edit database ${STB} set state='APPLY-ON'"
sleep 30
sqlplus -s "sys/${LAB_PWD}@${STB}" as sysdba <<'EOF'
set lines 150
col name for a15
col value for a20
select database_role, open_mode from v$database;
select name, value from v$dataguard_stats where name in ('transport lag','apply lag');
EOF
