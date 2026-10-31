#!/bin/bash
# OS prep for an Oracle AI Database 26ai node (root). Arg1: ORACLE_SID for the oracle user's profile.
set -e
SID=${1:?usage: os_prep_root.sh <ORACLE_SID>}
dnf -y -q install oracle-ai-database-preinstall-26ai >/dev/null
echo "oracle:${LAB_PWD}" | chpasswd
mkdir -p /u01/app/oraInventory /u01/app/oracle/product/23.0.0/dbhome_1 /u01/app/oracle/oradata \
         /u01/app/oracle/fra /u01/app/oracle/agent /u01/stage /u01/tmp
chown -R oracle:oinstall /u01; chmod -R 775 /u01
mkdir -p /home/oracle/.ssh; cp /root/.ssh/authorized_keys /home/oracle/.ssh/
chown -R oracle:oinstall /home/oracle/.ssh; chmod 700 /home/oracle/.ssh; chmod 600 /home/oracle/.ssh/authorized_keys
grep -q ORACLE_HOME /home/oracle/.bash_profile || cat >> /home/oracle/.bash_profile <<EOF

# Oracle AI Database 26ai lab
export TMP=/u01/tmp TMPDIR=/u01/tmp
export ORACLE_HOSTNAME=\$(hostname -f)
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=\$ORACLE_BASE/product/23.0.0/dbhome_1
export ORACLE_SID=${SID}
export PATH=\$ORACLE_HOME/bin:\$ORACLE_HOME/OPatch:\$PATH
umask 022
EOF
rpm -q oracle-ai-database-preinstall-26ai
