-- ME1 BACKUP_AGE: hours since the last completed database backup. No row on a standby.
-- NVL covers a primary with no backup in its control file, for example right after a failover.
select round(nvl(sysdate - max(j.end_time), 365) * 24, 1) as backup_age_hours
from v$rman_backup_job_details j
right join v$database d on j.status like 'COMPLETED%' and j.input_type in ('DB FULL', 'DB INCR')
where d.database_role = 'PRIMARY'
group by d.dbid
