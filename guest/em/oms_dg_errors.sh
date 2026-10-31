#!/bin/bash
# Recent Data Guard related errors in the OMS logs (oracle on oem24). Arg1: minutes to look back (default 30)
MIN=${1:-30}
LOG=/u01/app/oracle/gc_inst/em/EMGC_OMS1/sysman/log
since=$(date -d "-${MIN} min" '+%Y-%m-%d %H:%M')
for f in $(ls -t $LOG/emoms.trc $LOG/emoms.log $LOG/emoms_pbs.trc 2>/dev/null); do
  echo "=== $f"
  awk -v s="$since" 'substr($0,1,16) >= s' "$f" \
    | grep -iE -B2 -A12 'dataguard|data guard|dg_|switchover|DGMGRL|ORA-[0-9]+|Exception' \
    | grep -vE '^\s*$' | tail -60
done
