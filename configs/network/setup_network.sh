#!/bin/bash
sudo ip addr add 192.168.50.10/24 dev eth0 2>/dev/null
sudo ip addr add 192.168.50.20/24 dev eth0 2>/dev/null
sudo ip addr add 192.168.50.30/24 dev eth0 2>/dev/null
echo "IPs virtuales configuradas con éxito."