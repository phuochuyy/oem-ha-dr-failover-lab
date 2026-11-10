#!/bin/bash
# Set a metric threshold for a drill (oracle on oem24). Args: target metric column warning critical [key_columns].
# A key-based metric needs key_columns. " ;" is the "All others" row, where the FRA corrective action is attached;
# the key "RECOVERY AREA;" would create a separate row without it. Exits 1 if the threshold was not changed.
source ~/.bash_profile
EMCLI=/u01/app/oracle/middleware/oms_home/bin/emcli
$EMCLI login -username=sysman -password="$LAB_PWD" >/dev/null 2>&1
$EMCLI sync >/dev/null
KEY=()
[ -n "$6" ] && KEY=(-key_columns="$6")
OUT=$($EMCLI modify_threshold -target_name="$1" -target_type=oracle_database -metric="$2" -column="$3" "${KEY[@]}" \
  -warning_threshold="$4" -critical_threshold="$5" -occurrences=1 -force 2>&1 | grep -v '^\s*$' | tail -1)
echo "$OUT"
echo "$OUT" | grep -q 'modified successfully'
