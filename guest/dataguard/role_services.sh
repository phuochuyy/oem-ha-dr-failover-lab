#!/bin/bash
# Role-based services in PDB orclpdb (oracle on the current primary).
#   orclpdb_rw : runs only where the database is PRIMARY      (applications, read/write)
#   orclpdb_ro : runs only where the database is a STANDBY    (Active Data Guard reporting)
# Definitions and triggers live in the PDB dictionary, so redo carries them to the standby.
source ~/.bash_profile
sqlplus -s / as sysdba <<'EOF'
whenever sqlerror exit failure
-- CDB root: open all PDBs whenever the CDB opens. "save state" only works on the primary, so without
-- this a restarted ADG standby (or a reinstated old primary) comes back with orclpdb MOUNTED.
create or replace trigger sys.lab_open_pdbs after startup on database
begin
  execute immediate 'alter pluggable database all open';
exception
  when others then null;
end;
/

alter session set container = orclpdb;

declare
  procedure ensure(p_name varchar2) is
  begin
    dbms_service.create_service(service_name => p_name, network_name => p_name);
  exception
    when others then
      if sqlcode != -44303 then raise; end if;   -- ORA-44303: service already exists
  end;
begin
  ensure('orclpdb_rw');
  ensure('orclpdb_ro');
end;
/

create or replace procedure sys.lab_role_services authid definer as
  v_role v$database.database_role%type;
  procedure try_start(p varchar2) is begin dbms_service.start_service(p); exception when others then null; end;
  procedure try_stop(p varchar2)  is begin dbms_service.stop_service(p);  exception when others then null; end;
begin
  select database_role into v_role from v$database;
  if v_role = 'PRIMARY' then
    try_start('orclpdb_rw'); try_stop('orclpdb_ro');
  else
    try_start('orclpdb_ro'); try_stop('orclpdb_rw');
  end if;
end;
/

create or replace trigger sys.lab_role_services_startup after startup on database
begin sys.lab_role_services; end;
/

create or replace trigger sys.lab_role_services_rolechg after db_role_change on database
begin sys.lab_role_services; end;
/

exec sys.lab_role_services
alter system register;
EOF
sleep 3
lsnrctl status | grep -iE 'service "orclpdb'
