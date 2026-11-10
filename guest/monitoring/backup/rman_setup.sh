#!/bin/bash
# RMAN settings for the lab (oracle on prm1 or stb1). Idempotent; run again after a role change.
# The primary keeps archive logs until they are applied on the standby and backed up.
# The standby takes no backups, so only the apply condition can apply there. A standby control file
# accepts the deletion policy but not the other settings (RMAN-05021), so those are primary only.
source ~/.bash_profile
export ORACLE_SID=orcl
ROLE=$(sqlplus -s / as sysdba <<'SQL'
set heading off feedback off pages 0
select database_role from v$database;
SQL
)
ROLE=$(echo $ROLE)
echo "role=$ROLE"
if [ "$ROLE" = "PRIMARY" ]; then
  rman target / <<'RMAN'
CONFIGURE RETENTION POLICY TO REDUNDANCY 1;
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY BACKED UP 1 TIMES TO DEVICE TYPE DISK;
SHOW ARCHIVELOG DELETION POLICY;
RMAN
else
  rman target / <<'RMAN'
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
SHOW ARCHIVELOG DELETION POLICY;
RMAN
fi
