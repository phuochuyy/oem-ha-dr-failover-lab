#!/bin/bash
# Planned role change through the broker (oracle on oem24, observer wallet). Arg1: database to become primary.
export ORACLE_HOME=/u01/app/oracle/product/23.0.0/dbhome_1
export TNS_ADMIN=/u01/app/oracle/dgobs/network
TARGET=${1:?usage: switchover.sh prm1|stb1}
$ORACLE_HOME/bin/dgmgrl -silent /@$TARGET <<EOF
validate database ${TARGET};
switchover to ${TARGET};
EOF
