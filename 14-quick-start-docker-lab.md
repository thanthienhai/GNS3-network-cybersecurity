<br>

# **14 - Quick Start Docker Lab Guide**

<br>

## **14.1 Giới thiệu**

Hướng dẫn nhanh để thiết lập và chạy lab cybersecurity sử dụng Docker chỉ trong **5 phút**. Đây là phiên bản đơn giản hóa của Chương 13, tập trung vào việc thực hiện nhanh chóng.


<br>

---

<br>

## **14.2 Cài đặt Nhanh (5 phút)**

### **Bước 1: Kiểm tra Docker**

```bash
# Kiểm tra Docker đã cài chưa
docker --version
docker compose version

# Nếu chưa cài đặt (Ubuntu/Debian):
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Logout và login lại
```

### **Bước 2: Clone hoặc Copy Lab**

```bash
# Nếu có git repo
cd /root/thien.than/GNS3-network-cybersecurity/docker-lab

# Hoặc tạo thủ công
mkdir -p ~/cyber-lab
cd ~/cyber-lab
```

### **Bước 3: Chạy Quickstart**

```bash
# Cấp quyền thực thi
chmod +x quickstart.sh

# Chạy script
./quickstart.sh
```

Script sẽ tự động:
1. ✅ Kiểm tra Docker
2. ✅ Tạo thư mục cần thiết
3. ✅ Tạo web content (login portal)
4. ✅ Cấu hình ELK Stack
5. ✅ Tạo attack scripts
6. ✅ Start tất cả services

### **Bước 4: Truy cập Services**

Sau khi script chạy xong, truy cập:

```
🌐 Web Server (DMZ):   http://localhost:8080
📊 Kibana (SIEM):      http://localhost:5601
🔍 Elasticsearch:      http://localhost:9200
💾 Backup (Duplicati): http://localhost:8200
📋 Log Viewer:         http://localhost:8081
```


<br>

---

<br>

## **14.3 Thực nghiệm Attack Chain (2 phút)**

### **Option 1: Tự động**

```bash
cd /root/thien.than/GNS3-network-cybersecurity/docker-lab
./security_drill.sh
```

### **Option 2: Thủ công**

```bash
# 1. Access Kali container
docker exec -it attack-kali-linux bash

# 2. Chạy attack chain
cd /root/attacks
./03_attack_chain.sh
```

### **Kết quả mong đợi:**

```
╔══════════════════════════════════════╗
║   ATTACK CHAIN SIMULATION            ║
╚══════════════════════════════════════╝

[1/5] Reconnaissance...
    → Scan DMZ network
[2/5] Phishing...
    → Email sent to finance.user
[3/5] Credential Harvest...
    → Captured: finance.user / password123
[4/5] Lateral Movement...
    → Access granted to file server
[5/5] Ransomware...
    → Files "encrypted" (simulation)

✅ Attack chain complete!
```


<br>

---

<br>

## **14.4 Xem SIEM Alerts**

### **Truy cập Kibana:**

1. Mở trình duyệt: http://localhost:5601

2. Tạo Index Pattern:
   ```
   Management → Stack Management → Index Patterns
   → Create index pattern: security-events-*
   → Time field: @timestamp
   → Create
   ```

3. Xem events:
   ```
   Discover → Chọn security-events-*
   → See logs from attack simulation
   ```

### **Tạo Dashboard đơn giản:**

```
Dashboard → Create Dashboard → Add from library

Thêm visualizations:
- Data table: Top source IPs
- Line chart: Events over time
- Pie chart: Events by severity
```


<br>

---

<br>

## **14.5 Các lệnh hữu ích**

### **Quản lý Services**

```bash
# Start tất cả
docker compose up -d

# Stop tất cả
docker compose down

# Restart service
docker compose restart web-server

# Xem logs
docker compose logs -f

# Xem logs service cụ thể
docker compose logs siem-logstash

# Kiểm tra status
docker compose ps

# Xem resource usage
docker stats
```

### **Truy cập Containers**

```bash
# Kali Linux
docker exec -it attack-kali-linux bash

# Xem attack scripts
docker exec attack-kali-linux ls -la /root/attacks/

# Web server
docker exec dmz-web-server cat /usr/local/apache2/logs/access.log

# Elasticsearch
curl http://localhost:9200/_cat/indices?v
```

### **Kiểm tra Network**

```bash
# List Docker networks
docker network ls

# Inspect network
docker network inspect gns3lab_dmz

# Test connectivity
docker exec attack-kali-linux ping 172.18.0.10
```


<br>

---

<br>

## **14.6 Kịch bản Thực nghiệm**

### **Scenario 1: Phishing Attack**

```bash
# 1. Access Kali
docker exec -it attack-kali-linux bash

# 2. Xem phishing script
cat /root/attacks/01_phishing.sh

# 3. Simulate phishing email
echo "Sending phishing email to finance.user..."
echo "Subject: URGENT - Password Reset Required"
echo "Link: http://172.18.0.10/login.php"

# 4. Victim clicks link (trong browser)
# http://localhost:8080/login.php

# 5. Enter credentials
# Username: finance.user
# Password: P@ssw0rd123!

# 6. Check logs
docker exec dmz-web-server cat /usr/local/apache2/logs/login_attempts.log
```

### **Scenario 2: Ransomware Simulation**

```bash
# Run ransomware simulation
docker exec attack-kali-linux bash /root/attacks/02_ransomware_sim.sh

# Check simulated files
docker exec attack-kali-linux ls -la /root/data/ransom_sim/

# View ransom note
docker exec attack-kali-linux cat /root/data/ransom_sim/RANSOM_NOTE.txt
```

### **Scenario 3: Complete Attack Chain**

```bash
# Run full drill
./security_drill.sh

# Timeline:
# T+00:00 - Reconnaissance scan
# T+02:00 - Phishing email sent
# T+05:00 - Credentials harvested
# T+10:00 - Lateral movement
# T+15:00 - Ransomware deployed
# T+20:00 - Check SIEM alerts
```


<br>

---

<br>

## **14.7 Troubleshooting**

### **Problem: Services not starting**

```bash
# Check Docker
docker ps

# Check logs
docker compose logs

# Restart
docker compose down
docker compose up -d
```

### **Problem: Can't access web server**

```bash
# Check if port 8080 is in use
netstat -tlnp | grep 8080

# Check container
docker ps | grep web-server

# Test locally
curl http://localhost:8080

# Check logs
docker logs dmz-web-server
```

### **Problem: Kali can't reach DMZ**

```bash
# Check network
docker exec attack-kali-linux ip route

# Test connectivity
docker exec attack-kali-linux ping 172.18.0.10

# Check network config
docker network inspect gns3lab_dmz
```

### **Problem: ELK not receiving logs**

```bash
# Check Logstash
docker logs siem-logstash

# Test Elasticsearch
curl http://localhost:9200/_cluster/health

# Check indices
curl http://localhost:9200/_cat/indices?v
```


<br>

---

<br>

## **14.8 Tài nguyên hệ thống**

### **RAM Usage:**

```
Elasticsearch:  1-2 GB
Logstash:       512 MB
Kibana:         500 MB
Web Server:     50 MB
Mail Server:    50 MB
Kali:           200 MB
Backup:         200 MB
─────────────────────
Total:         ~3-4 GB
```

### **Disk Usage:**

```
Docker Images:   5-8 GB
Volumes:         2-5 GB
Logs:            500 MB
─────────────────────
Total:          ~10-15 GB
```


<br>

---

<br>

## **14.9 Cleanup**

### **Soft Cleanup (giữ data)**

```bash
docker compose down
# Containers stopped but volumes kept
```

### **Hard Cleanup (xóa tất cả)**

```bash
docker compose down -v
# Volumes deleted

# Remove all lab files
rm -rf web/* mail/* elk/* kali/data/* backup/*
```

### **Remove Docker Images**

```bash
docker image prune -a
# Remove all unused images
```


<br>

---

<br>

## **14.10 Next Steps**

### **Customize Lab:**

1. Edit `docker-compose.yml` để thay đổi IP, ports
2. Thêm attack scripts vào `kali/scripts/`
3. Customize web content trong `web/www/`
4. Thêm Logstash pipelines trong `elk/logstash/pipeline/`

### **Integrate with GNS3:**

1. Connect GNS3 Cloud node to Docker network
2. Configure OPNsense để route đến Docker subnet
3. Send logs từ GNS3 devices đến Logstash

### **Advanced Scenarios:**

1. Thêm Active Directory (docker-ldap)
2. Thêm vulnerability scanning (OWASP ZAP)
3. Thêm threat intelligence (MISP)
4. Thêm SOAR capabilities


<br>

---

<br>

## **14.11 Kết luận**

Docker-based lab cung cấp:

✅ **Quick Setup:** 5 phút vs 1-2 giờ của VM
✅ **Lightweight:** 3-4 GB RAM vs 16-32 GB
✅ **Portable:** Chạy trên mọi hệ thống có Docker
✅ **Easy Reset:** `docker compose down && up -d`

### **So sánh:**

| Feature | VM Lab | Docker Lab |
|---------|--------|------------|
| Setup Time | 1-2 hours | 5 minutes |
| RAM | 16-32 GB | 3-4 GB |
| Disk | 100 GB | 15 GB |
| Start Time | 2-5 min | 30 sec |
| Snapshots | QCOW2 | Docker images |

### **Recommended For:**

- ✅ Quick testing and demos
- ✅ Security training workshops
- ✅ CI/CD pipeline integration
- ✅ Portable security range
- ✅ Resource-constrained systems


<br>

---


<br>

**Previous Chapter:** [Docker-based Lab Implementation](13-docker-based-lab-implementation.md)

**Back to project overview:** [README](README.md)

**Quick Start:** `cd docker-lab && ./quickstart.sh`
