#!/bin/bash
# Listener + EM repository database (oracle on oem24): CDB emcdb / PDB empdb, sized for EM "Small".
source ~/.bash_profile
netca -silent -responsefile $ORACLE_HOME/assistants/netca/netca.rsp | tail -1
dbca -silent -createDatabase -templateName General_Purpose.dbc \
  -gdbName emcdb.localdomain -sid emcdb -responseFile NO_VALUE \
  -characterSet AL32UTF8 -nationalCharacterSet AL16UTF16 \
  -createAsContainerDatabase true -numberOfPDBs 1 -pdbName empdb \
  -sysPassword "$LAB_PWD" -systemPassword "$LAB_PWD" -pdbAdminPassword "$LAB_PWD" \
  -databaseType MULTIPURPOSE -automaticMemoryManagement false -totalMemory 5120 \
  -storageType FS -datafileDestination /u01/app/oracle/oradata \
  -enableArchive false -redoLogFileSize 600 -emConfiguration NONE -sampleSchema false \
  -initParams "sga_target=4G,pga_aggregate_target=1G,shared_pool_size=1G,processes=1000,open_cursors=300,session_cached_cursors=500,job_queue_processes=50,db_securefile=PERMITTED" \
  2>&1 | grep -E '100%|ERROR|DBT-|Look at'

# EM prereq check fails without this hidden parameter (cannot be passed through dbca -initParams)
sqlplus -s / as sysdba <<'EOF'
alter system set "_allow_insert_with_update_check"=TRUE scope=both;
alter pluggable database empdb save state;
EOF
