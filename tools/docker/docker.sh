#!/bin/bash

# Docker Installation Script for Ubuntu
# Compatible: Ubuntu 22.04 LTS (Jammy) and Ubuntu 24.04 LTS (Noble)

set -euo pipefail

# Global variables
readonly APP_NAME="docker"
readonly APP_SECTION="tools"
readonly SCRIPT_VERSION="0.1.0"

# Color definitions for elegant output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Unicode symbols for better visual appeal
readonly CHECKMARK="✓"
readonly CROSS="✗"
readonly INFO="ℹ"
readonly ARROW="▸"
readonly GEAR="▹"
readonly APP_SYMBOL="★"

# Script configuration
readonly SCRIPT_PATH="/${APP_SECTION}/${APP_NAME}"
readonly SCRIPT_NAME="Installer for ${APP_NAME}"
readonly BASE_URL="https://raw.githubusercontent.com/agonza05/runap/refs/heads/main"
readonly LOG_FILE="/tmp/${APP_NAME}_$(date +%Y%m%d_%H%M%S).log"

# Function to print colored output with icons
print_header() {
    echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${APP_SYMBOL} ${SCRIPT_NAME} v${SCRIPT_VERSION} ${APP_SYMBOL}${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "${BLUE}${ARROW} ${1}${NC}"
}

print_substep() {
    echo -e "  ${CYAN}${GEAR} ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}${CHECKMARK} ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}${INFO} ${1}${NC}"
}

print_error() {
    echo -e "${RED}${CROSS} ${1}${NC}" >&2
}

print_info() {
    echo -e "${CYAN}${INFO} ${1}${NC}"
}

# Function to start log file
start_logging() {
    echo "${SCRIPT_NAME} Log - $(date)" > "${LOG_FILE}"
}

# Function to log commands
log_command() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executing: $*" >> "${LOG_FILE}"
    print_info "Executing command. Please wait..."
    # Print output to log file and errors to console
    "$@" >> "${LOG_FILE}" 2>&1
    # Print output to console and log file
    # "$@" 2>&1 | tee -a "${LOG_FILE}"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "This script should not be run as root for security reasons."
        print_info "Please run as a regular user. The script will use sudo when needed."
        exit 1
    else
        print_step "Checking sudo privileges"

        sudo echo -e "${GREEN}${CHECKMARK} Privileges successfully granted.${NC}"
    fi
}

# Function to check OS version
check_system_compatibility() {
    print_step "Checking system compatibility"

    print_substep "Checking OS version"

    if [ ! -f /etc/os-release ]; then
        print_error "Cannot determine OS version. /etc/os-release not found."
        exit 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release

    if [ "${ID}" == "ubuntu" ]; then
        case ${VERSION_ID} in
            "22.04"|"24.04")
                print_success "${PRETTY_NAME} detected - Supported"
                OS=${ID}
                OS_CODENAME=${VERSION_CODENAME}
                OS_VERSION=${VERSION_ID}
                ;;
            *)
                print_error "Unsupported Ubuntu version: ${VERSION_ID}"
                print_info "This script supports Ubuntu 22.04 and 24.04 only"
                exit 1
                ;;
        esac
    fi

    print_substep "Checking system architecture"

        # Check architecture
        ARCH=$(uname -m)
        if [ "${ARCH}" == "x86_64" ]; then
            OS_ARCH="amd64"
            OS_ARCH_ALT=${ARCH}
            print_success "Architecture ${OS_ARCH} is supported"
        else
            print_error "Unsupported architecture: ${ARCH}"
            exit 1
        fi

}

# Function to check system requirements
check_system_requirements() {
    print_step "Checking system requirements"

    # Check available disk space (minimum 10GB)
    AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
    if [[ ${AVAILABLE_SPACE} -lt 10485760 ]]; then
        print_warning "Low disk space detected. Minimum 10GB recommended."
    else
        print_success "Sufficient disk space available"
    fi

    # Check memory (minimum 2GB)
    TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
    if [[ ${TOTAL_MEM} -lt 2048 ]]; then
        print_warning "Low memory detected. Minimum 2GB recommended."
    else
        print_success "Sufficient memory available (${TOTAL_MEM} MB)"
    fi
}

# Function to update system packages
update_system() {
    print_step "Updating system packages"

    print_substep "Updating package index"
    log_command sudo apt-get update

    print_substep "Upgrading packages"
    log_command sudo apt-get upgrade -y

    print_success "System packages updated successfully"
}

# Function to run installation script
run_install_script() {
    print_step "Running installation script"

    print_info "Installing from: ${BASE_URL}"
    print_info "Script located at: ${SCRIPT_PATH}"
    log_command whoami
    log_command curl -LsSf ${BASE_URL}${SCRIPT_PATH}/install.sh | bash

    print_success "Docker installed successfully"
}

# Function to display post-installation information
show_post_install_info() {
    print_step "Post-installation information"

    print_info "Log file saved to: ${LOG_FILE}"
    print_info "System information: ${OS} ${OS_CODENAME} (${OS_VERSION}) on ${OS_ARCH} (${OS_ARCH_ALT})"
    echo
    print_success "🎉 ${SCRIPT_NAME} completed successfully!"

    echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
}

# Function to handle script interruption
cleanup() {
    print_error "\nScript interrupted by user"
    print_info "Log file saved to: ${LOG_FILE}"
    exit 130
}

# Main installation function
main() {
    # Set up signal handlers
    trap cleanup SIGINT SIGTERM

    # Start log file
    start_logging

    # Start logging
    start_logging

    # Print header text
    print_header

    # Pre-installation checks
    check_root
    check_system_compatibility
    check_system_requirements

    # Installation process
    update_system
    run_install_script

    # Post-installation
    show_post_install_info
}

# Run main function
main "$@"
