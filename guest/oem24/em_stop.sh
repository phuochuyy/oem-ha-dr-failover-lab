#!/bin/bash
# Stop OMS and the OMS-host agent (oracle on oem24)
/u01/app/oracle/middleware/oms_home/bin/emctl stop oms -all 2>&1 | tail -2
/u01/app/oracle/agent/agent_inst/bin/emctl stop agent 2>&1 | tail -1
