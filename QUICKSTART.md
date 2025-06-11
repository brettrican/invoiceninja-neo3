# 🚀 NanoPi Neo3 Self-Hosted Server - Quick Start Guide

This guide will get your NanoPi Neo3 running as a complete self-hosted server with Invoice Ninja, web management interface, and additional services in under 30 minutes.

## 📋 What You'll Get

Your Neo3 will be a complete self-hosted server featuring:

- **📊 Invoice Ninja**: Professional billing and invoicing
- **🌐 Web Admin UI**: Comprehensive management interface
- **📈 System Monitoring**: Real-time performance metrics
- **🔒 Zero-Trust VPN**: Secure remote access (Tailscale)
- **💾 Automated Backups**: Scheduled data protection
- **🤖 AI Assistant**: Natural language system management
- **🔧 Service Manager**: One-click service installation
- **📱 Mobile-Friendly**: Responsive web interface

## 🛠 Prerequisites

### Hardware Required
- NanoPi Neo3 (1GB RAM minimum)
- MicroSD card (8GB+, Class 10 recommended)
- Ethernet cable
- Power supply (5V/2A)

### Software Required (on your computer)
- Linux/macOS/WSL (Windows Subsystem for Linux)
- `sudo` access
- Internet connection
- SD card reader

## ⚡ One-Click Build Process

### Step 1: Download and Setup
```bash
# Clone or download the builder
git clone https://github.com/your-repo/nanopi-neo3-builder.git
# OR download and extract the ZIP file

cd nanopi-neo3-builder
chmod +x *.sh
```

### Step 2: Integrate Web UI (One-time setup)
```bash
# Run the integration script to add web management
sudo ./integrate-web-ui.sh
```

### Step 3: Customize Configuration (Optional)
```bash
# Edit settings if desired
nano config.conf

# Key settings you might want to change:
# - ROOT_PASSWORD: Change from default
# - HOSTNAME: Your device name
# - TIMEZONE: Your local timezone
# - WEB_UI_PASS: Web interface password
```

### Step 4: Build Your Image
```bash
# Interactive mode (recommended for first-time users)
sudo ./nanopi-invoiceninja-builder.sh --interactive

# OR automated mode (no prompts)
sudo ./nanopi-invoiceninja-builder.sh --automated
```

The build process will:
1. ✅ Check system requirements
2. 📦 Install dependencies
3. 🧪 Run tests
4. ⚙️ Configure settings
5. 🏗️ Build the bootable image
6. 💾 Offer to flash to SD card

**⏱️ Build time: 15-30 minutes** (depending on internet speed)

### Step 5: Flash to SD Card
```bash
# The builder can do this automatically, or manually:
sudo dd if=build/nanopi-neo3-invoiceninja.img of=/dev/sdX bs=4M status=progress

# Replace /dev/sdX with your actual SD card device
# Use 'lsblk' to find the correct device
```

## 🔌 First Boot Setup

1. **Insert SD card** into Neo3
2. **Connect Ethernet** cable to your network
3. **Power on** the device
4. **Wait 2-3 minutes** for initial setup

The system will:
- Auto-configure network (DHCP)
- Start all services
- Generate SSL certificates
- Setup firewall rules
- Display welcome message

## 🌐 Access Your Server

### Find Your Device IP
```bash
# Scan your network (from your computer)
nmap -sn 192.168.1.0/24

# OR check your router's admin panel
# OR check the device console if connected
```

### Access Points
Once you have the IP address:

- **🌐 Web Admin UI**: `http://[device-ip]:8080`
- **📊 Invoice Ninja**: `http://[device-ip]`
- **📈 System Monitor**: `http://[device-ip]:19999`
- **🔧 SSH Access**: `ssh root@[device-ip]`

### Default Credentials
- **Web Admin**: `admin` / `neo3admin123`
- **Root SSH**: `root` / `invoiceninja123`
- **Invoice Ninja**: Setup wizard on first access

## 🎛️ Web Management Interface

The web interface provides:

### Dashboard
- Real-time CPU, memory, disk usage
- Service status indicators
- Quick action buttons
- System information

### Service Management
- Start/stop/restart services
- View service logs
- Install new services
- Configure service settings

### Quick Actions
- **Install VPN**: One-click Tailscale setup
- **Setup Monitoring**: Advanced system monitoring
- **Configure Backup**: Automated backup setup
- **Add Services**: File server, DNS, proxy, etc.

## 🔧 Installing Additional Services

### Via Web Interface
1. Open Web Admin UI
2. Go to "Quick Actions" section
3. Click desired service button
4. Follow setup prompts

### Via Command Line
```bash
# SSH into your Neo3
ssh root@[device-ip]

# Run service installer
service-installer.sh

# Follow interactive menu
```

### Available Services
- **Zero-Trust VPN** (Tailscale): Secure remote access
- **System Monitoring** (Netdata): Advanced metrics
- **File Server** (MinIO): Object storage
- **Automated Backup** (Restic): Data protection
- **AI Assistant**: Natural language management
- **Private DNS** (Pi-hole): Ad blocking DNS
- **Reverse Proxy** (Traefik): Service routing

## 📱 Mobile Access

The web interface is fully responsive:
- **📱 Phone**: Quick monitoring and basic controls
- **📱 Tablet**: Full administration capabilities
- **💻 Desktop**: Complete management interface

## 🔒 Security First Steps

### Change Default Passwords
```bash
# SSH into device
passwd root  # Change root password

# Via web interface:
# 1. Login to Web Admin UI
# 2. Go to Settings
# 3. Change admin password
```

### Setup VPN Access
```bash
# Install Tailscale VPN
service-installer.sh
# Choose option 1 (VPN)
# Follow authentication prompts
```

### Configure Firewall
The firewall is pre-configured but you can adjust:
```bash
ufw status                    # Check current rules
ufw allow [port]/tcp         # Allow specific port
ufw deny [port]/tcp          # Deny specific port
```

## 🔧 Troubleshooting

### Build Issues
```bash
# Check system requirements
./test-build.sh

# Clean and retry
sudo rm -rf build/
sudo ./nanopi-invoiceninja-builder.sh
```

### Boot Issues
- Ensure SD card is properly flashed
- Check power supply (5V/2A minimum)
- Wait full 3 minutes for first boot
- Check ethernet connection

### Network Issues
```bash
# Check IP address (on device console)
ip addr show

# Restart networking
systemctl restart networking

# Check DHCP client
systemctl status dhcpcd
```

### Service Issues
```bash
# Check service status
systemctl status neo3-admin
systemctl status nginx
systemctl status php8.1-fpm

# View logs
journalctl -u neo3-admin -f
journalctl -u nginx -f
```

## 📊 Performance Optimization

### For Heavy Usage
```bash
# Increase swap (if needed)
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Add to /etc/fstab for persistence
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

### Resource Monitoring
- Use Web Admin UI dashboard
- Access Netdata at `:19999`
- Monitor via SSH: `htop`, `iotop`, `free -h`

## 🆘 Getting Help

### Log Files
- System: `/var/log/syslog`
- Neo3 Admin: `journalctl -u neo3-admin`
- Nginx: `/var/log/nginx/`
- Invoice Ninja: `/var/www/ninja/storage/logs/`

### Common Commands
```bash
# Restart web interface
systemctl restart neo3-admin

# Restart web server
systemctl restart nginx php8.1-fpm

# Check disk space
df -h

# Check memory usage
free -h

# Check running processes
htop
```

## 🎉 You're Done!

Your NanoPi Neo3 is now a complete self-hosted server! 

### Next Steps:
1. **Secure**: Change all default passwords
2. **Backup**: Configure automated backups
3. **Monitor**: Set up monitoring alerts
4. **Expand**: Install additional services as needed
5. **Access**: Setup VPN for remote access

### Pro Tips:
- Regular backups are automatically scheduled
- Use the AI assistant for natural language commands
- Mobile interface works great for quick checks
- VPN access allows management from anywhere

**Enjoy your self-hosted server! 🚀**

---

*Need help? Check the troubleshooting section above or examine the log files for detailed error information.*
