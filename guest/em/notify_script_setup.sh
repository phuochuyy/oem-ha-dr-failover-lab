#!/bin/bash
# OS Command notification target for EM incident rules (oracle on oem24).
# EM runs the script on the OMS host with event/incident details in environment variables;
# it appends one line per notification to events.log and keeps the full variable set per event.
DIR=/u01/app/oracle/em_notify
mkdir -p $DIR/events
cat > $DIR/dg_event_log.sh <<'EOF'
#!/bin/bash
DIR=/u01/app/oracle/em_notify
ts=$(date '+%Y-%m-%d %H:%M:%S')
printf '%s | %-8s | %-10s | %-22s | %s | incident=%s\n' "$ts" "${SEVERITY:-?}" "${TARGET_NAME:-?}" \
  "${EVENT_TYPE:-${ISSUE_TYPE:-?}}" "${MESSAGE:-?}" "${INCIDENT_ID:-${SEQUENCE_ID:-}}" >> $DIR/events.log
env | grep -E '^[A-Z_]+=' | grep -vE '^(PATH|LD_LIBRARY_PATH|CLASSPATH|HOME|PWD|SHLVL|_)=' | sort \
  > "$DIR/events/$(date '+%Y%m%d-%H%M%S')-$$.env"
exit 0
EOF
chmod 750 $DIR/dg_event_log.sh
touch $DIR/events.log
ls -l $DIR
