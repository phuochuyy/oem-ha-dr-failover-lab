#!/bin/bash
# Root scripts after a software-only install (root)
/u01/app/oraInventory/orainstRoot.sh >/dev/null
/u01/app/oracle/product/23.0.0/dbhome_1/root.sh -silent
ls -l /u01/app/oracle/product/23.0.0/dbhome_1/bin/oracle
