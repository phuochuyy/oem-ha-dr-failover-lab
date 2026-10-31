#!/bin/bash
# systemd unit for the FSFO observer on oem24 (root)
cat > /etc/systemd/system/dg-observer.service <<'EOF'
[Unit]
Description=Data Guard Fast-Start Failover observer (dgconf)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=oracle
Group=oinstall
ExecStart=/u01/app/oracle/dgobs/start_observer.sh
ExecStop=/bin/bash -c 'ORACLE_HOME=/u01/app/oracle/product/23.0.0/dbhome_1 TNS_ADMIN=/u01/app/oracle/dgobs/network; for a in prm1 stb1; do $ORACLE_HOME/bin/dgmgrl -silent /@$a "stop observer obs_oem24" && break; done'
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now dg-observer.service 2>&1 | tail -1
sleep 20
systemctl is-active dg-observer.service
