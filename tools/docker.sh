#!/bin/bash

# Docker Installation Script for Ubuntu
# Version: 0.1.0
# Compatible: Ubuntu 22.04 LTS (Jammy) and Ubuntu 24.04 LTS (Noble)

set -euo pipefail

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
readonly ARROW="→"
readonly DOCKER="🐳"
readonly GEAR="⚙"

# Script configuration
readonly SCRIPT_NAME="Docker Installer"
readonly SCRIPT_VERSION="0.1.0"
readonly LOG_FILE="/tmp/docker_install_$(date +%Y%m%d_%H%M%S).log"

# Function to print colored output with icons
print_header() {
    echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${DOCKER} ${SCRIPT_NAME} v${SCRIPT_VERSION} ${DOCKER}${NC}"
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

# Function to log commands
log_command() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executing: $*" >> "$LOG_FILE"
    "$@" 2>&1 | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root for security reasons."
        print_info "Please run as a regular user. The script will use sudo when needed."
        exit 1
    fi
}

# Function to check Ubuntu version
check_ubuntu_version() {
    print_step "Checking Ubuntu version compatibility"

    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot determine OS version. /etc/os-release not found."
        exit 1
    fi

    source /etc/os-release

    case $VERSION_ID in
        "22.04")
            print_success "Ubuntu 22.04 LTS (Jammy) detected - Supported"
            UBUNTU_CODENAME="jammy"
            ;;
        "24.04")
            print_success "Ubuntu 24.04 LTS (Noble) detected - Supported"
            UBUNTU_CODENAME="noble"
            ;;
        *)
            print_error "Unsupported Ubuntu version: $VERSION_ID"
            print_info "This script supports Ubuntu 22.04 and 24.04 only"
            exit 1
            ;;
    esac
}

# Function to check system requirements
check_system_requirements() {
    print_step "Checking system requirements"

    # Check architecture
    ARCH=$(dpkg --print-architecture)
    case $ARCH in
        amd64|arm64|armhf)
            print_success "Architecture $ARCH is supported"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    # Check available disk space (minimum 2GB)
    AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
    if [[ $AVAILABLE_SPACE -lt 2097152 ]]; then
        print_warning "Low disk space detected. Minimum 2GB recommended."
    else
        print_success "Sufficient disk space available"
    fi

    # Check memory (minimum 1GB)
    TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
    if [[ $TOTAL_MEM -lt 1024 ]]; then
        print_warning "Low memory detected. Minimum 1GB recommended for Docker."
    else
        print_success "Sufficient memory available ($TOTAL_MEM MB)"
    fi
}

# Function to check if Docker is already installed
check_existing_docker() {
    print_step "Checking for existing Docker installation"

    if command -v docker >/dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version 2>/dev/null || echo "Unknown")
        print_warning "Docker is already installed: $DOCKER_VERSION"

        read -p "Do you want to reinstall Docker? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installation cancelled by user"
            exit 0
        fi

        print_substep "Proceeding with Docker reinstallation"
    else
        print_success "No existing Docker installation found"
    fi
}

# Function to update system packages
update_system() {
    print_step "Updating system packages"

    print_substep "Updating package index"
    log_command sudo apt-get update

    print_substep "Installing prerequisite packages"
    log_command sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common

    print_success "System packages updated successfully"
}

# Function to remove old Docker versions
remove_old_docker() {
    print_step "Removing old Docker versions (if any)"

    OLD_PACKAGES="docker docker-engine docker.io containerd runc docker-compose"

    for package in $OLD_PACKAGES; do
        if dpkg -l | grep -q "^ii.*$package "; then
            print_substep "Removing $package"
            log_command sudo apt-get remove -y "$package"
        fi
    done

    print_success "Old Docker packages removed"
}

# Function to add Docker's official GPG key and repository
setup_docker_repository() {
    print_step "Setting up Docker's official repository"

    print_substep "Creating keyrings directory"
    sudo mkdir -p /etc/apt/keyrings

    print_substep "Adding Docker's official GPG key"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    print_substep "Setting up Docker repository"
    echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $UBUNTU_CODENAME stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    print_substep "Updating package index with Docker repository"
    log_command sudo apt-get update

    print_success "Docker repository configured successfully"
}

# Function to install Docker Engine
install_docker_engine() {
    print_step "Installing Docker Engine"

    print_substep "Installing Docker CE, CLI, and containerd"
    log_command sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    print_success "Docker Engine installed successfully"
}

# Function to configure Docker for non-root usage
configure_docker_user() {
    print_step "Configuring Docker for non-root usage"

    print_substep "Adding current user to docker group"
    log_command sudo usermod -aG docker "$USER"

    print_substep "Setting up Docker socket permissions"
    sudo chmod 666 /var/run/docker.sock

    print_success "Docker user configuration completed"
    print_warning "Note: You may need to log out and back in for group changes to take effect"
}

# Function to configure Docker daemon
configure_docker_daemon() {
    print_step "Configuring Docker daemon with best practices"

    print_substep "Creating Docker daemon configuration at /etc/docker/daemon.json"

    # Create daemon.json with best practices for 2025
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "features": {
        "buildkit": true
    },
    "default-address-pools": [
        {
            "base": "172.20.0.0/16",
            "size": 24
        }
    ],
    "userland-proxy": false,
    "experimental": false,
    "live-restore": true
}
EOF

    print_substep "Enabling Docker service"
    log_command sudo systemctl enable docker

    print_substep "Starting Docker service"
    log_command sudo systemctl start docker

    print_substep "Restarting Docker with new configuration"
    log_command sudo systemctl restart docker

    print_success "Docker daemon configured with best practices"
}

# Function to verify Docker installation
verify_installation() {
    print_step "Verifying Docker installation"

    print_substep "Checking Docker version"
    DOCKER_VERSION=$(docker --version)
    print_info "$DOCKER_VERSION"

    print_substep "Checking Docker Compose version"
    COMPOSE_VERSION=$(docker compose version)
    print_info "$COMPOSE_VERSION"

    print_substep "Checking Docker service status"
    if sudo systemctl is-active --quiet docker; then
        print_success "Docker service is running"
    else
        print_error "Docker service is not running"
        return 1
    fi

    print_substep "Running Docker hello-world test"
    if docker run --rm hello-world >/dev/null 2>&1; then
        print_success "Docker hello-world test passed"
    else
        print_warning "Docker hello-world test failed (this may be due to group permissions)"
        print_info "Try logging out and back in, then run: docker run hello-world"
    fi

    print_success "Docker installation verification completed"
}

# Function to display post-installation information
show_post_install_info() {
    print_step "Post-installation information"

    echo -e "\n${GREEN}${CHECKMARK} Docker installation completed successfully!${NC}\n"

    echo -e "${CYAN}📋 Installation Summary:${NC}"
    echo -e "   • Docker Engine: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    echo -e "   • Docker Compose: $(docker compose version --short)"
    echo -e "   • Architecture: $ARCH"
    echo -e "   • Ubuntu Version: $VERSION_ID ($UBUNTU_CODENAME)"
    echo -e "   • Installation Log: $LOG_FILE"

    echo -e "\n${YELLOW}⚠️  Important Notes:${NC}"
    echo -e "   • You may need to log out and back in for group changes to take effect"
    echo -e "   • Test your installation: ${WHITE}docker run hello-world${NC}"
    echo -e "   • Check Docker status: ${WHITE}sudo systemctl status docker${NC}"

    echo -e "\n${CYAN}🚀 Quick Start Commands:${NC}"
    echo -e "   • Start a container: ${WHITE}docker run -it ubuntu:latest bash${NC}"
    echo -e "   • List containers: ${WHITE}docker ps -a${NC}"
    echo -e "   • List images: ${WHITE}docker images${NC}"
    echo -e "   • Docker Compose: ${WHITE}docker compose up -d${NC}"

    echo -e "\n${CYAN}📚 Additional Resources:${NC}"
    echo -e "   • Docker Documentation: https://docs.docker.com/"
    echo -e "   • Docker Compose Guide: https://docs.docker.com/compose/"
    echo -e "   • Best Practices: https://docs.docker.com/develop/best-practices/"

    echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
}

# Function to handle script interruption
cleanup() {
    print_error "\nScript interrupted by user"
    print_info "Installation log saved to: $LOG_FILE"
    exit 130
}

# Main installation function
main() {
    # Set up signal handlers
    trap cleanup SIGINT SIGTERM

    # Start logging
    echo "Docker Installation Script Log - $(date)" > "$LOG_FILE"

    print_header

    # Pre-installation checks
    check_root
    check_ubuntu_version
    check_system_requirements
    check_existing_docker

    # Installation process
    update_system
    remove_old_docker
    setup_docker_repository
    install_docker_engine
    configure_docker_user
    configure_docker_daemon

    # Post-installation
    verify_installation
    show_post_install_info

    print_success "\n🎉 Docker installation completed successfully!"
    print_info "Installation log saved to: $LOG_FILE"
}

# Run main function
main "$@"
