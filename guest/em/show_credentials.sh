#!/bin/bash
# List named credentials owned by SYSMAN and show the details of one (oracle on oem24). Arg1: credential name (optional)
EMCLI=/u01/app/oracle/middleware/oms_home/bin/emcli
$EMCLI login -username=sysman -password="$LAB_PWD" >/dev/null 2>&1
$EMCLI list_named_credentials
[ -n "$1" ] && $EMCLI get_named_credential -cred_name="$1"
