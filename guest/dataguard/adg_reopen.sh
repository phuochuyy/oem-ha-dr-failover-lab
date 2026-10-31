#!/bin/bash
# Re-open a mounted physical standby READ ONLY WITH APPLY (oracle on oem24, observer wallet).
# A reinstated or switched-over standby comes back MOUNTED; Active Data Guard needs it open.
# Arg1: standby name, Arg2: primary name
export ORACLE_HOME=/u01/app/oracle/product/23.0.0/dbhome_1
export TNS_ADMIN=/u01/app/oracle/dgobs/network
STB=${1:?usage: adg_reopen.sh <standby> <primary>}; PRM=${2:?}
MODE=$($ORACLE_HOME/bin/sqlplus -s -L /@$STB as sysdba <<'EOF'
set heading off feedback off pages 0
select open_mode from v$database;
EOF
)
MODE=$(echo $MODE | xargs)
echo "$STB open_mode: $MODE"
if [ "$MODE" = MOUNTED ]; then
  $ORACLE_HOME/bin/dgmgrl -silent /@$PRM "edit database $STB set state='APPLY-OFF'"
  $ORACLE_HOME/bin/sqlplus -s -L /@$STB as sysdba <<'EOF'
alter database open read only;
alter pluggable database all open read only;
EOF
  $ORACLE_HOME/bin/dgmgrl -silent /@$PRM "edit database $STB set state='APPLY-ON'"
fi
$ORACLE_HOME/bin/sqlplus -s -L /@$STB as sysdba <<'EOF'
set heading off feedback off pages 0
select database_role||' / '||open_mode from v$database;
EOF
