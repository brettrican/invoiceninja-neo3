#!/bin/bash
# Configuration parser for NanoPi Neo3 Invoice Ninja Image Builder

# Default configuration file path
CONFIG_FILE="config.conf"

# Function to load configuration
load_config() {
    local config_file="${1:-$CONFIG_FILE}"
    
    if [ ! -f "$config_file" ]; then
        warn "Configuration file not found: $config_file"
        warn "Using default values"
        return 1
    fi
    
    log "Loading configuration from: $config_file"
    
    # Source the configuration file
    source "$config_file"
    
    # Validate critical settings
    validate_config
    
    success "Configuration loaded successfully"
}

# Function to validate configuration
validate_config() {
    local errors=0
    
    # Validate image size
    if [[ ! "$VALID_IMAGE_SIZES" == *"$IMAGE_SIZE"* ]]; then
        error "Invalid IMAGE_SIZE: $IMAGE_SIZE. Valid options: $VALID_IMAGE_SIZES"
        ((errors++))
    fi
    
    # Validate PHP version
    if [[ ! "$VALID_PHP_VERSIONS" == *"$PHP_VERSION"* ]]; then
        error "Invalid PHP_VERSION: $PHP_VERSION. Valid options: $VALID_PHP_VERSIONS"
        ((errors++))
    fi
    
    # Validate database connection
    if [[ ! "$VALID_DB_CONNECTIONS" == *"$DB_CONNECTION"* ]]; then
        error "Invalid DB_CONNECTION: $DB_CONNECTION. Valid options: $VALID_DB_CONNECTIONS"
        ((errors++))
    fi
    
    # Validate environment
    if [[ ! "$VALID_ENVIRONMENTS" == *"$IN_APP_ENV"* ]]; then
        error "Invalid IN_APP_ENV: $IN_APP_ENV. Valid options: $VALID_ENVIRONMENTS"
        ((errors++))
    fi
    
    # Validate hostname
    if [[ ! "$HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$ ]]; then
        error "Invalid HOSTNAME: $HOSTNAME. Must be a valid hostname"
        ((errors++))
    fi
    
    # Validate memory settings
    if [[ ! "$PHP_MEMORY_LIMIT" =~ ^[0-9]+[MG]$ ]]; then
        error "Invalid PHP_MEMORY_LIMIT: $PHP_MEMORY_LIMIT. Must be in format like '256M' or '1G'"
        ((errors++))
    fi
    
    # Validate static IP if provided
    if [ "$ENABLE_DHCP" = "false" ] && [ -z "$STATIC_IP" ]; then
        error "STATIC_IP must be provided when DHCP is disabled"
        ((errors++))
    fi
    
    # Validate SSH port
    if [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
        error "Invalid SSH_PORT: $SSH_PORT. Must be between 1 and 65535"
        ((errors++))
    fi
    
    # Validate swap size
    if [[ ! "$SWAP_SIZE" =~ ^[0-9]+[MG]$ ]]; then
        error "Invalid SWAP_SIZE: $SWAP_SIZE. Must be in format like '512M' or '1G'"
        ((errors++))
    fi
    
    # Validate parallel jobs
    if [[ ! "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [ "$PARALLEL_JOBS" -lt 1 ]; then
        error "Invalid PARALLEL_JOBS: $PARALLEL_JOBS. Must be a positive integer"
        ((errors++))
    fi
    
    if [ $errors -gt 0 ]; then
        error "Configuration validation failed with $errors error(s)"
        exit 1
    fi
}

# Function to show current configuration
show_config() {
    echo "Current Configuration:"
    echo "====================="
    echo
    echo "Image Settings:"
    echo "  Image Size: $IMAGE_SIZE"
    echo "  Image Name: $IMAGE_NAME"
    echo
    echo "System Settings:"
    echo "  Hostname: $HOSTNAME"
    echo "  Timezone: $TIMEZONE"
    echo "  Root Password: [HIDDEN]"
    echo
    echo "Network Settings:"
    echo "  DHCP Enabled: $ENABLE_DHCP"
    echo "  SSH Enabled: $ENABLE_SSH"
    echo "  SSH Port: $SSH_PORT"
    if [ "$ENABLE_DHCP" = "false" ]; then
        echo "  Static IP: $STATIC_IP"
        echo "  Gateway: $STATIC_GATEWAY"
        echo "  DNS: $STATIC_DNS"
    fi
    echo
    echo "Invoice Ninja Settings:"
    echo "  App Name: $IN_APP_NAME"
    echo "  Environment: $IN_APP_ENV"
    echo "  Debug Mode: $IN_APP_DEBUG"
    echo "  Database: $DB_CONNECTION"
    echo
    echo "Web Server Settings:"
    echo "  Nginx Worker Processes: $NGINX_WORKER_PROCESSES"
    echo "  Max Body Size: $NGINX_CLIENT_MAX_BODY_SIZE"
    echo
    echo "PHP Settings:"
    echo "  PHP Version: $PHP_VERSION"
    echo "  Memory Limit: $PHP_MEMORY_LIMIT"
    echo "  Max Execution Time: $PHP_MAX_EXECUTION_TIME"
    echo "  Upload Max Size: $PHP_UPLOAD_MAX_FILESIZE"
    echo
    echo "Performance Settings:"
    echo "  OPcache Enabled: $ENABLE_OPCACHE"
    echo "  Gzip Enabled: $ENABLE_GZIP"
    echo "  Swap Size: $SWAP_SIZE"
    echo
    echo "Security Settings:"
    echo "  Firewall Enabled: $ENABLE_FIREWALL"
    echo "  Fail2ban Enabled: $ENABLE_FAIL2BAN"
    echo "  Root Login Disabled: $DISABLE_ROOT_LOGIN"
    echo
}

# Function to generate environment-specific configurations
generate_env_file() {
    local env_file="$1"
    
    cat > "$env_file" << EOF
APP_NAME="$IN_APP_NAME"
APP_ENV=$IN_APP_ENV
APP_KEY=
APP_DEBUG=$IN_APP_DEBUG
APP_URL=$IN_APP_URL

LOG_CHANNEL=stack

DB_CONNECTION=$DB_CONNECTION
DB_DATABASE=$DB_DATABASE

BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=database
SESSION_DRIVER=file
SESSION_LIFETIME=120

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS=null
MAIL_FROM_NAME="\${APP_NAME}"

NINJA_ENVIRONMENT=selfhost
REQUIRE_HTTPS=$IN_REQUIRE_HTTPS
PHANTOMJS_PDF_GENERATION=false
PDF_GENERATOR=snappdf

TRUSTED_PROXIES="$IN_TRUSTED_PROXIES"
EOF
}

# Function to generate PHP-FPM configuration
generate_php_fpm_config() {
    local php_fpm_file="$1"
    
    cat > "$php_fpm_file" << EOF
[global]
pid = /run/php/php$PHP_VERSION-fpm.pid
error_log = /var/log/php$PHP_VERSION-fpm.log
log_level = $PHP_LOG_LEVEL

[www]
user = www-data
group = www-data
listen = /var/run/php/php$PHP_VERSION-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 4
pm.start_servers = 1
pm.min_spare_servers = 1
pm.max_spare_servers = 2
pm.max_requests = 500

php_admin_value[memory_limit] = $PHP_MEMORY_LIMIT
php_admin_value[max_execution_time] = $PHP_MAX_EXECUTION_TIME
php_admin_value[max_input_time] = $PHP_MAX_INPUT_TIME
php_admin_value[upload_max_filesize] = $PHP_UPLOAD_MAX_FILESIZE
php_admin_value[post_max_size] = $PHP_POST_MAX_SIZE
php_admin_flag[log_errors] = on
php_admin_value[error_log] = /var/log/php$PHP_VERSION-fpm-www.log
EOF
}

# Function to generate Nginx configuration
generate_nginx_config() {
    local nginx_file="$1"
    
    cat > "$nginx_file" << EOF
user www-data;
worker_processes $NGINX_WORKER_PROCESSES;
pid /run/nginx.pid;

events {
    worker_connections $NGINX_WORKER_CONNECTIONS;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log $NGINX_LOG_LEVEL;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;
    client_body_timeout 12;
    client_header_timeout 12;
    send_timeout 10;
EOF

    if [ "$ENABLE_GZIP" = "true" ]; then
        cat >> "$nginx_file" << EOF
    
    gzip on;
    gzip_comp_level 6;
    gzip_min_length 1000;
    gzip_proxied any;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;
EOF
    fi
    
    cat >> "$nginx_file" << EOF
    
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF
}

# Function to generate systemd network configuration
generate_network_config() {
    local network_file="$1"
    
    if [ "$ENABLE_DHCP" = "true" ]; then
        cat > "$network_file" << EOF
[Match]
Name=eth0

[Network]
DHCP=yes
EOF
    else
        cat > "$network_file" << EOF
[Match]
Name=eth0

[Network]
Address=$STATIC_IP
Gateway=$STATIC_GATEWAY
DNS=$STATIC_DNS
EOF
    fi
}

# Function to create configuration summary
create_config_summary() {
    local summary_file="$1"
    
    cat > "$summary_file" << EOF
# Configuration Summary
# Generated on: $(date)

IMAGE_SIZE=$IMAGE_SIZE
HOSTNAME=$HOSTNAME
PHP_VERSION=$PHP_VERSION
DB_CONNECTION=$DB_CONNECTION
ENABLE_DHCP=$ENABLE_DHCP
ENABLE_SSH=$ENABLE_SSH
SSH_PORT=$SSH_PORT
ENABLE_FIREWALL=$ENABLE_FIREWALL
ENABLE_FAIL2BAN=$ENABLE_FAIL2BAN
SWAP_SIZE=$SWAP_SIZE
PARALLEL_JOBS=$PARALLEL_JOBS
EOF
}

# Function to backup current configuration
backup_config() {
    local backup_dir="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$backup_dir"
    cp "$CONFIG_FILE" "$backup_dir/config_$timestamp.conf"
    
    log "Configuration backed up to: $backup_dir/config_$timestamp.conf"
}

# Export functions for use in other scripts
export -f load_config
export -f validate_config
export -f show_config
export -f generate_env_file
export -f generate_php_fpm_config
export -f generate_nginx_config
export -f generate_network_config
export -f create_config_summary
export -f backup_config
