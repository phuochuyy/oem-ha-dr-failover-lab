#!/bin/bash
# After EM install (root on oem24): allroot.sh, OMS/agent start after the repository DB, cleanup
/u01/app/oracle/middleware/oms_home/allroot.sh 2>&1 | tail -2

if [ -f /etc/init.d/gcstartup ]; then
  mkdir -p /etc/systemd/system/gcstartup.service.d
  cat > /etc/systemd/system/gcstartup.service.d/after-db.conf <<'EOF'
[Unit]
After=oracle-db.service
Requires=oracle-db.service
EOF
  systemctl daemon-reload
fi

rm -f /u01/stage/em24_new_install.rsp
rm -rf /u01/stage/em /var/tmp/emtmp/* /u01/tmp/*
fstrim -a
df -h / /u01 | tail -2
