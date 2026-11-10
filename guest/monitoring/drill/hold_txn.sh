#!/bin/bash
# Keep one transaction open, then roll it back and clean up (oracle on the primary).
# The session ends when the sleep ends, so a drill releases it with: pkill -f '^sleep 3000$'
source ~/.bash_profile
export ORACLE_SID=orcl
{
  echo "alter session set container = orclpdb;"
  echo "create table if not exists system.me_drill (ts timestamp default systimestamp);"
  echo "insert into system.me_drill values (default);"
  sleep 3000
  echo "rollback;"
  echo "drop table system.me_drill purge;"
  echo "exit"
} | sqlplus -s / as sysdba
