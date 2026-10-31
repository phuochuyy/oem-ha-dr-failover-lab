#!/bin/bash
# Install Oracle AI Database 26ai software only (oracle). Expects the zip in /u01/stage. Run root.sh afterwards.
source ~/.bash_profile
ZIP=${1:-/u01/stage/LINUX.X64_2326100_db_home.zip}
cd $ORACLE_HOME
unzip -q -o "$ZIP" && rm -f "$ZIP"
./runInstaller -silent -waitforcompletion \
  installOption=INSTALL_DB_SWONLY UNIX_GROUP_NAME=oinstall INVENTORY_LOCATION=/u01/app/oraInventory \
  ORACLE_HOME=$ORACLE_HOME ORACLE_BASE=$ORACLE_BASE installEdition=EE \
  OSDBA=dba OSOPER=oper OSBACKUPDBA=backupdba OSDGDBA=dgdba OSKMDBA=kmdba OSRACDBA=racdba \
  executeRootScript=false 2>&1 | grep -E 'Successfully|FATAL|ERROR'
