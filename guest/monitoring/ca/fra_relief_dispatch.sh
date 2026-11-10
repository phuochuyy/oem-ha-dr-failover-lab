#!/bin/bash
# OS Command notification target for the "FRA relief" incident rule (runs as oracle on the OMS host).
# EM passes the event in environment variables. This submits an EM job that runs fra_relief.sh on the host of
# the alerting database, with the named credential DG_HOST_ORACLE. The job appears in EM with its output.
# A metric corrective action does the same when attached in the console, but that has no emcli verb.
DIR=/u01/app/oracle/em_notify
LOG=$DIR/fra_relief_dispatch.log
EMCLI=/u01/app/oracle/middleware/oms_home/bin/emcli
log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

[ -n "$HOST_NAME" ] || { log "no HOST_NAME in the event: nothing submitted"; exit 0; }
set -a; . /home/oracle/.lab.env; set +a

NAME="FRA_RELIEF_$(date '+%Y%m%d_%H%M%S')"
PROP=$(mktemp "$DIR/job.XXXXXX")
cat > "$PROP" <<EOF
name=$NAME
type=OSCommand
targetType=host
target_list=$HOST_NAME:host
cred.defaultHostCred.$HOST_NAME:host=NAMED:SYSMAN:DG_HOST_ORACLE
variable.default_shell_command=/u01/app/oracle/lab/ca/fra_relief.sh
schedule.frequency=IMMEDIATE
EOF

$EMCLI login -username=sysman -password="$LAB_PWD" >/dev/null 2>&1
$EMCLI sync >/dev/null 2>&1
OUT=$($EMCLI create_job -input_file=property_file:"$PROP" 2>&1 | grep -v '^\s*$' | tail -1)
log "target=$TARGET_NAME host=$HOST_NAME severity=$SEVERITY message=[$MESSAGE] job=$NAME result=[$OUT]"
rm -f "$PROP"
exit 0
