#!/usr/bin/env bash

echo "===================================="
echo "Configuring DNS"
echo "===================================="

for i in {0..1}
do
    NETWORK_INTERFACE=/etc/sysconfig/network-scripts/ifcfg-eth${i}
    echo "DNS1=8.8.8.8" >> $NETWORK_INTERFACE
    echo "DNS2=8.8.4.4" >> $NETWORK_INTERFACE
done

cat /etc/resolv.conf

service network restart

cat /etc/resolv.conf
