#!/bin/bash
# Second NIC on NAT network "oemnet" (root on oem24). NIC1 (NAT, 10.0.2.15) keeps the host port forwards;
# oem24.localdomain stays 10.0.2.15 locally and is 192.168.100.10 for prm1/stb1 (EM ports listen on *).
dev2=$(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | sed -n 2p)
nmcli con show oemnet >/dev/null 2>&1 || \
  nmcli con add type ethernet ifname "$dev2" con-name oemnet ipv4.method manual \
    ipv4.addresses 192.168.100.10/24 ipv4.never-default yes ipv6.method disabled >/dev/null
nmcli con up oemnet >/dev/null
grep -q prm1 /etc/hosts || printf '192.168.100.11  prm1.localdomain  prm1\n192.168.100.12  stb1.localdomain  stb1\n' >> /etc/hosts
ip -4 -br addr | grep -v lo
