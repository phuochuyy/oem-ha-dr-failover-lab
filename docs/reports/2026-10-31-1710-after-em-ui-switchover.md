# Lab status report: after-em-ui-switchover

Generated 2026-10-31 17:10:16 (host time) by `host/report.ps1`.

## Summary

| Item | Value |
|---|---|
| Primary | **stb1** |
| Broker configuration status | SUCCESS   (status updated 47 seconds ago) |
| Fast-Start Failover | Enabled in Zero Data Loss Mode |
| Host RAM free | 0.2 GB |
| Host C: free | 10.6 GB |

## VMs

| VM | State |
|---|---|
| OEM24 | running |
| prm1 | running |
| stb1 | running |

## Data Guard

### Broker configuration

```
Configuration - dgconf
  Protection Mode: MaxAvailability
  Members:
  stb1 - Primary database
    prm1 - (*) Physical standby database
  (*) Fast-Start Failover target
  Properties:
    BystandersFollowRoleChange      = 'ALL'
    CommunicationTimeout            = '180'
    ConfigurationSimpleName         = 'dgconf'
    ConfigurationWideServiceName    = 'orcl_CFG'
    DrainTimeout                    = '0'
    ExternalDestination1            = ''
    ExternalDestination2            = ''
    FastStartFailoverAutoReinstate  = 'TRUE'
    FastStartFailoverLagGraceTime   = '0'
    FastStartFailoverLagLimit       = '0'
    FastStartFailoverLagType        = 'APPLY'
    FastStartFailoverPmyShutdown    = 'TRUE'
    FastStartFailoverThreshold      = '30'
    ObserverOverride                = 'FALSE'
    ObserverPingInterval            = '0'
    ObserverPingRetry               = '0'
    ObserverReconnect               = '0'
    OperationTimeout                = '30'
    PrimaryDatabaseCandidates       = ''
    PrimaryLostWriteAction          = 'CONTINUE'
    TraceLevel                      = 'USER'
Fast-Start Failover: Enabled in Zero Data Loss Mode
  Lag Limit:          0 seconds
  Lag Type:           APPLY
  Threshold:          30 seconds
  Ping Interval:      3000 milliseconds
  Ping Retry:         0
  Active Target:      prm1
  Potential Targets:  "prm1"
    prm1       valid
  Observer:           obs_oem24
  Shutdown Primary:   TRUE
  Auto-reinstate:     TRUE
  Observer Reconnect: (none)
  Observer Override:  FALSE
  Lag Grace Time:     0 seconds
Configuration Status:
SUCCESS   (status updated 47 seconds ago)
```

### Fast-Start Failover

```
Fast-Start Failover: Enabled in Zero Data Loss Mode
  Protection Mode:    MaxAvailability
  Lag Limit:          0 seconds
  Lag Type:           APPLY
  Threshold:          30 seconds
  Ping Interval:      3000 milliseconds
  Ping Retry:         0
  Active Target:      prm1
  Potential Targets:  "prm1"
    prm1       valid
  Observer:           obs_oem24
  Shutdown Primary:   TRUE
  Auto-reinstate:     TRUE
  Observer Reconnect: (none)
  Observer Override:  FALSE
  Lag Grace Time:     0 seconds
Configurable Failover Conditions
  Health Conditions:
    Corrupted Controlfile          YES
    Corrupted Dictionary           YES
    Inaccessible Logfile            NO
    Stuck Archiver                  NO
    Datafile Write Errors          YES
  Oracle Error Conditions:
    (none)
```

### Broker member prm1

```
Database - prm1
  Enterprise Manager Name: orcl_prm1
  Role:                    PHYSICAL STANDBY
  Intended State:          APPLY-ON
  Transport Lag:           0 seconds (computed 1 second ago)
  Apply Lag:               0 seconds (computed 1 second ago)
  Average Apply Rate:      19.00 KByte/s
  Real Time Query:         ON
  Instance(s):
    orcl
Database Status:
SUCCESS
```

### Broker member stb1

```
Database - stb1
  Enterprise Manager Name: orcl_stb1
  Role:                    PRIMARY
  Intended State:          TRANSPORT-ON
  Redo Rate:               717.13 KByte/s  in 15 seconds (computed 8 seconds ago)
  Instance(s):
    orcl
Database Status:
SUCCESS
```

### Database prm1

```

DB_UNIQU DATABASE_ROLE	   OPEN_MODE		 PROTECTION_MODE      FLASHB FORCE
-------- ----------------- --------------------- -------------------- ------ -------
prm1	 PHYSICAL STANDBY  READ ONLY WITH APPLY  MAXIMUM AVAILABILITY YES    YES

NAME	       VALUE		TIME_COMPUTED
-------------- ---------------- --------------------
transport lag  +00 00:00:00	10/31/2026 17:10:26
apply lag      +00 00:00:00	10/31/2026 17:10:26
apply finish t +00 00:00:00.000 10/31/2026 17:10:26
ime


CON_NAME   SERVICE
---------- ----------------------------
ORCLPDB    orclpdb
ORCLPDB    orclpdb_ro
```

### Database stb1

```

DB_UNIQU DATABASE_ROLE	   OPEN_MODE		 PROTECTION_MODE      FLASHB FORCE
-------- ----------------- --------------------- -------------------- ------ -------
stb1	 PRIMARY	   READ WRITE		 MAXIMUM AVAILABILITY YES    YES

CON_NAME   SERVICE
---------- ----------------------------
ORCLPDB    orclpdb
ORCLPDB    orclpdb_rw
```

### Application probe (dg_probe via ORCLPDB_RW / ORCLPDB_RO)

```

RW
------------------------------------------------------------------------------------------------------------------------------------------------------
RW served by: stb1

RO
------------------------------------------------------------------------------------------------------------------------------------------------------
RO served by: prm1

TOTAL_ROWS
----------
	13

	ID NOTE 			    WRITTEN_ON TS
---------- -------------------------------- ---------- ----------------------------
	 1 baseline, FSFO enabled	    prm1       2026-10-31 15:59:58
	 2 baseline, FSFO enabled	    prm1       2026-10-31 16:00:20
	 3 before failover (primary prm1)   prm1       2026-10-31 16:00:51
	21 after failover (primary stb1)    stb1       2026-10-31 16:02:10
	41 reinstated prm1 as standby	    stb1       2026-10-31 16:03:57
	61 after switchback (primary prm1)  prm1       2026-10-31 16:05:55
	62 before failover (primary prm1)   prm1       2026-10-31 16:06:23
	81 after failover (primary stb1)    stb1       2026-10-31 16:07:24
       101 before failover (primary stb1)   stb1       2026-10-31 16:17:00
       121 after failover (primary prm1)    prm1       2026-10-31 16:17:53
       141 after drill			    stb1       2026-10-31 16:20:11
       161 final: primary prm1		    prm1       2026-10-31 16:24:11
       181 after EM UI switchover	    stb1       2026-10-31 17:00:30
```

### Observer service (oem24)

```
active
[W000 2026-10-31T16:17:47.542+07:00] The standby stb1 needs to be reinstated
ORA-12543: TNS:destination host unreachable
ORA-12543: TNS:destination host unreachable
ORA-12543: TNS:destination host unreachable
ORA-12543: TNS:destination host unreachable
[W000 2026-10-31T16:18:38.549+07:00] Wait for new primary to be ready to reinstate.
[W000 2026-10-31T16:18:39.554+07:00] New primary is now ready to reinstate.
Initiating reinstatement for database "stb1"...
[W000 2026-10-31T16:19:00.565+07:00] Successfully reinstated database stb1.
ORA-12537: TNS:connection closed
```

## Enterprise Manager view

```
TARGET_NAME
------------
DATAGUARD_ROLE
----------------------------------------------------------------------------------------------------------------------------------------------------------------
orcl_prm1
Physical Standby
orcl_stb1
Primary
1       Up               oracle_database       orcl_prm1                          
1       Up               oracle_database       orcl_stb1                          
1       Up               oracle_listener       LISTENER_prm1                      
1       Up               oracle_listener       LISTENER_stb1                      
1       Up               oracle_pdb            orcl_prm1_ORCLPDB                  
1       Up               oracle_pdb            orcl_stb1_ORCLPDB                  
1       Up               oracle_pdb            orcl_stb1_CDBROOT                  
1       Up               oracle_pdb            orcl_prm1_CDBROOT                  
```
