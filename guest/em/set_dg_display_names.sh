#!/bin/bash
# Map broker members to their EM target names (oracle on oem24, observer wallet).
# EM fills DbDisplayName itself when its own wizard builds the configuration; for a DGMGRL-built
# configuration it is '' and EM 24.1's switchover pre-check dies with a NullPointerException
# (SwitchoverBean.preChecks) -> UI shows "Data Guard Internal Error".
export ORACLE_HOME=/u01/app/oracle/product/23.0.0/dbhome_1
export TNS_ADMIN=/u01/app/oracle/dgobs/network
for a in prm1 stb1; do
  $ORACLE_HOME/bin/dgmgrl -silent /@$a "show configuration" >/dev/null 2>&1 || continue
  $ORACLE_HOME/bin/dgmgrl -silent /@$a <<'EOF'
edit database prm1 set property DbDisplayName='orcl_prm1';
edit database stb1 set property DbDisplayName='orcl_stb1';
show database prm1 DbDisplayName;
show database stb1 DbDisplayName;
EOF
  exit 0
done
echo "no Data Guard member reachable"; exit 1
