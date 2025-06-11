#!/bin/bash
# NanoPi Neo3 Invoice Ninja Image Builder - macOS Version
# Uses Docker to create bootable SD card images on macOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/build"
IMAGE_NAME="nanopi-neo3-invoiceninja.img"
IMAGE_SIZE="4G"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

check_macos_dependencies() {
    log "Checking macOS dependencies..."
    
    # Check if we're on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        error "This script is designed for macOS. Use the regular version on Linux."
    fi
    
    # Check for Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is required but not installed. Please install Docker Desktop for Mac."
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker Desktop."
    fi
    
    # Check for sufficient disk space (at least 10GB)
    local available_space=$(df -g . | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 10 ]; then
        error "Insufficient disk space. Need at least 10GB free."
    fi
    
    success "macOS dependencies satisfied"
}

create_docker_builder() {
    log "Creating Docker build environment..."
    
    cat > "$WORK_DIR/Dockerfile" << 'EOF'
FROM debian:bullseye-slim

# Install build dependencies
RUN apt-get update && apt-get install -y \
    debootstrap \
    qemu-user-static \
    parted \
    kpartx \
    wget \
    curl \
    git \
    binfmt-support \
    dosfstools \
    rsync \
    xz-utils \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create build user
RUN useradd -m -s /bin/bash builder && \
    echo 'builder ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Set up working directory
WORKDIR /build
COPY . /build/

# Make scripts executable
RUN chmod +x /build/*.sh

# Switch to builder user for safety
USER root

CMD ["/bin/bash"]
EOF
    
    success "Docker build environment created"
}

create_build_script() {
    log "Creating container build script..."
    
    cat > "$WORK_DIR/docker-build.sh" << 'EOF'
#!/bin/bash
set -e

# Source configuration
if [ -f "/build/config-parser.sh" ] && [ -f "/build/config.conf" ]; then
    source /build/config-parser.sh
    load_config
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[DOCKER-BUILD]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

WORK_DIR="/build"
IMAGE_NAME="${IMAGE_NAME:-nanopi-neo3-invoiceninja.img}"
IMAGE_SIZE="${IMAGE_SIZE:-4G}"
MOUNT_POINT="/tmp/nanopi-mount"
ROOTFS_DIR="/tmp/nanopi-rootfs"

# Convert image size to MB
case "$IMAGE_SIZE" in
    *G|*g) SIZE_MB=$(echo "$IMAGE_SIZE" | sed 's/[Gg]//' | awk '{print $1*1024}') ;;
    *M|*m) SIZE_MB=$(echo "$IMAGE_SIZE" | sed 's/[Mm]//') ;;
    *) SIZE_MB=4096 ;;
esac

setup_workspace() {
    log "Setting up container workspace..."
    mkdir -p "$MOUNT_POINT" "$ROOTFS_DIR"
    success "Container workspace ready"
}

create_image() {
    log "Creating disk image (${IMAGE_SIZE})..."
    
    dd if=/dev/zero of="$WORK_DIR/$IMAGE_NAME" bs=1M count=0 seek="$SIZE_MB" status=progress
    
    # Create partition table using parted
    parted -s "$WORK_DIR/$IMAGE_NAME" mklabel msdos
    parted -s "$WORK_DIR/$IMAGE_NAME" mkpart primary ext4 1MiB 100%
    parted -s "$WORK_DIR/$IMAGE_NAME" set 1 boot on
    
    success "Disk image created"
}

setup_loop_device() {
    log "Setting up loop device..."
    
    # Use kpartx for loop device management
    LOOP_DEV=$(losetup -fP --show "$WORK_DIR/$IMAGE_NAME")
    
    # Wait for device to be ready
    sleep 2
    
    # Format the partition
    mkfs.ext4 -F "${LOOP_DEV}p1"
    
    # Mount the partition
    mount "${LOOP_DEV}p1" "$MOUNT_POINT"
    
    export LOOP_DEVICE="$LOOP_DEV"
    success "Loop device $LOOP_DEV configured and mounted"
}

install_base_system() {
    log "Installing base Debian system for ARM64..."
    
    # Use debootstrap to create ARM64 rootfs
    debootstrap --arch=arm64 --foreign bullseye "$ROOTFS_DIR" http://deb.debian.org/debian
    
    # Copy qemu static for ARM64 emulation
    cp /usr/bin/qemu-aarch64-static "$ROOTFS_DIR/usr/bin/"
    
    # Complete the bootstrap in chroot
    chroot "$ROOTFS_DIR" /debootstrap/debootstrap --second-stage
    
    success "Base system installed"
}

configure_system() {
    log "Configuring system for NanoPi Neo3..."
    
    # Configure APT sources
    cat > "$ROOTFS_DIR/etc/apt/sources.list" << 'SOURCES_EOF'
deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian-security bullseye-security main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
SOURCES_EOF
    
    # Set hostname
    echo "${HOSTNAME:-nanopi-invoiceninja}" > "$ROOTFS_DIR/etc/hostname"
    
    # Configure hosts
    cat > "$ROOTFS_DIR/etc/hosts" << 'HOSTS_EOF'
127.0.0.1       localhost
127.0.1.1       nanopi-invoiceninja
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
HOSTS_EOF
    
    # Set root password
    echo "root:${ROOT_PASSWORD:-invoiceninja123}" | chroot "$ROOTFS_DIR" chpasswd
    
    success "Basic system configuration completed"
}

install_web_stack() {
    log "Installing web stack (Nginx, PHP, SQLite)..."
    
    # Update package list and install packages
    chroot "$ROOTFS_DIR" apt-get update
    chroot "$ROOTFS_DIR" apt-get install -y \
        nginx \
        php8.1-fpm \
        php8.1-cli \
        php8.1-common \
        php8.1-mysql \
        php8.1-sqlite3 \
        php8.1-zip \
        php8.1-gd \
        php8.1-mbstring \
        php8.1-curl \
        php8.1-xml \
        php8.1-bcmath \
        php8.1-json \
        php8.1-tokenizer \
        php8.1-fileinfo \
        php8.1-intl \
        sqlite3 \
        curl \
        wget \
        git \
        unzip \
        supervisor \
        cron \
        nano \
        htop \
        ufw \
        fail2ban \
        openssh-server
    
    success "Web stack installed"
}

install_invoice_ninja() {
    log "Installing Invoice Ninja..."
    
    # Create web directory
    mkdir -p "$ROOTFS_DIR/var/www/ninja"
    
    # Download Invoice Ninja
    chroot "$ROOTFS_DIR" wget -O /tmp/ninja.zip https://download.invoiceninja.com/
    chroot "$ROOTFS_DIR" unzip /tmp/ninja.zip -d /var/www/
    chroot "$ROOTFS_DIR" rm /tmp/ninja.zip
    
    # Set permissions
    chroot "$ROOTFS_DIR" chown -R www-data:www-data /var/www/ninja
    chroot "$ROOTFS_DIR" chmod -R 755 /var/www/ninja
    chroot "$ROOTFS_DIR" chmod -R 775 /var/www/ninja/storage
    chroot "$ROOTFS_DIR" chmod -R 775 /var/www/ninja/bootstrap/cache
    
    # Create SQLite database
    chroot "$ROOTFS_DIR" touch /var/www/ninja/database/database.sqlite
    chroot "$ROOTFS_DIR" chown www-data:www-data /var/www/ninja/database/database.sqlite
    chroot "$ROOTFS_DIR" chmod 664 /var/www/ninja/database/database.sqlite
    
    success "Invoice Ninja installed"
}

configure_services() {
    log "Configuring web services..."
    
    # Configure Nginx
    cat > "$ROOTFS_DIR/etc/nginx/sites-available/default" << 'NGINX_EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/ninja/public;
    index index.php index.html;
    
    server_name _;
    
    client_max_body_size 100M;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
NGINX_EOF
    
    # Enable services
    chroot "$ROOTFS_DIR" systemctl enable nginx
    chroot "$ROOTFS_DIR" systemctl enable php8.1-fpm
    chroot "$ROOTFS_DIR" systemctl enable ssh
    
    success "Services configured"
}

install_boot_files() {
    log "Installing boot files for NanoPi Neo3..."
    
    # Install kernel and bootloader
    chroot "$ROOTFS_DIR" apt-get install -y linux-image-arm64 u-boot-sunxi
    
    # Create boot script
    cat > "$ROOTFS_DIR/boot/boot.cmd" << 'BOOT_EOF'
setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p1 rootwait rw
load mmc 0:1 0x43000000 /boot/vmlinuz
load mmc 0:1 0x44000000 /boot/initrd.img
bootz 0x43000000 0x44000000
BOOT_EOF
    
    # Compile boot script
    chroot "$ROOTFS_DIR" mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
    
    success "Boot files installed"
}

finalize_image() {
    log "Finalizing image..."
    
    # Sync filesystem to mounted image
    rsync -avP "$ROOTFS_DIR/" "$MOUNT_POINT/"
    
    # Sync and unmount
    sync
    umount "$MOUNT_POINT" || true
    losetup -d "$LOOP_DEVICE" || true
    
    # Compress image
    log "Compressing image..."
    xz -z -9 "$WORK_DIR/$IMAGE_NAME"
    
    success "Image finalized: $WORK_DIR/$IMAGE_NAME.xz"
}

cleanup() {
    log "Cleaning up..."
    umount "$MOUNT_POINT" 2>/dev/null || true
    [ -n "$LOOP_DEVICE" ] && losetup -d "$LOOP_DEVICE" 2>/dev/null || true
    rm -rf "$ROOTFS_DIR" "$MOUNT_POINT"
}

trap cleanup EXIT

main() {
    log "Starting NanoPi Neo3 image build in Docker container..."
    
    setup_workspace
    create_image
    setup_loop_device
    install_base_system
    configure_system
    install_web_stack
    install_invoice_ninja
    configure_services
    install_boot_files
    finalize_image
    
    success "Build completed successfully!"
    log "Image ready: $WORK_DIR/$IMAGE_NAME.xz"
}

main "$@"
EOF

    chmod +x "$WORK_DIR/docker-build.sh"
    success "Container build script created"
}

build_docker_image() {
    log "Building Docker image..."
    
    docker build -t nanopi-builder "$WORK_DIR"
    
    success "Docker image built"
}

run_build_in_container() {
    log "Running build process in Docker container..."
    log "This will take 20-40 minutes depending on your internet speed..."
    
    # Run the build in a privileged container (needed for loop devices)
    docker run --rm \
        --privileged \
        -v "$SCRIPT_DIR:/build" \
        -v "$WORK_DIR:/build/output" \
        nanopi-builder \
        /build/docker-build.sh
    
    success "Build completed in container"
}

setup_workspace() {
    log "Setting up macOS workspace..."
    
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
    
    # Copy necessary files to build directory
    cp "$SCRIPT_DIR"/*.sh "$WORK_DIR/" 2>/dev/null || true
    cp "$SCRIPT_DIR"/*.conf "$WORK_DIR/" 2>/dev/null || true
    
    success "Workspace ready at $WORK_DIR"
}

main() {
    echo "=========================================="
    echo "NanoPi Neo3 Builder for macOS"
    echo "=========================================="
    echo
    
    check_macos_dependencies
    setup_workspace
    create_docker_builder
    create_build_script
    build_docker_image
    run_build_in_container
    
    echo
    success "🎉 Build completed successfully!"
    echo
    echo "Your bootable image is ready:"
    echo "📁 Location: $WORK_DIR/$IMAGE_NAME.xz"
    echo "📏 Compressed size: $(ls -lh "$WORK_DIR/$IMAGE_NAME.xz" 2>/dev/null | awk '{print $5}' || echo 'Unknown')"
    echo
    echo "🔄 Next steps:"
    echo "1. Extract: gunzip $WORK_DIR/$IMAGE_NAME.xz"
    echo "2. Flash to SD card using:"
    echo "   • Balena Etcher (GUI): https://www.balena.io/etcher/"
    echo "   • Command line: sudo dd if=$WORK_DIR/$IMAGE_NAME of=/dev/diskX bs=4m"
    echo "     (Replace /dev/diskX with your SD card device)"
    echo "3. Insert SD card into NanoPi Neo3 and power on"
    echo
    warn "⚠️  Important: Use 'diskutil list' to find the correct SD card device"
    warn "⚠️  Wrong device selection can destroy your data!"
}

main "$@"
