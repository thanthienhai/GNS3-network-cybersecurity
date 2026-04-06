#!/bin/bash
# Quick Start Script for Docker-based Cyber Range Lab
# Usage: ./quickstart.sh

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   GNS3 Cyber Range - Docker Lab Setup                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "   https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo "❌ Docker Compose is not installed."
    echo "   Install: sudo apt install docker-compose-plugin"
    exit 1
fi

echo "[✓] Docker: $(docker --version)"
echo "[✓] Compose: $(docker compose version)"
echo ""

# Create directory structure
echo "[1/5] Creating directory structure..."
mkdir -p web/{www,logs}
mkdir -p mail/data
mkdir -p elk/{elasticsearch/data,logstash/{pipeline,config},kibana/data}
mkdir -p kali/{scripts,data}
mkdir -p backup/{config,backups,source}

# Create web content
echo "[2/5] Creating web server content..."
cat > web/www/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Infracorp Portal</title>
    <style>
        body {
            font-family: Arial;
            background: linear-gradient(135deg, #667eea, #764ba2);
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
        }
        .login {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.3);
            width: 100%;
            max-width: 400px;
        }
        h1 { color: #333; text-align: center; }
        input {
            width: 100%;
            padding: 12px;
            margin: 10px 0;
            border: 2px solid #ddd;
            border-radius: 5px;
        }
        button {
            width: 100%;
            padding: 12px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
        }
        .alert {
            background: #fee;
            border-left: 4px solid #f44;
            padding: 10px;
            margin: 10px 0;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="login">
        <h1>🔐 Infracorp Portal</h1>
        <div class="alert">⚠️ Security Simulation Lab</div>
        <form action="/login.php" method="POST">
            <input type="text" name="username" placeholder="Username" required>
            <input type="password" name="password" placeholder="Password" required>
            <button type="submit">Sign In</button>
        </form>
    </div>
</body>
</html>
EOF

cat > web/www/login.php << 'EOF'
<?php
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $log = "[" . date('Y-m-d H:i:s') . "] User: " . $_POST['username'] . "\n";
    file_put_contents('/usr/local/apache2/logs/login_attempts.log', $log, FILE_APPEND);
    header("Location: /failed.html");
}
?>
EOF

cat > web/www/failed.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Login Failed</title></head>
<body style="font-family:Arial;text-align:center;padding:50px;">
    <h1 style="color:red;">❌ Login Failed</h1>
    <a href="/">Try again</a>
</body>
</html>
EOF

# Create ELK configs
echo "[3/5] Creating ELK Stack configuration..."

cat > elk/logstash/pipeline/security.conf << 'EOF'
input {
  syslog { port => 5514 type => "syslog" }
  tcp { port => 5000 codec => json type => "firewall" }
  beats { port => 5044 type => "beats" }
}

filter {
  if [type] == "syslog" {
    grok { match => { "message" => "%{SYSLOGPRI}%{SYSLOGTIMESTAMP:ts} %{SYSLOGHOST:host} %{DATA:prog}: %{GREEDYDATA:msg}" } }
  }
  if [msg] =~ /Failed password/ { mutate { add_tag => ["failed_login"] } }
  if [msg] =~ /[Pp]ort [Ss]can/ { mutate { add_tag => ["port_scan"] } }
}

output {
  elasticsearch { hosts => ["elasticsearch:9200"] index => "security-events-%{+YYYY.MM.dd}" }
}
EOF

cat > elk/logstash/config/logstash.yml << 'EOF'
http.host: 0.0.0.0
config.reload.automatic: true
EOF

# Create Kali attack scripts
echo "[4/5] Creating Kali attack scripts..."

cat > kali/scripts/01_phishing.sh << 'EOF'
#!/bin/bash
echo "=== PHISHING SIMULATION ==="
echo "Target: finance.user@infracorp.local"
echo "Landing page: http://172.18.0.10"
echo ""
echo "Gophish UI: http://localhost:3333"
echo "Login: admin / gophish"
EOF

cat > kali/scripts/02_ransomware_sim.sh << 'EOF'
#!/bin/bash
echo "=== RANSOMWARE SIMULATION (SAFE) ==="
DIR="/root/data/ransom_sim"
mkdir -p $DIR
echo "Sample data" > $DIR/doc1.txt
echo "Financial report" > $DIR/finance.docx
for f in $DIR/*; do mv $f $f.encrypted 2>/dev/null; done
echo "!!! YOUR FILES ARE ENCRYPTED !!!" > $DIR/RANSOM_NOTE.txt
echo "(This is a simulation)" >> $DIR/RANSOM_NOTE.txt
echo "Files in: $DIR"
EOF

cat > kali/scripts/03_attack_chain.sh << 'EOF'
#!/bin/bash
echo "╔══════════════════════════════════════╗"
echo "║   ATTACK CHAIN SIMULATION            ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "[1/5] Reconnaissance..."
echo "[2/5] Phishing..."
echo "[3/5] Credential Harvest..."
echo "[4/5] Lateral Movement..."
echo "[5/5] Ransomware..."
bash /root/attacks/02_ransomware_sim.sh
echo ""
echo "✅ Attack chain complete!"
echo "Check ELK SIEM for alerts"
EOF

chmod +x kali/scripts/*.sh

# Create .env file
echo "[5/5] Creating environment file..."
cat > .env << 'EOF'
PROJECT_NAME=gns3-cyber-lab
COMPOSE_PROJECT_NAME=gns3lab
EOF

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Setup complete! Starting services..."
echo "═══════════════════════════════════════════════════════════"
echo ""

# Start services
docker compose up -d

echo ""
echo "Waiting for services to start..."
sleep 15

# Show status
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "SERVICE STATUS"
echo "═══════════════════════════════════════════════════════════"
docker compose ps

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "ACCESS INFORMATION"
echo "═══════════════════════════════════════════════════════════"
echo ""
HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

echo "🌐 DMZ ZONE:"
echo "   Web Server:    http://$HOST_IP:8080"
echo "   Mail Server:   $HOST_IP:25"
echo ""
echo "📊 SIEM ZONE:"
echo "   Elasticsearch: http://$HOST_IP:9200"
echo "   Kibana:        http://$HOST_IP:5601"
echo ""
echo "💾 BACKUP:"
echo "   Duplicati:     http://$HOST_IP:8200"
echo ""
echo "📋 MONITORING:"
echo "   Dozzle Logs:   http://$HOST_IP:8081"
echo ""
echo "💀 KALI LINUX:"
echo "   Access: docker exec -it attack-kali-linux bash"
echo "   Scripts:  /root/attacks/"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "QUICK START COMMANDS"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "# Run attack simulation:"
echo "docker exec -it attack-kali-linux bash /root/attacks/03_attack_chain.sh"
echo ""
echo "# View logs:"
echo "docker compose logs -f"
echo ""
echo "# Stop all services:"
echo "docker compose down"
echo ""
echo "═══════════════════════════════════════════════════════════"
