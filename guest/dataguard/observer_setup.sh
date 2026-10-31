#!/bin/bash
# FSFO observer home on oem24 (oracle). Uses the local 26ai DB home's dgmgrl with its own TNS_ADMIN,
# so the EM repository's network config is untouched. SYS credentials are kept in an auto-login wallet.
source ~/.bash_profile
OBS=/u01/app/oracle/dgobs
mkdir -p $OBS/network $OBS/wallet
cp /tmp/dg_tnsnames.ora $OBS/network/tnsnames.ora
cat > $OBS/network/sqlnet.ora <<EOF
NAMES.DIRECTORY_PATH = (TNSNAMES)
WALLET_LOCATION = (SOURCE = (METHOD = FILE)(METHOD_DATA = (DIRECTORY = $OBS/wallet)))
SQLNET.WALLET_OVERRIDE = TRUE
EOF

WPWD="Wlt_${LAB_PWD}"
if [ ! -f $OBS/wallet/cwallet.sso ]; then
  orapki wallet create -wallet $OBS/wallet -pwd "$WPWD" -auto_login_local >/dev/null
fi
for a in prm1 stb1; do
  mkstore -wrl $OBS/wallet -deleteCredential $a <<<"$WPWD" >/dev/null 2>&1
  mkstore -wrl $OBS/wallet -createCredential $a sys "$LAB_PWD" <<<"$WPWD" >/dev/null
done
chmod 700 $OBS/wallet; chmod 600 $OBS/wallet/*

# Observer launcher: attach through whichever member answers (prm1 may be the one that is down)
cat > $OBS/start_observer.sh <<'EOF'
#!/bin/bash
export ORACLE_HOME=/u01/app/oracle/product/23.0.0/dbhome_1
export TNS_ADMIN=/u01/app/oracle/dgobs/network
OBS=/u01/app/oracle/dgobs
for a in prm1 stb1; do
  if $ORACLE_HOME/bin/dgmgrl -silent /@$a "show configuration" >/dev/null 2>&1; then
    exec $ORACLE_HOME/bin/dgmgrl -silent /@$a \
      "start observer obs_oem24 file is '$OBS/fsfo.dat' logfile is '$OBS/observer.log'"
  fi
done
echo "no Data Guard member reachable" >&2
exit 1
EOF
chmod 750 $OBS/start_observer.sh

export TNS_ADMIN=$OBS/network
dgmgrl -silent /@prm1 "show configuration" | grep -E 'Configuration -|Status|Primary|standby'
