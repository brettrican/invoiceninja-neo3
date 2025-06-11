#!/bin/bash
# Integration script to add Web UI and Service Management to the Neo3 build

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INTEGRATION]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

update_config() {
    log "Updating configuration to include Web UI..."
    
    # Add Web UI configuration to config.conf
    if ! grep -q "INSTALL_WEB_UI" config.conf; then
        cat >> config.conf << 'EOF'

# Web Management UI Configuration
INSTALL_WEB_UI=yes
WEB_UI_PORT=8080
WEB_UI_USER=admin
WEB_UI_PASS=neo3admin123

# Service Management
INSTALL_SERVICES=yes
DEFAULT_SERVICES="monitoring,backup,vpn"

# AI Agent Configuration  
ENABLE_AI_AGENT=yes
AI_AGENT_PORT=8081

# Resource Monitoring
ENABLE_MONITORING=yes
MONITORING_PORT=19999

# Backup Configuration
ENABLE_BACKUP=yes
BACKUP_SCHEDULE="0 2 * * *"
EOF
        success "Configuration updated"
    else
        log "Web UI configuration already exists"
    fi
}

update_build_script() {
    log "Updating build script to include Web UI installation..."
    
    # Create a patch file for the build script
    cat > build-script-patch.sh << 'EOF'
#!/bin/bash
# Patch to add Web UI installation to the build process

add_web_ui_to_build() {
    local build_script="build-nanopi-invoiceninja.sh"
    
    # Find the line where we should add the Web UI installation
    local insert_line=$(grep -n "Final system optimizations" "$build_script" | cut -d: -f1)
    
    if [ -n "$insert_line" ]; then
        # Create temporary file with Web UI installation
        cat > web_ui_install_block.tmp << 'WEBUI_EOF'

# Install Web Management UI and Services
log "Installing Web Management UI..."
if [ -f "/tmp/build-files/web-management-ui.sh" ]; then
    chmod +x /tmp/build-files/web-management-ui.sh
    chroot "$ROOTFS_DIR" /tmp/build-files/web-management-ui.sh
else
    warn "Web Management UI installer not found"
fi

# Install Service Manager
log "Installing Service Management System..."
if [ -f "/tmp/build-files/service-installer.sh" ]; then
    cp /tmp/build-files/service-installer.sh "$ROOTFS_DIR/usr/local/bin/"
    chmod +x "$ROOTFS_DIR/usr/local/bin/service-installer.sh"
fi

# Copy additional scripts
cp /tmp/build-files/*.sh "$ROOTFS_DIR/opt/neo3-scripts/" 2>/dev/null || true
chmod +x "$ROOTFS_DIR/opt/neo3-scripts/"*.sh 2>/dev/null || true

WEBUI_EOF
        
        # Insert the Web UI block before final optimizations
        head -n $((insert_line - 1)) "$build_script" > "$build_script.tmp"
        cat web_ui_install_block.tmp >> "$build_script.tmp"
        tail -n +$insert_line "$build_script" >> "$build_script.tmp"
        
        mv "$build_script.tmp" "$build_script"
        rm -f web_ui_install_block.tmp
        
        success "Build script updated with Web UI installation"
    else
        warn "Could not find insertion point in build script"
    fi
}

add_web_ui_to_build
EOF

    chmod +x build-script-patch.sh
    ./build-script-patch.sh
    rm -f build-script-patch.sh
}

create_startup_script() {
    log "Creating startup script for first boot configuration..."
    
    cat > first-boot-setup.sh << 'EOF'
#!/bin/bash
# First boot setup script for Neo3 system

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/neo3-setup.log; }

# Wait for network
log "Waiting for network connectivity..."
for i in {1..30}; do
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log "Network is ready"
        break
    fi
    sleep 2
done

# Start essential services
log "Starting essential services..."
systemctl enable neo3-admin 2>/dev/null || true
systemctl start neo3-admin 2>/dev/null || true

# Configure firewall for web access
log "Configuring firewall..."
ufw allow 8080/tcp comment "Neo3 Admin UI"
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"
ufw allow 22/tcp comment "SSH"

# Get IP address and display welcome message
IP_ADDRESS=$(hostname -I | awk '{print $1}')
log "System ready! Access Web UI at: http://$IP_ADDRESS:8080"

# Create welcome message
cat > /etc/motd << MOTD_EOF

┌─────────────────────────────────────────────────────────────┐
│                    NanoPi Neo3 Server                       │
│                   Invoice Ninja Ready                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  🌐 Web Admin UI:    http://$IP_ADDRESS:8080          │
│  📊 Invoice Ninja:   http://$IP_ADDRESS                │
│  📈 Monitoring:      http://$IP_ADDRESS:19999         │
│                                                             │
│  Default Login: admin / neo3admin123                        │
│                                                             │
│  🔧 Service Manager: sudo service-installer.sh             │
│  📋 Logs:           journalctl -u neo3-admin               │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  Remember to change default passwords!                      │
└─────────────────────────────────────────────────────────────┘

MOTD_EOF

# Disable this service after first run
systemctl disable neo3-first-boot 2>/dev/null || true

log "First boot setup completed successfully"
EOF

    # Create systemd service for first boot
    cat > neo3-first-boot.service << 'EOF'
[Unit]
Description=Neo3 First Boot Setup
After=network.target
Wants=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/first-boot-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    success "First boot setup script created"
}

update_documentation() {
    log "Updating documentation..."
    
    # Update README with new features
    cat >> README.md << 'EOF'

## 🌐 Web Management Interface

The Neo3 system includes a comprehensive web-based management interface:

### Features
- **System Monitoring**: Real-time CPU, memory, and disk usage
- **Service Management**: Start, stop, and restart services
- **Log Viewing**: View system and service logs
- **Quick Actions**: Install additional services with one click
- **AI Assistant**: Natural language system management (experimental)

### Access
- Web UI: `http://[device-ip]:8080`
- Default Login: `admin` / `neo3admin123`

### Available Services
- **Invoice Ninja**: Main billing application
- **System Monitoring**: Real-time performance metrics
- **Zero-Trust VPN**: Secure remote access via Tailscale
- **File Server**: Object storage with MinIO
- **Automated Backup**: Scheduled backups with Restic
- **AI Assistant**: Natural language system management
- **Private DNS**: Ad-blocking DNS with Pi-hole
- **Reverse Proxy**: Service routing with Traefik

### Service Installation
Use the service installer to add new capabilities:
```bash
sudo service-installer.sh
```

Or install specific services via the web interface.

## 🔧 Advanced Configuration

### Resource Optimization
The system is optimized for the Neo3's limited resources:
- Minimal service footprint
- Aggressive memory management
- SSD-optimized I/O
- Network performance tuning

### Security Features
- UFW firewall configured
- Fail2ban for intrusion prevention
- Secure default configurations
- Regular security updates

### Backup System
Automated backups include:
- System configurations
- User data
- Service configurations
- Invoice Ninja database

## 🚀 Quick Start Guide

1. **First Boot**: Wait 2-3 minutes for initial setup
2. **Find IP**: Check your router or use `nmap`
3. **Access Web UI**: Open `http://[ip]:8080`
4. **Change Passwords**: Update default credentials
5. **Install Services**: Use web interface or CLI tool
6. **Configure Backups**: Set up remote backup storage

## 📱 Mobile Access

The web interface is mobile-responsive and works great on:
- Tablets for administration
- Phones for quick monitoring
- Desktop for full management

EOF

    success "Documentation updated"
}

create_test_script() {
    log "Creating integration test script..."
    
    cat > test-integration.sh << 'EOF'
#!/bin/bash
# Integration test for Web UI and Service Management

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "[TEST] $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

test_web_ui_files() {
    log "Testing Web UI file creation..."
    
    local required_files=(
        "web-management-ui.sh"
        "service-installer.sh"
        "integrate-web-ui.sh"
        "first-boot-setup.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            success "✓ $file exists"
        else
            error "✗ $file missing"
        fi
    done
}

test_config_updates() {
    log "Testing configuration updates..."
    
    if grep -q "INSTALL_WEB_UI" config.conf; then
        success "✓ Web UI configuration added"
    else
        error "✗ Web UI configuration missing"
    fi
    
    if grep -q "INSTALL_SERVICES" config.conf; then
        success "✓ Service configuration added"
    else
        error "✗ Service configuration missing"
    fi
}

test_script_permissions() {
    log "Testing script permissions..."
    
    local scripts=("web-management-ui.sh" "service-installer.sh" "integrate-web-ui.sh")
    
    for script in "${scripts[@]}"; do
        if [ -x "$script" ]; then
            success "✓ $script is executable"
        else
            warn "Making $script executable"
            chmod +x "$script"
        fi
    done
}

test_syntax() {
    log "Testing script syntax..."
    
    local scripts=("web-management-ui.sh" "service-installer.sh")
    
    for script in "${scripts[@]}"; do
        if bash -n "$script"; then
            success "✓ $script syntax is valid"
        else
            error "✗ $script has syntax errors"
        fi
    done
}

main() {
    echo "========================================"
    echo "Web UI Integration Test Suite"
    echo "========================================"
    
    test_web_ui_files
    test_config_updates
    test_script_permissions
    test_syntax
    
    echo
    success "All integration tests passed!"
    echo
    echo "You can now build your Neo3 image with:"
    echo "  sudo ./nanopi-invoiceninja-builder.sh"
    echo
}

main "$@"
EOF

    chmod +x test-integration.sh
    success "Integration test script created"
}

main() {
    if [ "$EUID" -ne 0 ]; then
        error "This integration script must be run as root"
    fi
    
    echo "========================================"
    echo "Neo3 Web UI Integration"
    echo "========================================"
    echo
    
    log "Integrating Web Management UI into Neo3 build system..."
    echo
    
    update_config
    update_build_script
    create_startup_script
    update_documentation
    create_test_script
    
    # Make scripts executable
    chmod +x *.sh 2>/dev/null || true
    
    echo
    success "Integration completed successfully!"
    echo
    echo "🎉 Your Neo3 build system now includes:"
    echo "   • Web-based management interface"
    echo "   • Service installation system"
    echo "   • AI assistant integration"
    echo "   • First-boot configuration"
    echo "   • Comprehensive monitoring"
    echo
    echo "Next steps:"
    echo "1. Run integration tests: ./test-integration.sh"
    echo "2. Build your image: sudo ./nanopi-invoiceninja-builder.sh"
    echo "3. Flash to SD card and boot your Neo3!"
    echo
    warn "Remember to change default passwords after first boot!"
}

main "$@"
