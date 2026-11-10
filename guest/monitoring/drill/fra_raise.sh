#!/bin/bash
# Raise non-reclaimable FRA usage a little with real archive logs that have no backup yet (oracle on the primary).
# Writes about 150 MB of redo, far below the FRA size, so the drill does not fill the host disk.
# Prints: before=<pct> after=<pct>
source ~/.bash_profile
export ORACLE_SID=orcl

fra_pct() {
  sqlplus -s / as sysdba <<'SQL' | tr -d '[:space:]'
set heading off feedback off pages 0
select round((space_used - space_reclaimable) / space_limit * 100, 2) from v$recovery_file_dest;
SQL
}

BEFORE=$(fra_pct)
sqlplus -s / as sysdba >/dev/null <<'SQL'
whenever sqlerror exit failure
alter session set container = orclpdb;
create table if not exists system.me_drill_fra (pad varchar2(4000));
insert into system.me_drill_fra select rpad('x', 4000, 'x') from dual connect by level <= 37000;
commit;
drop table system.me_drill_fra purge;
alter session set container = cdb$root;
alter system archive log current;
alter system archive log current;
SQL
rc=$?
# Wait until the standby has applied the new logs: the deletion policy keeps unapplied logs (RMAN-08120).
for i in $(seq 1 24); do
  UNAPPLIED=$(sqlplus -s / as sysdba <<'SQL' | tr -d '[:space:]'
set heading off feedback off pages 0
select count(*) from v$archived_log where standby_dest = 'YES' and applied = 'NO' and first_time > sysdate - 1/24;
SQL
)
  [ "$UNAPPLIED" = "0" ] && break
  sleep 5
done
[ "$UNAPPLIED" = "0" ] || echo "warning: $UNAPPLIED log(s) not yet applied on the standby"
# arch = archive logs without a backup, the only part the corrective action can remove. The insert also adds
# flashback logs, which stay for db_flashback_retention_target, so after - arch is the floor the relief can reach.
ARCH=$(sqlplus -s / as sysdba <<'SQL' | tr -d '[:space:]'
set heading off feedback off pages 0
select to_char(nvl(sum(percent_space_used - percent_space_reclaimable), 0), 'FM990.00') from v$recovery_area_usage where file_type = 'ARCHIVED LOG';
SQL
)
echo "before=$BEFORE after=$(fra_pct) arch=$ARCH"
exit $rc
