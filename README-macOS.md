# 🍎 NanoPi Neo3 Self-Hosted Server Builder - macOS Edition

A complete one-click solution to build bootable SD card images for NanoPi Neo3 on macOS using Docker. Creates a full-featured self-hosted server with Invoice Ninja, web management interface, and expandable services.

## ✨ What You Get

Your NanoPi Neo3 becomes a complete self-hosted server featuring:

- **📊 Invoice Ninja**: Professional billing and invoicing (SQLite-optimized)
- **🌐 Web Admin UI**: Beautiful, responsive management interface
- **📈 System Monitoring**: Real-time performance metrics
- **🔒 Zero-Trust VPN**: Secure remote access (Tailscale ready)
- **💾 Automated Backups**: Scheduled data protection
- **🤖 AI Assistant**: Natural language system management
- **🔧 Service Manager**: One-click service installation
- **📱 Mobile-Friendly**: Works great on iPhone/iPad

## 🛠 macOS Requirements

### Hardware
- Mac with Intel or Apple Silicon (M1/M2)
- 15GB+ free disk space
- Internet connection
- NanoPi Neo3 device
- MicroSD card (8GB+, Class 10 recommended)

### Software
- **macOS 10.14+** (Mojave or later)
- **Docker Desktop for Mac** (required for cross-compilation)
- **Xcode Command Line Tools** (for basic utilities)

## 🚀 Quick Start (5 Minutes Setup)

### Step 1: Install Prerequisites
```bash
# Install Docker Desktop for Mac
# Download from: https://www.docker.com/products/docker-desktop

# Install Xcode Command Line Tools (if not already installed)
xcode-select --install

# Optional: Install Homebrew for additional tools
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Step 2: Download and Setup
```bash
# Clone the repository
git clone https://github.com/your-repo/nanopi-neo3-builder.git
cd nanopi-neo3-builder

# Make scripts executable
chmod +x *-macos.sh

# Start Docker Desktop and wait for it to be ready
open -a Docker
```

### Step 3: Build Your Image
```bash
# Interactive mode (recommended for first-time users)
./nanopi-invoiceninja-builder-macos.sh

# OR automated mode (no prompts)
./nanopi-invoiceninja-builder-macos.sh --automated
```

**⏱️ Build time: 25-45 minutes** (depending on internet speed)

The build process will:
1. ✅ Check system requirements
2. 🐳 Set up Docker build environment
3. 📦 Install dependencies via Homebrew
4. ⚙️ Configure build settings
5. 🏗️ Build the image using Docker containers
6. 💾 Create compressed bootable image

## 📱 Flashing Your SD Card

### Option 1: Balena Etcher (Recommended - GUI)
1. Download [Balena Etcher](https://www.balena.io/etcher/)
2. Launch Etcher
3. Select your compressed image: `build/nanopi-neo3-invoiceninja.img.xz`
4. Select your SD card
5. Click "Flash!"

### Option 2: Command Line (Advanced)
```bash
# Extract the image
gunzip build/nanopi-neo3-invoiceninja.img.xz

# Find your SD card device
diskutil list

# Unmount the SD card (replace diskX with your device)
diskutil unmountDisk /dev/diskX

# Flash the image (CAREFUL with device selection!)
sudo dd if=build/nanopi-neo3-invoiceninja.img of=/dev/diskX bs=4m

# Safely eject
diskutil eject /dev/diskX
```

⚠️ **CRITICAL WARNING**: Double-check the disk device number! Wrong selection will destroy your Mac's data!

## 🌐 First Boot and Access

### Setup Process
1. **Insert SD card** into NanoPi Neo3
2. **Connect Ethernet** to your network
3. **Power on** the device
4. **Wait 3-5 minutes** for initial setup

### Finding Your Device
```bash
# Scan your network
nmap -sn 192.168.1.0/24

# Look for hostname "nanopi-invoiceninja"
# OR check your router's admin panel
```

### Access Your Server
Once you have the IP address:

- **🎛️ Web Admin UI**: `http://[device-ip]:8080`
- **📊 Invoice Ninja**: `http://[device-ip]`
- **📈 System Monitor**: `http://[device-ip]:19999` (after install)
- **🔧 SSH Access**: `ssh root@[device-ip]`

### Default Credentials
- **Web Admin**: `admin` / `neo3admin123`
- **SSH**: `root` / `invoiceninja123`
- **Invoice Ninja**: Setup wizard on first access

## 🎛️ Web Management Interface

The responsive web interface provides:

### 📊 Dashboard
- Real-time CPU, memory, temperature monitoring
- Service status indicators
- Quick action buttons
- System information overview

### 🔧 Service Management
- Start/stop/restart services
- View service logs in real-time
- Install new services with one click
- Configure service settings

### 📱 Mobile Support
- **iPhone/iPad**: Perfect for quick monitoring
- **Mac**: Full administration capabilities
- **Responsive design**: Works on all screen sizes

## 🛠 Installing Additional Services

### Via Web Interface
1. Open Web Admin UI at `http://[device-ip]:8080`
2. Go to "Quick Actions" section
3. Click desired service button:
   - **System Monitoring**: Advanced metrics with Netdata
   - **VPN Service**: Zero-trust access with Tailscale
   - **Automated Backup**: Data protection with Restic
   - **File Server**: Object storage with MinIO
   - **Private DNS**: Ad-blocking with Pi-hole
   - **AI Assistant**: Natural language management

### Via SSH
```bash
# SSH into your device
ssh root@[device-ip]

# Run the service installer
service-installer.sh

# Follow the interactive menu
```

## 🔧 macOS-Specific Features

### Docker Integration
- Cross-compilation happens inside Docker containers
- No need for ARM64 toolchains on your Mac
- Clean, isolated build environment
- Automatic cleanup after build

### Homebrew Integration
- Automatic installation of required tools
- Optimal versions for macOS compatibility
- Easy updates and maintenance

### Native macOS Tools
- Uses macOS `diskutil` for SD card management
- Optimized for macOS filesystem permissions
- Compatible with macOS security features

## 🔒 Security Best Practices

### First Boot Setup
```bash
# SSH into your device
ssh root@[device-ip]

# Change root password
passwd root

# Change web admin password via web interface
# Settings → Change Password
```

### Setup VPN Access
```bash
# Install Tailscale VPN for secure remote access
service-installer.sh
# Choose option 1 (VPN)
# Follow authentication prompts
```

### Configure Firewall
```bash
# View current firewall rules
ufw status

# The firewall is pre-configured with secure defaults:
# - Port 22: SSH access
# - Port 80: HTTP (Invoice Ninja)
# - Port 8080: Web Admin UI
# - Port 443: HTTPS (when configured)
```

## 🚀 Performance Optimization

### For Heavy Usage
The system is pre-optimized for the Neo3's ARM64 architecture and limited resources:

- **Memory Management**: Aggressive swap configuration
- **CPU Scaling**: Dynamic frequency scaling
- **I/O Optimization**: SSD-optimized filesystem settings
- **Network Tuning**: Optimized for Gigabit Ethernet

### Resource Monitoring
- Real-time monitoring via Web Admin UI
- Detailed metrics with optional Netdata installation
- Mobile alerts and notifications

## 📊 Troubleshooting

### Build Issues on macOS
```bash
# Ensure Docker is running
docker info

# Check available disk space
df -h .

# Clean Docker system if needed
docker system prune -a

# Rebuild from scratch
rm -rf build/
./nanopi-invoiceninja-builder-macos.sh
```

### SD Card Issues
```bash
# If SD card isn't detected
diskutil list

# Force unmount if stuck
sudo diskutil unmountDisk force /dev/diskX

# Repair SD card if corrupted
sudo diskutil repairDisk /dev/diskX
```

### Network Issues
```bash
# On the Neo3 device (via SSH or console)
# Check network interface
ip addr show

# Restart networking
sudo systemctl restart networking

# Check DHCP client
sudo systemctl status dhcpcd
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

# Restart services
systemctl restart neo3-admin
```

## 🔄 Updates and Maintenance

### Updating the Build System
```bash
# Pull latest changes
git pull origin main

# Rebuild with latest updates
./nanopi-invoiceninja-builder-macos.sh
```

### System Updates (on Neo3)
```bash
# SSH into device
ssh root@[device-ip]

# Update system packages
apt update && apt upgrade -y

# Update Invoice Ninja (when new versions available)
# Use the web interface or follow Invoice Ninja docs
```

## 🎯 Advanced Configuration

### Custom Configuration
Edit `config.conf` before building:
```bash
# Key settings you might want to change:
ROOT_PASSWORD="your-secure-password"
HOSTNAME="your-device-name"
TIMEZONE="America/New_York"
WEB_UI_PASS="your-admin-password"
IMAGE_SIZE="8G"  # For larger SD cards
```

### Custom Services
Add your own services to the Docker build:
1. Edit `build-nanopi-invoiceninja-macos.sh`
2. Add your installation commands
3. Rebuild the image

### Development Mode
For testing and development:
```bash
# Enable development features in config.conf
ENABLE_XDEBUG="true"
ENABLE_DEBUG_TOOLS="true"
LOG_LEVEL="debug"

# Rebuild with development settings
./nanopi-invoiceninja-builder-macos.sh
```

## 📚 Additional Resources

### Documentation
- [Invoice Ninja Documentation](https://invoiceninja.github.io/)
- [NanoPi Neo3 Hardware Guide](http://wiki.friendlyarm.com/wiki/index.php/NanoPi_NEO3)
- [Docker Desktop for Mac](https://docs.docker.com/desktop/mac/)

### Community
- [Invoice Ninja Community](https://forum.invoiceninja.com/)
- [FriendlyElec Forum](http://www.friendlyarm.com/Forum/)

### Support
- Check the troubleshooting section above
- Review log files for detailed error information
- Create issues on the project repository

## 🎉 Success Stories

Once set up, your Neo3 server provides:

- **Professional invoicing** for small businesses
- **Remote access** via VPN from anywhere
- **Automated backups** for peace of mind
- **System monitoring** for proactive maintenance
- **Mobile management** for on-the-go administration
- **Expandable platform** for additional services

## 🏆 Why This macOS Version?

- **Native macOS integration** - Works seamlessly with your Mac workflow
- **Docker-based builds** - Clean, reproducible, no system pollution
- **Cross-compilation** - ARM64 images built on Intel/Apple Silicon
- **macOS-optimized tools** - Uses diskutil, Homebrew, native utilities
- **Security-first** - Leverages macOS security features
- **Developer-friendly** - Easy to customize and extend

---

**🚀 Ready to transform your NanoPi Neo3 into a powerful self-hosted server? Get started now!**

```bash
./nanopi-invoiceninja-builder-macos.sh
```

**Need help?** Check the troubleshooting section or create an issue on GitHub.

**🔒 Remember**: Change all default passwords after first boot for security!
