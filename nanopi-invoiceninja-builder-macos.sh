#!/bin/bash
# NanoPi Neo3 Invoice Ninja Builder - macOS Version
# One-click utility for macOS users

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
header() { echo -e "\n${BOLD}${BLUE}$1${NC}\n"; }

check_root() {
    if [ "$EUID" -eq 0 ]; then
        error "This macOS version should NOT be run as root. Run as regular user."
    fi
}

check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        error "This script is for macOS only. Use the regular version on Linux."
    fi
    
    log "Running on macOS $(sw_vers -productVersion)"
}

check_system() {
    header "🔍 System Requirements Check"
    
    check_macos
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is required but not installed. Please install Docker Desktop for Mac from: https://www.docker.com/products/docker-desktop"
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker Desktop and try again."
    fi
    
    success "Docker is running"
    
    # Check disk space (need at least 15GB)
    local available_gb=$(df -g . | awk 'NR==2 {print $4}')
    if [ "$available_gb" -lt 15 ]; then
        warn "Low disk space. You have ${available_gb}GB free, recommend 15GB+"
        read -p "Continue anyway? (y/n): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        success "Sufficient disk space (${available_gb}GB available)"
    fi
    
    # Check for required tools
    local tools=("unzip" "curl" "git")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            success "$tool is available"
        else
            error "$tool is required but not found. Install Xcode Command Line Tools: xcode-select --install"
        fi
    done
}

install_dependencies() {
    header "📦 Installing Dependencies"
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        log "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        success "Homebrew installed"
    else
        success "Homebrew is already installed"
    fi
    
    # Install useful tools
    log "Installing helpful tools..."
    brew install --quiet wget pv || true
    
    success "Dependencies ready"
}

show_configuration() {
    header "⚙️  Configuration Summary"
    
    if [ -f "./config-parser.sh" ] && [ -f "./config.conf" ]; then
        source ./config-parser.sh
        load_config
        show_config
    else
        warn "Configuration files not found, using defaults"
        log "Default configuration:"
        echo "  • Image Size: 4GB"
        echo "  • Hostname: nanopi-invoiceninja"
        echo "  • Root Password: invoiceninja123"
        echo "  • Web UI: Enabled on port 8080"
        echo "  • Services: Monitoring, Backup, VPN ready"
    fi
    
    echo
    read -p "Do you want to proceed with this configuration? (y/n): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "You can edit config.conf to customize the build"
        exit 0
    fi
}

build_image() {
    header "🏗️  Building Bootable Image"
    
    if [ -f "./build-nanopi-invoiceninja-macos.sh" ]; then
        log "Starting macOS Docker-based build process..."
        log "This will take 25-45 minutes depending on your internet speed..."
        echo
        
        # Make sure the script is executable
        chmod +x ./build-nanopi-invoiceninja-macos.sh
        
        # Run the macOS build script
        if ./build-nanopi-invoiceninja-macos.sh; then
            success "Image build completed successfully!"
            return 0
        else
            error "Image build failed. Check the output above for details."
        fi
    else
        error "build-nanopi-invoiceninja-macos.sh not found"
    fi
}

offer_flash() {
    header "💾 SD Card Flashing"
    
    echo "Your bootable image is ready!"
    echo "Location: build/nanopi-neo3-invoiceninja.img.xz"
    echo
    echo "Flashing options for macOS:"
    echo
    echo "1. 🖥️  Balena Etcher (Recommended - GUI)"
    echo "   Download: https://www.balena.io/etcher/"
    echo "   • Easy to use graphical interface"
    echo "   • Automatically detects SD cards"
    echo "   • Built-in verification"
    echo
    echo "2. ⌨️  Command Line (Advanced users)"
    echo "   • First extract: gunzip build/nanopi-neo3-invoiceninja.img.xz"
    echo "   • Find SD card: diskutil list"
    echo "   • Flash: sudo dd if=build/nanopi-neo3-invoiceninja.img of=/dev/diskX bs=4m"
    echo "   (Replace diskX with your SD card)"
    echo
    
    read -p "Open Balena Etcher download page? (y/n): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "https://www.balena.io/etcher/"
    fi
    
    show_manual_flash_instructions
}

show_manual_flash_instructions() {
    header "📋 Manual Flashing Instructions (Command Line)"
    
    echo "1. Extract the compressed image:"
    echo "   gunzip build/nanopi-neo3-invoiceninja.img.xz"
    echo
    echo "2. Insert your SD card and find its device:"
    echo "   diskutil list"
    echo "   (Look for your SD card, usually /dev/disk2 or /dev/disk3)"
    echo
    echo "3. Unmount the SD card (if mounted):"
    echo "   diskutil unmountDisk /dev/diskX"
    echo
    echo "4. Flash the image:"
    echo "   sudo dd if=build/nanopi-neo3-invoiceninja.img of=/dev/diskX bs=4m"
    echo "   (This will take 10-20 minutes)"
    echo
    echo "5. Eject the SD card:"
    echo "   diskutil eject /dev/diskX"
    echo
    warn "⚠️  CRITICAL WARNING: Double-check the disk number!"
    warn "⚠️  Wrong disk selection will destroy your Mac's data!"
    echo
    echo "💡 Pro tip: Use 'diskutil list' before and after inserting"
    echo "   the SD card to identify the correct device."
}

show_completion_info() {
    header "🎉 Build Complete!"
    
    echo
    echo -e "${BOLD}${GREEN}Your NanoPi Neo3 Invoice Ninja image is ready!${NC}"
    echo
    echo "📁 Image location: build/nanopi-neo3-invoiceninja.img.xz"
    echo "📏 Compressed size: $(ls -lh build/nanopi-neo3-invoiceninja.img.xz 2>/dev/null | awk '{print $5}' || echo 'Unknown')"
    echo
    echo "🚀 Next Steps:"
    echo "1. Flash the image to an 8GB+ SD card using Balena Etcher"
    echo "2. Insert SD card into your NanoPi Neo3"
    echo "3. Connect ethernet cable to your network"
    echo "4. Power on the device"
    echo "5. Wait 3-5 minutes for first boot setup"
    echo "6. Find device IP on your network:"
    echo "   • Check your router's admin panel"
    echo "   • Use: nmap -sn 192.168.1.0/24"
    echo "   • Look for hostname 'nanopi-invoiceninja'"
    echo "7. Open http://[device-ip]:8080 for Web Admin"
    echo "8. Open http://[device-ip] for Invoice Ninja"
    echo
    echo "🔐 Default Credentials:"
    echo "• SSH: root / invoiceninja123"
    echo "• Web Admin: admin / neo3admin123"
    echo "• Invoice Ninja: Setup wizard on first access"
    echo
    echo "🌐 Services Available:"
    echo "• 📊 Invoice Ninja: http://[device-ip]"
    echo "• 🎛️  Web Admin UI: http://[device-ip]:8080"
    echo "• 📈 System Monitor: http://[device-ip]:19999 (after install)"
    echo "• 🔧 SSH Access: ssh root@[device-ip]"
    echo
    echo "🔧 Service Installation:"
    echo "Use the Web Admin UI or SSH and run: service-installer.sh"
    echo
    warn "🔒 IMPORTANT: Change default passwords after first boot!"
    echo
    echo "📱 The web interface is mobile-friendly and works great on:"
    echo "• iPhone/iPad for quick monitoring"
    echo "• Mac for full administration"
    echo
    echo "🎯 Enjoy your self-hosted Invoice Ninja server!"
}

interactive_mode() {
    header "🚀 Interactive Build Mode"
    
    echo "This will build a complete NanoPi Neo3 server image with:"
    echo "• Invoice Ninja (SQLite-based for efficiency)"
    echo "• Web Management Interface"
    echo "• System Monitoring"
    echo "• Service Management System"
    echo "• AI Assistant Integration"
    echo "• Ready for additional services (VPN, backup, etc.)"
    echo
    
    # Step 1: Check system
    check_system
    echo
    
    # Step 2: Install dependencies
    install_dependencies
    echo
    
    # Step 3: Show configuration
    show_configuration
    echo
    
    # Step 4: Build image
    build_image
    echo
    
    # Step 5: Offer flashing help
    offer_flash
    echo
    
    # Step 6: Show completion info
    show_completion_info
}

automated_mode() {
    log "Running in automated mode..."
    
    check_system
    install_dependencies
    build_image
    
    show_completion_info
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "NanoPi Neo3 Invoice Ninja Builder for macOS"
    echo "Uses Docker to build bootable SD card images"
    echo
    echo "Options:"
    echo "  --interactive, -i    Interactive mode (default)"
    echo "  --automated, -a      Automated mode (no prompts)"
    echo "  --help, -h           Show this help"
    echo
    echo "Prerequisites:"
    echo "  • macOS 10.14+ (Mojave or later)"
    echo "  • Docker Desktop for Mac"
    echo "  • 15GB+ free disk space"
    echo "  • Internet connection"
    echo
    echo "Examples:"
    echo "  $0                   # Interactive mode"
    echo "  $0 -i                # Interactive mode"
    echo "  $0 -a                # Automated mode"
    echo
    echo "First time setup:"
    echo "  1. Install Docker Desktop from docker.com"
    echo "  2. Start Docker Desktop"
    echo "  3. Run this script"
    echo
}

main() {
    echo "=========================================="
    echo "🍎 NanoPi Neo3 Builder for macOS"
    echo "=========================================="
    echo
    
    case "${1:-}" in
        --interactive|-i|"")
            check_root
            interactive_mode
            ;;
        --automated|-a)
            check_root
            automated_mode
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
