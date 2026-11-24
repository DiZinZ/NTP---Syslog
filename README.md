# Laboratório 15 – NTP + Syslog com Docker

CIC1001 A03 – Redes 2. Servidor NTP (chrony), servidor de logs central (rsyslog) e 2 clientes, tudo com `docker compose up -d`.

## Topologia

Rede `labnet` = **172.20.15.0/24** (máscara 255.255.255.0 · rede 172.20.15.0 · broadcast 172.20.15.255 · hosts úteis .1–.254 = 254)

| Container   | IP fixo       | Função                                   | Portas (container → host) |
|-------------|---------------|------------------------------------------|---------------------------|
| (gateway)   | 172.20.15.1   | Gateway da bridge Docker                 | –                         |
| ntp-server  | 172.20.15.10  | chrony (fonte: pool.ntp.br; fallback local stratum 10) | 123/udp → 1123/udp        |
| log-server  | 172.20.15.20  | rsyslog central                          | 514/udp,tcp → 1514       |
| client1     | 172.20.15.31  | cliente NTP + Syslog RFC 3164            | –                         |
| client2     | 172.20.15.32  | cliente NTP + Syslog RFC 5424            | –                         |

Configurações montadas por volume em `config/`. Logs recebidos aparecem em `logs/` no host.

## Pré-requisitos (Windows)
1. Docker Desktop (backend WSL2): https://www.docker.com/products/docker-desktop/
2. Wireshark (opcional, para abrir os `.pcap`): https://www.wireshark.org/download.html

## Subir
```powershell
cd $HOME\Documents\lab-ntp-syslog
docker compose up -d --build
docker compose ps
```

## Testar
Aguarde ~30 s para os clientes sincronizarem.
```powershell
# Servidor: fontes, stratum e offset
docker exec ntp-server chronyc sources -v
docker exec ntp-server chronyc tracking

# Clientes: stratum e offset
docker exec client1 chronyc tracking
docker exec client2 chronyc tracking
docker exec client1 chronyc sources

# O servidor enxerga os clientes
docker exec ntp-server chronyc clients   # lista os clientes (IP, nº de pacotes NTP)

# Syslog: gerar mensagem e ver no servidor central
docker exec client1 logger -t teste -p user.err "mensagem do client1"
docker exec client2 logger -t teste -p user.info "mensagem do client2"
docker exec log-server tail -n 25 /var/log/remote/all.log
docker exec log-server ls -R /var/log/remote
```
Todos os testes de uma vez (Git Bash/WSL): `sh scripts/test.sh`

## Capturar tráfego (gera `pcap/ntp.pcap` e `pcap/syslog.pcap`)
```powershell
docker exec -d ntp-server tcpdump -i eth0 -nn -w /pcap/ntp.pcap udp port 123
docker exec -d log-server tcpdump -i eth0 -nn -w /pcap/syslog.pcap udp port 514
Start-Sleep 30
docker exec ntp-server pkill tcpdump
docker exec log-server pkill tcpdump
# leitura em texto (prints) – campos NTP completos
docker exec ntp-server tshark -r /pcap/ntp.pcap -V -c 2
docker exec log-server tshark -r /pcap/syslog.pcap -V -c 4
```
Abra os `.pcap` no Wireshark e use os filtros `ntp` e `syslog`.

## O que destacar na captura
- **NTP (UDP 123):** pacote *client* (mode 3) e *server* (mode 4); campos Leap Indicator, Version, Stratum, Poll, Precision, Reference ID e os 4 timestamps (Reference, Origin, Receive, Transmit).
- **Syslog (UDP 514):** PRI (`<facility*8+severity>`), formato RFC 3164 (client1) × RFC 5424 (client2: versão, timestamp ISO, hostname, app-name, msgid), texto claro.

## Experimentos extras
- Derrubar o servidor NTP (`docker stop ntp-server`) e ver `chronyc sources` do cliente marcar a fonte como inalcançável; religar com `docker start ntp-server`.
- Ver a correlação de eventos por horário: `docker exec log-server sort /var/log/remote/all.log | tail -30`.
- (Opcional) trocar o rsyslog central por Graylog para busca e dashboards.

## Observações
- Containers compartilham o relógio do host; por isso o chrony roda com `-x` (não altera o relógio) e o offset medido é pequeno.
- A pasta `/run/chrony` precisa ter permissão 750; senão o chrony desativa o socket de comandos e o `chronyc clients` falha.
- As portas do host são 1123 e 1514 para não colidir com o serviço Windows Time.
- Derrubar tudo: `docker compose down`.
