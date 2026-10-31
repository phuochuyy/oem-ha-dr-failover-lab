#!/bin/bash
# Data Guard primary on prm1 (oracle): CDB orcl / PDB orclpdb, archivelog, force logging, flashback,
# standby redo logs, broker, explicit local_listener, DBSNMP unlocked for EM.
source ~/.bash_profile
dbca -silent -createDatabase -templateName General_Purpose.dbc \
  -gdbName orcl.localdomain -sid orcl -responseFile NO_VALUE \
  -characterSet AL32UTF8 -nationalCharacterSet AL16UTF16 \
  -createAsContainerDatabase true -numberOfPDBs 1 -pdbName orclpdb \
  -sysPassword "$LAB_PWD" -systemPassword "$LAB_PWD" -pdbAdminPassword "$LAB_PWD" \
  -databaseType MULTIPURPOSE -automaticMemoryManagement false -totalMemory 2048 \
  -storageType FS -useOMF true -datafileDestination /u01/app/oracle/oradata \
  -enableArchive true -recoveryAreaDestination /u01/app/oracle/fra -recoveryAreaSize 15360 \
  -redoLogFileSize 200 -emConfiguration NONE -sampleSchema false \
  -initParams "db_unique_name=prm1,db_domain=localdomain,sga_target=1536M,pga_aggregate_target=512M,processes=400" \
  2>&1 | grep -E '100%|ERROR|DBT-|Look at'

sqlplus -s / as sysdba <<EOF
whenever sqlerror continue
-- DBCA sets local_listener=LISTENER_ORCL, an alias that will not exist on the standby
alter system set local_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=prm1.localdomain)(PORT=1521))' scope=both;
alter pluggable database orclpdb save state;
alter database force logging;
alter database flashback on;
alter system set standby_file_management=AUTO scope=both;
alter system set log_archive_config='DG_CONFIG=(prm1,stb1)' scope=both;
alter system set dg_broker_start=TRUE scope=both;
-- standby redo logs: online groups + 1, same size (200M)
alter database add standby logfile thread 1 size 200M;
alter database add standby logfile thread 1 size 200M;
alter database add standby logfile thread 1 size 200M;
alter database add standby logfile thread 1 size 200M;
alter user dbsnmp identified by "${LAB_PWD}" account unlock container=all;
alter system register;
set lines 150
col db_unique_name for a10
select db_unique_name, log_mode, force_logging, flashback_on, database_role, open_mode from v\$database;
select count(*) srl_groups from v\$standby_log;
EOF
