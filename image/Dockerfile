# Imagem única do laboratório: chrony (NTP) + rsyslog (Syslog) + ferramentas de teste
FROM alpine:3.20
RUN apk add --no-cache chrony rsyslog util-linux-misc tcpdump tshark bind-tools procps tzdata \
 && mkdir -p /var/spool/rsyslog /var/lib/chrony /var/log/chrony /run/chrony /pcap
ENTRYPOINT ["/scripts/node-entrypoint.sh"]
