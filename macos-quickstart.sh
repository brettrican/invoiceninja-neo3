#!/bin/bash
# Quick Start Script for macOS Users
# Sets up everything needed to build NanoPi Neo3 images on macOS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${BLUE}[SETUP]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
header() { echo -e "\n${BOLD}${BLUE}$1${NC}\n"; }

check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        error "This script is for macOS only."
    fi
    
    local macos_version=$(sw_vers -productVersion)
    log "Running on macOS $macos_version"
    
    # Check minimum version (10.14 Mojave)
    if [[ $(echo "$macos_version" | cut -d. -f1-2 | tr -d .) -lt 1014 ]]; then
        error "macOS 10.14 (Mojave) or later required. You have $macos_version"
    fi
    
    success "macOS version compatible"
}

check_xcode_tools() {
    log "Checking Xcode Command Line Tools..."
    
    if ! xcode-select -p &> /dev/null; then
        warn "Xcode Command Line Tools not installed"
        read -p "Install Xcode Command Line Tools now? (y/n): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Installing Xcode Command Line Tools..."
            xcode-select --install
            echo
            warn "Please complete the Xcode installation in the popup window"
            warn "Then run this script again"
            exit 0
        else
            error "Xcode Command Line Tools are required"
        fi
    else
        success "Xcode Command Line Tools installed"
    fi
}

check_docker() {
    log "Checking Docker Desktop..."
    
    if ! command -v docker &> /dev/null; then
        warn "Docker Desktop not found"
        echo
        echo "Docker Desktop is required for building ARM64 images on macOS."
        echo
        read -p "Open Docker Desktop download page? (y/n): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open "https://www.docker.com/products/docker-desktop"
            echo
            warn "Please download and install Docker Desktop"
            warn "Then run this script again"
            exit 0
        else
            error "Docker Desktop is required"
        fi
    else
        success "Docker found at $(which docker)"
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        warn "Docker is not running"
        log "Starting Docker Desktop..."
        open -a Docker
        
        echo "Waiting for Docker to start..."
        local attempts=0
        while ! docker info &> /dev/null && [ $attempts -lt 30 ]; do
            echo -n "."
            sleep 2
            attempts=$((attempts + 1))
        done
        echo
        
        if docker info &> /dev/null; then
            success "Docker is now running"
        else
            error "Docker failed to start. Please start Docker Desktop manually"
        fi
    else
        success "Docker is running"
    fi
}

install_homebrew() {
    log "Checking Homebrew..."
    
    if ! command -v brew &> /dev/null; then
        warn "Homebrew not found"
        read -p "Install Homebrew? (recommended) (y/n): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            
            # Add Homebrew to PATH for Apple Silicon Macs
            if [[ $(uname -m) == "arm64" ]]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
            
            success "Homebrew installed"
        else
            warn "Skipping Homebrew installation"
        fi
    else
        success "Homebrew found at $(which brew)"
    fi
}

install_helpful_tools() {
    if command -v brew &> /dev/null; then
        log "Installing helpful tools via Homebrew..."
        
        local tools=("wget" "pv" "nmap")
        for tool in "${tools[@]}"; do
            if ! command -v "$tool" &> /dev/null; then
                log "Installing $tool..."
                brew install --quiet "$tool" || warn "Failed to install $tool"
            else
                success "$tool already installed"
            fi
        done
    else
        warn "Homebrew not available, skipping additional tools"
    fi
}

check_disk_space() {
    log "Checking disk space..."
    
    local available_gb=$(df -g . | awk 'NR==2 {print $4}')
    
    if [ "$available_gb" -lt 15 ]; then
        warn "Low disk space: ${available_gb}GB available (recommend 15GB+)"
        read -p "Continue anyway? (y/n): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        success "Sufficient disk space: ${available_gb}GB available"
    fi
}

setup_build_environment() {
    log "Setting up build environment..."
    
    # Make all scripts executable
    chmod +x *.sh 2>/dev/null || true
    
    # Create build directory
    mkdir -p build
    
    success "Build environment ready"
}

show_next_steps() {
    header "🎉 Setup Complete!"
    
    echo "Your macOS environment is ready to build NanoPi Neo3 images!"
    echo
    echo "📋 What's been set up:"
    echo "• ✅ macOS compatibility verified"
    echo "• ✅ Xcode Command Line Tools"
    echo "• ✅ Docker Desktop running"
    echo "• ✅ Homebrew and useful tools"
    echo "• ✅ Build environment configured"
    echo
    echo "🚀 Next steps:"
    echo
    echo "1. Customize your build (optional):"
    echo "   nano config.conf"
    echo
    echo "2. Start building your image:"
    echo "   ./nanopi-invoiceninja-builder-macos.sh"
    echo
    echo "3. While it builds (25-45 minutes):"
    echo "   • Prepare an 8GB+ SD card"
    echo "   • Download Balena Etcher for flashing"
    echo "   • Read README-macOS.md for detailed instructions"
    echo
    echo "4. After building:"
    echo "   • Flash image to SD card"
    echo "   • Insert into NanoPi Neo3"
    echo "   • Power on and access web interface"
    echo
    echo "💡 Pro tips:"
    echo "• The build runs in Docker - your Mac stays clean"
    echo "• Web interface works great on iPhone/iPad"
    echo "• Change default passwords after first boot!"
    echo
    warn "⚠️  Remember: Use correct disk device when flashing SD card!"
}

run_quick_build_check() {
    read -p "Run a quick build system test? (y/n): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Running quick build system test..."
        
        # Test Docker with a simple ARM64 container
        if docker run --rm --platform linux/arm64 alpine:latest echo "ARM64 build test successful" > /dev/null 2>&1; then
            success "Docker ARM64 emulation working"
        else
            warn "Docker ARM64 emulation test failed - builds may not work"
        fi
        
        # Check script syntax
        local scripts=("nanopi-invoiceninja-builder-macos.sh" "build-nanopi-invoiceninja-macos.sh")
        for script in "${scripts[@]}"; do
            if [ -f "$script" ]; then
                if bash -n "$script" 2>/dev/null; then
                    success "$script syntax OK"
                else
                    warn "$script has syntax errors"
                fi
            fi
        done
        
        success "Build system test completed"
    fi
}

main() {
    echo "=========================================="
    echo "🍎 NanoPi Neo3 Builder - macOS Setup"
    echo "=========================================="
    echo
    echo "This script will set up everything needed to build"
    echo "NanoPi Neo3 bootable images on your Mac."
    echo
    
    check_macos
    check_xcode_tools
    check_docker
    install_homebrew
    install_helpful_tools
    check_disk_space
    setup_build_environment
    run_quick_build_check
    show_next_steps
    
    echo
    success "🎯 Setup completed successfully!"
    echo
    echo "Ready to build? Run:"
    echo "  ./nanopi-invoiceninja-builder-macos.sh"
}

main "$@"
