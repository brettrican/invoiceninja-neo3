#!/bin/bash
# Test script for NanoPi Neo3 Invoice Ninja Image Builder

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    exit 1
}

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS=()

test_file_exists() {
    local file="$1"
    local description="$2"
    
    if [ -f "$file" ]; then
        success "$description exists"
        TEST_RESULTS+=("PASS: $description")
        return 0
    else
        fail "$description missing: $file"
        TEST_RESULTS+=("FAIL: $description")
        return 1
    fi
}

test_file_executable() {
    local file="$1"
    local description="$2"
    
    if [ -x "$file" ]; then
        success "$description is executable"
        TEST_RESULTS+=("PASS: $description executable")
        return 0
    else
        error "$description is not executable: $file"
        TEST_RESULTS+=("FAIL: $description not executable")
        return 1
    fi
}

test_dependencies() {
    log "Testing system dependencies..."
    
    local deps=("bash" "wget" "curl" "tar" "gzip")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            success "Found $dep"
        else
            missing+=("$dep")
            error "Missing $dep"
        fi
    done
    
    if [ ${#missing[@]} -eq 0 ]; then
        success "All basic dependencies available"
        TEST_RESULTS+=("PASS: Basic dependencies")
        return 0
    else
        error "Missing dependencies: ${missing[*]}"
        TEST_RESULTS+=("FAIL: Missing dependencies")
        return 1
    fi
}

test_config_parsing() {
    log "Testing configuration parsing..."
    
    # Source the config parser
    if [ -f "config-parser.sh" ]; then
        source config-parser.sh
        success "Config parser loaded"
    else
        error "Config parser not found"
        TEST_RESULTS+=("FAIL: Config parser missing")
        return 1
    fi
    
    # Test loading configuration
    if load_config "config.conf" &>/dev/null; then
        success "Configuration loaded successfully"
        TEST_RESULTS+=("PASS: Configuration parsing")
        return 0
    else
        error "Failed to load configuration"
        TEST_RESULTS+=("FAIL: Configuration parsing")
        return 1
    fi
}

test_image_size_validation() {
    log "Testing image size validation..."
    
    # Save original value
    local original_size="$IMAGE_SIZE"
    
    # Test valid size
    IMAGE_SIZE="4G"
    if validate_config &>/dev/null; then
        success "Valid image size accepted"
    else
        error "Valid image size rejected"
        TEST_RESULTS+=("FAIL: Image size validation")
        return 1
    fi
    
    # Test invalid size
    IMAGE_SIZE="invalid"
    if ! validate_config &>/dev/null; then
        success "Invalid image size rejected"
    else
        error "Invalid image size accepted"
        TEST_RESULTS+=("FAIL: Image size validation")
        return 1
    fi
    
    # Restore original value
    IMAGE_SIZE="$original_size"
    
    TEST_RESULTS+=("PASS: Image size validation")
    return 0
}

test_network_connectivity() {
    log "Testing network connectivity..."
    
    # Test basic connectivity
    if ping -c 1 8.8.8.8 &>/dev/null; then
        success "Internet connectivity available"
    else
        warn "No internet connectivity (required for package downloads)"
        TEST_RESULTS+=("WARN: No internet connectivity")
        return 1
    fi
    
    # Test Debian repository
    if curl -s --head http://deb.debian.org/debian/ &>/dev/null; then
        success "Debian repository accessible"
    else
        warn "Debian repository not accessible"
        TEST_RESULTS+=("WARN: Debian repository inaccessible")
        return 1
    fi
    
    # Test Invoice Ninja repository
    if curl -s --head https://github.com/invoiceninja/invoiceninja/releases &>/dev/null; then
        success "Invoice Ninja repository accessible"
    else
        warn "Invoice Ninja repository not accessible"
        TEST_RESULTS+=("WARN: Invoice Ninja repository inaccessible")
        return 1
    fi
    
    TEST_RESULTS+=("PASS: Network connectivity")
    return 0
}

test_disk_space() {
    log "Testing available disk space..."
    
    local available_space=$(df . | tail -1 | awk '{print $4}')
    local required_space=$((8 * 1024 * 1024)) # 8GB in KB
    
    if [ "$available_space" -gt "$required_space" ]; then
        success "Sufficient disk space available ($(($available_space / 1024 / 1024))GB)"
        TEST_RESULTS+=("PASS: Disk space")
        return 0
    else
        error "Insufficient disk space. Need at least 8GB, have $(($available_space / 1024 / 1024))GB"
        TEST_RESULTS+=("FAIL: Insufficient disk space")
        return 1
    fi
}

test_build_dependencies() {
    log "Testing build dependencies..."
    
    if [ "$EUID" -eq 0 ]; then
        # Test for required build tools
        local build_deps=("debootstrap" "qemu-user-static" "parted" "kpartx")
        local missing_build=()
        
        for dep in "${build_deps[@]}"; do
            if command -v "$dep" &> /dev/null; then
                success "Found build dependency: $dep"
            else
                missing_build+=("$dep")
                warn "Missing build dependency: $dep"
            fi
        done
        
        if [ ${#missing_build[@]} -eq 0 ]; then
            success "All build dependencies available"
            TEST_RESULTS+=("PASS: Build dependencies")
            return 0
        else
            warn "Missing build dependencies: ${missing_build[*]}"
            warn "Run: sudo ./setup-dependencies.sh"
            TEST_RESULTS+=("WARN: Missing build dependencies")
            return 1
        fi
    else
        warn "Not running as root - cannot test build dependencies"
        warn "Run: sudo $0 to test build dependencies"
        TEST_RESULTS+=("WARN: Cannot test build dependencies")
        return 1
    fi
}

test_config_generation() {
    log "Testing configuration file generation..."
    
    local temp_dir=$(mktemp -d)
    
    # Test environment file generation
    if generate_env_file "$temp_dir/test.env" &>/dev/null; then
        if [ -f "$temp_dir/test.env" ] && [ -s "$temp_dir/test.env" ]; then
            success "Environment file generation works"
        else
            error "Environment file generation failed"
            rm -rf "$temp_dir"
            TEST_RESULTS+=("FAIL: Config generation")
            return 1
        fi
    else
        error "Environment file generation failed"
        rm -rf "$temp_dir"
        TEST_RESULTS+=("FAIL: Config generation")
        return 1
    fi
    
    # Test PHP-FPM config generation
    if generate_php_fpm_config "$temp_dir/test-fpm.conf" &>/dev/null; then
        if [ -f "$temp_dir/test-fpm.conf" ] && [ -s "$temp_dir/test-fpm.conf" ]; then
            success "PHP-FPM config generation works"
        else
            error "PHP-FPM config generation failed"
            rm -rf "$temp_dir"
            TEST_RESULTS+=("FAIL: Config generation")
            return 1
        fi
    else
        error "PHP-FPM config generation failed"
        rm -rf "$temp_dir"
        TEST_RESULTS+=("FAIL: Config generation")
        return 1
    fi
    
    rm -rf "$temp_dir"
    TEST_RESULTS+=("PASS: Config generation")
    return 0
}

create_test_report() {
    local report_file="test-report.txt"
    
    {
        echo "NanoPi Neo3 Invoice Ninja Build System Test Report"
        echo "=================================================="
        echo "Generated: $(date)"
        echo "Host: $(hostname)"
        echo "User: $(whoami)"
        echo "OS: $(uname -a)"
        echo
        echo "Test Results:"
        echo "============="
        
        local pass_count=0
        local fail_count=0
        local warn_count=0
        
        for result in "${TEST_RESULTS[@]}"; do
            echo "$result"
            if [[ "$result" == "PASS:"* ]]; then
                ((pass_count++))
            elif [[ "$result" == "FAIL:"* ]]; then
                ((fail_count++))
            elif [[ "$result" == "WARN:"* ]]; then
                ((warn_count++))
            fi
        done
        
        echo
        echo "Summary:"
        echo "========"
        echo "PASSED: $pass_count"
        echo "FAILED: $fail_count"
        echo "WARNINGS: $warn_count"
        echo "TOTAL: $((pass_count + fail_count + warn_count))"
        
        if [ $fail_count -eq 0 ]; then
            echo
            echo "STATUS: READY TO BUILD"
            if [ $warn_count -gt 0 ]; then
                echo "Note: Warnings may affect build process"
            fi
        else
            echo
            echo "STATUS: NOT READY - PLEASE FIX FAILURES"
        fi
        
    } | tee "$report_file"
    
    log "Test report saved to: $report_file"
}

run_quick_test() {
    log "Running quick validation test..."
    
    test_file_exists "build-nanopi-invoiceninja.sh" "Main build script"
    test_file_exists "setup-dependencies.sh" "Dependency setup script"
    test_file_exists "flash-image.sh" "Flash utility script"
    test_file_exists "config.conf" "Configuration file"
    test_file_exists "config-parser.sh" "Config parser script"
    
    success "Quick test completed"
}

run_full_test() {
    log "Running comprehensive test suite..."
    
    # File existence tests
    test_file_exists "build-nanopi-invoiceninja.sh" "Main build script"
    test_file_exists "setup-dependencies.sh" "Dependency setup script"
    test_file_exists "flash-image.sh" "Flash utility script"
    test_file_exists "config.conf" "Configuration file"
    test_file_exists "config-parser.sh" "Config parser script"
    
    # File permissions tests
    test_file_executable "build-nanopi-invoiceninja.sh" "Main build script"
    test_file_executable "setup-dependencies.sh" "Dependency setup script"
    test_file_executable "flash-image.sh" "Flash utility script"
    
    # Dependency tests
    test_dependencies
    test_config_parsing
    test_image_size_validation
    test_network_connectivity
    test_disk_space
    test_build_dependencies
    test_config_generation
    
    success "Full test suite completed"
}

show_usage() {
    echo "Usage: $0 [--quick|--full|--help]"
    echo
    echo "Test the NanoPi Neo3 Invoice Ninja build system"
    echo
    echo "Options:"
    echo "  --quick  Run quick validation tests only"
    echo "  --full   Run comprehensive test suite (default)"
    echo "  --help   Show this help message"
    echo
}

main() {
    echo "========================================"
    echo "NanoPi Neo3 Invoice Ninja - Build Tester"
    echo "========================================"
    echo
    
    case "${1:-}" in
        --quick)
            run_quick_test
            ;;
        --full|"")
            run_full_test
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
    
    create_test_report
    
    # Exit with appropriate code
    local fail_count=0
    for result in "${TEST_RESULTS[@]}"; do
        if [[ "$result" == "FAIL:"* ]]; then
            ((fail_count++))
        fi
    done
    
    if [ $fail_count -eq 0 ]; then
        echo
        success "All tests passed! System is ready for building."
        exit 0
    else
        echo
        error "Some tests failed. Please address the issues before building."
        exit 1
    fi
}

main "$@"
