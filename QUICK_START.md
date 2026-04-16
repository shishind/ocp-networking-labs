# OCP Networking Labs - Quick Start Guide

Welcome to the OpenShift Container Platform (OCP) Networking Labs! This guide will help you get your environment set up quickly and start learning.

## Table of Contents

- [Prerequisites](#prerequisites)
- [One-Command Setup](#one-command-setup)
- [Manual Setup (Alternative)](#manual-setup-alternative)
- [Verify Installation](#verify-installation)
- [First Lab](#first-lab)
- [Troubleshooting](#troubleshooting)
- [What's Included](#whats-included)

## Prerequisites

Before starting, ensure you have:

- **Operating System**: Linux (Ubuntu 20.04+, Debian 11+, RHEL 8+, Fedora 35+, Rocky Linux 8+, AlmaLinux 8+)
- **Architecture**: x86_64 (AMD64)
- **Memory**: At least 4GB RAM (8GB+ recommended for Kubernetes labs)
- **Disk Space**: 20GB+ free space
- **Privileges**: sudo/root access
- **Network**: Internet connection for downloading tools

## One-Command Setup

The easiest way to get started is to run our automated setup script:

```bash
# Make the script executable
chmod +x setup.sh

# Run the setup (requires sudo)
sudo ./setup.sh
```

The setup script will:
- Detect your OS automatically
- Install all required networking tools
- Set up Docker and container runtime
- Install Kubernetes tools (kubectl, kind)
- Install OVS/OVN tools for Week 7 labs
- Configure Docker for your user
- Create a test environment

**Time estimate**: 10-15 minutes (depending on internet speed)

## Manual Setup (Alternative)

If you prefer to install tools manually or the automated script doesn't work for your system:

### Ubuntu/Debian

```bash
# Update package lists
sudo apt update

# Install networking tools
sudo apt install -y iproute2 iputils-ping net-tools dnsutils netcat-openbsd \
  tcpdump curl wget socat traceroute mtr ethtool iptables nftables

# Install development utilities
sudo apt install -y git jq vim bash-completion make python3 python3-pip

# Install Docker (see https://docs.docker.com/engine/install/ubuntu/)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### RHEL/Fedora/Rocky/AlmaLinux

```bash
# Update package lists
sudo dnf check-update

# Install networking tools
sudo dnf install -y iproute iputils net-tools bind-utils nmap-ncat \
  tcpdump curl wget socat traceroute mtr ethtool iptables nftables

# Install development utilities
sudo dnf install -y git jq vim bash-completion make python3 python3-pip

# Install Docker (see https://docs.docker.com/engine/install/fedora/)
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

## Verify Installation

After running the setup (automated or manual), verify everything is working:

```bash
# Make verification script executable
chmod +x verify-setup.sh

# Run verification
./verify-setup.sh
```

The verification script will:
- Check all required commands are available
- Show version information for key tools
- Test Docker functionality
- Test network capabilities
- Provide specific fix commands for any missing tools

**Expected output**: All checks should pass with green checkmarks (✓)

### Quick Manual Verification

```bash
# Check core tools
docker --version
kubectl version --client
kind version

# Test Docker
docker run --rm hello-world
```

## First Lab

Once setup is complete and verified, start with Week 1-2 labs:

```bash
# Navigate to Week 1-2 directory
cd week1-2

# Read the lab overview
cat README.md

# Start with Lab 1
cat lab1-*.md
```

### Week-by-Week Overview

- **Week 1-2**: Linux networking fundamentals (network namespaces, interfaces, routing)
- **Week 3-4**: Container networking basics (Docker networking, CNI concepts)
- **Week 5-6**: Kubernetes networking (Services, Ingress, NetworkPolicies)
- **Week 7**: OVS/OVN deep dive (SDN implementation in OCP)
- **Week 8**: Advanced topics and real-world scenarios

## Troubleshooting

### Docker Permission Denied

**Problem**: `permission denied while trying to connect to the Docker daemon socket`

**Solution**:
```bash
# Add your user to docker group
sudo usermod -aG docker $USER

# Apply group changes (option 1: log out/in, or option 2: run)
newgrp docker

# Test
docker run --rm hello-world
```

### Docker Daemon Not Running

**Problem**: `Cannot connect to the Docker daemon`

**Solution**:
```bash
# Start Docker service
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker

# Check status
sudo systemctl status docker
```

### Kind Cluster Creation Fails

**Problem**: `failed to create cluster`

**Solution**:
```bash
# Ensure Docker is running
docker info

# Delete any existing cluster
kind delete cluster

# Create fresh cluster
kind create cluster

# Check logs if it fails
docker logs kind-control-plane
```

### Network Namespace Commands Require Root

**Problem**: `Cannot open network namespace "netns": Permission denied`

**Solution**: This is expected. Network namespace operations require root privileges:
```bash
# Run with sudo
sudo ip netns add test-ns
sudo ip netns exec test-ns ip addr

# Or start a root shell
sudo -i
```

### OVS/OVN Tools Not Available

**Problem**: `ovs-vsctl: command not found`

**Solution**: OVS/OVN is optional for Week 7 labs only:
```bash
# Ubuntu/Debian
sudo apt install openvswitch-switch ovn-central ovn-host

# RHEL/Fedora
sudo dnf install openvswitch ovn ovn-central ovn-host

# Or re-run setup script
sudo ./setup.sh
```

### Missing Dependencies on Older Systems

**Problem**: Some packages not available in older OS versions

**Solutions**:
1. **Upgrade OS** (recommended):
   - Ubuntu: Upgrade to 20.04 LTS or newer
   - RHEL/Fedora: Upgrade to RHEL 8+ or Fedora 35+

2. **Use alternative tools**:
   - Use `podman` instead of `docker` (for RHEL/CentOS 8+)
   - Install tools from source or third-party repositories

3. **Use containers**: Run labs inside a containerized environment:
   ```bash
   docker run -it --privileged --network host ubuntu:22.04 bash
   apt update && apt install -y iproute2 iputils-ping
   ```

### Script Fails Midway

**Problem**: Setup script exits with error

**Solution**:
```bash
# The script is idempotent - safe to re-run
sudo ./setup.sh

# Or check specific component
docker --version
kubectl version --client

# Install missing components manually
```

### Internet Connectivity Issues

**Problem**: Cannot download packages or images

**Solution**:
```bash
# Check connectivity
ping -c 3 google.com

# Check DNS
dig google.com

# Configure proxy if needed (set before running setup)
export http_proxy=http://your-proxy:port
export https_proxy=http://your-proxy:port
```

## What's Included

After successful setup, you'll have:

### Networking Tools
- `ip`, `ss`, `ping`, `dig`, `nc`, `tcpdump`, `curl`, `socat`, `iptables`
- Network analysis and debugging utilities

### Container Tools
- **Docker**: Container runtime and CLI
- **Podman**: Alternative container runtime (Red Hat systems)
- **BuildKit**: Container image builder

### Kubernetes Tools
- **kubectl**: Kubernetes command-line tool
- **kind**: Local Kubernetes clusters using Docker
- Ready for multi-node cluster creation

### OVS/OVN Tools (Week 7)
- **Open vSwitch**: Software-defined networking
- **OVN**: Network virtualization platform
- Control and data plane tools

### Development Utilities
- **git**: Version control
- **jq/yq**: JSON/YAML processors
- **vim/nano**: Text editors
- **Python 3**: Scripting support

## Next Steps

After completing setup:

1. **Run verification**: `./verify-setup.sh`
2. **Read main README**: `cat README.md`
3. **Check cheat sheets**: `ls cheat-sheets/`
4. **Start Week 1 labs**: `cd week1-2 && cat README.md`

## Getting Help

- Review lab-specific README files in each week's directory
- Check cheat sheets in `cheat-sheets/` directory
- Re-run verification script to diagnose issues
- Consult official documentation:
  - [Docker Docs](https://docs.docker.com/)
  - [Kubernetes Docs](https://kubernetes.io/docs/)
  - [OpenShift Docs](https://docs.openshift.com/)

## Resources

- **requirements.txt**: Complete list of required tools
- **setup.sh**: Automated installation script
- **verify-setup.sh**: Verification and testing script
- **Week directories**: Individual lab exercises
- **cheat-sheets/**: Quick reference guides

Happy learning!
