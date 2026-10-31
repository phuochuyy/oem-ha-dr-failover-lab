#!/bin/bash
# Silent EM 24.1 install (oracle on oem24). Runs detached; follow /u01/stage/em_install.out.
# The installer's own temp area goes to / (not /u01): its disk check counts /u01 free space
# after extraction and needs ~37 GB there for OMS + instance home.
source ~/.bash_profile
RSP=/u01/stage/em24_new_install.rsp
umask 077
sed "s/\${LAB_PWD}/${LAB_PWD}/g" /tmp/em24_new_install.rsp.tmpl > $RSP
rm -f /tmp/em24_new_install.rsp.tmpl
umask 022
mkdir -p /var/tmp/emtmp && rm -rf /var/tmp/emtmp/*
export TMP=/var/tmp/emtmp TMPDIR=/var/tmp/emtmp
cd /u01/stage/em
nohup ./em24100_linux64.bin -silent -responseFile $RSP -J-Djava.io.tmpdir=/var/tmp/emtmp \
  > /u01/stage/em_install.out 2>&1 < /dev/null &
echo "EM installer started (pid $!)"
