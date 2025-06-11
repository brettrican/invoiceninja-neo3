#!/bin/bash
# Dependency installer and system preparation script for NanoPi Neo3 Image Builder

set -e

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

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        error "Cannot detect OS. This script supports Ubuntu/Debian systems."
    fi
    
    log "Detected OS: $OS $VER"
}

install_ubuntu_debian() {
    log "Installing dependencies for Ubuntu/Debian..."
    
    # Update package list
    apt-get update
    
    # Install required packages
    apt-get install -y \
        debootstrap \
        qemu-user-static \
        parted \
        kpartx \
        wget \
        curl \
        binfmt-support \
        dosfstools \
        zip \
        unzip
    
    success "Dependencies installed for Ubuntu/Debian"
}

install_arch() {
    log "Installing dependencies for Arch Linux..."
    
    # Install required packages
    pacman -Sy --noconfirm \
        debootstrap \
        qemu-user-static \
        parted \
        device-mapper \
        wget \
        curl \
        dosfstools \
        zip \
        unzip
    
    success "Dependencies installed for Arch Linux"
}

install_fedora_centos() {
    log "Installing dependencies for Fedora/CentOS..."
    
    # Install required packages
    if command -v dnf &> /dev/null; then
        dnf install -y \
            debootstrap \
            qemu-user-static \
            parted \
            kpartx \
            wget \
            curl \
            dosfstools \
            zip \
            unzip
    else
        yum install -y \
            debootstrap \
            qemu-user-static \
            parted \
            kpartx \
            wget \
            curl \
            dosfstools \
            zip \
            unzip
    fi
    
    success "Dependencies installed for Fedora/CentOS"
}

check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
    fi
}

enable_services() {
    log "Enabling required services..."
    
    # Enable binfmt support for cross-architecture emulation
    if systemctl is-enabled binfmt-support &>/dev/null; then
        systemctl enable binfmt-support
    fi
    
    success "Services configured"
}

verify_installation() {
    log "Verifying installation..."
    
    local deps=("debootstrap" "qemu-aarch64-static" "parted" "kpartx" "wget" "curl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        warn "Some dependencies might not be available: ${missing[*]}"
        warn "The build script will check again and provide specific error messages"
    else
        success "All dependencies verified"
    fi
}

show_usage() {
    echo "Usage: $0 [--help]"
    echo
    echo "This script installs all dependencies required for building NanoPi Neo3 images."
    echo "It supports Ubuntu, Debian, Arch Linux, Fedora, and CentOS."
    echo
    echo "After running this script, you can use:"
    echo "  sudo ./build-nanopi-invoiceninja.sh"
    echo
}

main() {
    if [ "$1" = "--help" ]; then
        show_usage
        exit 0
    fi
    
    echo "=========================================="
    echo "NanoPi Neo3 Image Builder - Dependencies"
    echo "=========================================="
    echo
    
    check_privileges
    detect_os
    
    case $OS in
        ubuntu|debian)
            install_ubuntu_debian
            ;;
        arch)
            install_arch
            ;;
        fedora|centos|rhel)
            install_fedora_centos
            ;;
        *)
            error "Unsupported OS: $OS. This script supports Ubuntu, Debian, Arch Linux, Fedora, and CentOS."
            ;;
    esac
    
    enable_services
    verify_installation
    
    echo
    success "System preparation completed!"
    echo
    echo "You can now run the image builder:"
    echo "  sudo ./build-nanopi-invoiceninja.sh"
    echo
}

main "$@"
