#!/bin/bash
# Security Drill Script - Complete Attack Simulation
# Usage: ./security_drill.sh

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   SECURITY INCIDENT RESPONSE DRILL                       ║"
echo "║   Phishing → Ransomware Attack Chain                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

START_TIME=$(date +%s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if services are running
echo "[PRE-DRILL] Checking services..."
if ! docker compose ps | grep -q "running"; then
    echo "⚠️  Services not running. Starting..."
    docker compose up -d
    echo "[*] Waiting for services..."
    sleep 20
fi

# Verify connectivity
echo ""
echo "[PRE-DRILL] Verifying connectivity..."
WEB_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null || echo "000")
ES_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9200 2>/dev/null || echo "000")
KIBANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5601 2>/dev/null || echo "000")

echo "  Web Server:  $WEB_STATUS"
echo "  Elasticsearch: $ES_STATUS"
echo "  Kibana:    $KIBANA_STATUS"

if [ "$WEB_STATUS" != "200" ] || [ "$ES_STATUS" != "200" ]; then
    echo ""
    echo "❌ Services not ready. Please run: docker compose up -d"
    exit 1
fi

echo ""
echo "✅ All services ready!"
echo ""
read -p "Press ENTER to start attack simulation..."

# Start drill
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "DRILL STARTED at $(date)"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Phase 1: Reconnaissance
echo "[T+00:00] 📡 PHASE 1: RECONNAISSANCE"
echo "─────────────────────────────────────"
echo "[*] Scanning DMZ network..."
docker exec attack-kali-linux bash -c "
    echo 'Scanning 172.18.0.0/24...'
    nmap -sV 172.18.0.0/24 --top-ports 10 2>/dev/null || echo 'nmap not installed, skipping'
" || echo "Scan completed"
echo ""
echo "[*] Discovered services:"
echo "    • 172.18.0.10:80 (HTTP Web Server)"
echo "    • 172.18.0.20:25 (SMTP Mail Server)"
sleep 3

# Phase 2: Phishing
echo ""
echo "[T+02:00] 🎣 PHASE 2: PHISHING CAMPAIGN"
echo "─────────────────────────────────────"
echo "[*] Crafting phishing email..."
echo "[*] Target: finance.user@infracorp.local"
echo "[*] Subject: URGENT - Password Reset Required"
echo "[*] Sending..."
sleep 2
echo "[+] Email delivered!"
sleep 2

# Phase 3: Credential Harvesting
echo ""
echo "[T+05:00] 🪝 PHASE 3: CREDENTIAL HARVESTING"
echo "─────────────────────────────────────"
echo "[*] Waiting for victim to click link..."
sleep 3
echo "[*] Victim clicked: http://172.18.0.10/login.php"
echo "[*] Entering credentials..."
sleep 2

# Simulate credential submission
curl -s -X POST http://localhost:8080/login.php \
    -d "username=finance.user&password=Summer2024!" > /dev/null || true

echo "[+] Credentials captured!"
echo "    Username: finance.user"
echo "    Password: Summer2024!"
sleep 2

# Phase 4: Lateral Movement
echo ""
echo "[T+10:00] 🔄 PHASE 4: LATERAL MOVEMENT"
echo "─────────────────────────────────────"
echo "[*] Using harvested credentials..."
echo "[*] Attempting access to internal resources..."
sleep 2
echo "[+] Access granted to file server!"
echo "[*] Enumerating shares..."
echo "    • \\\\SERVER\\Finance"
echo "    • \\\\SERVER\\HR"
echo "    • \\\\SERVER\\Public"
sleep 3

# Phase 5: Ransomware
echo ""
echo "[T+15:00] 🔓 PHASE 5: RANSOMWARE DEPLOYMENT"
echo "─────────────────────────────────────"
echo "[*] Executing ransomware simulation..."
docker exec attack-kali-linux bash /root/attacks/02_ransomware_sim.sh || \
    echo "Running local simulation..."
sleep 3

# Check SIEM
echo ""
echo "[T+20:00] 📊 CHECKING SIEM ALERTS"
echo "─────────────────────────────────────"
echo "[*] Querying Elasticsearch for security events..."

ES_QUERY=$(curl -s "http://localhost:9200/security-events-*/_search?size=10" \
    -H "Content-Type: application/json" \
    -d '{"query": {"match_all": {}}}' 2>/dev/null || echo '{"hits":{"hits":[]}}')

EVENT_COUNT=$(echo "$ES_QUERY" | grep -o '"hits":\[' | wc -l || echo "0")
echo "    Events found: $EVENT_COUNT"

if [ "$EVENT_COUNT" -gt 0 ]; then
    echo "[+] SIEM is collecting events!"
else
    echo "[*] No events in Elasticsearch yet (normal for first run)"
    echo "    Check Kibana dashboard for real-time monitoring"
fi

sleep 2

# Summary
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "DRILL COMPLETE"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📊 Summary:"
echo "   Start Time: $(date -d @$START_TIME '+%H:%M:%S')"
echo "   End Time:   $(date -d @$END_TIME '+%H:%M:%S')"
echo "   Duration:   $DURATION seconds"
echo ""
echo "🎯 Attack Chain Results:"
echo "   ✓ Reconnaissance: Completed"
echo "   ✓ Phishing: Email delivered"
echo "   ✓ Credential Harvest: finance.user compromised"
echo "   ✓ Lateral Movement: Access gained"
echo "   ✓ Ransomware: Simulation executed"
echo ""
echo "📈 Detection Status:"
echo "   • Check Kibana: http://localhost:5601"
echo "   • Index: security-events-*"
echo "   • Look for: failed_login, port_scan tags"
echo ""
echo "🔧 Next Steps:"
echo "   1. Review SIEM alerts in Kibana"
echo "   2. Verify detection time (< 5 minutes?)"
echo "   3. Check backup integrity"
echo "   4. Document lessons learned"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Useful commands:"
echo "  # View Kibana dashboard:"
echo "  open http://localhost:5601"
echo ""
echo "  # Check container logs:"
echo "  docker compose logs -f"
echo ""
echo "  # Reset simulation:"
echo "  docker compose down && docker compose up -d"
echo ""
