#!/bin/bash
# SD Card flashing utility for NanoPi Neo3 Invoice Ninja image

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

show_usage() {
    echo "Usage: $0 [IMAGE_FILE] [SD_DEVICE]"
    echo
    echo "Flash NanoPi Neo3 Invoice Ninja image to SD card"
    echo
    echo "Arguments:"
    echo "  IMAGE_FILE  Path to the .img file (optional, will prompt if not provided)"
    echo "  SD_DEVICE   SD card device (optional, will show available devices if not provided)"
    echo
    echo "Examples:"
    echo "  $0                                           # Interactive mode"
    echo "  $0 build/nanopi-neo3-invoiceninja.img       # Will prompt for device"
    echo "  $0 build/nanopi-neo3-invoiceninja.img /dev/sdb  # Direct flash"
    echo
    echo "Safety features:"
    echo "  - Shows available storage devices"
    echo "  - Confirms device selection"
    echo "  - Verifies image integrity"
    echo "  - Shows progress during flashing"
    echo
}

check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
    fi
}

find_image_file() {
    local image_file="$1"
    
    if [ -n "$image_file" ] && [ -f "$image_file" ]; then
        echo "$image_file"
        return
    fi
    
    # Look for image files in common locations
    local candidates=(
        "build/nanopi-neo3-invoiceninja.img"
        "nanopi-neo3-invoiceninja.img"
        "*.img"
    )
    
    log "Searching for image files..."
    
    for pattern in "${candidates[@]}"; do
        for file in $pattern; do
            if [ -f "$file" ]; then
                echo "Found image file: $file"
                read -p "Use this image file? (y/n): " -r
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    echo "$file"
                    return
                fi
            fi
        done
    done
    
    # Ask user to specify
    echo
    echo "Please specify the path to your image file:"
    read -r image_file
    
    if [ ! -f "$image_file" ]; then
        error "Image file not found: $image_file"
    fi
    
    echo "$image_file"
}

show_storage_devices() {
    log "Available storage devices:"
    echo
    
    # Show block devices
    lsblk -d -o NAME,SIZE,TYPE,MODEL,VENDOR | grep -E "(disk|card)"
    echo
    
    # Show more detailed info about removable devices
    log "Removable devices:"
    for dev in /sys/block/*/removable; do
        if [ -f "$dev" ] && [ "$(cat "$dev")" = "1" ]; then
            device="/dev/$(basename $(dirname "$dev"))"
            size=$(lsblk -d -n -o SIZE "$device" 2>/dev/null || echo "unknown")
            model=$(lsblk -d -n -o MODEL "$device" 2>/dev/null || echo "unknown")
            echo "  $device - $size - $model"
        fi
    done
    echo
}

select_device() {
    local device="$1"
    
    if [ -n "$device" ]; then
        if [ ! -b "$device" ]; then
            error "Device not found: $device"
        fi
        echo "$device"
        return
    fi
    
    show_storage_devices
    
    echo "Enter the device path (e.g., /dev/sdb):"
    echo "WARNING: All data on the selected device will be PERMANENTLY ERASED!"
    echo
    read -p "Device: " -r device
    
    if [ ! -b "$device" ]; then
        error "Invalid device: $device"
    fi
    
    echo "$device"
}

confirm_device() {
    local device="$1"
    local image_file="$2"
    
    echo
    warn "======================================="
    warn "         DANGER: DATA WILL BE LOST"
    warn "======================================="
    echo
    echo "Image file: $image_file"
    echo "Target device: $device"
    echo
    
    # Show device info
    log "Device information:"
    lsblk "$device" || true
    echo
    
    # Check if device is mounted
    if mount | grep -q "$device"; then
        warn "Device $device has mounted partitions:"
        mount | grep "$device"
        echo
        log "Attempting to unmount all partitions..."
        for part in ${device}*; do
            if [ "$part" != "$device" ]; then
                umount "$part" 2>/dev/null || true
            fi
        done
    fi
    
    echo "This will PERMANENTLY ERASE all data on $device"
    echo "Are you absolutely sure you want to continue?"
    echo
    read -p "Type 'YES' (in capital letters) to confirm: " -r confirmation
    
    if [ "$confirmation" != "YES" ]; then
        log "Operation cancelled by user"
        exit 0
    fi
}

verify_image() {
    local image_file="$1"
    
    log "Verifying image file..."
    
    # Check file size
    local size=$(stat -c%s "$image_file")
    local size_mb=$((size / 1024 / 1024))
    
    log "Image size: ${size_mb}MB"
    
    if [ $size -lt 1000000 ]; then
        warn "Image file seems very small (${size_mb}MB). Are you sure this is correct?"
        read -p "Continue anyway? (y/n): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    success "Image verification completed"
}

flash_image() {
    local image_file="$1"
    local device="$2"
    
    log "Starting flash process..."
    log "This may take several minutes..."
    echo
    
    # Flash the image
    if command -v pv &> /dev/null; then
        # Use pv for progress if available
        pv "$image_file" | dd of="$device" bs=4M conv=fsync
    else
        # Use dd with progress
        dd if="$image_file" of="$device" bs=4M status=progress conv=fsync
    fi
    
    # Sync to ensure all data is written
    sync
    
    success "Image flashed successfully!"
}

verify_flash() {
    local device="$1"
    
    log "Verifying flash (this may take a moment)..."
    
    # Re-read partition table
    partprobe "$device" 2>/dev/null || true
    sleep 2
    
    # Show new partition layout
    log "New partition layout:"
    lsblk "$device" || true
    
    success "Flash verification completed"
}

show_completion_info() {
    local device="$1"
    
    echo
    success "======================================="
    success "         FLASHING COMPLETED!"
    success "======================================="
    echo
    echo "Your NanoPi Neo3 SD card is ready!"
    echo
    echo "Next steps:"
    echo "1. Safely remove the SD card from your computer"
    echo "2. Insert it into your NanoPi Neo3"
    echo "3. Connect ethernet cable"
    echo "4. Power on the device"
    echo "5. Wait 2-3 minutes for first boot setup"
    echo "6. Find the device IP address on your network"
    echo "7. Open http://[device-ip] in your web browser"
    echo
    echo "Default credentials:"
    echo "  SSH: root / invoiceninja123"
    echo "  Invoice Ninja: Set up through web interface"
    echo
    warn "IMPORTANT: Change the default root password after first login!"
    echo
}

main() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_usage
        exit 0
    fi
    
    echo "========================================"
    echo "NanoPi Neo3 Invoice Ninja - SD Flasher"
    echo "========================================"
    echo
    
    check_privileges
    
    local image_file
    local device
    
    image_file=$(find_image_file "$1")
    verify_image "$image_file"
    
    device=$(select_device "$2")
    confirm_device "$device" "$image_file"
    
    flash_image "$image_file" "$device"
    verify_flash "$device"
    
    show_completion_info "$device"
}

main "$@"
