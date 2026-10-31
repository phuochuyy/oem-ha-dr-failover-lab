#!/bin/bash
# Restart the local database the way dbstart does (plain STARTUP), then show PDB + service state (oracle)
source ~/.bash_profile
sqlplus -s / as sysdba <<'EOF'
shutdown immediate
startup
EOF
sleep 15
sqlplus -s / as sysdba <<'EOF'
set lines 120 heading on feedback off
col name for a10
select database_role, open_mode from v$database;
select name, open_mode from v$pdbs where name = 'ORCLPDB';
EOF
lsnrctl status | grep -i 'orclpdb_'
