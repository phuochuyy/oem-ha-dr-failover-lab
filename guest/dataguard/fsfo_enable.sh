#!/bin/bash
# Fast-Start Failover (oracle on the primary): MaxAvailability (SYNC), 30 s threshold,
# automatic reinstate of the failed primary (needs Flashback Database, already on).
source ~/.bash_profile
dgmgrl -silent "sys/${LAB_PWD}@prm1" <<'EOF'
edit database prm1 set property LogXptMode='SYNC';
edit database stb1 set property LogXptMode='SYNC';
edit configuration set protection mode as maxavailability;
edit database prm1 set property FastStartFailoverTarget='stb1';
edit database stb1 set property FastStartFailoverTarget='prm1';
edit configuration set property FastStartFailoverThreshold=30;
edit configuration set property FastStartFailoverAutoReinstate=TRUE;
edit configuration set property ObserverOverride=FALSE;
enable fast_start failover;
show fast_start failover;
EOF
