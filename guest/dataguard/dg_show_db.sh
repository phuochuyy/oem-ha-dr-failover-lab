#!/bin/bash
# Broker view of one member (oracle on oem24, observer wallet). Arg1: member name
export ORACLE_HOME=/u01/app/oracle/product/23.0.0/dbhome_1
export TNS_ADMIN=/u01/app/oracle/dgobs/network
DB=${1:?usage: dg_show_db.sh prm1|stb1}
for a in prm1 stb1; do
  $ORACLE_HOME/bin/dgmgrl -silent /@$a "show database $DB" 2>/dev/null | grep -vE '^\s*$' && exit 0
done
exit 1
