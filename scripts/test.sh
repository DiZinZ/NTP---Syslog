#!/bin/sh
# Roda a bateria de testes do laboratório (execute no host, com os containers de pé)
set -e
echo "== 1. Servidor NTP: fontes e estado =="
docker exec ntp-server chronyc sources -v
docker exec ntp-server chronyc tracking
echo; echo "== 2. Clientes: stratum e offset =="
for c in client1 client2; do
  echo "--- $c ---"; docker exec $c chronyc sources; docker exec $c chronyc tracking | grep -E "Reference ID|Stratum|System time|Last offset"
done
echo; echo "== 3. Servidor NTP vê os clientes =="
docker exec ntp-server chronyc clients
echo; echo "== 4. Logs centralizados =="
docker exec client1 logger -t teste -p user.err "mensagem de teste do client1"
docker exec client2 logger -t teste -p user.info "mensagem de teste do client2"
sleep 2
docker exec log-server sh -c 'ls -R /var/log/remote; echo; tail -n 20 /var/log/remote/all.log'
