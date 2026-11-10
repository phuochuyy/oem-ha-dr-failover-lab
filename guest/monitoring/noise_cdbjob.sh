#!/bin/bash
# Stop the EM metric that triggers ORA-600 [ktpStSlTx:!Tmppxid] on the Active Data Guard standby (oracle on oem24).
# cdbjob_status queries CDB_SCHEDULER_JOB_RUN_DETAILS in parallel, which fails on a read-only standby.
# Its collection holds no other metric. Arg1: target (default orcl_stb1). Arg2: DISABLED (default) or ENABLED.
source ~/.bash_profile
TARGET=${1:-orcl_stb1}
STATE=${2:-DISABLED}
EMCLI=/u01/app/oracle/middleware/oms_home/bin/emcli
$EMCLI login -username=sysman -password="$LAB_PWD" >/dev/null 2>&1
$EMCLI sync >/dev/null
$EMCLI modify_collection_schedule -targetType=oracle_database -targetNames="$TARGET" \
  -collectionName=cdbjob_status -collectionStatus="$STATE" -preview=N -force 2>&1 | grep -v '^\s*$' | tail -3
