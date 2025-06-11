#!/bin/bash
# Web Management UI Installer - macOS Container Version
# Installs the Neo3 web admin interface inside Docker container

set -e

# This script runs inside the Docker container during image build
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[WEB-UI]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Configuration
WEB_UI_DIR="/var/www/neo3-admin"
SERVICE_DIR="/opt/neo3-services"
NGINX_CONF_DIR="/etc/nginx/sites-available"

install_node_and_npm() {
    log "Installing Node.js and npm..."
    
    # Install Node.js 18.x LTS
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    
    # Verify installation
    node --version
    npm --version
    
    success "Node.js and npm installed"
}

create_web_ui_backend() {
    log "Creating Web Management UI backend..."
    
    mkdir -p "$WEB_UI_DIR"
    cd "$WEB_UI_DIR"
    
    # Initialize npm project
    cat > package.json << 'EOF'
{
  "name": "neo3-admin",
  "version": "1.0.0",
  "description": "NanoPi Neo3 Web Administration Interface",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "express-ws": "^5.0.2",
    "multer": "^1.4.5",
    "node-cron": "^3.0.2",
    "systeminformation": "^5.17.12",
    "socket.io": "^4.6.1",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.0",
    "helmet": "^6.1.5",
    "cors": "^2.8.5"
  },
  "author": "Neo3 Admin",
  "license": "MIT"
}
EOF

    # Install dependencies
    npm install --production
    
    success "Backend dependencies installed"
}

create_server_app() {
    log "Creating server application..."
    
    cat > "$WEB_UI_DIR/server.js" << 'EOF'
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const si = require('systeminformation');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const helmet = require('helmet');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

// Security middleware
app.use(helmet({
    contentSecurityPolicy: false // Disable for local admin interface
}));
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const PORT = process.env.WEB_UI_PORT || 8080;
const JWT_SECRET = process.env.JWT_SECRET || 'neo3-admin-secret-change-in-production';

// Default admin credentials (change in production!)
const ADMIN_USER = process.env.WEB_UI_USER || 'admin';
const ADMIN_PASS_HASH = bcrypt.hashSync(process.env.WEB_UI_PASS || 'neo3admin123', 10);

// Authentication middleware
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.sendStatus(401);
    }

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) return res.sendStatus(403);
        req.user = user;
        next();
    });
};

// Routes
app.post('/api/login', async (req, res) => {
    const { username, password } = req.body;
    
    if (username === ADMIN_USER && bcrypt.compareSync(password, ADMIN_PASS_HASH)) {
        const token = jwt.sign({ username }, JWT_SECRET, { expiresIn: '24h' });
        res.json({ success: true, token });
    } else {
        res.status(401).json({ success: false, message: 'Invalid credentials' });
    }
});

app.get('/api/system-info', authenticateToken, async (req, res) => {
    try {
        const [cpu, mem, disk, network, system] = await Promise.all([
            si.cpu(),
            si.mem(),
            si.fsSize(),
            si.networkInterfaces(),
            si.system()
        ]);
        
        res.json({ cpu, mem, disk, network, system });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/services', authenticateToken, (req, res) => {
    exec('systemctl list-units --type=service --state=running --no-pager', (error, stdout) => {
        if (error) {
            return res.status(500).json({ error: error.message });
        }
        
        const services = stdout.split('\n')
            .filter(line => line.includes('.service'))
            .map(line => {
                const parts = line.trim().split(/\s+/);
                return {
                    name: parts[0],
                    load: parts[1],
                    active: parts[2],
                    sub: parts[3],
                    description: parts.slice(4).join(' ')
                };
            });
        
        res.json(services);
    });
});

app.post('/api/service/:action/:name', authenticateToken, (req, res) => {
    const { action, name } = req.params;
    const validActions = ['start', 'stop', 'restart', 'status'];
    
    if (!validActions.includes(action)) {
        return res.status(400).json({ error: 'Invalid action' });
    }
    
    exec(`systemctl ${action} ${name}`, (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: stderr || error.message });
        }
        res.json({ success: true, output: stdout });
    });
});

app.get('/api/logs/:service', authenticateToken, (req, res) => {
    const { service } = req.params;
    const lines = req.query.lines || 50;
    
    exec(`journalctl -u ${service} -n ${lines} --no-pager`, (error, stdout) => {
        if (error) {
            return res.status(500).json({ error: error.message });
        }
        res.json({ logs: stdout });
    });
});

app.post('/api/install-service', authenticateToken, (req, res) => {
    const { service } = req.body;
    
    // Run service installer
    exec(`/usr/local/bin/service-installer.sh install ${service}`, (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: stderr || error.message });
        }
        res.json({ success: true, output: stdout });
    });
});

// Real-time system monitoring
io.on('connection', (socket) => {
    console.log('Client connected for real-time monitoring');
    
    const sendSystemStats = async () => {
        try {
            const [cpu, mem, temp] = await Promise.all([
                si.currentLoad(),
                si.mem(),
                si.cpuTemperature()
            ]);
            
            socket.emit('systemStats', {
                cpu: cpu.currentLoad,
                memory: (mem.used / mem.total) * 100,
                temperature: temp.main || 0,
                timestamp: new Date()
            });
        } catch (error) {
            console.error('Error getting system stats:', error);
        }
    };
    
    const interval = setInterval(sendSystemStats, 2000);
    
    socket.on('disconnect', () => {
        clearInterval(interval);
        console.log('Client disconnected');
    });
});

// Serve the admin interface
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`Neo3 Admin Interface running on port ${PORT}`);
});
EOF

    success "Server application created"
}

create_web_ui_frontend() {
    log "Creating Web UI frontend..."
    
    mkdir -p "$WEB_UI_DIR/public"
    
    # Create main HTML file
    cat > "$WEB_UI_DIR/public/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Neo3 Admin - NanoPi Neo3 Management</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.8.1/font/bootstrap-icons.css" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdn.socket.io/4.6.1/socket.io.min.js"></script>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div id="loginModal" class="modal" tabindex="-1">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Neo3 Admin Login</h5>
                </div>
                <div class="modal-body">
                    <form id="loginForm">
                        <div class="mb-3">
                            <label class="form-label">Username</label>
                            <input type="text" class="form-control" id="username" required>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Password</label>
                            <input type="password" class="form-control" id="password" required>
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-primary" onclick="login()">Login</button>
                </div>
            </div>
        </div>
    </div>

    <div id="mainApp" style="display: none;">
        <nav class="navbar navbar-expand-lg navbar-dark bg-primary">
            <div class="container-fluid">
                <span class="navbar-brand">
                    <i class="bi bi-server"></i> Neo3 Admin
                </span>
                <button class="btn btn-outline-light btn-sm" onclick="logout()">Logout</button>
            </div>
        </nav>

        <div class="container-fluid mt-3">
            <div class="row">
                <div class="col-12">
                    <div class="row mb-3">
                        <div class="col-md-3">
                            <div class="card text-center">
                                <div class="card-body">
                                    <h5 class="card-title">CPU Usage</h5>
                                    <h2 id="cpuUsage">--</h2>
                                    <canvas id="cpuChart" width="100" height="100"></canvas>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <div class="card text-center">
                                <div class="card-body">
                                    <h5 class="card-title">Memory</h5>
                                    <h2 id="memoryUsage">--</h2>
                                    <canvas id="memoryChart" width="100" height="100"></canvas>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <div class="card text-center">
                                <div class="card-body">
                                    <h5 class="card-title">Temperature</h5>
                                    <h2 id="temperature">--</h2>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <div class="card text-center">
                                <div class="card-body">
                                    <h5 class="card-title">Uptime</h5>
                                    <h2 id="uptime">--</h2>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="row">
                        <div class="col-md-6">
                            <div class="card">
                                <div class="card-header">
                                    <h5>Quick Actions</h5>
                                </div>
                                <div class="card-body">
                                    <div class="d-grid gap-2">
                                        <button class="btn btn-success" onclick="installService('monitoring')">
                                            <i class="bi bi-graph-up"></i> Install System Monitoring
                                        </button>
                                        <button class="btn btn-info" onclick="installService('vpn')">
                                            <i class="bi bi-shield-lock"></i> Install VPN Service
                                        </button>
                                        <button class="btn btn-warning" onclick="installService('backup')">
                                            <i class="bi bi-archive"></i> Setup Automated Backup
                                        </button>
                                        <button class="btn btn-primary" onclick="window.open('/', '_blank')">
                                            <i class="bi bi-receipt"></i> Open Invoice Ninja
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="card">
                                <div class="card-header">
                                    <h5>System Services</h5>
                                </div>
                                <div class="card-body" style="max-height: 300px; overflow-y: auto;">
                                    <div id="servicesList">Loading...</div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="row mt-3">
                        <div class="col-12">
                            <div class="card">
                                <div class="card-header">
                                    <h5>System Information</h5>
                                </div>
                                <div class="card-body">
                                    <div id="systemInfo">Loading...</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    <script src="app.js"></script>
</body>
</html>
EOF

    # Create JavaScript application
    cat > "$WEB_UI_DIR/public/app.js" << 'EOF'
let authToken = localStorage.getItem('neo3-admin-token');
let socket;

// Initialize app
document.addEventListener('DOMContentLoaded', function() {
    if (authToken) {
        showMainApp();
    } else {
        showLoginModal();
    }
});

function showLoginModal() {
    const modal = new bootstrap.Modal(document.getElementById('loginModal'), {
        backdrop: 'static',
        keyboard: false
    });
    modal.show();
}

function showMainApp() {
    document.getElementById('loginModal').style.display = 'none';
    document.getElementById('mainApp').style.display = 'block';
    
    // Initialize real-time monitoring
    initializeSocket();
    
    // Load initial data
    loadServices();
    loadSystemInfo();
}

async function login() {
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;
    
    try {
        const response = await fetch('/api/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ username, password })
        });
        
        const data = await response.json();
        
        if (data.success) {
            authToken = data.token;
            localStorage.setItem('neo3-admin-token', authToken);
            showMainApp();
        } else {
            alert('Invalid credentials');
        }
    } catch (error) {
        alert('Login failed: ' + error.message);
    }
}

function logout() {
    authToken = null;
    localStorage.removeItem('neo3-admin-token');
    location.reload();
}

function initializeSocket() {
    socket = io();
    
    socket.on('systemStats', function(data) {
        document.getElementById('cpuUsage').textContent = data.cpu.toFixed(1) + '%';
        document.getElementById('memoryUsage').textContent = data.memory.toFixed(1) + '%';
        document.getElementById('temperature').textContent = data.temperature.toFixed(1) + '°C';
    });
}

async function loadServices() {
    try {
        const response = await fetch('/api/services', {
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        });
        
        const services = await response.json();
        const servicesList = document.getElementById('servicesList');
        
        servicesList.innerHTML = services.map(service => `
            <div class="d-flex justify-content-between align-items-center mb-2">
                <div>
                    <strong>${service.name}</strong>
                    <br>
                    <small class="text-muted">${service.description}</small>
                </div>
                <div>
                    <span class="badge ${service.active === 'active' ? 'bg-success' : 'bg-danger'}">
                        ${service.active}
                    </span>
                    <button class="btn btn-sm btn-outline-primary ms-2" onclick="restartService('${service.name}')">
                        Restart
                    </button>
                </div>
            </div>
        `).join('');
    } catch (error) {
        console.error('Failed to load services:', error);
    }
}

async function loadSystemInfo() {
    try {
        const response = await fetch('/api/system-info', {
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        });
        
        const info = await response.json();
        const systemInfo = document.getElementById('systemInfo');
        
        systemInfo.innerHTML = `
            <div class="row">
                <div class="col-md-6">
                    <p><strong>Hostname:</strong> ${info.system.hostname}</p>
                    <p><strong>Platform:</strong> ${info.system.platform}</p>
                    <p><strong>Architecture:</strong> ${info.system.arch}</p>
                </div>
                <div class="col-md-6">
                    <p><strong>CPU:</strong> ${info.cpu.manufacturer} ${info.cpu.brand}</p>
                    <p><strong>Memory:</strong> ${(info.mem.total / 1024 / 1024 / 1024).toFixed(1)} GB</p>
                    <p><strong>Free Memory:</strong> ${(info.mem.free / 1024 / 1024 / 1024).toFixed(1)} GB</p>
                </div>
            </div>
        `;
    } catch (error) {
        console.error('Failed to load system info:', error);
    }
}

async function restartService(serviceName) {
    if (!confirm(`Restart ${serviceName}?`)) return;
    
    try {
        const response = await fetch(`/api/service/restart/${serviceName}`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        });
        
        const result = await response.json();
        if (result.success) {
            alert('Service restarted successfully');
            loadServices();
        } else {
            alert('Failed to restart service: ' + result.error);
        }
    } catch (error) {
        alert('Error: ' + error.message);
    }
}

async function installService(service) {
    if (!confirm(`Install ${service} service?`)) return;
    
    try {
        const response = await fetch('/api/install-service', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
            },
            body: JSON.stringify({ service })
        });
        
        const result = await response.json();
        if (result.success) {
            alert('Service installation started. Check services list for updates.');
            loadServices();
        } else {
            alert('Failed to install service: ' + result.error);
        }
    } catch (error) {
        alert('Error: ' + error.message);
    }
}
EOF

    # Create CSS styles
    cat > "$WEB_UI_DIR/public/style.css" << 'EOF'
.modal {
    display: block;
}

.card {
    margin-bottom: 1rem;
}

.navbar-brand {
    font-weight: bold;
}

#cpuChart, #memoryChart {
    max-width: 100px;
    max-height: 100px;
}

.btn-group-vertical .btn {
    margin-bottom: 0.5rem;
}

.service-item {
    border-bottom: 1px solid #dee2e6;
    padding: 0.5rem 0;
}

.service-item:last-child {
    border-bottom: none;
}

@media (max-width: 768px) {
    .container-fluid {
        padding: 0.5rem;
    }
    
    .card-body {
        padding: 0.75rem;
    }
}
EOF

    success "Frontend created"
}

configure_nginx_for_admin() {
    log "Configuring Nginx for admin interface..."
    
    cat > "$NGINX_CONF_DIR/neo3-admin" << 'EOF'
server {
    listen 8080;
    server_name _;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

    # Enable the site
    ln -sf "$NGINX_CONF_DIR/neo3-admin" /etc/nginx/sites-enabled/
    
    success "Nginx configured for admin interface"
}

create_systemd_service() {
    log "Creating systemd service for admin interface..."
    
    cat > /etc/systemd/system/neo3-admin.service << 'EOF'
[Unit]
Description=Neo3 Admin Interface
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/neo3-admin
Environment=NODE_ENV=production
Environment=WEB_UI_PORT=8080
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=neo3-admin

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable neo3-admin
    
    success "Systemd service created and enabled"
}

main() {
    log "Installing Neo3 Web Management UI (Container Version)..."
    
    install_node_and_npm
    create_web_ui_backend
    create_server_app
    create_web_ui_frontend
    configure_nginx_for_admin
    create_systemd_service
    
    # Set proper permissions
    chown -R www-data:www-data "$WEB_UI_DIR"
    chmod -R 755 "$WEB_UI_DIR"
    
    success "Neo3 Web Management UI installed successfully!"
    log "Access the admin interface at: http://[device-ip]:8080"
    log "Default credentials: admin / neo3admin123"
}

main "$@"
