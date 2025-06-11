#!/bin/bash
set -e

# NanoPi Neo3 Invoice Ninja Image Builder
# One-click utility to create a bootable SD card image

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/build"
IMAGE_NAME="nanopi-neo3-invoiceninja.img"
IMAGE_SIZE="4G"
MOUNT_POINT="/tmp/nanopi-mount"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

check_dependencies() {
    log "Checking dependencies..."
    
    local deps=("debootstrap" "qemu-user-static" "parted" "kpartx" "wget" "curl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        error "Missing dependencies: ${missing[*]}. Please install them first."
    fi
    
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
    fi
    
    success "All dependencies satisfied"
}

setup_workspace() {
    log "Setting up workspace..."
    
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
    mkdir -p "$MOUNT_POINT"
    
    success "Workspace ready at $WORK_DIR"
}

create_image() {
    log "Creating disk image ($IMAGE_SIZE)..."
    
    dd if=/dev/zero of="$WORK_DIR/$IMAGE_NAME" bs=1M count=0 seek=4096 status=progress
    
    # Create partition table
    parted -s "$WORK_DIR/$IMAGE_NAME" mklabel msdos
    parted -s "$WORK_DIR/$IMAGE_NAME" mkpart primary ext4 1MiB 100%
    parted -s "$WORK_DIR/$IMAGE_NAME" set 1 boot on
    
    success "Disk image created"
}

setup_loop_device() {
    log "Setting up loop device..."
    
    LOOP_DEVICE=$(losetup -fP --show "$WORK_DIR/$IMAGE_NAME")
    log "Using loop device: $LOOP_DEVICE"
    
    # Format the partition
    mkfs.ext4 -F "${LOOP_DEVICE}p1"
    
    # Mount the partition
    mount "${LOOP_DEVICE}p1" "$MOUNT_POINT"
    
    success "Loop device configured and mounted"
}

install_base_system() {
    log "Installing base Debian system..."
    
    # Use Debian Bullseye (stable) for ARM64
    debootstrap --arch=arm64 --include=systemd,systemd-sysv,udev,dbus bullseye "$MOUNT_POINT" http://deb.debian.org/debian/
    
    # Copy qemu static for chroot
    cp /usr/bin/qemu-aarch64-static "$MOUNT_POINT/usr/bin/"
    
    success "Base system installed"
}

configure_system() {
    log "Configuring system..."
    
    # Configure hostname
    echo "nanopi-invoiceninja" > "$MOUNT_POINT/etc/hostname"
    
    # Configure hosts
    cat > "$MOUNT_POINT/etc/hosts" << 'EOF'
127.0.0.1   localhost
127.0.1.1   nanopi-invoiceninja
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

    # Configure network (using systemd-networkd)
    mkdir -p "$MOUNT_POINT/etc/systemd/network"
    cat > "$MOUNT_POINT/etc/systemd/network/eth0.network" << 'EOF'
[Match]
Name=eth0

[Network]
DHCP=yes
EOF

    # Enable systemd-networkd
    chroot "$MOUNT_POINT" systemctl enable systemd-networkd
    chroot "$MOUNT_POINT" systemctl enable systemd-resolved
    
    # Configure fstab
    echo "LABEL=rootfs / ext4 defaults,noatime 0 1" > "$MOUNT_POINT/etc/fstab"
    
    # Set root password (change this!)
    chroot "$MOUNT_POINT" bash -c "echo 'root:invoiceninja123' | chpasswd"
    
    success "System configured"
}

install_packages() {
    log "Installing required packages..."
    
    # Update package list
    chroot "$MOUNT_POINT" apt-get update
    
    # Install essential packages
    chroot "$MOUNT_POINT" apt-get install -y \
        curl \
        wget \
        unzip \
        git \
        nginx \
        php8.1-fpm \
        php8.1-cli \
        php8.1-curl \
        php8.1-gd \
        php8.1-mbstring \
        php8.1-xml \
        php8.1-zip \
        php8.1-sqlite3 \
        php8.1-bcmath \
        php8.1-intl \
        php8.1-imap \
        composer \
        sqlite3 \
        supervisor \
        openssh-server
    
    success "Packages installed"
}

install_invoice_ninja() {
    log "Installing Invoice Ninja..."
    
    # Create web directory
    mkdir -p "$MOUNT_POINT/var/www"
    
    # Download Invoice Ninja
    chroot "$MOUNT_POINT" bash -c "cd /var/www && wget https://github.com/invoiceninja/invoiceninja/releases/latest/download/invoiceninja.tar -O invoiceninja.tar"
    chroot "$MOUNT_POINT" bash -c "cd /var/www && tar -xf invoiceninja.tar && rm invoiceninja.tar"
    
    # Set permissions
    chroot "$MOUNT_POINT" chown -R www-data:www-data /var/www/ninja
    chroot "$MOUNT_POINT" chmod -R 755 /var/www/ninja
    chroot "$MOUNT_POINT" chmod -R 775 /var/www/ninja/storage
    chroot "$MOUNT_POINT" chmod -R 775 /var/www/ninja/bootstrap/cache
    
    # Install composer dependencies (if needed)
    chroot "$MOUNT_POINT" bash -c "cd /var/www/ninja && composer install --no-dev --optimize-autoloader"
    
    success "Invoice Ninja installed"
}

configure_invoice_ninja() {
    log "Configuring Invoice Ninja..."
    
    # Create .env file
    cat > "$MOUNT_POINT/var/www/ninja/.env" << 'EOF'
APP_NAME="Invoice Ninja"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://localhost

LOG_CHANNEL=stack

DB_CONNECTION=sqlite
DB_DATABASE=/var/www/ninja/database/database.sqlite

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
MAIL_FROM_NAME="${APP_NAME}"

NINJA_ENVIRONMENT=selfhost
REQUIRE_HTTPS=false
PHANTOMJS_PDF_GENERATION=false
PDF_GENERATOR=snappdf

TRUSTED_PROXIES="*"
EOF

    # Create SQLite database
    mkdir -p "$MOUNT_POINT/var/www/ninja/database"
    touch "$MOUNT_POINT/var/www/ninja/database/database.sqlite"
    chroot "$MOUNT_POINT" chown www-data:www-data /var/www/ninja/database/database.sqlite
    
    # Generate app key and run migrations
    chroot "$MOUNT_POINT" bash -c "cd /var/www/ninja && php artisan key:generate --force"
    chroot "$MOUNT_POINT" bash -c "cd /var/www/ninja && php artisan migrate --force --seed"
    
    success "Invoice Ninja configured"
}

configure_nginx() {
    log "Configuring Nginx..."
    
    # Remove default site
    rm -f "$MOUNT_POINT/etc/nginx/sites-enabled/default"
    
    # Create Invoice Ninja site configuration
    cat > "$MOUNT_POINT/etc/nginx/sites-available/invoiceninja" << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/ninja/public;
    index index.php index.html index.htm;
    
    server_name _;
    
    charset utf-8;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
    
    access_log /var/log/nginx/invoiceninja.access.log;
    error_log /var/log/nginx/invoiceninja.error.log;
    
    sendfile off;
    
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF

    # Enable the site
    chroot "$MOUNT_POINT" ln -s /etc/nginx/sites-available/invoiceninja /etc/nginx/sites-enabled/
    
    # Enable services
    chroot "$MOUNT_POINT" systemctl enable nginx
    chroot "$MOUNT_POINT" systemctl enable php8.1-fpm
    
    success "Nginx configured"
}

install_bootloader() {
    log "Installing bootloader..."
    
    # Install kernel and bootloader for NanoPi Neo3
    chroot "$MOUNT_POINT" apt-get install -y linux-image-arm64 u-boot-tools
    
    # Create boot script
    cat > "$MOUNT_POINT/boot/boot.cmd" << 'EOF'
setenv bootargs console=ttyS0,115200 root=LABEL=rootfs rootwait rw
load mmc 0:1 ${kernel_addr_r} /boot/vmlinuz
load mmc 0:1 ${fdt_addr_r} /boot/dtb
bootz ${kernel_addr_r} - ${fdt_addr_r}
EOF

    chroot "$MOUNT_POINT" mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
    
    success "Bootloader installed"
}

create_startup_service() {
    log "Creating startup service..."
    
    # Create a service to ensure Invoice Ninja is ready on boot
    cat > "$MOUNT_POINT/etc/systemd/system/invoiceninja-setup.service" << 'EOF'
[Unit]
Description=Invoice Ninja Setup Service
After=network.target nginx.service php8.1-fpm.service
Wants=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/invoiceninja-setup.sh
RemainAfterExit=true
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Create the setup script
    cat > "$MOUNT_POINT/usr/local/bin/invoiceninja-setup.sh" << 'EOF'
#!/bin/bash
# Ensure Invoice Ninja is properly set up on first boot

cd /var/www/ninja

# Clear caches
php artisan config:clear
php artisan cache:clear
php artisan view:clear

# Ensure proper permissions
chown -R www-data:www-data /var/www/ninja
chmod -R 755 /var/www/ninja
chmod -R 775 /var/www/ninja/storage
chmod -R 775 /var/www/ninja/bootstrap/cache

# Update app URL with actual IP
IP_ADDRESS=$(ip route get 1 | awk '{print $7; exit}')
if [ ! -z "$IP_ADDRESS" ]; then
    sed -i "s|APP_URL=.*|APP_URL=http://$IP_ADDRESS|" /var/www/ninja/.env
fi

echo "Invoice Ninja is ready! Access it at http://$(hostname -I | awk '{print $1}')"
EOF

    chmod +x "$MOUNT_POINT/usr/local/bin/invoiceninja-setup.sh"
    chroot "$MOUNT_POINT" systemctl enable invoiceninja-setup.service
    
    success "Startup service created"
}

cleanup() {
    log "Cleaning up..."
    
    # Clean package cache
    chroot "$MOUNT_POINT" apt-get clean
    chroot "$MOUNT_POINT" apt-get autoremove -y
    
    # Remove qemu static
    rm -f "$MOUNT_POINT/usr/bin/qemu-aarch64-static"
    
    # Unmount and detach loop device
    umount "$MOUNT_POINT" 2>/dev/null || true
    losetup -d "$LOOP_DEVICE" 2>/dev/null || true
    
    success "Cleanup completed"
}

main() {
    echo "========================================"
    echo "NanoPi Neo3 Invoice Ninja Image Builder"
    echo "========================================"
    echo
    
    check_dependencies
    setup_workspace
    create_image
    setup_loop_device
    
    install_base_system
    configure_system
    install_packages
    install_invoice_ninja
    configure_invoice_ninja
    configure_nginx
    install_bootloader
    create_startup_service
    
    cleanup
    
    echo
    success "Image build completed!"
    echo
    echo "Your bootable image is ready at: $WORK_DIR/$IMAGE_NAME"
    echo
    echo "To flash to SD card, use:"
    echo "  sudo dd if=$WORK_DIR/$IMAGE_NAME of=/dev/sdX bs=4M status=progress"
    echo "  (Replace /dev/sdX with your SD card device)"
    echo
    echo "Default credentials:"
    echo "  Root password: invoiceninja123"
    echo "  Invoice Ninja will be accessible via web browser on port 80"
    echo
    warn "Remember to change the default root password after first boot!"
}

# Run main function
main "$@"
