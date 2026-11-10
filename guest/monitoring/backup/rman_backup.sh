#!/bin/bash
# Compressed level 0 backup of the primary into /u01/backup, outside the FRA (oracle on prm1 or stb1).
# Keeps one backup (redundancy 1). Refuses to run on a standby. Arg1: minimum free GB on /u01 (default 8).
source ~/.bash_profile
export ORACLE_SID=orcl
MIN_GB=${1:-8}
ROLE=$(sqlplus -s / as sysdba <<'SQL'
set heading off feedback off pages 0
select database_role from v$database;
SQL
)
ROLE=$(echo $ROLE)
[ "$ROLE" = "PRIMARY" ] || { echo "role is $ROLE, not PRIMARY: no backup taken"; exit 0; }
FREE_GB=$(df -BG --output=avail /u01/backup | tail -1 | tr -dc 0-9)
[ "$FREE_GB" -ge "$MIN_GB" ] || { echo "/u01 has ${FREE_GB} GB free, below ${MIN_GB} GB"; exit 1; }
rman target / <<'RMAN'
run {
  backup as compressed backupset incremental level 0 database format '/u01/backup/db_%d_%T_%U.bkp';
  sql 'alter system archive log current';
  backup as compressed backupset archivelog all not backed up 1 times format '/u01/backup/arc_%d_%T_%U.bkp';
}
delete noprompt obsolete;
list backup of database summary;
RMAN
rc=$?
du -sh /u01/backup
exit $rc
