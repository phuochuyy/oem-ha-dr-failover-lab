#!/bin/bash
# Show one broker property for both members (oracle on oem24, observer wallet). Arg1: property name
export ORACLE_HOME=/u01/app/oracle/product/23.0.0/dbhome_1
export TNS_ADMIN=/u01/app/oracle/dgobs/network
PROP=${1:?usage: dg_member_property.sh <property>}
for db in prm1 stb1; do
  $ORACLE_HOME/bin/dgmgrl -silent /@prm1 "show database $db '$PROP'" 2>&1 | grep -vE '^\s*$|^Connected'
done
