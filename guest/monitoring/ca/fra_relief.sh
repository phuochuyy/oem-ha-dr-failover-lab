#!/bin/bash
# Corrective action for high non-reclaimable FRA usage (oracle on the database host).
# Backs up archive logs that have no backup yet, outside the FRA, then lets RMAN delete what the deletion
# policy allows: applied on the standby and backed up. Never uses FORCE, so a log that does not meet the
# policy stays. Exits non-zero on failure so the job fails and the incident stays open.
source ~/.bash_profile
export ORACLE_SID=orcl
LOG=/u01/backup/fra_relief.log
exec 9>/tmp/fra_relief.lock
flock -n 9 || { echo "another run is active"; exit 0; }

log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

ROLE=$(sqlplus -s / as sysdba <<'SQL'
set heading off feedback off pages 0
select database_role from v$database;
SQL
)
ROLE=$(echo $ROLE)
[ "$ROLE" = "PRIMARY" ] || { log "role is $ROLE: nothing to do"; exit 0; }

fra_pct() {
  sqlplus -s / as sysdba <<'SQL' | tr -d '[:space:]'
set heading off feedback off pages 0
select round((space_used - space_reclaimable) / space_limit * 100, 2) from v$recovery_file_dest;
SQL
}

log "start, non-reclaimable FRA $(fra_pct)%"
OUT=$(rman target / <<'RMAN'
backup as compressed backupset archivelog all not backed up 1 times format '/u01/backup/arc_%d_%T_%U.bkp';
delete noprompt archivelog all;
RMAN
)
rc=$?
echo "$OUT" >> "$LOG"
# RMAN-08120 and RMAN-08137 are warnings: a log was kept because the deletion policy protects it.
if [ $rc -ne 0 ] || echo "$OUT" | grep -E 'RMAN-[0-9]+|ORA-[0-9]+' | grep -vqE 'RMAN-0?8120|RMAN-0?8137'; then
  log "FAILED, rman rc=$rc, non-reclaimable FRA $(fra_pct)%"
  exit 1
fi
log "done, non-reclaimable FRA $(fra_pct)%"
