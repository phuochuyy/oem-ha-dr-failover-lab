-- ME2 LONG_TXN: age in minutes of the oldest active transaction. No row on a standby.
select round(nvl(max((sysdate - t.start_date) * 1440), 0), 1) as oldest_txn_minutes
from v$database d left join v$transaction t on 1 = 1
where d.database_role = 'PRIMARY'
group by d.dbid
