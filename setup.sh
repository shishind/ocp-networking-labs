#!/bin/bash
#
# OCP Networking Labs - Automated Setup Script
# This script installs all required tools for Week 1-7 labs
#
# Usage: sudo ./setup.sh
#

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    echo ""
    echo "=========================================="
    echo "  OCP Networking Labs - Setup Script"
    echo "=========================================="
    echo ""
}

# Check if running as root or with sudo
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        echo "Usage: sudo ./setup.sh"
        exit 1
    fi
}

# Detect OS distribution
detect_os() {
    log_info "Detecting operating system..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_NAME=$NAME
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
        OS_NAME=$(cat /etc/redhat-release)
    else
        log_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi

    log_info "Detected: $OS_NAME"

    case $OS in
        ubuntu|debian)
            PKG_MANAGER="apt-get"
            PKG_UPDATE="apt-get update"
            PKG_INSTALL="apt-get install -y"
            ;;
        rhel|centos|fedora|rocky|almalinux)
            PKG_MANAGER="dnf"
            # Use yum for older versions
            if ! command -v dnf &> /dev/null; then
                PKG_MANAGER="yum"
            fi
            PKG_UPDATE="$PKG_MANAGER check-update || true"
            PKG_INSTALL="$PKG_MANAGER install -y"
            ;;
        *)
            log_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac

    log_success "OS detected: $OS (Package manager: $PKG_MANAGER)"
}

# Update package lists
update_packages() {
    log_info "Updating package lists..."
    $PKG_UPDATE
    log_success "Package lists updated"
}

# Install basic networking tools
install_networking_tools() {
    log_info "Installing basic networking tools..."

    local packages=""

    case $OS in
        ubuntu|debian)
            packages="iproute2 iputils-ping net-tools dnsutils netcat-openbsd tcpdump curl wget socat traceroute mtr ethtool iptables nftables"
            ;;
        rhel|centos|fedora|rocky|almalinux)
            packages="iproute iputils net-tools bind-utils nmap-ncat tcpdump curl wget socat traceroute mtr ethtool iptables nftables"
            ;;
    esac

    $PKG_INSTALL $packages
    log_success "Networking tools installed"
}

# Install development utilities
install_dev_utilities() {
    log_info "Installing development utilities..."

    local packages="git jq vim bash-completion make python3 util-linux coreutils procps lsof htop"

    case $OS in
        ubuntu|debian)
            packages="$packages python3-pip nano"
            ;;
        rhel|centos|fedora|rocky|almalinux)
            packages="$packages python3-pip nano"
            ;;
    esac

    $PKG_INSTALL $packages
    log_success "Development utilities installed"
}

# Install yq (YAML processor)
install_yq() {
    log_info "Installing yq..."

    if command -v yq &> /dev/null; then
        log_warning "yq already installed, skipping"
        return
    fi

    local YQ_VERSION="v4.40.5"
    local YQ_BINARY="yq_linux_amd64"

    wget -q https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY} -O /usr/local/bin/yq
    chmod +x /usr/local/bin/yq

    log_success "yq installed"
}

# Install Docker
install_docker() {
    log_info "Installing Docker..."

    if command -v docker &> /dev/null; then
        log_warning "Docker already installed, skipping"
        docker --version
        return
    fi

    case $OS in
        ubuntu|debian)
            # Install prerequisites
            $PKG_INSTALL ca-certificates gnupg lsb-release

            # Add Docker's official GPG key
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg

            # Set up the repository
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
              $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

            # Install Docker
            apt-get update
            $PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        rhel|centos|rocky|almalinux)
            # Add Docker repository
            $PKG_INSTALL dnf-plugins-core || $PKG_INSTALL yum-utils
            dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || \
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

            # Install Docker
            $PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        fedora)
            # Add Docker repository
            $PKG_INSTALL dnf-plugins-core
            dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

            # Install Docker
            $PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
    esac

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    log_success "Docker installed and started"
    docker --version
}

# Install Podman (alternative container runtime)
install_podman() {
    log_info "Installing Podman..."

    if command -v podman &> /dev/null; then
        log_warning "Podman already installed, skipping"
        podman --version
        return
    fi

    case $OS in
        ubuntu|debian)
            # Podman is available in Ubuntu 20.10+ and Debian 11+
            $PKG_INSTALL podman buildah skopeo || log_warning "Podman not available in repositories"
            ;;
        rhel|centos|fedora|rocky|almalinux)
            $PKG_INSTALL podman buildah skopeo
            ;;
    esac

    if command -v podman &> /dev/null; then
        log_success "Podman installed"
        podman --version
    else
        log_warning "Podman installation skipped or failed"
    fi
}

# Install kubectl
install_kubectl() {
    log_info "Installing kubectl..."

    if command -v kubectl &> /dev/null; then
        log_warning "kubectl already installed, skipping"
        kubectl version --client
        return
    fi

    # Download latest stable version
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

    # Install kubectl
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl

    # Enable bash completion
    kubectl completion bash > /etc/bash_completion.d/kubectl

    log_success "kubectl installed"
    kubectl version --client
}

# Install kind (Kubernetes in Docker)
install_kind() {
    log_info "Installing kind (Kubernetes in Docker)..."

    if command -v kind &> /dev/null; then
        log_warning "kind already installed, skipping"
        kind version
        return
    fi

    # Download and install kind
    local KIND_VERSION="v0.22.0"
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64
    chmod +x ./kind
    mv ./kind /usr/local/bin/kind

    # Enable bash completion
    kind completion bash > /etc/bash_completion.d/kind

    log_success "kind installed"
    kind version
}

# Install OVS/OVN tools
install_ovs_ovn() {
    log_info "Installing Open vSwitch and OVN..."

    if command -v ovs-vsctl &> /dev/null; then
        log_warning "Open vSwitch already installed, skipping"
        ovs-vsctl --version
        return
    fi

    case $OS in
        ubuntu|debian)
            $PKG_INSTALL openvswitch-switch openvswitch-common ovn-central ovn-host || \
                log_warning "Some OVS/OVN packages not available"
            ;;
        rhel|centos|fedora|rocky|almalinux)
            $PKG_INSTALL openvswitch openvswitch-ovn-central openvswitch-ovn-host || \
                $PKG_INSTALL openvswitch ovn ovn-central ovn-host || \
                log_warning "Some OVS/OVN packages not available"
            ;;
    esac

    if command -v ovs-vsctl &> /dev/null; then
        log_success "Open vSwitch installed"
        ovs-vsctl --version
    else
        log_warning "OVS/OVN installation skipped or failed"
    fi
}

# Configure Docker for non-root user access
configure_docker_user() {
    log_info "Configuring Docker for non-root user access..."

    # Get the original user (before sudo)
    local ACTUAL_USER=${SUDO_USER:-$USER}

    if [ "$ACTUAL_USER" = "root" ]; then
        log_warning "Running as root user, skipping user group configuration"
        return
    fi

    # Add user to docker group
    usermod -aG docker $ACTUAL_USER

    log_success "User $ACTUAL_USER added to docker group"
    log_warning "Note: You may need to log out and back in for group changes to take effect"
}

# Create test environment
create_test_environment() {
    log_info "Creating test environment..."

    # Test Docker
    if command -v docker &> /dev/null; then
        log_info "Testing Docker installation..."
        docker run --rm hello-world > /dev/null 2>&1 && \
            log_success "Docker test successful" || \
            log_warning "Docker test failed (may need to log out/in for group permissions)"
    fi

    log_success "Test environment checks completed"
}

# Print completion message
print_completion() {
    echo ""
    echo "=========================================="
    log_success "Setup completed successfully!"
    echo "=========================================="
    echo ""
    echo "Next Steps:"
    echo "1. Log out and log back in (for Docker group permissions)"
    echo "2. Run the verification script:"
    echo "   ./verify-setup.sh"
    echo ""
    echo "3. Start with Week 1-2 labs:"
    echo "   cd week1-2"
    echo "   cat README.md"
    echo ""
    echo "Troubleshooting:"
    echo "- If Docker commands fail, try: newgrp docker"
    echo "- Or log out and log back in"
    echo "- Run ./verify-setup.sh to check installation"
    echo ""
}

# Main installation flow
main() {
    print_banner
    check_privileges
    detect_os
    update_packages

    # Install tools
    install_networking_tools
    install_dev_utilities
    install_yq
    install_docker
    install_podman
    install_kubectl
    install_kind
    install_ovs_ovn

    # Configuration
    configure_docker_user
    create_test_environment

    # Completion
    print_completion
}

# Run main function
main "$@"
