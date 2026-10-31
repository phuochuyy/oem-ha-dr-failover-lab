#!/bin/bash
# Set a standby's broker state (oracle on oem24, observer wallet). Arg1: standby, Arg2: APPLY-ON|APPLY-OFF
export ORACLE_HOME=/u01/app/oracle/product/23.0.0/dbhome_1
export TNS_ADMIN=/u01/app/oracle/dgobs/network
DB=${1:?usage: apply_state.sh <standby> APPLY-ON|APPLY-OFF}; STATE=${2:?}
for a in prm1 stb1; do
  $ORACLE_HOME/bin/dgmgrl -silent /@$a "show configuration" >/dev/null 2>&1 || continue
  $ORACLE_HOME/bin/dgmgrl -silent /@$a "edit database $DB set state='$STATE'" | grep -vE '^\s*$|^Connected'
  exit 0
done
exit 1
