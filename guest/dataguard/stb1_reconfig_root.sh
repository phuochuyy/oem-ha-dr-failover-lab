#!/bin/bash
# Turn a linked clone of prm1 into stb1 (root): hostname, IP, machine-id, SSH host keys, then reboot.
# Run while prm1 is powered off (the clone boots with prm1's IP).
set -e
hostnamectl set-hostname stb1.localdomain
con=$(nmcli -t -f NAME,TYPE con show | grep ethernet | head -1 | cut -d: -f1)
nmcli con mod "$con" ipv4.addresses 192.168.100.12/24
rm -f /etc/machine-id && systemd-machine-id-setup >/dev/null
rm -f /etc/ssh/ssh_host_* && ssh-keygen -A >/dev/null
sync
nohup bash -c 'sleep 2; systemctl reboot' >/dev/null 2>&1 &
