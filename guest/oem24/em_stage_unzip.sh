#!/bin/bash
# Unzip the EM 24.1 download parts (V10469xx-01.zip, each wraps one installer file) into /u01/stage/em (oracle)
mkdir -p /u01/stage/em
cd /u01/stage/em
for z in /u01/stage/V10469*-01.zip; do
  unzip -q -o "$z" && rm -f "$z"
done
chmod +x em24100_linux64.bin
ls -l /u01/stage/em
