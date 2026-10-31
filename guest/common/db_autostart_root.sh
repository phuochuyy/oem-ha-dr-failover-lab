#!/bin/bash
# DB autostart (root): oratab entry + systemd unit running dbstart/dbshut. Arg1: ORACLE_SID.
SID=${1:?usage: db_autostart_root.sh <ORACLE_SID>}
OH=/u01/app/oracle/product/23.0.0/dbhome_1
if grep -q "^${SID}:" /etc/oratab 2>/dev/null; then
  sed -i "s#^${SID}:.*#${SID}:${OH}:Y#" /etc/oratab
else
  echo "${SID}:${OH}:Y" >> /etc/oratab
fi
chown oracle:oinstall /etc/oratab
cat > /etc/systemd/system/oracle-db.service <<EOF
[Unit]
Description=Oracle AI Database 26ai (${SID}) and listener
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=oracle
Group=oinstall
Environment=ORACLE_HOME=${OH}
ExecStart=${OH}/bin/dbstart ${OH}
ExecStop=${OH}/bin/dbshut ${OH}
RemainAfterExit=yes
TimeoutStartSec=600
TimeoutStopSec=600
LimitNOFILE=65536
LimitNPROC=16384
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable oracle-db.service 2>&1 | tail -1
grep "^${SID}:" /etc/oratab
