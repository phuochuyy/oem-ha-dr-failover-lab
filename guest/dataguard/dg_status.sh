#!/bin/bash
# Data Guard status through the observer's wallet (oracle on oem24): works whichever member is primary
export ORACLE_HOME=/u01/app/oracle/product/23.0.0/dbhome_1
export TNS_ADMIN=/u01/app/oracle/dgobs/network
for a in prm1 stb1; do
  out=$($ORACLE_HOME/bin/dgmgrl -silent /@$a "show configuration" 2>/dev/null) || continue
  echo "$out" | grep -vE '^\s*$'
  $ORACLE_HOME/bin/dgmgrl -silent /@$a "show fast_start failover" 2>/dev/null \
    | grep -E 'Fast-Start Failover:|Threshold|Active Target|Observer:|Lag Limit'
  exit 0
done
echo "no Data Guard member reachable"; exit 1
