#!/bin/sh
# Captura NTP (UDP 123) no ntp-server e Syslog (UDP 514) no log-server por 30 s -> ./pcap/
docker exec -d ntp-server  tcpdump -i eth0 -nn -w /pcap/ntp.pcap    udp port 123
docker exec -d log-server  tcpdump -i eth0 -nn -w /pcap/syslog.pcap udp port 514
sleep 30
docker exec ntp-server  pkill tcpdump
docker exec log-server  pkill tcpdump
echo "Arquivos em ./pcap: ntp.pcap e syslog.pcap"
