#!/bin/bash
# Listener (static entries for RMAN duplicate + broker) and tnsnames for both members (oracle). Arg1: prm1|stb1
source ~/.bash_profile
NODE=${1:?usage: net_config.sh prm1|stb1}
cat > $ORACLE_HOME/network/admin/listener.ora <<EOF
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE}.localdomain)(PORT = 1521)))
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ${NODE}_DGMGRL.localdomain)
      (ORACLE_HOME = $ORACLE_HOME)
      (SID_NAME = orcl)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = ${NODE}.localdomain)
      (ORACLE_HOME = $ORACLE_HOME)
      (SID_NAME = orcl)
    )
  )
EOF
cp /tmp/dg_tnsnames.ora $ORACLE_HOME/network/admin/tnsnames.ora 2>/dev/null || true
cat > $ORACLE_HOME/network/admin/sqlnet.ora <<'EOF'
NAMES.DIRECTORY_PATH = (TNSNAMES, EZCONNECT)
EOF
lsnrctl stop >/dev/null 2>&1; lsnrctl start | grep -E 'successfully|TNS-'
