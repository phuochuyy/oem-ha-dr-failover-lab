#!/bin/bash
# Clean stop of a Data Guard node (oracle): EM agent, then DB and listener.
# On the primary, archive the current log first so the standby holds every change before shutdown.
source ~/.bash_profile
/u01/app/oracle/agent/agent_inst/bin/emctl stop agent 2>&1 | tail -1
ROLE=$(sqlplus -s / as sysdba <<'EOF'
set heading off feedback off pages 0
select database_role from v$database;
EOF
)
ROLE=$(echo $ROLE | xargs)
echo "$(hostname -s): role=${ROLE:-down}"
if [ "$ROLE" = PRIMARY ]; then
  sqlplus -s / as sysdba <<'EOF'
alter system archive log current;
EOF
  sleep 10
elif [ -n "$ROLE" ]; then
  sqlplus -s / as sysdba <<'EOF'
set lines 120
col name for a15
col value for a20
select name, value from v$dataguard_stats where name in ('transport lag','apply lag');
EOF
fi
sqlplus -s / as sysdba <<'EOF'
shutdown immediate
EOF
lsnrctl stop | tail -1
