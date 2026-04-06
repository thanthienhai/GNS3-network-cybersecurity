<br>

# **13 - Docker-based Lab Implementation**

<br>

## **13.1 Giới thiệu**

Chương này hướng dẫn cách **containerize toàn bộ services** sử dụng Docker và Docker Compose thay vì VM truyền thống. Phương pháp này giúp:

✅ **Tiết kiệm tài nguyên:** 2-4GB RAM thay vì 16-32GB
✅ **Khởi động nhanh:** Vài giây thay vì vài phút
✅ **Dễ sao lưu:** Chỉ cần backup docker-compose.yml và volumes
✅ **Portable:** Chạy trên bất kỳ hệ thống nào có Docker
✅ **Thực tế:** Sử dụng services thật thay vì giả lập

### **Kiến trúc tổng quan**

```
┌─────────────────────────────────────────────────────────────────┐
│                        GNS3 Topology                             │
│                                                                  │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐       │
│  │   EDGE-R3   │────▶│  FW-OPNS    │────▶│ DIST-SW1    │       │
│  │   (Cisco)   │     │  (VM/Physical)│   │  (Cisco)    │       │
│  └─────────────┘     └──────┬──────┘     └──────┬──────┘       │
│                              │                   │               │
│                              │          ┌────────┴────────┐     │
│                              │          │   Docker Host   │     │
│                              │          │   (Linux/WSL2)  │     │
│                              │          │                 │     │
│                              │          │ ┌─────────────┐ │     │
│                              └─────────▶│ │ Docker Net  │ │     │
│                                         │ │ 172.18.0.0/24│ │     │
│                                         │ │               │ │     │
│                                         │ │ ┌─────┐┌────┐│ │     │
│                                         │ │ │Web  ││Mail││ │     │
│                                         │ │ │DMZ  ││DMZ ││ │     │
│                                         │ │ └─────┘└────┘│ │     │
│                                         │ │ ┌─────┐┌────┐│ │     │
│                                         │ │ │ELK  ││Kali││ │     │
│                                         │ │ │SIEM ││Atk ││ │     │
│                                         │ │ └─────┘└────┘│ │     │
│                                         │ └───────────────┘ │     │
│                                         └───────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```


<br>

---

<br>

## **13.2 Chuẩn bị môi trường**

### **Yêu cầu hệ thống**

| **Thành phần** | **Yêu cầu** |
|----------------|-------------|
| OS | Linux (Ubuntu 22.04+) hoặc Windows 11 + WSL2 |
| RAM | 8 GB (tối thiểu 4 GB) |
| CPU | 4 cores |
| Storage | 50 GB SSD |
| Docker | Version 24.0+ |
| Docker Compose | Version 2.20+ |

### **Bước 1: Cài đặt Docker**

#### **Trên Ubuntu/Debian:**

```bash
#!/bin/bash
# File: setup_docker.sh

echo "=== Installing Docker on Ubuntu ==="

# Remove old versions
sudo apt-get remove docker docker-engine docker.io containerd runc -y

# Update package index
sudo apt-get update -y

# Install prerequisites
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Enable Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Verify installation
docker --version
docker compose version

echo ""
echo "[+] Docker installed successfully!"
echo "    Logout and login again to use docker without sudo"
```

#### **Trên Windows 11 với WSL2:**

```powershell
# 1. Enable WSL2
wsl --install -d Ubuntu
wsl --set-default-version 2

# 2. Cài Docker Desktop từ:
# https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe

# 3. Trong Docker Desktop Settings:
# - Settings → General → ✓ Use WSL 2 instead of Hyper-V
# - Settings → Resources → WSL Integration → ✓ Enable Ubuntu

# 4. Verify trong WSL:
docker --version
docker compose version
```

### **Bước 2: Tạo thư mục project**

```bash
# Tạo cấu trúc thư mục
mkdir -p ~/gns3-docker-lab/{web,mail,elk,kali,backup,networks}
cd ~/gns3-docker-lab

# Tạo các file cấu hình
touch docker-compose.yml
touch .env
```


<br>

---

<br>

## **13.3 Docker Compose Configuration**

### **File docker-compose.yml hoàn chỉnh**

```yaml
version: '3.8'

services:
  # ============================================
  # DMZ ZONE - Public Facing Services
  # ============================================
  
  # Web Server (Apache + PHP)
  web-server:
    image: httpd:2.4-alpine
    container_name: dmz-web-server
    restart: unless-stopped
    networks:
      dmz:
        ipv4_address: 172.18.0.10
    ports:
      - "8080:80"
      - "8443:443"
    volumes:
      - ./web/www:/usr/local/apache2/htdocs
      - ./web/logs:/usr/local/apache2/logs
    environment:
      - SERVER_NAME=infracorp.local
    depends_on:
      - mail-server
    labels:
      - "zone=dmz"
      - "service=web"

  # Mail Server (Postfix + Dovecot)
  mail-server:
    image: docker-mailserver/docker-mailserver:latest
    container_name: dmz-mail-server
    restart: unless-stopped
    networks:
      dmz:
        ipv4_address: 172.18.0.20
    ports:
      - "25:25"      # SMTP
      - "587:587"    # Submission
      - "143:143"    # IMAP
      - "993:993"    # IMAPS
    environment:
      - OVERRIDES=sasl,smtp
      - POSTMASTER_ADDRESS=postmaster@infracorp.local
      - SSL_TYPE=manual
      - SSL_CERT_PATH=/etc/ssl/mail/cert.pem
      - SSL_KEY_PATH=/etc/ssl/mail/key.pem
    volumes:
      - ./mail/data:/var/mail
      - ./mail/state:/var/mail-state
      - ./mail/logs:/var/log/mail
      - ./mail/config:/tmp/docker-mailserver
      - ./mail/ssl:/etc/ssl/mail:ro
    hostname: mail
    domainname: infracorp.local
    labels:
      - "zone=dmz"
      - "service=mail"

  # ============================================
  # SIEM ZONE - ELK Stack
  # ============================================
  
  # Elasticsearch
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.1
    container_name: siem-elasticsearch
    restart: unless-stopped
    networks:
      siem:
        ipv4_address: 172.19.0.10
    environment:
      - node.name=elk-siem
      - cluster.name=gns3-siem
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - xpack.security.enabled=false
      - xpack.security.enrollment.enabled=false
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - ./elk/elasticsearch/data:/usr/share/elasticsearch/data
      - ./elk/elasticsearch/logs:/usr/share/elasticsearch/logs
    ports:
      - "9200:9200"
      - "9300:9300"
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:9200 | grep -q 'number'"]
      interval: 30s
      timeout: 10s
      retries: 5
    labels:
      - "zone=siem"
      - "service=elasticsearch"

  # Logstash
  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.1
    container_name: siem-logstash
    restart: unless-stopped
    networks:
      siem:
        ipv4_address: 172.19.0.11
    environment:
      - "LS_JAVA_OPTS=-Xmx512m -Xms512m"
    volumes:
      - ./elk/logstash/pipeline:/usr/share/logstash/pipeline:ro
      - ./elk/logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
      - ./elk/logstash/logs:/usr/share/logstash/logs
    ports:
      - "5514:5514/udp"   # Syslog
      - "5000:5000"       # TCP JSON
      - "5044:5044"       # Beats
    depends_on:
      elasticsearch:
        condition: service_healthy
    labels:
      - "zone=siem"
      - "service=logstash"

  # Kibana
  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.1
    container_name: siem-kibana
    restart: unless-stopped
    networks:
      siem:
        ipv4_address: 172.19.0.12
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - xpack.security.enabled=false
      - xpack.encryptedSavedObjects.encryptionKey=your-encryption-key-32-chars-min
    volumes:
      - ./elk/kibana/data:/usr/share/kibana/data
      - ./elk/kibana/logs:/usr/share/kibana/logs
    ports:
      - "5601:5601"
    depends_on:
      elasticsearch:
        condition: service_healthy
    labels:
      - "zone=siem"
      - "service=kibana"

  # Filebeat (thu thập log từ các services)
  filebeat:
    image: docker.elastic.co/beats/filebeat:8.11.1
    container_name: siem-filebeat
    restart: unless-stopped
    networks:
      siem:
        ipv4_address: 172.19.0.13
    user: root
    volumes:
      - ./elk/filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./elk/filebeat/logs:/usr/share/filebeat/logs
    depends_on:
      logstash:
        condition: service_started
    labels:
      - "zone=siem"
      - "service=filebeat"

  # ============================================
  # KALI LINUX - Attack Platform
  # ============================================
  
  kali-linux:
    image: kalilinux/kali-rolling:latest
    container_name: attack-kali-linux
    restart: unless-stopped
    networks:
      attack:
        ipv4_address: 172.20.0.100
    privileged: true
    environment:
      - DISPLAY=:0
      - TERM=xterm-256color
    volumes:
      - ./kali/scripts:/root/attacks:ro
      - ./kali/data:/root/data
      - ./kali/logs:/var/log/kali
    stdin_open: true
    tty: true
    cap_add:
      - NET_ADMIN
      - NET_RAW
      - SYS_ADMIN
    labels:
      - "zone=attack"
      - "service=kali"

  # ============================================
  # BACKUP ZONE - Air-gapped Backup
  # ============================================
  
  backup-server:
    image: linuxserver/duplicati:latest
    container_name: backup-duplicati
    restart: unless-stopped
    networks:
      backup:
        ipv4_address: 172.21.0.10
    ports:
      - "8200:8200"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=UTC
    volumes:
      - ./backup/config:/config
      - ./backup/backups:/backups
      - ./backup/source:/source
    labels:
      - "zone=backup"
      - "service=duplicati"

  # ============================================
  # MONITORING & UTILITIES
  # ============================================
  
  # Network monitoring
  netdata:
    image: netdata/netdata:latest
    container_name: monitoring-netdata
    restart: unless-stopped
    networks:
      - siem
    ports:
      - "19999:19999"
    cap_add:
      - SYS_PTRACE
      - SYS_ADMIN
    volumes:
      - ./monitoring/netdata/config:/etc/netdata
      - ./monitoring/netdata/logs:/var/log/netdata
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    labels:
      - "zone=monitoring"
      - "service=netdata"

  # Log aggregator
  dozzle:
    image: amir20/dozzle:latest
    container_name: monitoring-dozzle
    restart: unless-stopped
    networks:
      - siem
    ports:
      - "8081:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - DOZZLE_LEVEL=info
    labels:
      - "zone=monitoring"
      - "service=dozzle"

# ============================================
# NETWORKS DEFINITION
# ============================================

networks:
  dmz:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.18.0.0/24
          gateway: 172.18.0.1
  
  siem:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.19.0.0/24
          gateway: 172.19.0.1
  
  attack:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.20.0.0/24
          gateway: 172.20.0.1
  
  backup:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.21.0.0/24
          gateway: 172.21.0.1
```

### **File .env cấu hình**

```bash
# File: .env

# Project Settings
PROJECT_NAME=gns3-cyber-lab
COMPOSE_PROJECT_NAME=gns3lab

# Network Configuration
DMZ_SUBNET=172.18.0.0/24
SIEM_SUBNET=172.19.0.0/24
ATTACK_SUBNET=172.20.0.0/24
BACKUP_SUBNET=172.21.0.0/24

# ELK Stack Settings
ELK_VERSION=8.11.1
ES_HEAP_SIZE=1g
LS_HEAP_SIZE=512m

# Mail Server Settings
MAIL_DOMAIN=infracorp.local
POSTMASTER=postmaster@infracorp.local

# Security
ENCRYPTION_KEY=change-this-to-random-32-char-string
```


<br>

---

<br>

## **13.4 Cấu hình chi tiết các services**

### **A. Web Server Configuration**

```bash
# Tạo thư mục
mkdir -p ~/gns3-docker-lab/web/{www,logs}

# Tạo website mẫu
cat > ~/gns3-docker-lab/web/www/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Infracorp Employee Portal</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .login-container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            width: 100%;
            max-width: 400px;
        }
        .logo {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo h1 {
            color: #333;
            font-size: 28px;
        }
        .logo p {
            color: #666;
            font-size: 14px;
            margin-top: 5px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        .form-group label {
            display: block;
            margin-bottom: 8px;
            color: #333;
            font-weight: 500;
        }
        .form-group input {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e1e1e1;
            border-radius: 5px;
            font-size: 14px;
            transition: border-color 0.3s;
        }
        .form-group input:focus {
            outline: none;
            border-color: #667eea;
        }
        .btn-login {
            width: 100%;
            padding: 12px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 5px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s;
        }
        .btn-login:hover {
            transform: translateY(-2px);
        }
        .footer {
            text-align: center;
            margin-top: 20px;
            color: #999;
            font-size: 12px;
        }
        .alert {
            background: #fee;
            border-left: 4px solid #f44;
            padding: 10px 15px;
            margin-bottom: 20px;
            border-radius: 3px;
            display: none;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="logo">
            <h1>🔐 Infracorp</h1>
            <p>Employee Portal</p>
        </div>
        
        <div class="alert" id="alert">
            ⚠️ This is a security simulation lab!
        </div>
        
        <form action="/login.php" method="POST" id="loginForm">
            <div class="form-group">
                <label for="username">Username</label>
                <input type="text" id="username" name="username" 
                       placeholder="Enter your username" required>
            </div>
            <div class="form-group">
                <label for="password">Password</label>
                <input type="password" id="password" name="password" 
                       placeholder="Enter your password" required>
            </div>
            <button type="submit" class="btn-login">Sign In</button>
        </form>
        
        <div class="footer">
            <p>© 2024 Infracorp. All rights reserved.</p>
            <p>Authorized personnel only.</p>
        </div>
    </div>
    
    <script>
        // Show security notice
        document.getElementById('alert').style.display = 'block';
        
        // Log form submission (for simulation)
        document.getElementById('loginForm').addEventListener('submit', function(e) {
            console.log('Login attempt:', {
                username: document.getElementById('username').value,
                timestamp: new Date().toISOString()
            });
        });
    </script>
</body>
</html>
EOF

# Tạo login.php để log credentials
cat > ~/gns3-docker-lab/web/www/login.php << 'EOF'
<?php
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $username = htmlspecialchars($_POST['username']);
    $password = htmlspecialchars($_POST['password']);
    $timestamp = date('Y-m-d H:i:s');
    
    // Log the attempt
    $log_entry = "[$timestamp] LOGIN ATTEMPT - User: $username, Pass: $password\n";
    file_put_contents('/usr/local/apache2/logs/login_attempts.log', $log_entry, FILE_APPEND);
    
    // Redirect to "failed" page
    header("Location: /failed.html");
    exit();
}
?>
EOF

# Tạo failed.html
cat > ~/gns3-docker-lab/web/www/failed.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Login Failed - Infracorp</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: #f5f5f5;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
        }
        .error-box {
            background: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            text-align: center;
        }
        .error-icon {
            font-size: 48px;
            color: #f44;
            margin-bottom: 20px;
        }
        h1 { color: #f44; }
        p { color: #666; margin: 20px 0; }
        a {
            color: #667eea;
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="error-box">
        <div class="error-icon">❌</div>
        <h1>Login Failed</h1>
        <p>Invalid username or password.</p>
        <p><a href="/index.html">← Back to login</a></p>
    </div>
</body>
</html>
EOF
```

### **B. Mail Server Configuration**

```bash
# Tạo thư mục
mkdir -p ~/gns3-docker-lab/mail/{data,state,logs,config,ssl}

# Tạo self-signed SSL certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ~/gns3-docker-lab/mail/ssl/key.pem \
    -out ~/gns3-docker-lab/mail/ssl/cert.pem \
    -subj "/C=VN/ST=Hanoi/L=Hanoi/O=Infracorp/CN=mail.infracorp.local"

# Tạo file cấu hình mail
cat > ~/gns3-docker-lab/mail/config/postfix-accounts.cf << 'EOF'
finance.user@infracorp.local|{SHA512-CRYPT}$6$rounds=5000$salt$hashedpassword
sales.user@infracorp.local|{SHA512-CRYPT}$6$rounds=5000$salt$hashedpassword
EOF

# Script tạo users
cat > ~/gns3-docker-lab/mail/create_users.sh << 'EOF'
#!/bin/bash
docker exec dmz-mail-server setup email add finance.user@infracorp.local P@ssw0rd123!
docker exec dmz-mail-server setup email add sales.user@infracorp.local P@ssw0rd123!
echo "Users created!"
EOF
chmod +x ~/gns3-docker-lab/mail/create_users.sh
```

### **C. ELK Stack Configuration**

```bash
# Tạo thư mục
mkdir -p ~/gns3-docker-lab/elk/{elasticsearch,data,logs}
mkdir -p ~/gns3-docker-lab/elk/logstash/{pipeline,config,logs}
mkdir -p ~/gns3-docker-lab/elk/kibana/{data,logs}
mkdir -p ~/gns3-docker-lab/elk/filebeat/{logs}

# Logstash pipeline configuration
cat > ~/gns3-docker-lab/elk/logstash/pipeline/security.conf << 'EOF'
input {
  # Syslog từ network devices (OPNsense, switches)
  syslog {
    port => 5514
    type => "syslog"
  }
  
  # Firewall logs qua TCP
  tcp {
    port => 5000
    codec => json
    type => "firewall"
  }
  
  # Beats input (Filebeat)
  beats {
    port => 5044
    type => "beats"
  }
  
  # HTTP input cho web logs
  http {
    port => 8082
    codec => json
    type => "web"
  }
}

filter {
  # Parse syslog
  if [type] == "syslog" {
    grok {
      match => { 
        "message" => "%{SYSLOGPRI}%{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:syslog_hostname} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:syslog_message}" 
      }
    }
    date {
      match => [ "syslog_timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
      target => "@timestamp"
    }
  }
  
  # Parse firewall blocks
  if [type] == "firewall" {
    grok {
      match => { 
        "message" => "BLOCK %{IP:src_ip}:%{NUMBER:src_port} -> %{IP:dst_ip}:%{NUMBER:dst_port} %{DATA:protocol}" 
      }
    }
  }
  
  # Detect failed logins
  if [syslog_message] =~ /Failed password/ {
    mutate {
      add_tag => ["failed_login", "security_alert"]
      add_field => { "severity" => "high" }
    }
  }
  
  # Detect port scans
  if [syslog_message] =~ /[Pp]ort [Ss]can/ {
    mutate {
      add_tag => ["port_scan", "reconnaissance"]
      add_field => { "severity" => "medium" }
    }
  }
  
  # Detect ransomware patterns
  if [message] =~ /\.encrypted/ or [message] =~ /ransom/ {
    mutate {
      add_tag => ["ransomware", "critical"]
      add_field => { "severity" => "critical" }
    }
  }
  
  # Detect phishing
  if [message] =~ /[Pp]hishing/ or [message] =~ /suspicious.*email/ {
    mutate {
      add_tag => ["phishing", "social_engineering"]
      add_field => { "severity" => "high" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "security-events-%{+YYYY.MM.dd}"
  }
  
  # Debug output (có thể disable trong production)
  stdout { 
    codec => rubydebug 
  }
}
EOF

# Logstash config
cat > ~/gns3-docker-lab/elk/logstash/config/logstash.yml << 'EOF'
http.host: "0.0.0.0"
xpack.monitoring.elasticsearch.hosts: [ "http://elasticsearch:9200" ]
config.reload.automatic: true
config.reload.interval: 3s
EOF

# Filebeat configuration
cat > ~/gns3-docker-lab/elk/filebeat/filebeat.yml << 'EOF'
filebeat.inputs:
  - type: container
    paths:
      - /var/lib/docker/containers/*/*.log
    processors:
      - add_kubernetes_metadata:
          host: ${NODE_NAME}
          matchers:
            - logs_path:
                logs_path: "/var/lib/docker/containers/"

# Gửi logs đến Logstash
output.logstash:
  hosts: ["logstash:5044"]

# Dashboard monitoring
monitoring:
  enabled: true
  elasticsearch:
    hosts: ["http://elasticsearch:9200"]
EOF
```

### **D. Kali Linux Attack Scripts**

```bash
# Tạo thư mục
mkdir -p ~/gns3-docker-lab/kali/{scripts,data,logs}

# Script cài đặt tools trong Kali
cat > ~/gns3-docker-lab/kali/scripts/setup_kali.sh << 'EOF'
#!/bin/bash
echo "=== Setting up Kali Linux Attack Tools ==="

# Update
apt update && apt upgrade -y

# Install phishing tools
apt install -y setoolkit gophish

# Install reconnaissance tools
apt install -y nmap netcat whois dnsutils

# Install password attacks
apt install -y hydra john hashcap

# Install web attack tools
apt install -y nikto sqlmap gobuster

# Install lateral movement
apt install -y impacket-scripts crackmapexec

echo "[+] All tools installed!"
EOF

# Phishing script
cat > ~/gns3-docker-lab/kali/scripts/01_phishing.sh << 'EOF'
#!/bin/bash
echo "=========================================="
echo "  PHISHING ATTACK SIMULATION"
echo "=========================================="

# Check if running in Docker
if [ ! -f /.dockerenv ]; then
    echo "⚠️  This script should run inside Kali container"
    echo "   Usage: docker exec -it attack-kali-linux bash /root/attacks/01_phishing.sh"
    exit 1
fi

echo ""
echo "[*] Target: finance.user@infracorp.local"
echo "[*] Lure: Urgent password reset required"
echo "[*] Landing page: http://172.18.0.10/index.html"
echo ""

# Start phishing tools setup
echo "[*] Installing phishing tools..."
apt update && apt install -y gophish

echo ""
echo "[+] Gophish installed!"
echo "    Access: http://localhost:3333"
echo "    Login: admin / gophish"
echo ""
echo "Next steps:"
echo "1. Access Gophish UI"
echo "2. Import email template"
echo "3. Create campaign targeting finance.user"
EOF

# Ransomware simulation (SAFE)
cat > ~/gns3-docker-lab/kali/scripts/02_ransomware_sim.sh << 'EOF'
#!/bin/bash
echo "=========================================="
echo "  RANSOMWARE SIMULATION (SAFE)"
echo "  ⚠️  EDUCATIONAL PURPOSES ONLY"
echo "=========================================="

TARGET_DIR="/root/data/ransomware_sim"
mkdir -p $TARGET_DIR

echo "[*] Creating sample files..."

# Create sample documents
cat > $TARGET_DIR/financial_report.docx << 'INNER_EOF'
CONFIDENTIAL FINANCIAL REPORT
Q4 2025 Revenue: $1,234,567
Net Profit: $246,913
INNER_EOF

cat > $TARGET_DIR/employee_database.csv << 'INNER_EOF'
ID,Name,Department,Salary
001,John Smith,Finance,75000
002,Jane Doe,Sales,68000
INNER_EOF

echo "[*] Simulating encryption..."
sleep 2

# "Encrypt" by renaming
for file in $TARGET_DIR/*.{docx,csv,txt} 2>/dev/null; do
    [ -f "$file" ] && mv "$file" "$file.encrypted"
    echo "    [SIM] Encrypted: $(basename $file)"
done

# Create ransom note
cat > $TARGET_DIR/!!!_READ_ME_.txt << 'INNER_EOF'
╔═══════════════════════════════════════════════╗
║     YOUR FILES HAVE BEEN ENCRYPTED!           ║
╠═══════════════════════════════════════════════╣
║  This is a SAFE EDUCATIONAL SIMULATION        ║
║  No files were actually damaged.              ║
║                                               ║
║  PROTECTION TIPS:                             ║
║  ✓ Maintain offline backups                   ║
║  ✓ Use endpoint protection                    ║
║  ✓ Train users on phishing                    ║
╚═══════════════════════════════════════════════╝
INNER_EOF

echo ""
echo "[+] Simulation complete!"
echo "    Files: $TARGET_DIR"
echo ""
echo "To cleanup: rm -rf $TARGET_DIR"
EOF

# Complete attack chain
cat > ~/gns3-docker-lab/kali/scripts/03_attack_chain.sh << 'EOF'
#!/bin/bash
echo "╔════════════════════════════════════════════╗"
echo "║   CYBER ATTACK CHAIN SIMULATION            ║"
echo "╚════════════════════════════════════════════╝"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[PHASE 1/5] RECONNAISSANCE${NC}"
echo "─────────────────────────────────────"
echo "[*] Scanning DMZ network (172.18.0.0/24)..."
# nmap -sV 172.18.0.0/24
echo -e "${GREEN}[+] Found:${NC} Web (172.18.0.10:80), Mail (172.18.0.20:25)"
sleep 2

echo ""
echo -e "${YELLOW}[PHASE 2/5] PHISHING${NC}"
echo "─────────────────────────────────────"
echo "[*] Sending phishing email to finance.user..."
echo -e "${GREEN}[+] Email delivered${NC}"
sleep 2

echo ""
echo -e "${YELLOW}[PHASE 3/5] CREDENTIAL HARVEST${NC}"
echo "─────────────────────────────────────"
echo "[*] Waiting for victim to click..."
echo -e "${GREEN}[+] Credentials captured!${NC}"
sleep 2

echo ""
echo -e "${RED}[PHASE 4/5] LATERAL MOVEMENT${NC}"
echo "─────────────────────────────────────"
echo "[*] Using harvested credentials..."
echo -e "${GREEN}[+] Access granted to file server${NC}"
sleep 2

echo ""
echo -e "${RED}[PHASE 5/5] RANSOMWARE${NC}"
echo "─────────────────────────────────────"
bash /root/attacks/02_ransomware_sim.sh

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║   ATTACK CHAIN COMPLETE                    ║"
echo "║   Total Time: ~15 seconds (demo mode)      ║"
echo "║   Check ELK SIEM for alerts!               ║"
echo "╚════════════════════════════════════════════╝"
EOF

chmod +x ~/gns3-docker-lab/kali/scripts/*.sh
```


<br>

---

<br>

## **13.5 Tích hợp với GNS3 Topology**

### **Bước 1: Cấu hình Docker Host trong GNS3**

```
1. Trong GNS3, thêm Docker Host:
   - Edit → Preferences → Docker → Docker containers
   - Add Docker container
   - Host: localhost (hoặc IP của Docker host)
   - Port: 2375

2. Hoặc dùng Cloud node:
   - Thêm Cloud node vào topology
   - Configure → Bind to → Host interface
   - Chọn interface mà Docker đang listen
```

### **Bước 2: Cấu hình mạng bridge**

```bash
# Tạo network bridge để GNS3 và Docker communicate
sudo ip link add name docker-gns3 type bridge
sudo ip addr add 192.168.100.1/24 dev docker-gns3
sudo ip link set docker-gns3 up

# Cấu hình Docker sử dụng bridge này
sudo cat > /etc/docker/daemon.json << 'EOF'
{
  "bip": "192.168.100.1/24",
  "fixed-cidr": "192.168.100.0/24"
}
EOF

sudo systemctl restart docker
```

### **Bước 3: Kết nối GNS3 với Docker Networks**

```bash
# Script kết nối GNS3 network với Docker
cat > ~/gns3-docker-lab/connect_gns3.sh << 'EOF'
#!/bin/bash

# Tìm interface từ GNS3 (thường là tap interface)
GNS3_INTERFACE=$(ip link show | grep -E "tap|veth" | head -1 | cut -d: -f2 | tr -d ' ')

if [ -z "$GNS3_INTERFACE" ]; then
    echo "No GNS3 interface found. Make sure GNS3 topology is running."
    exit 1
fi

# Connect GNS3 interface to Docker DMZ network
echo "Connecting GNS3 to Docker networks..."

# Get Docker network IDs
DMZ_NET=$(docker network ls | grep gns3lab_dmz | awk '{print $1}')
SIEM_NET=$(docker network ls | grep gns3lab_siem | awk '{print $1}')

# Connect interface (cần veth pair)
sudo ip link set $GNS3_INTERFACE up
sudo brctl addif docker0 $GNS3_INTERFACE 2>/dev/null || true

echo "[+] Connected!"
echo "    GNS3 can now reach Docker containers"
EOF

chmod +x ~/gns3-docker-lab/connect_gns3.sh
```

### **Bước 4: Cấu hình OPNsense để route đến Docker**

```
Trong OPNsense Web UI:

1. Interfaces → Other Interfaces → + Add
   - Interface: OPT4 (GNS3-Docker)
   - IP: 192.168.100.254/24
   - Enable: ✓

2. Firewall → Rules → GNS3-Docker
   - Allow all traffic từ Docker network
   - Source: 192.168.100.0/24
   - Destination: any

3. System → Routing → Gateways
   - Add gateway cho Docker network nếu cần
```


<br>

---

<br>

## **13.6 Khởi động và Vận hành**

### **Bước 1: Start toàn bộ services**

```bash
cd ~/gns3-docker-lab

# Start tất cả services
docker compose up -d

# Kiểm tra status
docker compose ps

# Xem logs
docker compose logs -f
```

### **Bước 2: Verify connectivity**

```bash
#!/bin/bash
# File: verify_setup.sh

echo "=== Verifying Docker Lab Setup ==="
echo ""

# Check containers
echo "[1/5] Container Status:"
docker compose ps
echo ""

# Check networks
echo "[2/5] Docker Networks:"
docker network ls | grep gns3lab
echo ""

# Test DMZ connectivity
echo "[3/5] DMZ Services:"
curl -s -o /dev/null -w "  Web Server: %{http_code}\n" http://172.18.0.10
nc -zv 172.18.0.20 25 2>&1 | grep -E "succeeded|failed"
echo ""

# Test SIEM connectivity
echo "[4/5] SIEM Services:"
curl -s -o /dev/null -w "  Elasticsearch: %{http_code}\n" http://172.19.0.10:9200
curl -s -o /dev/null -w "  Kibana: %{http_code}\n" http://172.19.0.12:5601
echo ""

# Test Kali
echo "[5/5] Kali Linux:"
docker exec attack-kali-linux ping -c 1 172.18.0.10 > /dev/null 2>&1 && \
    echo "  Kali → Web Server: OK ✓" || echo "  Kali → Web Server: FAIL ✗"

echo ""
echo "=== Verification Complete ==="
```

### **Bước 3: Truy cập các services**

```bash
# Tạo script hiển thị access info
cat > ~/gns3-docker-lab/access_info.sh << 'EOF'
#!/bin/bash

echo "╔══════════════════════════════════════════════════════════╗"
echo "║         GNS3 DOCKER LAB - SERVICE ACCESS                 ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

HOST_IP=$(hostname -I | awk '{print $1}')

echo "DMZ ZONE:"
echo "  🌐 Web Server:    http://$HOST_IP:8080"
echo "  📧 Mail Server:   $HOST_IP:25 (SMTP), $HOST_IP:993 (IMAPS)"
echo ""

echo "SIEM ZONE:"
echo "  🔍 Elasticsearch: http://$HOST_IP:9200"
echo "  📊 Kibana:        http://$HOST_IP:5601"
echo ""

echo "MONITORING:"
echo "  📈 Netdata:       http://$HOST_IP:19999"
echo "  📋 Dozzle:        http://$HOST_IP:8081"
echo ""

echo "BACKUP:"
echo "  💾 Duplicati:     http://$HOST_IP:8200"
echo ""

echo "KALI LINUX:"
echo "  💀 Access: docker exec -it attack-kali-linux bash"
echo "  Scripts:   /root/attacks/"
echo ""
EOF

chmod +x ~/gns3-docker-lab/access_info.sh
./access_info.sh
```

### **Bước 4: Chạy Attack Simulation**

```bash
# Execute attack chain từ host
docker exec -it attack-kali-linux bash /root/attacks/03_attack_chain.sh

# Hoặc vào container rồi chạy
docker exec -it attack-kali-linux bash
# Trong container:
cd /root/attacks
./03_attack_chain.sh
```

### **Bước 5: Xem SIEM Alerts**

```
1. Mở Kibana: http://localhost:5601

2. Tạo Index Pattern:
   - Management → Stack Management → Index Patterns
   - Create: security-events-*
   - Time field: @timestamp

3. Xem alerts:
   - Discover → Chọn index security-events-*
   - Filter: tags:"security_alert"

4. Tạo Dashboard:
   - Dashboard → Create Dashboard
   - Add visualizations cho failed_login, port_scan, ransomware
```


<br>

---

<br>

## **13.7 Kịch bản Thực nghiệm (30 phút)**

```bash
#!/bin/bash
# File: ~/gns3-docker-lab/security_drill.sh

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   SECURITY INCIDENT RESPONSE DRILL                       ║"
echo "║   Docker-based Cyber Range                               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

START_TIME=$(date +%s)

# Pre-drill check
echo "[PRE-DRILL] Starting services..."
cd ~/gns3-docker-lab
docker compose up -d

echo "[*] Waiting for services to be ready..."
sleep 30

# Verify
./verify_setup.sh
echo ""
read -p "Press ENTER to start attack simulation..."

# Start attack
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "DRILL STARTED at $(date)"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "[T+00:00] Phase 1: Reconnaissance"
docker exec attack-kali-linux bash -c "
    echo '[*] Scanning DMZ network...'
    nmap -sV 172.18.0.0/24 --top-ports 100 -oN /root/data/recon.txt
"
echo ""

echo "[T+05:00] Phase 2: Phishing"
docker exec attack-kali-linux bash /root/attacks/01_phishing.sh
echo ""

echo "[T+10:00] Phase 3: Credential Harvest"
echo "[*] Simulating user clicking phishing link..."
curl -X POST http://172.18.0.10/login.php \
    -d "username=finance.user&password=P@ssw0rd123" > /dev/null 2>&1
echo "[+] Credentials sent to attacker!"
echo ""

echo "[T+15:00] Phase 4: Lateral Movement"
echo "[*] Using harvested credentials..."
docker exec attack-kali-linux bash -c "
    echo '[*] Attempting SMB access...'
    # crackmapexec smb 172.18.0.0/24 -u 'finance.user' -p 'P@ssw0rd123'
    echo '[+] Access granted!'
"
echo ""

echo "[T+20:00] Phase 5: Ransomware"
docker exec attack-kali-linux bash /root/attacks/02_ransomware_sim.sh
echo ""

# Check SIEM
echo "[T+25:00] Checking SIEM alerts..."
echo "[*] Querying Elasticsearch for alerts..."
curl -s "http://172.19.0.10:9200/security-events-*/_search?size=5" \
    -H "Content-Type: application/json" \
    -d '{"query": {"match": {"tags": "security_alert"}}}' | \
    jq '.hits.hits[] | {time: ._source["@timestamp"], severity: ._source.severity}'

echo ""
echo "═══════════════════════════════════════════════════════════"
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "DRILL COMPLETE"
echo "Duration: $DURATION seconds"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "1. Check Kibana dashboard: http://localhost:5601"
echo "2. Review detection time"
echo "3. Verify backup integrity"
echo "4. Document lessons learned"
```


<br>

---

<br>

## **13.8 Troubleshooting**

### **Vấn đề 1: Containers không start**

```bash
# Check logs
docker compose logs <service-name>

# Check resource
docker stats

# Restart services
docker compose down
docker compose up -d
```

### **Vấn đề 2: Network connectivity issues**

```bash
# List networks
docker network ls

# Inspect network
docker network inspect gns3lab_dmz

# Test connectivity
docker exec dmz-web-server ping 172.19.0.10

# Restart network
docker compose down
docker network prune
docker compose up -d
```

### **Vấn đề 3: ELK không nhận logs**

```bash
# Check Logstash pipeline
docker exec siem-logstash logstash --pipeline.id main --config.test_and_exit

# View Logstash logs
docker logs siem-logstash

# Test sending log
echo "Test message" | nc -u localhost 5514
```

### **Vấn đề 4: Kali không scan được DMZ**

```bash
# Check network routing
docker exec attack-kali-linux ip route

# Add route nếu cần
docker exec attack-kali-linux ip route add 172.18.0.0/24 via 172.20.0.1

# Enable IP forwarding trên host
echo 1 > /proc/sys/net/ipv4/ip_forward
```


<br>

---

<br>

## **13.9 Kết luận**

Docker-based lab cung cấp:

✅ **Nhẹ hơn:** Chỉ 2-4GB RAM so với 16-32GB của VM
✅ **Nhanh hơn:** Start trong vài giây
✅ **Dễ quản lý:** docker compose up/down
✅ **Portable:** Chạy trên mọi hệ thống có Docker
✅ **Thực tế:** Services thật, không phải giả lập

### **So sánh VM vs Docker:**

| **Yếu tố** | **VM** | **Docker** |
|------------|--------|------------|
| RAM | 16-32 GB | 2-4 GB |
| Storage | 100+ GB | 20-30 GB |
| Start time | 2-5 phút | 10-30 giây |
| Performance | Overhead cao | Near-native |
| Portability | Khó | Dễ dàng |
| Snapshot | QCOW2/VMDK | Docker images |

### **Next Steps:**

1. Customize docker-compose.yml theo nhu cầu
2. Thêm attack scenarios mới
3. Tích hợp với GNS3 topology
4. Setup CI/CD cho lab environment


<br>

---


<br>

**Previous Chapter:** [Practical Lab Implementation Guide](12-practical-lab-implementation.md)

**Back to project overview:** [README](README.md)
