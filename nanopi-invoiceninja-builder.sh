#!/bin/bash
# NanoPi Neo3 Invoice Ninja - Master One-Click Builder
# Complete automation script for building bootable SD card images

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
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

header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
}

show_banner() {
    echo
    echo -e "${BOLD}${GREEN}================================================================${NC}"
    echo -e "${BOLD}${GREEN}    NanoPi Neo3 Invoice Ninja - One-Click Builder v1.0${NC}"
    echo -e "${BOLD}${GREEN}================================================================${NC}"
    echo
    echo "This script will:"
    echo "  ✓ Check and install all dependencies"
    echo "  ✓ Build a complete bootable SD card image"
    echo "  ✓ Configure Invoice Ninja with SQLite"
    echo "  ✓ Optionally flash the image to SD card"
    echo
    echo "Requirements:"
    echo "  • Linux system (Ubuntu/Debian/Arch/Fedora/CentOS)"
    echo "  • Root access (sudo)"
    echo "  • 8GB+ free disk space"
    echo "  • Internet connection"
    echo "  • SD card (8GB+ recommended)"
    echo -e "${BOLD}${GREEN}================================================================${NC}"
    echo
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root. Please use: sudo $0"
    fi
}

check_system() {
    header "🔍 Checking System Requirements"
    
    # Check if we're on a supported system
    if [ ! -f /etc/os-release ]; then
        error "Cannot detect OS. This script supports Linux systems only."
    fi
    
    source /etc/os-release
    log "Detected OS: $ID $VERSION_ID"
    
    # Check available disk space
    local available_space=$(df . | tail -1 | awk '{print $4}')
    local required_space=$((8 * 1024 * 1024)) # 8GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        error "Insufficient disk space. Need at least 8GB, have $(($available_space / 1024 / 1024))GB"
    fi
    
    log "Available disk space: $(($available_space / 1024 / 1024))GB"
    
    # Check internet connectivity
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        error "No internet connection. Internet access is required for downloading packages."
    fi
    
    log "Internet connectivity: OK"
    success "System requirements check passed"
}

install_dependencies() {
    header "📦 Installing Dependencies"
    
    if [ -f "./setup-dependencies.sh" ]; then
        log "Running dependency installer..."
        ./setup-dependencies.sh
        success "Dependencies installed successfully"
    else
        error "setup-dependencies.sh not found"
    fi
}

run_tests() {
    header "🧪 Running System Tests"
    
    if [ -f "./test-build.sh" ]; then
        log "Running comprehensive tests..."
        if ./test-build.sh --full; then
            success "All tests passed"
        else
            error "Some tests failed. Please check the test report."
        fi
    else
        warn "test-build.sh not found, skipping tests"
    fi
}

show_configuration() {
    header "⚙️  Configuration Summary"
    
    if [ -f "./config-parser.sh" ] && [ -f "./config.conf" ]; then
        source ./config-parser.sh
        load_config
        show_config
    else
        warn "Configuration files not found, using defaults"
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
    
    if [ -f "./build-nanopi-invoiceninja.sh" ]; then
        log "Starting image build process..."
        log "This will take 15-30 minutes depending on your internet speed..."
        echo
        
        # Run the build script
        if ./build-nanopi-invoiceninja.sh; then
            success "Image build completed successfully!"
            return 0
        else
            error "Image build failed. Check the output above for details."
        fi
    else
        error "build-nanopi-invoiceninja.sh not found"
    fi
}

offer_flash() {
    header "💾 SD Card Flashing"
    
    echo "Your bootable image is ready!"
    echo "Location: build/nanopi-neo3-invoiceninja.img"
    echo
    read -p "Do you want to flash it to an SD card now? (y/n): " -r
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "./flash-image.sh" ]; then
            log "Starting SD card flashing utility..."
            ./flash-image.sh
        else
            error "flash-image.sh not found"
        fi
    else
        show_manual_flash_instructions
    fi
}

show_manual_flash_instructions() {
    header "📋 Manual Flashing Instructions"
    
    echo "To flash the image manually:"
    echo
    echo "1. Insert your SD card into your computer"
    echo "2. Find the device name (usually /dev/sdX):"
    echo "   lsblk"
    echo
    echo "3. Flash the image:"
    echo "   sudo dd if=build/nanopi-neo3-invoiceninja.img of=/dev/sdX bs=4M status=progress"
    echo "   (Replace /dev/sdX with your actual SD card device)"
    echo
    echo "4. Safely eject the SD card"
    echo
    warn "⚠️  WARNING: Double-check the device name to avoid data loss!"
}

show_completion_info() {
    header "🎉 Build Complete!"
    
    echo
    echo -e "${BOLD}${GREEN}Your NanoPi Neo3 Invoice Ninja image is ready!${NC}"
    echo
    echo "📁 Image location: build/nanopi-neo3-invoiceninja.img"
    echo "📏 Image size: $(ls -lh build/nanopi-neo3-invoiceninja.img 2>/dev/null | awk '{print $5}' || echo 'Unknown')"
    echo
    echo "🚀 Next Steps:"
    echo "1. Flash the image to an 8GB+ SD card"
    echo "2. Insert SD card into your NanoPi Neo3"
    echo "3. Connect ethernet cable"
    echo "4. Power on the device"
    echo "5. Wait 2-3 minutes for first boot"
    echo "6. Find device IP on your network"
    echo "7. Open http://[device-ip] in web browser"
    echo
    echo "🔐 Default Credentials:"
    echo "• SSH: root / invoiceninja123"
    echo "• Invoice Ninja: Configure via web interface"
    echo
    echo -e "${BOLD}${RED}⚠️  IMPORTANT: Change default passwords after first login!${NC}"
    echo
    echo "📚 For detailed instructions, see README.md"
    echo
}

cleanup_on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo
        error "Build process failed with exit code $exit_code"
        echo
        echo "Troubleshooting:"
        echo "• Check the error messages above"
        echo "• Ensure you have sufficient disk space"
        echo "• Verify internet connection"
        echo "• Try running: sudo ./test-build.sh --full"
        echo
        echo "For help, check README.md or create an issue"
    fi
}

interactive_mode() {
    show_banner
    
    echo "Welcome to the interactive setup!"
    echo
    read -p "Press Enter to start the build process..."
    echo
    
    trap cleanup_on_exit EXIT
    
    # Step 1: System check
    check_system
    echo
    
    # Step 2: Install dependencies
    install_dependencies
    echo
    
    # Step 3: Run tests
    read -p "Run system tests? (recommended) (y/n): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_tests
        echo
    fi
    
    # Step 4: Show configuration
    show_configuration
    echo
    
    # Step 5: Build image
    build_image
    echo
    
    # Step 6: Offer to flash
    offer_flash
    echo
    
    # Step 7: Show completion info
    show_completion_info
}

automated_mode() {
    log "Running in automated mode..."
    
    trap cleanup_on_exit EXIT
    
    check_system
    install_dependencies
    run_tests
    build_image
    
    show_completion_info
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "One-click builder for NanoPi Neo3 Invoice Ninja bootable images"
    echo
    echo "Options:"
    echo "  --interactive, -i    Interactive mode (default)"
    echo "  --automated, -a      Automated mode (no prompts)"
    echo "  --help, -h           Show this help"
    echo
    echo "Examples:"
    echo "  sudo $0              # Interactive mode"
    echo "  sudo $0 -i           # Interactive mode"
    echo "  sudo $0 -a           # Automated mode"
    echo
}

main() {
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
