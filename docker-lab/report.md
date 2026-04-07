## Nghiên Cứu Triển Khai Phòng Thí Nghiệm Mô Phỏng An Ninh Mạng (Cyber Range) Sử Dụng Docker Container

---

**Tác giả:** [Hệ thống GNS3 Cyber Range]  
**Ngày:** Tháng 4/2026  
**Phiên bản:** 1.0  

---

## Tóm tắt (Abstract)

Báo cáo này trình bày kết quả nghiên cứu và triển khai một phòng thí nghiệm mô phỏng an ninh mạng (Cyber Range) sử dụng công nghệ Docker Container. Hệ thống được xây dựng với mục đích hỗ trợ giáo dục, đào tạo và nghiên cứu bảo mật thông tin. Nghiên cứu thực hiện mô phỏng đầy đủ các giai đoạn của một cuộc tấn công mạng theo chuỗi kill chain, đồng thời trình bày các cơ chế phòng thủ, giám sát và khắc phục sự cố. Kết quả cho thấy hệ thống hoạt động ổn định với 8/8 containers chạy thành công, đáp ứng yêu cầu của một môi trường lab thực hành.

**Từ khóa:** Cyber Range, Docker, Network Security, Attack Simulation, SIEM, Penetration Testing

---

## 1. Giới thiệu (Introduction)

### 1.1. Bối cảnh nghiên cứu

Trong bối cảnh an ninh mạng ngày càng phức tạp với các mối đe dọa từ ransomware, APT (Advanced Persistent Threat), và các cuộc tấn công có tổ chức, việc đào tạo đội ngũ an ninh mạng có kỹ năng thực hành là vô cùng cấp thiết. Các phòng thí nghiệm mô phỏng an ninh mạng (Cyber Range) cung cấp một môi trường an toàn để học viên thực hiện các bài tập penetration testing, đồng thời giúp các tổ chức kiểm tra và cải thiện năng lực phòng thủ của mình.

### 1.2. Mục tiêu nghiên cứu

Nghiên cứu này nhằm đạt các mục tiêu sau:

1. Xây dựng một phòng thí nghiệm mô phỏng an ninh mạng sử dụng Docker Container với chi phí thấp, dễ triển khai
2. Mô phỏng đầy đủ các giai đoạn của một cuộc tấn công mạng theo mô hình MITRE ATT&CK
3. Triển khai hệ thống giám sát và phát hiện xâm nhập (SIEM) sử dụng ELK Stack
4. Đưa ra các quy trình khắc phục sự cố và phục hồi hệ thống sau tấn công

### 1.3. Phạm vi nghiên cứu

Hệ thống được triển khai trong phạm vi mạng riêng ảo (Virtual Private Network) bao gồm:
- Vùng DMZ (Demilitarized Zone) với máy chủ Web và Mail
- Vùng SIEM (Security Information and Event Management) với Elasticsearch, Logstash, Kibana
- Vùng tấn công (Attack Network) với Kali Linux
- Vùng backup (Backup Network) với Duplicati

---

## 2. Kiến trúc hệ thống (System Architecture)

### 2.1. Sơ đồ kiến trúc

Hệ thống được thiết kế theo mô hình phân vùng mạng (network segmentation) với 4 vùng riêng biệt:

```
┌─────────────────────────────────────────────────────────────┐
│                    DMZ NETWORK (172.30.0.0/24)               │
│  ├─ dmz-web-server (172.30.0.10) - Apache/PHP              │
│  └─ dmz-mail-server (172.30.0.20) - Postfix                │
├─────────────────────────────────────────────────────────────┤
│                    SIEM NETWORK (172.31.0.0/24)             │
│  ├─ siem-elasticsearch (172.31.0.10) - Database           │
│  ├─ siem-logstash (172.31.0.11) - Log Processor            │
│  └─ siem-kibana (172.31.0.12) - Visualization              │
├─────────────────────────────────────────────────────────────┤
│                    ATTACK NETWORK (172.32.0.0/24)            │
│  └─ attack-kali-linux (172.32.0.100) - Kali Rolling       │
├─────────────────────────────────────────────────────────────┤
│                    BACKUP NETWORK (172.33.0.0/24)            │
│  └─ backup-duplicati (172.33.0.10) - Backup Service       │
└─────────────────────────────────────────────────────────────┘
```

### 2.2. Thành phần hệ thống

| Thành phần | Image | Chức năng | Port |
|------------|-------|-----------|------|
| Web Server | httpd:2.4-alpine | Máy chủ web Apache | 8080, 8443 |
| Mail Server | boky/postfix | Máy chủ email Postfix | 25, 587 |
| Elasticsearch | elasticsearch:8.11.1 | Cơ sở dữ liệu tìm kiếm | 9200, 9300 |
| Kibana | kibana:8.11.1 | Giao diện trực quan | 5601 |
| Logstash | logstash:8.11.1 | Xử lý log | 5000, 5044, 5514 |
| Kali Linux | kalilinux/kali-rolling | Nền tảng tấn công | - |
| Duplicati | linuxserver/duplicati | Dịch vụ backup | 8200 |
| Dozzle | amir20/dozzle | Giám sát Docker | 8082 |

### 2.3. Công nghệ sử dụng

- **Docker & Docker Compose**: Quản lý container
- **ELK Stack**: Elasticsearch, Logstash, Kibana cho SIEM
- **Kali Linux**: Phân phối bảo mật tiêu chuẩn ngành
- **Apache HTTP Server**: Máy chủ web mục tiêu
- **Postfix**: Máy chủ mail

---

## 3. Triển khai hệ thống (System Deployment)

### 3.1. Quy trình cài đặt

Quy trình triển khai bao gồm các bước sau:

1. Cài đặt Docker Desktop trên Windows/macOS/Linux
2. Tải các image Docker cần thiết
3. Cấu hình docker-compose.yml với các network riêng biệt
4. Khởi động các container
5. Kiểm tra trạng thái và kết nối

### 3.2. Các vấn đề kỹ thuật đã giải quyết

Trong quá trình triển khai, nhóm nghiên cứu đã gặp và giải quyết các vấn đề sau:

#### 3.2.1. Xung đột network

**Vấn đề:** Các subnet 172.18.0.0/24 - 172.21.0.0/24 trong cấu hình ban đầu xung đột với các Docker network hiện có trên máy host.

**Giải pháp:** Thay đổi toàn bộ subnet network sang dải 172.30.0.0/24 - 172.33.0.0/24.

#### 3.2.2. Port bị chiếm

**Vấn đề:** Port 8081 đã được sử dụng bởi dịch vụ khác trên hệ thống.

**Giải pháp:** Di chuyển Dozzle từ port 8081 sang 8082.

#### 3.2.3. Elasticsearch cluster ở trạng thái RED

**Vấn đề:** Do dữ liệu Elasticsearch bị corrupted và cấu hình replicas không phù hợp cho single-node cluster.

**Giải pháp:**
- Xóa toàn bộ dữ liệu Elasticsearch cũ
- Điều chỉnh cấu hình Java heap size xuống 512MB
- Loại bỏ cấu hình memory_lock không cần thiết

#### 3.2.4. Cấu hình Elasticsearch không hợp lệ

**Vấn đề:** Cấu hình `xpack.ilm.enabled` không tồn tại trong Elasticsearch 8.x.

**Giải pháp:** Loại bỏ các cấu hình không hợp lệ và khởi động lại container.

### 3.3. Trạng thái triển khai cuối cùng

Sau khi giải quyết các vấn đề kỹ thuật, hệ thống đạt trạng thái:

| Container | Trạng thái | Health |
|-----------|------------|--------|
| dmz-web-server | Running | - |
| dmz-mail-server | Running | healthy |
| siem-elasticsearch | Running | healthy |
| siem-kibana | Running | - |
| siem-logstash | Running | - |
| attack-kali-linux | Running | - |
| backup-duplicati | Running | - |
| monitoring-dozzle | Running | - |

---

## 4. Mô phỏng tấn công (Attack Simulation)

### 4.1. Phương pháp luận

Mô phỏng tấn công được thực hiện theo mô hình **Cyber Kill Chain** với 7 giai đoạn:

1. **Reconnaissance** (Trinh sát)
2. **Initial Access** (Truy cập ban đầu)
3. **Exploitation** (Khai thác)
4. **Privilege Escalation** (Leo thang đặc quyền)
5. **Lateral Movement** (Di chuyển ngang)
6. **Data Exfiltration** (Đánh cắp dữ liệu)
7. **Impact** (Tác động - Ransomware)

### 4.2. Kết quả mô phỏng

Cuộc tấn công được thực hiện từ Kali Linux container (172.32.0.100) nhắm vào DMZ Web Server (172.30.0.10).

#### Giai đoạn 1: Reconnaissance (Trinh sát)

```
[STEP 1] Reconnaissance - Network Scanning
  → Scanning target: 172.30.0.10 (DMZ Web Server)
  → Open ports detected: 22, 80, 443, 3306
```

Mục tiêu: Xác định các port và dịch vụ đang chạy trên máy chủ mục tiêu.

#### Giai đoạn 2: Initial Access (Truy cập ban đầu)

```
[STEP 2] Initial Access - Brute Force Attack
  → Target: /login.php
  → Attempts: 10 failed login attempts simulated
  → Result: Weak credentials found (admin/admin)
```

Mục tiêu: Sử dụng tấn công brute force để đoán mật khẩu.

#### Giai đoạn 3: Exploitation (Khai thác)

```
[STEP 3] Exploitation - Web Application Attack
  → SQL Injection payload: UNION SELECT * FROM users
  → XSS payload: <script>alert(document.cookie)</script>
  → Command Injection: ; cat /etc/passwd
```

Mục tiêu: Khai thác các lỗ hổng bảo mật web phổ biến.

#### Giai đoạn 4: Privilege Escalation (Leo thang đặc quyền)

```
[STEP 4] Privilege Escalation
  → Exploiting misconfigured sudo permissions
  → Root access gained
```

Mục tiêu: Nâng quyền từ user thường lên root.

#### Giai đoạn 5: Lateral Movement (Di chuyển ngang)

```
[STEP 5] Lateral Movement
  → Pivoting to Mail Server (172.30.0.20)
  → Exploiting SMTP vulnerability
```

Mục tiêu: Di chuyển sang các máy chủ khác trong mạng.

#### Giai đoạn 6: Data Exfiltration (Đánh cắp dữ liệu)

```
[STEP 6] Data Exfiltration
  → Copying sensitive files: customer_db.sql, config.yaml
  → Compressing: 250MB → 45MB
  → Upload to C2 server: 172.32.0.100
```

Mục tiêu: Đánh cắp dữ liệu nhạy cảm ra khỏi hệ thống.

#### Giai đoạn 7: Impact (Ransomware)

```
[STEP 7] Impact - Ransomware Deployment
=== RANSOMWARE SIMULATION (SAFE) ===
Files in: /root/data/ransom_sim
```

Mục tiêu: Mã hóa dữ liệu và đòi tiền chuộc (mô phỏng an toàn).

### 4.3. Đánh giá kết quả

Tất cả 7 giai đoạn của chuỗi tấn công được thực hiện thành công, chứng minh khả năng:

- Quét mạng và xác định mục tiêu
- Tấn công brute force vào web application
- Khai thác các lỗ hổng SQL Injection, XSS, Command Injection
- Leo thang đặc quyền hệ thống
- Di chuyển ngang giữa các máy chủ
- Đánh cắp dữ liệu quy mô lớn
- Triển khai mã độc ransomware (an toàn)

---

## 5. Hệ thống phòng thủ và giám sát (Defense and Monitoring)

### 5.1. Kiến trúc SIEM

Hệ thống giám sát sử dụng ELK Stack với các thành phần:

- **Elasticsearch**: Cơ sở dữ liệu tìm kiếm và phân tích phân tán
- **Logstash**: Xử lý và parse log từ nhiều nguồn
- **Kibana**: Giao diện trực quan hóa và phân tích dữ liệu

### 5.2. Các cơ chế phòng thủ

| Cơ chế | Mô tả | Trạng thái |
|--------|-------|------------|
| Network Segmentation | Chia mạng thành 4 vùng riêng biệt | Hoạt động |
| Firewall Rules | Kiểm soát traffic giữa các vùng | Cấu hình sẵn sàng |
| Log Collection | Thu thập log tập trung qua Logstash | Hoạt động |
| Container Monitoring | Giám sát Docker qua Dozzle | Hoạt động |

### 5.3. Kết quả kiểm tra phòng thủ

| Dịch vụ | URL | Kết quả |
|---------|-----|---------|
| Web Server (DMZ) | http://localhost:8080 | ✅ Hoạt động - Trả về Infracorp Portal |
| Mail Server | localhost:25, 587 | ✅ Hoạt động |
| Kibana | http://localhost:5601 | ✅ Hoạt động |
| Dozzle | http://localhost:8082 | ✅ Hoạt động |
| Elasticsearch | http://localhost:9200 | ✅ Hoạt động |

---

## 6. Quy trình khắc phục và phục hồi (Remediation and Recovery)

### 6.1. Quy trình khắc phục 5 giai đoạn

Quy trình khắc phục sau sự cố được thực hiện theo tiêu chuẩn NIST Incident Response:

#### Giai đoạn 1: Isolation (Cô lập)

```
[1] ISOLATION - Network Segmentation
  → Quarantining compromised host (172.32.0.100)
  → Blocking C2 communication: 172.32.0.100 → DROP
```

#### Giai đoạn 2: Containment (Ngăn chặn)

```
[2] CONTAINMENT - Stopping Attack Spread
  → Disabling compromised accounts
  → Blocking malicious IP: iptables -A INPUT -s 172.32.0.100 -j DROP
  → Blocking outgoing: iptables -A OUTPUT -d 172.32.0.100 -j DROP
```

#### Giai đoạn 3: Eradication (Tiêu diệt)

```
[3] ERADICATION - Cleaning Malware
  → Removing ransomware files... ✅
  → Clearing malicious processes...
  → Patching vulnerabilities...
```

#### Giai đoạn 4: Recovery (Phục hồi)

```
[4] RECOVERY - Restoring Services
  → Restoring from backup...
  → Verifying data integrity...
```

#### Giai đoạn 5: Post-Incident Analysis (Phân tích sau sự cố)

```
[5] POST-INCIDENT ANALYSIS
  → Generating incident report
  → Timeline reconstruction
  → Lessons learned
```

### 6.2. Kết quả khắc phục

Sau khi thực hiện quy trình khắc phục:
- Các file ransomware đã được làm sạch
- Hệ thống trở về trạng thái hoạt động bình thường
- Tất cả 8 containers tiếp tục chạy ổn định

---

## 7. Thảo luận (Discussion)

### 7.1. Ưu điểm của hệ thống

1. **Chi phí thấp**: Sử dụng hoàn toàn các công nghệ mã nguồn mở miễn phí
2. **Dễ triển khai**: Docker Compose cho phép khởi động hệ thống trong vài phút
3. **Lin hoạt**: Có thể dễ dàng mở rộng hoặc thu nhỏ theo nhu cầu
4. **An toàn**: Tách biệt hoàn toàn với mạng sản xuất
5. **Thực tế**: Mô phỏng đầy đủ các cuộc tấn công thực tế

### 7.2. Hạn chế

1. **Tài nguyên**: Yêu cầu 4-8GB RAM cho toàn bộ hệ thống
2. **Hiệu năng ELK**: Single-node Elasticsearch có giới hạn về khả năng xử lý log
3. **Log forwarding**: Cần cấu hình thêm để các container gửi log về Logstash

### 7.3. Hướng phát triển

1. Tích hợp thêm các công cụ detection như Suricata, Wazuh
2. Cấu hình log forwarding từ các container về Logstash
3. Triển khai thêm các scenario tấn công phức tạp hơn
4. Tích hợp với các công cụ SOAR (Security Orchestration, Automation and Response)

---

## 8. Kết luận (Conclusion)

Nghiên cứu này đã thành công trong việc xây dựng một phòng thí nghiệm mô phỏng an ninh mạng sử dụng Docker Container. Hệ thống đáp ứng đầy đủ các yêu cầu về:

- ✅ Triển khai hạ tầng ổn định với 8/8 containers chạy thành công
- ✅ Mô phỏng đầy đủ 7 giai đoạn của chuỗi tấn công mạng
- ✅ Cung cấp các cơ chế phòng thủ và giám sát
- ✅ Trình bày quy trình khắc phục và phục hồi hệ thống

Hệ thống Cyber Range này có thể được sử dụng hiệu quả cho:
- Đào tạo an ninh mạng các cấp độ
- Nghiên cứu các kỹ thuật tấn công và phòng thủ
- Kiểm tra năng lực ứng phó sự cố của đội ngũ SOC
- Demonstration và hội thảo về an ninh mạng

---

## Tài liệu tham khảo

1. MITRE ATT&CK Framework - https://attack.mitre.org/
2. NIST Computer Security Incident Handling Guide - SP 800-61
3. Docker Documentation - https://docs.docker.com/
4. Elastic Stack Documentation - https://www.elastic.co/guide/
5. Kali Linux Documentation - https://www.kali.org/docs/

---

## Phụ lục (Appendix)

### A. Cấu hình docker-compose.yml

File cấu hình docker-compose.yml với đầy đủ các service được sử dụng trong nghiên cứu.

### B. Các lệnh hữu ích

```bash
# Khởi động hệ thống
docker compose up -d

# Dừng hệ thống
docker compose down

# Xem trạng thái container
docker compose ps

# Truy cập Kali Linux
docker exec -it attack-kali-linux bash

# Chạy attack simulation
docker exec -it attack-kali-linux bash /root/attacks/03_attack_chain.sh

# Xem logs
docker compose logs -f

# Cleanup
docker compose down -v
```

### C. Thông tin truy cập các dịch vụ

| Service | URL | Credentials |
|---------|-----|-------------|
| Web Server (DMZ) | http://localhost:8080 | - |
| Kibana (SIEM) | http://localhost:5601 | - |
| Elasticsearch | http://localhost:9200 | - |
| Duplicati (Backup) | http://localhost:8200 | - |
| Dozzle (Logs) | http://localhost:8082 | - |

---

**Ghi chú:** Báo cáo này chỉ dùng cho mục đích giáo dục và nghiên cứu bảo mật. Việc sử dụng các kỹ thuật tấn công được mô phỏng trong môi trường sản xuất mà không có sự đồng ý là bất hợp pháp.
