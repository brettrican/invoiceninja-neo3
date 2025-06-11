#!/bin/bash
# Final setup verification for NanoPi Neo3 Self-Hosted Server Builder
# Comprehensive check of all components before building

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${BLUE}[CHECK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
header() { echo -e "\n${BOLD}${BLUE}$1${NC}\n"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

check_result() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ $1 -eq 0 ]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        success "✓ $2"
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        error "✗ $2"
    fi
}

warn_result() {
    WARNINGS=$((WARNINGS + 1))
    warn "⚠ $1"
}

check_core_files() {
    header "🔍 Core Files Check"
    
    local core_files=(
        "nanopi-invoiceninja-builder.sh:Main builder script"
        "build-nanopi-invoiceninja.sh:Image build script"
        "config.conf:Configuration file"
        "config-parser.sh:Configuration parser"
        "setup-dependencies.sh:Dependency installer"
        "flash-image.sh:SD card flasher"
        "test-build.sh:Build tester"
    )
    
    for file_info in "${core_files[@]}"; do
        local file="${file_info%%:*}"
        local desc="${file_info##*:}"
        
        if [ -f "$file" ]; then
            check_result 0 "$desc exists ($file)"
        else
            check_result 1 "$desc missing ($file)"
        fi
    done
}

check_web_ui_files() {
    header "🌐 Web UI Components Check"
    
    local web_files=(
        "web-management-ui.sh:Web management installer"
        "service-installer.sh:Service management system"
        "integrate-web-ui.sh:Integration script"
        "first-boot-setup.sh:First boot configuration"
    )
    
    for file_info in "${web_files[@]}"; do
        local file="${file_info%%:*}"
        local desc="${file_info##*:}"
        
        if [ -f "$file" ]; then
            check_result 0 "$desc exists ($file)"
        else
            check_result 1 "$desc missing ($file)"
        fi
    done
}

check_documentation() {
    header "📚 Documentation Check"
    
    local doc_files=(
        "README.md:Main documentation"
        "USAGE.md:Usage instructions"
        "QUICKSTART.md:Quick start guide"
    )
    
    for file_info in "${doc_files[@]}"; do
        local file="${file_info%%:*}"
        local desc="${file_info##*:}"
        
        if [ -f "$file" ]; then
            check_result 0 "$desc exists ($file)"
        else
            check_result 1 "$desc missing ($file)"
        fi
    done
}

check_script_permissions() {
    header "🔑 Script Permissions Check"
    
    local scripts=(
        "nanopi-invoiceninja-builder.sh"
        "build-nanopi-invoiceninja.sh"
        "setup-dependencies.sh"
        "flash-image.sh"
        "test-build.sh"
        "web-management-ui.sh"
        "service-installer.sh"
        "integrate-web-ui.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                check_result 0 "$script is executable"
            else
                warn_result "$script is not executable (will fix)"
                chmod +x "$script" 2>/dev/null || true
            fi
        fi
    done
}

check_configuration() {
    header "⚙️ Configuration Check"
    
    if [ -f "config.conf" ]; then
        # Check for required settings
        local required_settings=(
            "IMAGE_SIZE"
            "HOSTNAME"
            "ROOT_PASSWORD"
            "INSTALL_WEB_UI"
            "WEB_UI_PORT"
        )
        
        for setting in "${required_settings[@]}"; do
            if grep -q "^${setting}=" config.conf; then
                check_result 0 "Configuration has $setting"
            else
                check_result 1 "Configuration missing $setting"
            fi
        done
        
        # Check for web UI integration
        if grep -q "INSTALL_WEB_UI=yes" config.conf; then
            success "✓ Web UI is enabled in configuration"
        else
            warn_result "Web UI is not enabled in configuration"
        fi
        
    else
        check_result 1 "Configuration file missing"
    fi
}

check_system_requirements() {
    header "💻 System Requirements Check"
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        check_result 0 "Running as root"
    else
        check_result 1 "Not running as root (required for build)"
    fi
    
    # Check available disk space (need at least 10GB)
    local available_space=$(df . | awk 'NR==2 {print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    
    if [ "$available_gb" -ge 10 ]; then
        check_result 0 "Sufficient disk space (${available_gb}GB available)"
    else
        check_result 1 "Insufficient disk space (${available_gb}GB available, need 10GB+)"
    fi
    
    # Check for required commands
    local required_commands=(
        "curl:Download tool"
        "wget:Download tool"
        "git:Version control"
        "qemu-arm-static:ARM emulation"
        "debootstrap:Bootstrap tool"
        "parted:Partitioning tool"
    )
    
    for cmd_info in "${required_commands[@]}"; do
        local cmd="${cmd_info%%:*}"
        local desc="${cmd_info##*:}"
        
        if command -v "$cmd" >/dev/null 2>&1; then
            check_result 0 "$desc available ($cmd)"
        else
            check_result 1 "$desc missing ($cmd)"
        fi
    done
}

check_syntax() {
    header "🔍 Script Syntax Check"
    
    local scripts=(
        "nanopi-invoiceninja-builder.sh"
        "build-nanopi-invoiceninja.sh"
        "config-parser.sh"
        "web-management-ui.sh"
        "service-installer.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if bash -n "$script" 2>/dev/null; then
                check_result 0 "$script syntax is valid"
            else
                check_result 1 "$script has syntax errors"
            fi
        fi
    done
}

check_integration() {
    header "🔗 Integration Check"
    
    # Check if integration has been run
    if [ -f "neo3-first-boot.service" ]; then
        check_result 0 "First boot service created"
    else
        warn_result "First boot service not found (run integrate-web-ui.sh)"
    fi
    
    # Check if test scripts exist
    if [ -f "test-integration.sh" ]; then
        check_result 0 "Integration test script exists"
    else
        warn_result "Integration test script missing"
    fi
    
    # Check configuration for web UI settings
    if grep -q "WEB_UI_PORT" config.conf; then
        check_result 0 "Web UI configuration integrated"
    else
        warn_result "Web UI configuration not integrated"
    fi
}

show_summary() {
    header "📊 Summary Report"
    
    echo -e "Total Checks: ${BOLD}$TOTAL_CHECKS${NC}"
    echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"
    echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
    echo
    
    local success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    
    if [ "$FAILED_CHECKS" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}🎉 All checks passed! (${success_rate}%)${NC}"
        echo -e "${GREEN}Your build system is ready!${NC}"
        echo
        echo "Next steps:"
        echo "1. Run: sudo ./nanopi-invoiceninja-builder.sh"
        echo "2. Flash the image to SD card"
        echo "3. Boot your Neo3 and enjoy!"
        
        if [ "$WARNINGS" -gt 0 ]; then
            echo
            warn "Note: There were $WARNINGS warnings that should be addressed"
        fi
        
    elif [ "$success_rate" -ge 80 ]; then
        echo -e "${YELLOW}${BOLD}⚠️  Mostly ready (${success_rate}%)${NC}"
        echo -e "${YELLOW}You can proceed but should fix the failed checks${NC}"
        echo
        echo "Critical issues to fix:"
        echo "• Check failed items above"
        echo "• Run: sudo ./integrate-web-ui.sh (if not done)"
        echo "• Ensure all required files exist"
        
    else
        echo -e "${RED}${BOLD}❌ Not ready (${success_rate}%)${NC}"
        echo -e "${RED}Please fix the issues before building${NC}"
        echo
        echo "Required actions:"
        echo "• Download/create missing files"
        echo "• Run integration script: sudo ./integrate-web-ui.sh"
        echo "• Fix configuration issues"
        echo "• Install missing system requirements"
    fi
}

quick_fix() {
    header "🔧 Quick Fix Attempt"
    
    log "Attempting to fix common issues..."
    
    # Make scripts executable
    chmod +x *.sh 2>/dev/null || true
    success "Made all scripts executable"
    
    # Run integration if needed
    if [ ! -f "test-integration.sh" ] && [ -f "integrate-web-ui.sh" ]; then
        log "Running web UI integration..."
        if ./integrate-web-ui.sh; then
            success "Web UI integration completed"
        else
            warn "Web UI integration failed"
        fi
    fi
    
    # Create build directory
    mkdir -p build 2>/dev/null || true
    
    success "Quick fixes applied"
    echo
    log "Re-running checks..."
    echo
}

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Final setup verification for NanoPi Neo3 Builder"
    echo
    echo "Options:"
    echo "  --fix, -f        Attempt quick fixes"
    echo "  --help, -h       Show this help"
    echo
    echo "This script verifies that all components are ready for building"
    echo "your NanoPi Neo3 self-hosted server image."
}

main() {
    echo "=========================================="
    echo "NanoPi Neo3 Final Setup Check"
    echo "=========================================="
    echo
    
    case "${1:-}" in
        --fix|-f)
            quick_fix
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            # Continue with normal checks
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    
    check_core_files
    check_web_ui_files
    check_documentation
    check_script_permissions
    check_configuration
    check_system_requirements
    check_syntax
    check_integration
    
    show_summary
    
    echo
    if [ "$FAILED_CHECKS" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}🚀 Ready to build your Neo3 server!${NC}"
        exit 0
    else
        echo -e "${RED}${BOLD}❌ Please fix issues before building${NC}"
        exit 1
    fi
}

main "$@"
