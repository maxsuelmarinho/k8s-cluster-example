#!/usr/bin/env bash

echo "===================================="
echo "Configuring DNS"
echo "===================================="

NETWORK_INTERFACE=/etc/sysconfig/network-scripts/ifcfg-eth0
echo "DNS1=8.8.8.8" >> $NETWORK_INTERFACE
echo "DNS2=8.8.4.4" >> $NETWORK_INTERFACE

NETWORK_INTERFACE=/etc/sysconfig/network-scripts/ifcfg-eth1
echo "DNS1=8.8.8.8" >> $NETWORK_INTERFACE
echo "DNS2=8.8.4.4" >> $NETWORK_INTERFACE

cat /etc/resolv.conf

service network restart

cat /etc/resolv.conf
