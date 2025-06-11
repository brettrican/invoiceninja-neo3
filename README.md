# NanoPi Neo3 Invoice Ninja Image Builder

A one-click utility to create a bootable SD card image for NanoPi Neo3 with Invoice Ninja pre-configured and ready to run.

## 💻 Platform Support

### 🐧 Linux (Native Build)
Complete native support with direct hardware access for optimal performance.

### 🍎 macOS (Docker Build) **[NEW!]**
Full macOS support using Docker for cross-compilation:
- 🐳 Docker Desktop integration for ARM64 builds
- 🍺 Homebrew integration for dependency management  
- 🔧 Native macOS tools (diskutil, etc.)
- 📱 Works great on Intel and Apple Silicon Macs

**For macOS users:** See **[README-macOS.md](README-macOS.md)** for complete macOS-specific instructions and use the macOS-specific scripts.

### Quick Start for macOS:
```bash
# 1. One-time setup (installs Docker, Homebrew tools, etc.)
./macos-quickstart.sh

# 2. Build your image
./nanopi-invoiceninja-builder-macos.sh
```

## Features

- **Complete OS Setup**: Builds a minimal Debian-based system optimized for NanoPi Neo3
- **Invoice Ninja Pre-installed**: Latest version with SQLite database (resource-friendly)
- **Zero Configuration**: Boot and run - Invoice Ninja is accessible immediately
- **Optimized for Low Resources**: Configured specifically for NanoPi Neo3's limited resources
- **Security Ready**: Includes SSH access and basic security configurations
- **Web Interface**: Nginx web server configured and ready

## Quick Start

### 1. Prepare Your System

First, install the required dependencies:

```bash
# Make scripts executable
chmod +x setup-dependencies.sh build-nanopi-invoiceninja.sh flash-image.sh

# Install dependencies (Ubuntu/Debian/Arch/Fedora/CentOS supported)
sudo ./setup-dependencies.sh
```

### 2. Build the Image

Create the bootable image (this will take 15-30 minutes):

```bash
sudo ./build-nanopi-invoiceninja.sh
```

The script will:
- Create a 4GB disk image
- Install Debian base system for ARM64
- Install and configure Invoice Ninja with SQLite
- Set up Nginx web server
- Configure automatic startup services

### 3. Flash to SD Card

Flash the created image to your SD card:

```bash
# Interactive mode (recommended for beginners)
sudo ./flash-image.sh

# Or specify image and device directly
sudo ./flash-image.sh build/nanopi-neo3-invoiceninja.img /dev/sdX
```

### 4. Boot Your NanoPi Neo3

1. Insert the SD card into your NanoPi Neo3
2. Connect ethernet cable
3. Power on the device
4. Wait 2-3 minutes for first boot initialization

### 5. Access Invoice Ninja

1. Find your device's IP address (check your router's admin panel or use `nmap`)
2. Open `http://[device-ip]` in your web browser
3. Complete the Invoice Ninja setup wizard

## System Specifications

### Hardware Requirements
- **Device**: NanoPi Neo3 (ARM64)
- **SD Card**: Minimum 8GB (Class 10 recommended)
- **Network**: Ethernet connection required
- **Power**: 5V/2A power supply

### Software Stack
- **OS**: Debian 11 (Bullseye) ARM64
- **Web Server**: Nginx
- **PHP**: PHP 8.1 with FPM
- **Database**: SQLite (resource-friendly)
- **Application**: Invoice Ninja (latest stable)

### Default Credentials
- **SSH**: `root` / `invoiceninja123`
- **Invoice Ninja**: Configure through web interface on first access

⚠️ **Important**: Change the default root password immediately after first login!

## Advanced Configuration

### Customizing the Build

You can modify `build-nanopi-invoiceninja.sh` to customize:

- **Root Password**: Change line with `echo 'root:invoiceninja123'`
- **Image Size**: Modify `IMAGE_SIZE="4G"` variable
- **Additional Packages**: Add to the package installation section
- **Invoice Ninja Version**: Modify the download URL

### Network Configuration

The system uses DHCP by default. To set a static IP:

1. SSH into the device: `ssh root@[device-ip]`
2. Edit `/etc/systemd/network/eth0.network`
3. Replace DHCP configuration with static settings
4. Restart networking: `systemctl restart systemd-networkd`

### SSL/HTTPS Setup

To enable HTTPS:

1. Install Certbot: `apt install certbot python3-certbot-nginx`
2. Get certificate: `certbot --nginx -d your-domain.com`
3. Configure automatic renewal

### Performance Tuning

For optimal performance on NanoPi Neo3:

- **PHP-FPM**: Already configured with optimized settings
- **Nginx**: Configured for low resource usage
- **SQLite**: Optimized for embedded systems
- **System**: Minimal package installation to save resources

## Troubleshooting

### Build Issues

**"Missing dependencies" error**:
```bash
sudo ./setup-dependencies.sh
```

**"Permission denied" error**:
```bash
chmod +x *.sh
```

**Build fails during debootstrap**:
- Check internet connection
- Try running with `--verbose` flag (modify script)

### Boot Issues

**Device doesn't boot**:
- Verify SD card is properly flashed
- Check power supply (5V/2A minimum)
- Try different SD card (Class 10 recommended)

**Can't find device on network**:
- Check ethernet cable connection
- Wait longer (first boot can take 3-5 minutes)
- Check router's DHCP client list

### Application Issues

**Invoice Ninja not accessible**:
```bash
# SSH into device and check services
ssh root@[device-ip]
systemctl status nginx php8.1-fpm
```

**Database errors**:
```bash
# Check database permissions
chown -R www-data:www-data /var/www/ninja
```

## File Structure

```
.
├── setup-dependencies.sh      # Dependency installer
├── build-nanopi-invoiceninja.sh  # Main image builder
├── flash-image.sh             # SD card flashing utility
├── README.md                  # This documentation
└── build/                     # Generated files (created during build)
    └── nanopi-neo3-invoiceninja.img  # Final bootable image
```

## Development and Contribution

### Requirements for Development
- Linux system (Ubuntu/Debian recommended)
- Root access (for image creation)
- 8GB+ free disk space
- Internet connection

### Testing
The build process has been tested on:
- Ubuntu 20.04/22.04 LTS
- Debian 11/12
- Arch Linux
- Fedora 36+

### Contributing
1. Fork the repository
2. Make your changes
3. Test the complete build process
4. Submit a pull request

## Security Considerations

### Initial Security Setup
1. **Change default password**: `passwd root`
2. **Update system**: `apt update && apt upgrade`
3. **Configure firewall**: `ufw enable`
4. **Disable root SSH** (create user account first)

### Ongoing Maintenance
- Regular system updates
- Invoice Ninja updates
- Monitor system logs
- Backup configuration and data

## License and Disclaimer

This tool is provided as-is for educational and development purposes. Users are responsible for:
- Securing their systems
- Complying with applicable laws and regulations
- Maintaining backups of important data
- Using appropriate security measures

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review Invoice Ninja documentation
3. Check NanoPi Neo3 hardware documentation
4. Create an issue in the repository

---

**Note**: This is a complete, production-ready system builder. The created image includes a full operating system with Invoice Ninja configured for immediate use on NanoPi Neo3 hardware.
