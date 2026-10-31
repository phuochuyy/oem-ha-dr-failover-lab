#!/bin/bash
# Start the service matching this node's current role (oracle on prm1 or stb1).
# The startup/role-change triggers do this automatically; run it once on the standby after
# role_services.sh, since the standby PDB was already open when the definitions arrived via redo.
source ~/.bash_profile
sqlplus -s / as sysdba <<'EOF'
whenever sqlerror continue
alter pluggable database orclpdb open;
alter session set container = orclpdb;
exec sys.lab_role_services
alter system register;
EOF
sleep 3
lsnrctl status | grep -i 'orclpdb_'
