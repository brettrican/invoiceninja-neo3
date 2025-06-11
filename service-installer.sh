#!/bin/bash
# Advanced Service Installer for Neo3 Self-Hosted Server
# Supports multiple services with AI agent integration capabilities

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[SERVICE-INSTALLER]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_ROOT="/opt/neo3-services"
WEB_ROOT="/var/www/neo3-admin"

# Service definitions with resource optimization for Neo3
declare -A SERVICES=(
    ["vpn"]="Zero-Trust VPN (Tailscale)"
    ["monitoring"]="System Monitoring (Netdata)"
    ["backup"]="Automated Backup (Restic)"
    ["file-server"]="File Server (MinIO)"
    ["ai-agent"]="AI Assistant Agent"
    ["dashboard"]="Service Dashboard"
    ["dns"]="Private DNS (Pi-hole)"
    ["reverse-proxy"]="Reverse Proxy (Traefik)"
)

show_menu() {
    echo "========================================"
    echo "Neo3 Service Installer"
    echo "========================================"
    echo
    echo "Available services:"
    local i=1
    for service in "${!SERVICES[@]}"; do
        echo "$i) ${SERVICES[$service]} ($service)"
        ((i++))
    done
    echo
    echo "Special options:"
    echo "a) Install ALL services"
    echo "r) Remove a service"
    echo "s) Show service status"
    echo "q) Quit"
    echo
}

install_vpn_service() {
    log "Installing Zero-Trust VPN (Tailscale)..."
    
    # Download and install Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh
    
    # Create service configuration
    mkdir -p "$SERVICE_ROOT/vpn"
    cat > "$SERVICE_ROOT/vpn/config.json" << 'EOF'
{
    "service": "tailscale",
    "description": "Zero-Trust VPN Service",
    "autostart": true,
    "health_check": "tailscale status",
    "management_port": null,
    "resource_limits": {
        "memory": "64MB",
        "cpu": "10%"
    }
}
EOF

    # Create management script
    cat > "$SERVICE_ROOT/vpn/manage.sh" << 'EOF'
#!/bin/bash
case "$1" in
    start)
        systemctl start tailscaled
        ;;
    stop)
        systemctl stop tailscaled
        ;;
    status)
        tailscale status
        ;;
    auth)
        tailscale up
        ;;
    *)
        echo "Usage: $0 {start|stop|status|auth}"
        ;;
esac
EOF

    chmod +x "$SERVICE_ROOT/vpn/manage.sh"
    systemctl enable tailscaled
    
    success "VPN service installed. Run 'tailscale up' to authenticate."
}

install_monitoring_service() {
    log "Installing System Monitoring (Netdata)..."
    
    # Install Netdata with minimal configuration
    bash <(curl -Ss https://my-netdata.io/kickstart.sh) --dont-wait --disable-telemetry
    
    # Configure for low resource usage
    mkdir -p "$SERVICE_ROOT/monitoring"
    cat > "/etc/netdata/netdata.conf" << 'EOF'
[global]
    memory mode = ram
    history = 3600
    update every = 5
    page cache size = 32
    dbengine disk space = 128

[web]
    bind to = 127.0.0.1
    port = 19999
    allow connections from = localhost 10.* 192.168.*

[plugins]
    proc = yes
    diskspace = yes
    cgroups = no
    tc = no
    idlejitter = no
    checks = no
    apps = no
    python.d = no
    charts.d = no
    node.d = no
    go.d = yes
EOF

    cat > "$SERVICE_ROOT/monitoring/config.json" << 'EOF'
{
    "service": "netdata",
    "description": "System Monitoring Dashboard",
    "autostart": true,
    "health_check": "curl -s http://localhost:19999/api/v1/info",
    "management_port": 19999,
    "resource_limits": {
        "memory": "128MB",
        "cpu": "15%"
    }
}
EOF

    systemctl restart netdata
    success "Monitoring service installed. Access at http://[device-ip]:19999"
}

install_backup_service() {
    log "Installing Automated Backup (Restic)..."
    
    apt-get update && apt-get install -y restic
    
    mkdir -p "$SERVICE_ROOT/backup"/{scripts,repo,config}
    
    # Create backup configuration
    cat > "$SERVICE_ROOT/backup/config.json" << 'EOF'
{
    "service": "backup",
    "description": "Automated Backup Service",
    "autostart": false,
    "health_check": "restic version",
    "management_port": null,
    "schedule": "0 2 * * *",
    "resource_limits": {
        "memory": "256MB",
        "cpu": "20%"
    }
}
EOF

    # Create comprehensive backup script
    cat > "$SERVICE_ROOT/backup/scripts/backup.sh" << 'EOF'
#!/bin/bash
# Comprehensive backup script for Neo3

BACKUP_CONFIG="$SERVICE_ROOT/backup/config"
BACKUP_REPO="$SERVICE_ROOT/backup/repo"
BACKUP_PASSWORD="neo3backup$(date +%Y)"

export RESTIC_REPOSITORY="$BACKUP_REPO"
export RESTIC_PASSWORD="$BACKUP_PASSWORD"

# Critical directories to backup
BACKUP_SOURCES=(
    "/var/www"
    "/etc/nginx"
    "/etc/systemd/system"
    "/opt/neo3-services"
    "/home"
)

log_backup() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /var/log/neo3-backup.log
}

# Initialize repository if needed
if [ ! -d "$BACKUP_REPO" ]; then
    log_backup "Initializing backup repository"
    restic init
fi

# Create backup
log_backup "Starting backup process"
for source in "${BACKUP_SOURCES[@]}"; do
    if [ -d "$source" ]; then
        log_backup "Backing up $source"
        restic backup "$source" --verbose
    fi
done

# Cleanup old backups
log_backup "Cleaning up old backups"
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --prune

log_backup "Backup completed"
EOF

    chmod +x "$SERVICE_ROOT/backup/scripts/backup.sh"
    
    # Add to crontab
    echo "0 2 * * * root $SERVICE_ROOT/backup/scripts/backup.sh" >> /etc/crontab
    
    success "Backup service installed. Runs daily at 2 AM."
}

install_file_server() {
    log "Installing File Server (MinIO)..."
    
    # Download MinIO
    wget https://dl.min.io/server/minio/release/linux-arm64/minio -O /usr/local/bin/minio
    chmod +x /usr/local/bin/minio
    
    # Create MinIO user and directories
    useradd -r minio-user
    mkdir -p /opt/minio/{data,config}
    chown -R minio-user:minio-user /opt/minio
    
    mkdir -p "$SERVICE_ROOT/file-server"
    cat > "$SERVICE_ROOT/file-server/config.json" << 'EOF'
{
    "service": "minio",
    "description": "Object Storage File Server",
    "autostart": true,
    "health_check": "curl -s http://localhost:9000/minio/health/live",
    "management_port": 9001,
    "api_port": 9000,
    "resource_limits": {
        "memory": "512MB",
        "cpu": "25%"
    }
}
EOF

    # Create systemd service
    cat > "/etc/systemd/system/minio.service" << 'EOF'
[Unit]
Description=MinIO Object Storage
After=network.target

[Service]
Type=notify
User=minio-user
Group=minio-user
Environment="MINIO_ROOT_USER=neo3admin"
Environment="MINIO_ROOT_PASSWORD=neo3minio123"
ExecStart=/usr/local/bin/minio server /opt/minio/data --console-address ":9001"
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=minio

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable minio
    systemctl start minio
    
    success "File server installed. Access at http://[device-ip]:9001"
}

install_ai_agent() {
    log "Installing AI Assistant Agent..."
    
    mkdir -p "$SERVICE_ROOT/ai-agent"
    cd "$SERVICE_ROOT/ai-agent"
    
    python3 -m venv venv
    source venv/bin/activate
    pip install fastapi uvicorn openai anthropic requests python-multipart
    
    # Create AI agent service
    cat > app.py << 'EOF'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
import subprocess
import json
from typing import Optional

app = FastAPI(title="Neo3 AI Assistant", version="1.0.0")

class TaskRequest(BaseModel):
    task: str
    context: Optional[str] = None

class ServiceAction(BaseModel):
    service: str
    action: str

@app.get("/")
async def root():
    return {"message": "Neo3 AI Assistant is running"}

@app.post("/task")
async def process_task(request: TaskRequest):
    """Process natural language tasks"""
    # Simple task processor - can be extended with actual AI integration
    task_lower = request.task.lower()
    
    if "restart" in task_lower and "service" in task_lower:
        # Extract service name and restart it
        return {"response": "Service restart functionality would be implemented here"}
    elif "status" in task_lower:
        # Get system status
        try:
            result = subprocess.run(['systemctl', 'list-units', '--type=service'], 
                                  capture_output=True, text=True)
            return {"response": f"System status retrieved", "data": result.stdout[:1000]}
        except:
            return {"response": "Could not retrieve system status"}
    else:
        return {"response": f"I understand you want to: {request.task}. This feature is being developed."}

@app.post("/service-action")
async def service_action(request: ServiceAction):
    """Execute service actions through AI"""
    try:
        result = subprocess.run(['systemctl', request.action, request.service], 
                              capture_output=True, text=True)
        return {"success": result.returncode == 0, "output": result.stdout}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8081)
EOF

    cat > "$SERVICE_ROOT/ai-agent/config.json" << 'EOF'
{
    "service": "ai-agent",
    "description": "AI Assistant for System Management",
    "autostart": true,
    "health_check": "curl -s http://localhost:8081/",
    "management_port": 8081,
    "resource_limits": {
        "memory": "256MB",
        "cpu": "20%"
    }
}
EOF

    # Create systemd service
    cat > "/etc/systemd/system/neo3-ai-agent.service" << EOF
[Unit]
Description=Neo3 AI Assistant Agent
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$SERVICE_ROOT/ai-agent
Environment=PATH=$SERVICE_ROOT/ai-agent/venv/bin
ExecStart=$SERVICE_ROOT/ai-agent/venv/bin/python app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    deactivate
    systemctl daemon-reload
    systemctl enable neo3-ai-agent
    systemctl start neo3-ai-agent
    
    success "AI Agent installed. API available at http://[device-ip]:8081"
}

install_dns_service() {
    log "Installing Private DNS (Pi-hole)..."
    
    # Install Pi-hole with automated setup
    export PIHOLE_SKIP_OS_CHECK=true
    curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended
    
    mkdir -p "$SERVICE_ROOT/dns"
    cat > "$SERVICE_ROOT/dns/config.json" << 'EOF'
{
    "service": "pihole-FTL",
    "description": "Private DNS and Ad Blocker",
    "autostart": true,
    "health_check": "dig @localhost google.com",
    "management_port": 80,
    "resource_limits": {
        "memory": "128MB",
        "cpu": "10%"
    }
}
EOF

    success "DNS service installed. Access Pi-hole admin at http://[device-ip]/admin"
}

install_reverse_proxy() {
    log "Installing Reverse Proxy (Traefik)..."
    
    # Download Traefik
    wget https://github.com/traefik/traefik/releases/download/v2.10.4/traefik_v2.10.4_linux_arm64.tar.gz
    tar -xzf traefik_v2.10.4_linux_arm64.tar.gz
    mv traefik /usr/local/bin/
    chmod +x /usr/local/bin/traefik
    rm traefik_v2.10.4_linux_arm64.tar.gz
    
    mkdir -p "$SERVICE_ROOT/reverse-proxy"/{config,dynamic}
    
    # Create Traefik configuration
    cat > "$SERVICE_ROOT/reverse-proxy/config/traefik.yml" << 'EOF'
global:
  checkNewVersion: false
  sendAnonymousUsage: false

api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  file:
    directory: /opt/neo3-services/reverse-proxy/dynamic
    watch: true

log:
  level: INFO
EOF

    # Create dynamic configuration for services
    cat > "$SERVICE_ROOT/reverse-proxy/dynamic/services.yml" << 'EOF'
http:
  routers:
    admin-router:
      rule: "Host(`admin.neo3.local`)"
      service: admin-service
    monitoring-router:
      rule: "Host(`monitoring.neo3.local`)"
      service: monitoring-service
    files-router:
      rule: "Host(`files.neo3.local`)"
      service: files-service
    ai-router:
      rule: "Host(`ai.neo3.local`)"
      service: ai-service

  services:
    admin-service:
      loadBalancer:
        servers:
          - url: "http://localhost:8080"
    monitoring-service:
      loadBalancer:
        servers:
          - url: "http://localhost:19999"
    files-service:
      loadBalancer:
        servers:
          - url: "http://localhost:9001"
    ai-service:
      loadBalancer:
        servers:
          - url: "http://localhost:8081"
EOF

    cat > "$SERVICE_ROOT/reverse-proxy/config.json" << 'EOF'
{
    "service": "traefik",
    "description": "Reverse Proxy and Load Balancer",
    "autostart": true,
    "health_check": "curl -s http://localhost:8080/api/overview",
    "management_port": 8080,
    "resource_limits": {
        "memory": "128MB",
        "cpu": "10%"
    }
}
EOF

    # Create systemd service
    cat > "/etc/systemd/system/traefik.service" << EOF
[Unit]
Description=Traefik Reverse Proxy
After=network.target

[Service]
Type=simple
User=www-data
ExecStart=/usr/local/bin/traefik --configfile=$SERVICE_ROOT/reverse-proxy/config/traefik.yml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable traefik
    systemctl start traefik
    
    success "Reverse proxy installed. Dashboard at http://[device-ip]:8080"
}

remove_service() {
    local service="$1"
    log "Removing service: $service"
    
    case "$service" in
        vpn)
            systemctl stop tailscaled 2>/dev/null || true
            systemctl disable tailscaled 2>/dev/null || true
            apt-get remove -y tailscale 2>/dev/null || true
            ;;
        monitoring)
            systemctl stop netdata 2>/dev/null || true
            systemctl disable netdata 2>/dev/null || true
            ;;
        backup)
            crontab -l | grep -v "backup.sh" | crontab - 2>/dev/null || true
            ;;
        file-server)
            systemctl stop minio 2>/dev/null || true
            systemctl disable minio 2>/dev/null || true
            rm -f /etc/systemd/system/minio.service
            ;;
        ai-agent)
            systemctl stop neo3-ai-agent 2>/dev/null || true
            systemctl disable neo3-ai-agent 2>/dev/null || true
            rm -f /etc/systemd/system/neo3-ai-agent.service
            ;;
        dns)
            pihole uninstall 2>/dev/null || true
            ;;
        reverse-proxy)
            systemctl stop traefik 2>/dev/null || true
            systemctl disable traefik 2>/dev/null || true
            rm -f /etc/systemd/system/traefik.service
            ;;
    esac
    
    rm -rf "$SERVICE_ROOT/$service" 2>/dev/null || true
    systemctl daemon-reload
    
    success "Service $service removed"
}

show_service_status() {
    log "Service Status Overview"
    echo
    
    for service in "${!SERVICES[@]}"; do
        local config_file="$SERVICE_ROOT/$service/config.json"
        if [ -f "$config_file" ]; then
            local service_name=$(jq -r '.service' "$config_file" 2>/dev/null || echo "$service")
            local status=$(systemctl is-active "$service_name" 2>/dev/null || echo "unknown")
            local color=""
            
            case "$status" in
                active) color="$GREEN" ;;
                inactive) color="$YELLOW" ;;
                *) color="$RED" ;;
            esac
            
            echo -e "${SERVICES[$service]}: ${color}$status${NC}"
        else
            echo -e "${SERVICES[$service]}: ${RED}not installed${NC}"
        fi
    done
    echo
}

install_all_services() {
    log "Installing all services..."
    
    install_vpn_service
    install_monitoring_service
    install_backup_service
    install_file_server
    install_ai_agent
    install_dns_service
    install_reverse_proxy
    
    success "All services installed!"
}

main() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root"
    fi
    
    mkdir -p "$SERVICE_ROOT"
    
    while true; do
        show_menu
        read -p "Select an option: " choice
        
        case "$choice" in
            1) install_vpn_service ;;
            2) install_monitoring_service ;;
            3) install_backup_service ;;
            4) install_file_server ;;
            5) install_ai_agent ;;
            6) install_dns_service ;;
            7) install_reverse_proxy ;;
            a|A) install_all_services ;;
            r|R)
                echo "Available services to remove:"
                for service in "${!SERVICES[@]}"; do
                    echo "  $service"
                done
                read -p "Enter service name to remove: " service_to_remove
                if [ -n "$service_to_remove" ] && [ -n "${SERVICES[$service_to_remove]}" ]; then
                    remove_service "$service_to_remove"
                else
                    warn "Invalid service name"
                fi
                ;;
            s|S) show_service_status ;;
            q|Q) exit 0 ;;
            *) warn "Invalid option" ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
        clear
    done
}

main "$@"
