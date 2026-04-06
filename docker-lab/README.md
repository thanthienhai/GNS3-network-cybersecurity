# GNS3 Cyber Range - Docker Lab

Lightweight cybersecurity simulation lab using Docker containers.

## Quick Start

### 1. Prerequisites

- Docker 24.0+
- Docker Compose 2.20+
- 4-8 GB RAM
- 20 GB disk space

### 2. Start Lab

```bash
cd docker-lab
./quickstart.sh
```

Or manually:

```bash
docker compose up -d
```

### 3. Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Web Server (DMZ) | http://localhost:8080 | - |
| Kibana (SIEM) | http://localhost:5601 | - |
| Elasticsearch | http://localhost:9200 | - |
| Duplicati (Backup) | http://localhost:8200 | - |
| Dozzle (Logs) | http://localhost:8081 | - |

### 4. Run Attack Simulation

```bash
# Option 1: Use script
./security_drill.sh

# Option 2: Manual
docker exec -it attack-kali-linux bash /root/attacks/03_attack_chain.sh
```

## Architecture

```
┌─────────────────────────────────────────┐
│  DMZ Network (172.18.0.0/24)            │
│  ├─ web-server (172.18.0.10)            │
│  └─ mail-server (172.18.0.20)           │
├─────────────────────────────────────────┤
│  SIEM Network (172.19.0.0/24)           │
│  ├─ elasticsearch (172.19.0.10)         │
│  ├─ logstash (172.19.0.11)              │
│  └─ kibana (172.19.0.12)                │
├─────────────────────────────────────────┤
│  Attack Network (172.20.0.0/24)         │
│  └─ kali-linux (172.20.0.100)           │
├─────────────────────────────────────────┤
│  Backup Network (172.21.0.0/24)         │
│  └─ backup-server (172.21.0.10)         │
└─────────────────────────────────────────┘
```

## Commands

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# View logs
docker compose logs -f

# Check status
docker compose ps

# Access Kali
docker exec -it attack-kali-linux bash

# Restart specific service
docker compose restart web-server

# Rebuild containers
docker compose up -d --build
```

## Attack Scripts (in Kali)

- `/root/attacks/01_phishing.sh` - Phishing setup
- `/root/attacks/02_ransomware_sim.sh` - Ransomware simulation (SAFE)
- `/root/attacks/03_attack_chain.sh` - Complete attack chain

## Troubleshooting

### Services not starting
```bash
docker compose down
docker compose up -d
docker compose logs
```

### Can't access web server
```bash
curl http://localhost:8080
docker logs dmz-web-server
```

### ELK not receiving logs
```bash
docker logs siem-logstash
curl http://localhost:9200/_cat/indices?v
```

## Cleanup

```bash
# Stop and remove everything
docker compose down -v

# Remove all lab data
rm -rf web/* mail/* elk/* kali/data/* backup/*
```

## License

Educational purposes only. For security research and learning.
