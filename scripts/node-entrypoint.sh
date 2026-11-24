#!/bin/sh
# Entrypoint único: o papel do container vem da variável ROLE
mkdir -p /var/spool/rsyslog /var/lib/chrony /var/log/chrony /run/chrony
chown -R chrony:chrony /var/lib/chrony /var/log/chrony /run/chrony 2>/dev/null
# apaga pid de execuções anteriores (senão o chronyd recusa subir após um restart do container)
rm -f /run/chrony/chronyd.pid /var/run/chrony/chronyd.pid
# o chrony só abre o socket de comandos (chronyc clients) se a pasta tiver permissão 750
chmod 750 /run/chrony

# Supervisor: roda o chronyd em primeiro plano; se cair, mostra o erro (docker logs) e reinicia
start_chrony() {
  (
    while true; do
      rm -f /run/chrony/chronyd.pid
      chronyd -n -x -f /etc/chrony/chrony.conf
      echo "[entrypoint] chronyd terminou (codigo $?), reiniciando em 3 s" >&2
      sleep 3
    done
  ) &
}

if [ "$ROLE" = "log-server" ]; then
  # chrony como cliente, para os timestamps do servidor de logs também estarem sincronizados
  start_chrony
  exec rsyslogd -n -f /etc/rsyslog.conf
fi

rsyslogd -f /etc/rsyslog.conf
sleep 1
start_chrony     # chronyd com -x: não altera o relógio do host (containers compartilham o kernel)
logger -t lab -p daemon.notice "container $(hostname) iniciado (papel: $ROLE)"

N=0
while true; do
  T=$(chronyc tracking 2>/dev/null)
  STRATUM=$(echo "$T" | awk '/^Stratum/{print $3}')
  REF=$(echo "$T" | awk '/^Reference ID/{print $5 $6}')
  OFFSET=$(echo "$T" | awk '/^System time/{print $4" "$5" "$6" "$7" "$8}')
  logger -t ntp-check -p daemon.info "stratum=${STRATUM:-n/d} offset='${OFFSET:-n/d}' ref=${REF:-n/d}"
  N=$((N+1))
  # gera eventos de severidades diferentes para a demonstração do Syslog
  [ $((N % 3)) -eq 0 ] && logger -t app-sim -p user.warning "aviso simulado nº $N"
  [ $((N % 6)) -eq 0 ] && logger -t app-sim -p auth.err "falha de login simulada nº $N"
  sleep 10
done
