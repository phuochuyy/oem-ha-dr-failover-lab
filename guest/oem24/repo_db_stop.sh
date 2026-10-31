#!/bin/bash
# Stop the EM repository DB and listener (oracle on oem24)
source ~/.bash_profile
sqlplus -s / as sysdba <<'EOF'
shutdown immediate
EOF
lsnrctl stop | tail -1
