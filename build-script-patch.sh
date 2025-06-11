#!/bin/bash
# Patch to add Web UI installation to the build process

add_web_ui_to_build() {
    local build_script="build-nanopi-invoiceninja.sh"
    
    # Find the line where we should add the Web UI installation
    local insert_line=$(grep -n "Final system optimizations" "$build_script" | cut -d: -f1)
    
    if [ -n "$insert_line" ]; then
        # Create temporary file with Web UI installation
        cat > web_ui_install_block.tmp << 'WEBUI_EOF'

# Install Web Management UI and Services
log "Installing Web Management UI..."
if [ -f "/tmp/build-files/web-management-ui.sh" ]; then
    chmod +x /tmp/build-files/web-management-ui.sh
    chroot "$ROOTFS_DIR" /tmp/build-files/web-management-ui.sh
else
    warn "Web Management UI installer not found"
fi

# Install Service Manager
log "Installing Service Management System..."
if [ -f "/tmp/build-files/service-installer.sh" ]; then
    cp /tmp/build-files/service-installer.sh "$ROOTFS_DIR/usr/local/bin/"
    chmod +x "$ROOTFS_DIR/usr/local/bin/service-installer.sh"
fi

# Copy additional scripts
cp /tmp/build-files/*.sh "$ROOTFS_DIR/opt/neo3-scripts/" 2>/dev/null || true
chmod +x "$ROOTFS_DIR/opt/neo3-scripts/"*.sh 2>/dev/null || true

WEBUI_EOF
        
        # Insert the Web UI block before final optimizations
        head -n $((insert_line - 1)) "$build_script" > "$build_script.tmp"
        cat web_ui_install_block.tmp >> "$build_script.tmp"
        tail -n +$insert_line "$build_script" >> "$build_script.tmp"
        
        mv "$build_script.tmp" "$build_script"
        rm -f web_ui_install_block.tmp
        
        success "Build script updated with Web UI installation"
    else
        warn "Could not find insertion point in build script"
    fi
}

add_web_ui_to_build
