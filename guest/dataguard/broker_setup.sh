#!/bin/bash
# Data Guard Broker configuration "dgconf" (oracle on prm1)
source ~/.bash_profile
dgmgrl -silent "sys/${LAB_PWD}@prm1" <<'EOF'
create configuration dgconf as primary database is prm1 connect identifier is prm1;
add database stb1 as connect identifier is stb1;
enable configuration;
EOF
sleep 60
dgmgrl -silent "sys/${LAB_PWD}@prm1" "show configuration"
