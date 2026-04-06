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
