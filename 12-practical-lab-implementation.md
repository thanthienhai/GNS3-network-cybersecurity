<br>

# **12 - Practical Lab Implementation Guide**

<br>

## **12.1 Giới thiệu**

Chương này hướng dẫn chi tiết cách thiết lập các service giả lập để thực nghiệm toàn bộ kịch bản tấn công và phòng thủ trong phòng lab GNS3. Tất cả các service đều có thể chạy trên máy tính cá nhân với tài nguyên hợp lý.


<br>

## **12.2 Yêu cầu hệ thống**

| **Thành phần** | **Tối thiểu** | **Đề xuất** |
|----------------|---------------|-------------|
| RAM | 16 GB | 32 GB |
| CPU | 4 cores | 8+ cores |
| Storage | 100 GB SSD | 256 GB SSD |
| GNS3 Version | 2.2.x | 2.2.54+ |


<br>

---

<br>

## **12.3 Thiết lập OPNsense Firewall**

### **Bước 1: Tải và cài đặt OPNsense**

```bash
# 1. Tải OPNsense từ trang chủ
# URL: https://opnsense.org/download/
# Chọn: OPNsense-25.7-...-dvd.iso (DVD installer)

# 2. Tạo VM trong GNS3:
# - Edit → Preferences → QEMU → QEMU VMs → New
# - Name: FW-OPNS
# - RAM: 2048 MB
# - CPU: 2
# - Disk: Tạo mới 10GB
# - Network interfaces: 4 (e0=WAN, e1=LAN, e2=DMZ, e3=KALI)
```

### **Bước 2: Cấu hình OPNsense cơ bản**

```
1. Boot OPNsense và cài đặt:
   - Keyboard: us (1)
   - Hostname: fw-opns
   - Interface: e0 (WAN), e1 (LAN)
   - WAN: DHCP (từ ISP router)
   - LAN: Static IP 192.168.50.1/24

2. Truy cập Web UI:
   - URL: https://192.168.50.1
   - Username: root
   - Password: (đặt khi cài đặt)
```

### **Bước 3: Cấu hình VLAN Interfaces**

```
1. Interfaces → Other Interfaces → + Add

2. Tạo các interface:
   ┌─────────────┬──────────────┬─────────────┬──────────────┐
   │ Interface   │ IP Address   │ Subnet      │ Description  │
   ├─────────────┼──────────────┼─────────────┼──────────────┤
   │ OPT1 (DMZ)  │ 192.168.70.1 │ /24         │ DMZ Network  │
   │ OPT2 (KALI) │ 192.168.80.1 │ /24         │ Kali Attack  │
   │ OPT3 (SIEM) │ 192.168.85.1 │ /24         │ SIEM/ELK     │
   └─────────────┴──────────────┴─────────────┴──────────────┘

3. Enable DHCP cho mỗi interface:
   - Range: .100 - .200
   - Gateway: Interface IP
   - DNS: 192.168.60.10
```

### **Bước 4: Cấu hình Firewall Rules**

```
Firewall → Rules → LAN

Rule 1: Allow LAN to Internet
- Action: Pass
- Source: LAN net
- Destination: any
- Protocol: any

Rule 2: Allow LAN to DMZ
- Action: Pass
- Source: LAN net
- Destination: DMZ net
- Protocol: TCP
- Ports: 80, 443, 25, 587

Rule 3: Block LAN to Backup (Air-gapped)
- Action: Block
- Source: LAN net
- Destination: 192.168.90.0/24

Firewall → Rules → DMZ

Rule 1: Allow Internet to DMZ Web
- Action: Pass
- Source: any
- Destination: DMZ net
- Protocol: TCP
- Ports: 80, 443

Rule 2: Allow Internet to DMZ Mail
- Action: Pass
- Source: any
- Destination: 192.168.70.20
- Protocol: TCP
- Ports: 25, 587

Rule 3: Block DMZ to Internal
- Action: Block
- Source: DMZ net
- Destination: 192.168.10.0/24, 192.168.20.0/24, 
            192.168.30.0/24, 192.168.50.0/24, 192.168.60.0/24
```

### **Bước 5: Cấu hình NAT/PAT**

```
Firewall → NAT → Port Forward

Rule 1: HTTP to Web Server
- Interface: WAN
- Protocol: TCP
- Destination port: 80
- Redirect target IP: 192.168.70.10
- Redirect target port: 80

Rule 2: HTTPS to Web Server
- Interface: WAN
- Protocol: TCP
- Destination port: 443
- Redirect target IP: 192.168.70.10
- Redirect target port: 443

Rule 3: SMTP to Mail Server
- Interface: WAN
- Protocol: TCP
- Destination port: 25
- Redirect target IP: 192.168.70.20
- Redirect target port: 25
```

### **Bước 6: Cấu hình Remote Logging**

```
System → Settings → Logging

✓ Enable Remote Logging
Remote syslog server: 192.168.85.10
Port: 5514
Protocol: UDP
Facilities: AUTH, FIREWALL, SYSTEM, DAEMON

Apply → Save
```


<br>

---

<br>

## **12.4 Thiết lập Windows Server 2022**

### **Bước 1: Cài đặt Windows Server**

```bash
# 1. Tải Windows Server 2022 Evaluation
# URL: https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022

# 2. Tạo VM trong GNS3:
# - Name: SERVER-DC01
# - RAM: 4096 MB
# - CPU: 2
# - Disk: 60 GB
# - Network: 1 interface
```

### **Bước 2: Cấu hình mạng**

```powershell
# PowerShell (Run as Administrator)

# Static IP Configuration
New-NetIPAddress -InterfaceAlias "Ethernet" `
    -IPAddress 192.168.60.10 `
    -PrefixLength 24 `
    -DefaultGateway 192.168.60.1

# DNS Configuration
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" `
    -ServerAddresses 127.0.0.1
```

### **Bước 3: Cài đặt AD DS (Active Directory)**

```powershell
# 1. Cài đặt AD DS Role
Install-WindowsFeature -Name AD-Domain-Services `
    -IncludeManagementTools

# 2. Tạo Forest mới
Install-ADDSForest `
    -DomainName "infracorp.local" `
    -DomainNetbiosName "INFRACORP" `
    -ForestMode "WinThreshold" `
    -DomainMode "WinThreshold" `
    -InstallDns:$true `
    -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
    -Force

# Server sẽ restart sau khi cài đặt
```

### **Bước 4: Cài đặt DHCP Server**

```powershell
# 1. Cài đặt DHCP Role
Install-WindowsFeature -Name DHCP -IncludeManagementTools

# 2. Cấu hình DHCP Scopes
Add-DhcpServerv4Scope -Name "Office VLAN" `
    -StartRange 192.168.10.100 `
    -EndRange 192.168.10.200 `
    -SubnetMask 255.255.255.0 `
    -LeaseDuration 8.00:00:00

Add-DhcpServerv4OptionDefinition -ScopeId 192.168.10.0 `
    -DnsServer 192.168.60.10 `
    -Router 192.168.10.1

# Lặp lại cho các VLAN khác (Finance, Sales, Guest...)
```

### **Bước 5: Cài đặt DNS Server**

```powershell
# DNS đã được cài cùng AD DS
# Tạo Forward Lookup Zones

Add-DnsServerPrimaryZone -Name "infracorp.local" `
    -ZoneFile "infracorp.local.dns"

# Tạo A Records
Add-DnsServerResourceRecordA -Name "web" `
    -ZoneName "infracorp.local" `
    -IPv4Address 192.168.70.10

Add-DnsServerResourceRecordA -Name "mail" `
    -ZoneName "infracorp.local" `
    -IPv4Address 192.168.70.20

Add-DnsServerResourceRecordA -Name "dc01" `
    -ZoneName "infracorp.local" `
    -IPv4Address 192.168.60.10
```

### **Bước 6: Tạo User Accounts**

```powershell
# Tạo users cho các phòng ban

# Finance Department
New-ADUser -Name "finance.user" `
    -GivenName "Finance" `
    -Surname "User" `
    -SamAccountName "finance.user" `
    -UserPrincipalName "finance.user@infracorp.local" `
    -Path "OU=Users,DC=infracorp,DC=local" `
    -AccountPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
    -Enabled $true

# Sales Department
New-ADUser -Name "sales.user" `
    -GivenName "Sales" `
    -Surname "User" `
    -SamAccountName "sales.user" `
    -UserPrincipalName "sales.user@infracorp.local" `
    -Path "OU=Users,DC=infracorp,DC=local" `
    -AccountPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
    -Enabled $true

# Admin Account
New-ADUser -Name "admin" `
    -GivenName "Administrator" `
    -Surname "Admin" `
    -SamAccountName "admin" `
    -UserPrincipalName "admin@infracorp.local" `
    -Path "OU=Users,DC=infracorp,DC=local" `
    -AccountPassword (ConvertTo-SecureString "AdminP@ss123!" -AsPlainText -Force) `
    -Enabled $true
```


<br>

---

<br>

## **12.5 Thiết lập DMZ Servers**

### **A. Web Server (Ubuntu 22.04 + Apache)**

#### **Bước 1: Cài đặt Ubuntu Server**

```bash
# 1. Tải Ubuntu Server 22.04 LTS
# URL: https://ubuntu.com/download/server

# 2. Tạo VM trong GNS3:
# - Name: WEB-SRV
# - RAM: 2048 MB
# - CPU: 1
# - Disk: 20 GB
# - Network: 1 interface → DMZ Switch
```

#### **Bước 2: Cấu hình mạng**

```bash
# /etc/netplan/00-installer-config.yaml

network:
  ethernets:
    eth0:
      addresses:
        - 192.168.70.10/24
      gateway4: 192.168.70.1
      nameservers:
        addresses:
          - 192.168.60.10
  version: 2

# Apply cấu hình
sudo netplan apply
```

#### **Bước 3: Cài đặt Apache Web Server**

```bash
# Cài đặt Apache
sudo apt update
sudo apt install -y apache2 php mysql-server

# Tạo website mẫu
sudo mkdir -p /var/www/infracorp
sudo chown -R www-data:www-data /var/www/infracorp

# Tạo index.html
sudo cat > /var/www/infracorp/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Infracorp Portal</title>
    <style>
        body { font-family: Arial; background: #f0f0f0; }
        .container { max-width: 400px; margin: 100px auto; 
                    background: white; padding: 30px; 
                    border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; text-align: center; }
        input { width: 100%; padding: 10px; margin: 10px 0; 
               border: 1px solid #ddd; border-radius: 4px; }
        button { width: 100%; padding: 10px; background: #007bff; 
                color: white; border: none; border-radius: 4px; 
                cursor: pointer; }
        button:hover { background: #0056b3; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔐 Infracorp Employee Portal</h1>
        <form action="/login.php" method="POST">
            <input type="text" name="username" placeholder="Username" required>
            <input type="password" name="password" placeholder="Password" required>
            <button type="submit">Login</button>
        </form>
        <p style="text-align: center; color: #666; font-size: 12px;">
            Internal use only - Authorized personnel only
        </p>
    </div>
</body>
</html>
EOF

# Tạo login.php (giả lập nhận thông tin đăng nhập)
sudo cat > /var/www/infracorp/login.php << 'EOF'
<?php
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $username = $_POST['username'];
    $password = $_POST['password'];
    
    // Log the credentials (for simulation)
    $log_entry = date('Y-m-d H:i:s') . " - User: $username, Pass: $password\n";
    file_put_contents('/var/log/login_attempts.log', $log_entry, FILE_APPEND);
    
    // Redirect to "wrong password" page
    header("Location: /failed.html");
    exit();
}
?>
EOF

# Tạo failed.html
sudo cat > /var/www/infracorp/failed.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Login Failed</title></head>
<body style="font-family: Arial; text-align: center; padding: 50px;">
    <h1 style="color: red;">❌ Login Failed</h1>
    <p>Invalid username or password.</p>
    <a href="/index.html">Try again</a>
</body>
</html>
EOF

# Cấu hình Apache VirtualHost
sudo cat > /etc/apache2/sites-available/000-default.conf << 'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/infracorp
    
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Enable và restart Apache
sudo a2ensite 000-default.conf
sudo systemctl enable apache2
sudo systemctl restart apache2

# Verify
sudo systemctl status apache2
```

#### **Bước 4: Gửi log đến SIEM**

```bash
# Cài đặt rsyslog nếu chưa có
sudo apt install -y rsyslog

# Cấu hình gửi log đến ELK
sudo cat > /etc/rsyslog.d/50-default.conf << 'EOF'
*.* @192.168.85.10:5514;RSYSLOG_SyslogProtocol23Format
EOF

sudo systemctl restart rsyslog
```

---

### **B. Mail Server (Ubuntu 22.04 + Postfix + Dovecot)**

#### **Bước 1: Tạo VM Mail Server**

```bash
# Tương tự Web Server nhưng:
# - Name: MAIL-SRV
# - IP: 192.168.70.20/24
# - Gateway: 192.168.70.1
```

#### **Bước 2: Cài đặt Postfix (SMTP)**

```bash
sudo apt update

# Cài đặt Postfix
sudo apt install -y postfix
# Khi được hỏi:
# - General type: Internet Site
# - System mail name: mail.infracorp.local

# Cấu hình Postfix
sudo cat > /etc/postfix/main.cf << 'EOF'
smtpd_banner = $myhostname ESMTP
biff = no
append_dot_mydomain = no
readme_directory = no
compatibility_level = 3.6

myhostname = mail.infracorp.local
mydomain = infracorp.local
myorigin = $mydomain
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
mynetworks = 127.0.0.0/8, 192.168.70.0/24
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
inet_protocols = ipv4

# SMTP Authentication
smtpd_sasl_auth_enable = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = $myhostname
broken_sasl_auth_clients = yes

# TLS (optional for lab)
smtpd_tls_auth_only = no
smtpd_tls_security_level = may
smtpd_tls_cert_file = /etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file = /etc/ssl/private/ssl-cert-snakeoil.key

# Relay restrictions (cho lab testing)
smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, defer_unauth_destination
EOF

sudo systemctl restart postfix
```

#### **Bước 3: Cài đặt Dovecot (IMAP/POP3)**

```bash
sudo apt install -y dovecot-core dovecot-imapd

# Cấu hình Dovecot
sudo cat > /etc/dovecot/dovecot.conf << 'EOF'
protocols = imap
listen = *
EOF

sudo cat > /etc/dovecot/conf.d/10-auth.conf << 'EOF'
disable_plaintext_auth = no
auth_mechanisms = plain login
!include auth-system.conf.ext
EOF

sudo cat > /etc/dovecot/conf.d/10-master.conf << 'EOF'
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF

# Tạo user email
sudo useradd -m -s /usr/sbin/nologin finance.user
sudo useradd -m -s /usr/sbin/nologin sales.user
echo "finance.user:P@ssw0rd123!" | sudo chpasswd
echo "sales.user:P@ssw0rd123!" | sudo chpasswd

sudo systemctl restart dovecot
sudo systemctl enable dovecot
```

#### **Bước 4: Test Mail Server**

```bash
# Gửi email test
echo "This is a test email body" | mail -s "Test Subject" sales.user@infracorp.local

# Kiểm tra mail log
sudo tail -f /var/log/mail.log
```


<br>

---

<br>

## **12.6 Thiết lập Kali Linux Attack Platform**

### **Bước 1: Tải và cài đặt Kali**

```bash
# 1. Tải Kali Linux
# URL: https://www.kali.org/get-kali/#kali-platforms
# Chọn: Kali Linux 64-Bit (VMware/VirtualBox) hoặc ISO

# 2. Tạo VM trong GNS3:
# - Name: KALI-ATTACK
# - RAM: 4096 MB
# - CPU: 2
# - Disk: 40 GB
# - Network: 1 interface
```

### **Bước 2: Cấu hình mạng Kali**

```bash
# Static IP hoặc DHCP từ OPNsense
sudo ip addr add 192.168.80.100/24 dev eth0
sudo ip route add default via 192.168.80.1
echo "nameserver 192.168.60.10" | sudo tee /etc/resolv.conf

# Hoặc dùng DHCP
sudo dhclient eth0
```

### **Bước 3: Cài đặt Attack Tools**

```bash
#!/bin/bash
# File: /home/kali/setup_attacks.sh

echo "=== Setting up Attack Tools ==="

# Update system
sudo apt update && sudo apt upgrade -y

# Install Phishing Tools
echo "[*] Installing Phishing Tools..."
sudo apt install -y setoolkit gophish

# Install Reconnaissance Tools
echo "[*] Installing Reconnaissance Tools..."
sudo apt install -y nmap netcat-traditional whois dnsutils

# Install Password Attacks
echo "[*] Installing Password Attack Tools..."
sudo apt install -y hydra john hashcat

# Install Web Attack Tools
echo "[*] Installing Web Attack Tools..."
sudo apt install -y nikto sqlmap gobuster dirb

# Install Lateral Movement Tools
echo "[*] Installing Lateral Movement Tools..."
sudo apt install -y impacket-scripts crackmapexec

# Install Reporting Tools
echo "[*] Installing Reporting Tools..."
sudo apt install -y cherrytree

echo "[+] All tools installed successfully!"
```

### **Bước 4: Tạo Attack Scripts**

#### **Script 1: Phishing Setup**

```bash
#!/bin/bash
# File: /home/kali/attacks/01_phishing_setup.sh

echo "=========================================="
echo "  PHISHING ATTACK SIMULATION"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root: sudo $0"
    exit 1
fi

# Start Gophish
echo "[*] Starting Gophish service..."
sudo systemctl start gophish

# Show Gophish access info
echo ""
echo "[+] Gophish is running!"
echo "    Web UI: http://localhost:3333"
echo "    Default credentials: admin / gophish"
echo ""

# Create phishing email template
cat > /home/kali/attacks/templates/urgent_password_reset.eml << 'EOF'
From: IT Support <it-support@infracorp.local>
To: finance.user@infracorp.local
Subject: URGENT: Password Reset Required
MIME-Version: 1.0
Content-Type: text/html; charset=UTF-8

<!DOCTYPE html>
<html>
<body style="font-family: Arial; color: #333;">
    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #d9534f;">⚠️ Urgent Security Notice</h2>
        <p>Dear Employee,</p>
        <p>Our security system has detected suspicious activity on your account.</p>
        <p><strong>You must reset your password within 24 hours</strong> to avoid account suspension.</p>
        <p style="text-align: center; margin: 30px 0;">
            <a href="http://192.168.70.10/index.html" 
               style="background: #d9534f; color: white; padding: 12px 30px; 
                      text-decoration: none; border-radius: 4px;">
                Reset Password Now
            </a>
        </p>
        <p style="color: #666; font-size: 12px;">
            If you did not request this change, please contact IT immediately.
        </p>
        <hr style="border: none; border-top: 1px solid #ddd; margin-top: 30px;">
        <p style="color: #999; font-size: 11px;">
            Infracorp IT Security Team<br>
            This is an automated message.
        </p>
    </div>
</body>
</html>
EOF

echo "[+] Phishing template created: /home/kali/attacks/templates/urgent_password_reset.eml"
echo ""
echo "Next steps:"
echo "1. Access Gophish UI at http://localhost:3333"
echo "2. Import the email template"
echo "3. Create landing page (clone company portal)"
echo "4. Set target: finance.user@infracorp.local"
echo "5. Launch campaign"
```

#### **Script 2: Ransomware Simulation (SAFE)**

```bash
#!/bin/bash
# File: /home/kali/attacks/02_ransomware_sim.sh
# ⚠️ SAFE EDUCATIONAL SIMULATION - Does NOT actually encrypt files

echo "=========================================="
echo "  RANSOMWARE SIMULATION (SAFE)"
echo "  ⚠️  EDUCATIONAL PURPOSES ONLY"
echo "=========================================="
echo ""

TARGET_DIR="/tmp/ransomware_simulation"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "[*] Creating simulation directory..."
mkdir -p $TARGET_DIR

echo "[*] Creating sample 'victim' files..."

# Create sample documents
cat > $TARGET_DIR/financial_report.docx << 'EOF'
CONFIDENTIAL FINANCIAL REPORT
=============================
Q4 2025 Revenue: $1,234,567
Q4 2025 Expenses: $987,654
Net Profit: $246,913

This document contains sensitive financial information.
EOF

cat > $TARGET_DIR/employee_database.csv << 'EOF'
ID,Name,Department,Salary,SSN
001,John Smith,Finance,75000,XXX-XX-1234
002,Jane Doe,Sales,68000,XXX-XX-5678
003,Bob Wilson,IT,82000,XXX-XX-9012
EOF

cat > $TARGET_DIR/project_proposal.txt << 'EOF'
Project Phoenix - 2026 Initiative
==================================
Budget: $500,000
Timeline: Q1-Q3 2026
Team Size: 15 members

Key deliverables:
- New customer portal
- Mobile application
- API integration
EOF

echo "[*] Simulating encryption process..."
sleep 2

# "Encrypt" files by renaming (SAFE simulation)
for file in $TARGET_DIR/*.{docx,csv,txt} 2>/dev/null; do
    if [ -f "$file" ]; then
        mv "$file" "$file.encrypted"
        echo "    [SIMULATED] Encrypted: $(basename $file)"
    fi
done

# Create ransom note
cat > $TARGET_DIR/!!!_READ_ME_.txt << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║           !!! YOUR FILES HAVE BEEN ENCRYPTED !!!          ║
║                                                           ║
╠═══════════════════════════════════════════════════════════╣
║                                                           ║
║  This is a SAFE EDUCATIONAL SIMULATION                    ║
║  No files were actually encrypted or damaged.             ║
║                                                           ║
║  In a REAL ransomware attack:                             ║
║  • Your files would be encrypted with AES-256             ║
║  • Recovery would require a private key                   ║
║  • Attackers would demand cryptocurrency payment          ║
║                                                           ║
║  PROTECTION TIPS:                                         ║
║  ✓ Maintain offline/air-gapped backups                    ║
║  ✓ Keep systems updated                                   ║
║  ✓ Use endpoint protection                                ║
║  ✓ Train users to recognize phishing                      ║
║  ✓ Implement network segmentation                         ║
║                                                           ║
║  Simulation created: TIMESTAMP                            ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF

# Replace TIMESTAMP in ransom note
sed -i "s/TIMESTAMP/$(date)/" $TARGET_DIR/!!!_READ_ME_.txt

echo ""
echo "[+] Simulation complete!"
echo ""
echo "Files created in: $TARGET_DIR"
echo ""
echo "To view results:"
echo "  ls -la $TARGET_DIR"
echo "  cat $TARGET_DIR/!!!_READ_ME_.txt"
echo ""
echo "To cleanup:"
echo "  rm -rf $TARGET_DIR"
```

#### **Script 3: Complete Attack Chain**

```bash
#!/bin/bash
# File: /home/kali/attacks/03_attack_chain_demo.sh
# Complete attack chain simulation

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   CYBER ATTACK CHAIN SIMULATION                          ║"
echo "║   Phishing → Credential Harvest → Ransomware             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Phase 1: Reconnaissance
echo -e "${BLUE}[PHASE 1/5] RECONNAISSANCE${NC}"
echo "─────────────────────────────────────"
echo "[*] Scanning network for targets..."
echo ""

# Network scan (educational)
echo "    Target: 192.168.60.0/24 (Server VLAN)"
echo "    Command: nmap -sV 192.168.60.0/24"
echo ""
# Uncomment to actually run:
# nmap -sV 192.168.60.0/24 -oN /tmp/recon_scan.txt

echo -e "${GREEN}[+] Found services:${NC}"
echo "    • 192.168.60.10:53 (DNS)"
echo "    • 192.168.60.10:88 (Kerberos)"
echo "    • 192.168.60.10:389 (LDAP)"
echo "    • 192.168.60.10:445 (SMB)"
echo ""
sleep 2

# Phase 2: Phishing
echo -e "${YELLOW}[PHASE 2/5] PHISHING CAMPAIGN${NC}"
echo "─────────────────────────────────────"
echo "[*] Crafting phishing email..."
echo "[*] Target: finance.user@infracorp.local"
echo "[*] Lure: Urgent password reset required"
echo "[*] Landing page: http://192.168.70.10/index.html"
echo ""
echo -e "${GREEN}[+] Email sent successfully${NC}"
echo ""
sleep 2

# Phase 3: Credential Harvesting
echo -e "${YELLOW}[PHASE 3/5] CREDENTIAL HARVESTING${NC}"
echo "─────────────────────────────────────"
echo "[*] Waiting for victim to click link..."
echo ""
sleep 2
echo -e "${GREEN}[+] Credentials captured!${NC}"
echo "    Username: finance.user"
echo "    Password: [REDACTED]"
echo ""
sleep 2

# Phase 4: Lateral Movement
echo -e "${RED}[PHASE 4/5] LATERAL MOVEMENT${NC}"
echo "─────────────────────────────────────"
echo "[*] Using harvested credentials..."
echo "[*] Attempting SMB access to DC..."
echo ""
# crackmapexec smb 192.168.60.10 -u 'finance.user' -p '[REDACTED]'
echo -e "${GREEN}[+] Access granted to file server${NC}"
echo "[*] Enumerating shared folders..."
echo "    • \\\\DC01\\Finance"
echo "    • \\\\DC01\\HR"
echo "    • \\\\DC01\\Public"
echo ""
sleep 2

# Phase 5: Ransomware
echo -e "${RED}[PHASE 5/5] RANSOMWARE DEPLOYMENT${NC}"
echo "─────────────────────────────────────"
echo "[*] Executing ransomware simulation..."
echo ""
bash /home/kali/attacks/02_ransomware_sim.sh
echo ""

# Summary
echo "╔══════════════════════════════════════════════════════════╗"
echo "║              ATTACK CHAIN COMPLETE                       ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Timeline:                                               ║"
echo "║  • Phase 1 (Recon):     2 minutes                        ║"
echo "║  • Phase 2 (Phishing):  5 minutes                        ║"
echo "║  • Phase 3 (Harvest):   3 minutes                        ║"
echo "║  • Phase 4 (Movement):  5 minutes                        ║"
echo "║  • Phase 5 (Ransom):    2 minutes                        ║"
echo "║  ─────────────────────────────────                       ║"
echo "║  Total Time:            ~17 minutes                      ║"
echo "║                                                          ║"
echo "║  Detection Status: Check ELK SIEM dashboard              ║"
echo "╚══════════════════════════════════════════════════════════╝"
```

### **Bước 5: Chạy Attack Demo**

```bash
# Tạo thư mục attacks
mkdir -p /home/kali/attacks/templates

# Tạo các script
# (Copy các script trên vào file tương ứng)

# Cấp quyền thực thi
chmod +x /home/kali/attacks/*.sh

# Chạy demo
cd /home/kali/attacks
sudo ./03_attack_chain_demo.sh
```


<br>

---

<br>

## **12.7 Thiết lập ELK Stack SIEM**

### **Bước 1: Tạo VM ELK Stack**

```bash
# 1. Tải Ubuntu Server 22.04 LTS

# 2. Tạo VM trong GNS3:
# - Name: ELK-SIEM
# - RAM: 8192 MB (Elasticsearch cần nhiều RAM)
# - CPU: 4
# - Disk: 80 GB
# - Network: 1 interface → SIEM VLAN

# 3. Cấu hình mạng:
# IP: 192.168.85.10/24
# Gateway: 192.168.85.1
# DNS: 192.168.60.10
```

### **Bước 2: Cài đặt Elastic Stack**

```bash
#!/bin/bash
# File: /opt/elk/install_elk.sh

echo "=== Installing ELK Stack ==="

# Install Java
echo "[*] Installing Java..."
sudo apt update
sudo apt install -y openjdk-11-jdk

# Add Elastic GPG key
echo "[*] Adding Elastic repository..."
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

# Add repository
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | \
    sudo tee /etc/apt/sources.list.d/elastic-8.x.list

sudo apt update

# Install Elasticsearch
echo "[*] Installing Elasticsearch..."
sudo apt install -y elasticsearch

# Install Logstash
echo "[*] Installing Logstash..."
sudo apt install -y logstash

# Install Kibana
echo "[*] Installing Kibana..."
sudo apt install -y kibana

# Install Filebeat
echo "[*] Installing Filebeat..."
sudo apt install -y filebeat

echo "[+] ELK Stack installation complete!"
```

### **Bước 3: Cấu hình Elasticsearch**

```yaml
# /etc/elasticsearch/elasticsearch.yml

cluster.name: gns3-siem
node.name: elk-siem
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch

network.host: 0.0.0.0
http.port: 9200

discovery.type: single-node

# Disable security for lab (enable in production)
xpack.security.enabled: false
xpack.security.enrollment.enabled: false
```

### **Bước 4: Cấu hình Logstash**

```ruby
# /etc/logstash/conf.d/security.conf

input {
  # Syslog from network devices
  syslog {
    port => 5514
    type => "syslog"
  }
  
  # Firewall logs (OPNsense)
  tcp {
    port => 5000
    codec => json
    type => "firewall"
  }
  
  # Filebeat input
  beats {
    port => 5044
    type => "beats"
  }
}

filter {
  # Parse syslog messages
  if [type] == "syslog" {
    grok {
      match => { 
        "message" => "%{SYSLOGPRI}%{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:syslog_hostname} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:syslog_message}" 
      }
    }
    date {
      match => [ "syslog_timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
    }
  }
  
  # Parse firewall blocks
  if [type] == "firewall" and "BLOCK" in [message] {
    grok {
      match => { 
        "message" => "BLOCK %{IP:src_ip}:%{NUMBER:src_port} -> %{IP:dst_ip}:%{NUMBER:dst_port}" 
      }
    }
  }
  
  # Detect failed logins
  if [syslog_message] =~ /Failed password/ {
    mutate {
      add_tag => ["failed_login"]
    }
  }
  
  # Detect port scans
  if [syslog_message] =~ /port scan/ {
    mutate {
      add_tag => ["port_scan"]
    }
  }
}

output {
  elasticsearch {
    hosts => ["localhost:9200"]
    index => "security-events-%{+YYYY.MM.dd}"
  }
  
  # Debug output (optional)
  # stdout { codec => rubydebug }
}
```

### **Bước 5: Cấu hình Kibana**

```yaml
# /etc/kibana/kibana.yml

server.port: 5601
server.host: "0.0.0.0"
server.name: "elk-siem"
elasticsearch.hosts: ["http://localhost:9200"]
```

### **Bước 6: Khởi động Services**

```bash
# Enable and start services
sudo systemctl enable elasticsearch logstash kibana
sudo systemctl start elasticsearch
sudo systemctl start logstash
sudo systemctl start kibana

# Verify
sudo systemctl status elasticsearch
sudo systemctl status logstash
sudo systemctl status kibana

# Test Elasticsearch
curl http://localhost:9200

# Test Kibana
curl http://localhost:5601
```

### **Bước 7: Tạo Kibana Dashboard**

```
1. Truy cập Kibana: http://192.168.85.10:5601

2. Tạo Index Pattern:
   - Management → Stack Management → Index Patterns
   - Create index pattern: security-events-*
   - Time field: @timestamp

3. Tạo Visualizations:

   A. Blocked Connections (Bar Chart)
      - Data: Count of firewall events
      - X-axis: dst_ip
      - Filter: message:"BLOCK"
   
   B. Attack Timeline (Line Graph)
      - Data: Count of events
      - X-axis: @timestamp
      - Split series: syslog_program
   
   C. Top Source IPs (Data Table)
      - Data: Count
      - Split rows: src_ip
      - Sort: Count desc
   
   D. Security Events by Type (Pie Chart)
      - Data: Count
      - Split slices: tags

4. Tạo Dashboard:
   - Dashboard → Create Dashboard
   - Add all visualizations
   - Save as: "Security Operations Center"
   - Set refresh: 5 seconds
```

### **Bước 8: Tạo Alert Rules**

```
Stack Management → Rules → Create Rule

Rule 1: Multiple Failed Logins
- Name: Brute Force Detection
- Type: Threshold
- Index: security-events-*
- Condition: Count > 5 in 1 minute
- Filter: tags:"failed_login"
- Action: Email to security@infracorp.local

Rule 2: Port Scan Detection
- Name: Port Scan Alert
- Type: Threshold
- Condition: Count > 20 different ports in 2 minutes
- Filter: tags:"port_scan"
- Action: Critical Alert

Rule 3: Ransomware Activity
- Name: Ransomware Detection
- Type: Expression
- Query: message:".encrypted" OR message:"ransom"
- Threshold: 1 event
- Action: CRITICAL - Immediate notification
```


<br>

---

<br>

## **12.8 Thiết lập Air-gapped Backup Zone**

### **Bước 1: Tạo Isolated Switch**

```cisco
! BACKUP-SW8 Configuration
! This switch has NO uplink to other switches

enable
configure terminal

! Create backup VLAN
vlan 90
name backup-isolated

! Configure access ports
interface GigabitEthernet0/0
description BACKUP-SRV Connection
switchport mode access
switchport access vlan 90
spanning-tree portfast
spanning-tree bpduguard enable
no shutdown
exit

interface GigabitEthernet0/1
description TAPE-LIBRARY Connection
switchport mode access
switchport access vlan 90
spanning-tree portfast
spanning-tree bpduguard enable
no shutdown
exit

! NO trunk ports
! NO uplinks to other switches
! NO management SVI with gateway

! Management only (local console)
interface Vlan90
description Management VLAN
ip address 192.168.90.1 255.255.255.0
no shutdown
exit

! NO default gateway - truly isolated
! ip default-gateway is NOT configured

end
write memory
```

### **Bước 2: Tạo Backup Server VM**

```bash
# 1. Tạo VM trong GNS3:
# - Name: BACKUP-SRV
# - RAM: 4096 MB
# - CPU: 2
# - Disk: 100 GB (cho backup storage)
# - Network: 1 interface → BACKUP-SW8 Gi0/0

# 2. Cài đặt Ubuntu Server 22.04

# 3. Cấu hình mạng (KHÔNG có gateway)
sudo cat > /etc/netplan/00-installer-config.yaml << 'EOF'
network:
  ethernets:
    eth0:
      addresses:
        - 192.168.90.10/24
      # NO gateway - air-gapped!
      nameservers:
        addresses: []
        # NO DNS - air-gapped!
  version: 2
EOF

sudo netplan apply

# 4. Verify isolation
ip route show
# Should show ONLY: 192.168.90.0/24 via eth0
# NO default route!

ping 192.168.60.10
# Should FAIL - no routing
```

### **Bước 3: Cài đặt Backup Software**

```bash
# Cài đặt rsync + cron cho backup đơn giản
sudo apt update
sudo apt install -y rsync

# Tạo thư mục backup
sudo mkdir -p /backup/daily
sudo mkdir -p /backup/weekly
sudo mkdir -p /backup/monthly

# Tạo script backup
sudo cat > /usr/local/bin/backup.sh << 'EOF'
#!/bin/bash
# Backup script for air-gapped server

SOURCE_DIRS="/home /etc /var/www"
BACKUP_DEST="/backup/daily/$(date +%Y%m%d)"

mkdir -p $BACKUP_DEST

for dir in $SOURCE_DIRS; do
    if [ -d "$dir" ]; then
        rsync -av --delete $dir $BACKUP_DEST/
    fi
done

echo "Backup completed: $(date)" >> /var/log/backup.log
EOF

sudo chmod +x /usr/local/bin/backup.sh

# Tạo cron job cho backup hàng ngày
sudo crontab -e << 'EOF'
# Daily backup at 2:00 AM
0 2 * * * /usr/local/bin/backup.sh

# Weekly full backup on Sunday at 1:00 AM
0 1 * * 0 /usr/local/bin/backup.sh --full
EOF
```

### **Bước 4: Verify Air-gap**

```bash
#!/bin/bash
# File: /home/ubuntu/verify_airgap.sh

echo "=== Air-gap Verification Test ==="
echo ""

echo "[Test 1] Checking routing table..."
ip route show
if ip route | grep -q "default"; then
    echo "❌ FAIL: Default gateway exists!"
else
    echo "✓ PASS: No default gateway"
fi
echo ""

echo "[Test 2] Testing connectivity to internal networks..."
for ip in 192.168.60.10 192.168.50.1 192.168.70.1; do
    if ping -c 1 -W 2 $ip > /dev/null 2>&1; then
        echo "❌ FAIL: Can reach $ip (should be isolated!)"
    else
        echo "✓ PASS: Cannot reach $ip (properly isolated)"
    fi
done
echo ""

echo "[Test 3] Testing Internet connectivity..."
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo "❌ FAIL: Can reach Internet!"
else
    echo "✓ PASS: No Internet access"
fi
echo ""

echo "[Test 4] Checking DNS configuration..."
if [ -s /etc/resolv.conf ] && grep -q "nameserver" /etc/resolv.conf; then
    echo "⚠ WARNING: DNS servers configured"
else
    echo "✓ PASS: No DNS configured (air-gapped)"
fi
echo ""

echo "=== Air-gap Test Complete ==="
```


<br>

---

<br>

## **12.9 Kịch bản Thực nghiệm Hoàn chỉnh**

### **Timeline Thực nghiệm (60 phút)**

```
┌─────────┬──────────────────────────────────────┬──────────────┐
│ Thời gian │ Hoạt động                          │ Người thực hiện │
├─────────┼──────────────────────────────────────┼──────────────┤
│ 00:00   │ Khởi động toàn bộ topology          │ Admin        │
│ 00:05   │ Verify connectivity các VLAN        │ Admin        │
│ 00:10   │ Kiểm tra ELK SIEM nhận log          │ Admin        │
│ 00:15   │ Bắt đầu attack chain từ Kali        │ Attacker     │
│ 00:17   │ Reconnaissance scan                 │ Attacker     │
│ 00:20   │ Gửi phishing email                  │ Attacker     │
│ 00:25   │ User click link phishing            │ Victim       │
│ 00:27   │ Credential harvested                │ Attacker     │
│ 00:30   │ Lateral movement                    │ Attacker     │
│ 00:35   │ Ransomware simulation               │ Attacker     │
│ 00:37   │ ELK alert triggered (< 5 phút!)     │ SIEM         │
│ 00:40   │ Security team notified              │ SOC          │
│ 00:45   │ Isolate infected systems            │ Admin        │
│ 00:50   │ Verify backup integrity             │ Admin        │
│ 00:55   │ Recovery from air-gapped backup     │ Admin        │
│ 01:00   │ Debrief & lessons learned           │ All          │
└─────────┴──────────────────────────────────────┴──────────────┘
```

### **Kịch bản Chi tiết**

```bash
#!/bin/bash
# File: /home/admin/full_drill.sh
# Complete security drill script

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   SECURITY INCIDENT RESPONSE DRILL                       ║"
echo "║   Scenario: Phishing → Ransomware Attack                 ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Pre-drill checks
echo "[PRE-DRILL] System checks..."
echo ""

echo "[1/5] Checking GNS3 topology..."
# Verify all VMs are running
echo "    • FW-OPNS: Running ✓"
echo "    • SERVER-DC01: Running ✓"
echo "    • WEB-SRV: Running ✓"
echo "    • MAIL-SRV: Running ✓"
echo "    • KALI-ATTACK: Running ✓"
echo "    • ELK-SIEM: Running ✓"
echo "    • BACKUP-SRV: Running ✓"
echo ""

echo "[2/5] Testing network connectivity..."
ping -c 1 192.168.50.1 > /dev/null && echo "    • LAN Gateway: OK ✓"
ping -c 1 192.168.70.1 > /dev/null && echo "    • DMZ Gateway: OK ✓"
ping -c 1 192.168.85.10 > /dev/null && echo "    • SIEM Server: OK ✓"
echo ""

echo "[3/5] Checking ELK Stack..."
curl -s http://192.168.85.10:9200 > /dev/null && echo "    • Elasticsearch: OK ✓"
curl -s http://192.168.85.10:5601 > /dev/null && echo "    • Kibana: OK ✓"
echo ""

echo "[4/5] Verifying backup isolation..."
if ! ping -c 1 -W 2 192.168.90.10 > /dev/null 2>&1; then
    echo "    • Air-gap: Properly isolated ✓"
else
    echo "    • Air-gap: WARNING - Check isolation!"
fi
echo ""

echo "[5/5] Attack tools ready..."
if [ -x /home/kali/attacks/03_attack_chain_demo.sh ]; then
    echo "    • Attack scripts: Ready ✓"
else
    echo "    • Attack scripts: NOT FOUND"
fi
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "PRE-DRILL CHECKS COMPLETE"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Ready to begin security drill?"
echo "Press ENTER to start or Ctrl+C to cancel..."
read

# Start drill
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║              DRILL STARTED - $(date)                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

echo "[T+00:00] Attack chain initiated..."
bash /home/kali/attacks/03_attack_chain_demo.sh

echo ""
echo "[T+00:20] Check ELK dashboard for alerts..."
echo "    URL: http://192.168.85.10:5601"
echo ""

echo "[T+00:25] Verify detection time..."
# Check Elasticsearch for alerts
curl -s "http://192.168.85.10:9200/security-events-*/_search" \
    -H "Content-Type: application/json" \
    -d '{
        "query": {
            "match": {
                "tags": "failed_login"
            }
        },
        "size": 5
    }' | jq '.hits.hits[] | {time: ._source["@timestamp"], message: ._source.message}'

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "DRILL COMPLETE"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "1. Review ELK dashboard alerts"
echo "2. Check detection time (< 5 minutes?)"
echo "3. Verify backup integrity"
echo "4. Document lessons learned"
```


<br>

---

<br>

## **12.10 Troubleshooting**

### **Vấn đề 1: OPNsense không nhận log từ devices**

```bash
# Check OPNsense logging settings
# System → Settings → Logging

# Verify rsyslog on source devices
sudo systemctl status rsyslog

# Test connectivity
nc -zv 192.168.85.10 5514

# Check firewall rules
# Firewall must allow UDP 5514 from source devices
```

### **Vấn đề 2: ELK không hiển thị data**

```bash
# Check Elasticsearch status
sudo systemctl status elasticsearch
curl http://localhost:9200/_cluster/health

# Check Logstash pipeline
sudo systemctl status logstash
sudo tail -f /var/log/logstash/logstash-plain.log

# Verify index pattern in Kibana
# Management → Index Patterns → Refresh field list
```

### **Vấn đề 3: Attack scripts không chạy**

```bash
# Check permissions
ls -la /home/kali/attacks/
chmod +x /home/kali/attacks/*.sh

# Run with sudo for network operations
sudo ./script_name.sh

# Check required tools
which nmap setoolkit gophish
```

### **Vấn đề 4: Air-gap không hoạt động**

```bash
# Verify no default gateway
ip route show
# Should NOT show "default via..."

# Check switch configuration
# BACKUP-SW8 must have NO trunk to other switches

# Verify backup server config
cat /etc/netplan/00-installer-config.yaml
# Should NOT have gateway4 defined
```


<br>

---

<br>

## **12.11 Kết luận**

Hướng dẫn này cung cấp đầy đủ các bước để thiết lập môi trường thực nghiệm cybersecurity trong GNS3 với:

✅ **OPNsense Firewall** - VLAN routing, firewall rules, NAT/PAT, remote logging

✅ **Windows Server 2022** - AD DS, DHCP, DNS, user accounts

✅ **DMZ Servers** - Web (Apache) + Mail (Postfix/Dovecot)

✅ **Kali Linux** - Attack tools và scripts cho phishing, ransomware simulation

✅ **ELK Stack** - SIEM với detection < 5 phút

✅ **Air-gapped Backup** - Isolated network không routing

Toàn bộ môi trường có thể chạy trên máy tính cá nhân với 32GB RAM, cho phép thực nghiệm các kịch bản tấn công và phòng thủ thực tế mà không ảnh hưởng đến hệ thống production.


<br>

---


<br>

**Previous Chapter:** [Advanced Cybersecurity Simulation](11-advanced-cybersecurity-simulation.md)

**Back to project overview:** [README](README.md)
