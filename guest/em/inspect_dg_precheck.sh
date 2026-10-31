#!/bin/bash
# Diagnose an NPE in EM's Data Guard switchover pre-checks: show the bytecode calls around a source line
# of oracle.sysman.db.dg.SwitchoverBean.preChecks (oracle on oem24). Arg1: source line (default 1346)
LINE=${1:-1346}
JAVAP=/u01/app/oracle/middleware/oms_home/oracle_common/jdk/bin/javap
JAR=$(find /u01/app/oracle/gc_inst/user_projects/domains/GCDomain/servers/EMGC_OMS1/tmp/_WL_user/emdb \
        -name emDB.jar 2>/dev/null | head -1)
echo "jar: $JAR"
OUT=/tmp/SwitchoverBean.javap
$JAVAP -c -l -p -cp "$JAR" oracle.sysman.db.dg.SwitchoverBean > $OUT
# isolate preChecks method body
awk '/ preChecks\(/ {p=1} p && /^  [^ ].*\(.*\);$/ && !/ preChecks\(/ {p=0} p' $OUT > /tmp/preChecks.javap
echo "preChecks lines: $(wc -l < /tmp/preChecks.javap)"
OFFS=$(grep -E "line ${LINE}: " /tmp/preChecks.javap | awk '{gsub(/;/,"",$3); print $3}' | tr '\n' ' ')
echo "bytecode offsets for line ${LINE}: $OFFS"
NEXT=$(awk -v L="$LINE" '/line [0-9]+: / {gsub(/:/,"",$2); if ($2+0 > L) {gsub(/;/,"",$3); print $3; exit}}' /tmp/preChecks.javap)
FIRST=$(echo $OFFS | awk '{print $1}')
awk -v a="$FIRST" -v b="${NEXT:-999999}" '/^ *[0-9]+: / {split($1,x,":"); n=x[1]+0; if (n>=a-30 && n<b) print}' /tmp/preChecks.javap
echo "--- source lines around ${LINE} (line -> offset)"
grep -E "line (13[0-9][0-9]): " /tmp/preChecks.javap | awk -v L="$LINE" '{gsub(/:/,"",$2); if ($2+0>=L-6 && $2+0<=L+3) print}'
