#!/bin/bash
#
# OCP Networking Labs - Verification Script
# This script checks if all required tools are installed and working
#
# Usage: ./verify-setup.sh
#

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
MISSING_TOOLS=()
FIX_COMMANDS=()

print_banner() {
    echo ""
    echo "=========================================="
    echo "  OCP Networking Labs - Verification"
    echo "=========================================="
    echo ""
}

# Check if a command exists
check_command() {
    local cmd=$1
    local description=$2
    local fix_cmd=$3
    local optional=${4:-false}

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if command -v $cmd &> /dev/null; then
        echo -e "${GREEN}✓${NC} $description"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))

        # Show version if available
        case $cmd in
            docker|podman|kubectl|kind)
                local version=$($cmd version --short 2>/dev/null | head -n1 || $cmd --version 2>/dev/null | head -n1)
                if [ -n "$version" ]; then
                    echo -e "  ${CYAN}→${NC} $version"
                fi
                ;;
            ovs-vsctl)
                local version=$($cmd --version 2>/dev/null | head -n1)
                if [ -n "$version" ]; then
                    echo -e "  ${CYAN}→${NC} $version"
                fi
                ;;
        esac
    else
        if [ "$optional" = true ]; then
            echo -e "${YELLOW}○${NC} $description (optional)"
        else
            echo -e "${RED}✗${NC} $description"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            MISSING_TOOLS+=("$cmd")
            if [ -n "$fix_cmd" ]; then
                FIX_COMMANDS+=("$fix_cmd")
            fi
        fi
    fi
}

# Test Docker functionality
test_docker() {
    echo ""
    echo -e "${BLUE}=== Docker Functionality Tests ===${NC}"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗${NC} Docker not installed, skipping tests"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return
    fi

    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker daemon is running"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))

        # Test Docker pull and run
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        if docker run --rm hello-world &> /dev/null; then
            echo -e "${GREEN}✓${NC} Docker can pull and run containers"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            echo -e "${RED}✗${NC} Docker cannot run containers"
            echo -e "  ${CYAN}→${NC} Try: sudo usermod -aG docker \$USER && newgrp docker"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    else
        echo -e "${RED}✗${NC} Docker daemon is not running"
        echo -e "  ${CYAN}→${NC} Try: sudo systemctl start docker"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# Test Kubernetes tools
test_kubernetes() {
    echo ""
    echo -e "${BLUE}=== Kubernetes Functionality Tests ===${NC}"

    if ! command -v kubectl &> /dev/null; then
        echo -e "${YELLOW}○${NC} kubectl not installed, skipping Kubernetes tests"
        return
    fi

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    # Check if kind cluster exists
    if command -v kind &> /dev/null; then
        if kind get clusters 2>/dev/null | grep -q .; then
            echo -e "${GREEN}✓${NC} kind cluster(s) found"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            kind get clusters | while read cluster; do
                echo -e "  ${CYAN}→${NC} $cluster"
            done
        else
            echo -e "${YELLOW}○${NC} No kind clusters found (you can create one later)"
        fi
    fi
}

# Check network capabilities
test_network_capabilities() {
    echo ""
    echo -e "${BLUE}=== Network Capabilities Tests ===${NC}"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    # Test if user can create network namespaces
    if [ $EUID -eq 0 ]; then
        if ip netns add test-verify 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Can create network namespaces"
            ip netns delete test-verify 2>/dev/null
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            echo -e "${YELLOW}○${NC} Cannot create network namespaces (may need root)"
        fi
    else
        echo -e "${YELLOW}○${NC} Network namespace test skipped (run with sudo to test)"
    fi
}

# Main verification
main() {
    print_banner

    echo -e "${BLUE}=== Core Networking Tools ===${NC}"
    check_command "ip" "iproute2 (ip command)" "sudo apt install iproute2 || sudo dnf install iproute"
    check_command "ss" "Socket statistics (ss command)" "sudo apt install iproute2 || sudo dnf install iproute"
    check_command "ping" "Ping utility" "sudo apt install iputils-ping || sudo dnf install iputils"
    check_command "dig" "DNS lookup (dig command)" "sudo apt install dnsutils || sudo dnf install bind-utils"
    check_command "nc" "Netcat" "sudo apt install netcat-openbsd || sudo dnf install nmap-ncat"
    check_command "tcpdump" "Packet capture (tcpdump)" "sudo apt install tcpdump || sudo dnf install tcpdump"
    check_command "curl" "HTTP client (curl)" "sudo apt install curl || sudo dnf install curl"
    check_command "socat" "Socket relay (socat)" "sudo apt install socat || sudo dnf install socat"
    check_command "iptables" "Netfilter (iptables)" "sudo apt install iptables || sudo dnf install iptables"

    echo ""
    echo -e "${BLUE}=== Container Tools ===${NC}"
    check_command "docker" "Docker" "Run: sudo ./setup.sh"
    check_command "podman" "Podman" "sudo apt install podman || sudo dnf install podman" true

    echo ""
    echo -e "${BLUE}=== Kubernetes Tools ===${NC}"
    check_command "kubectl" "Kubernetes CLI (kubectl)" "Run: sudo ./setup.sh"
    check_command "kind" "Kubernetes in Docker (kind)" "Run: sudo ./setup.sh"

    echo ""
    echo -e "${BLUE}=== OVS/OVN Tools (Week 7) ===${NC}"
    check_command "ovs-vsctl" "Open vSwitch (ovs-vsctl)" "sudo apt install openvswitch-switch || sudo dnf install openvswitch" true
    check_command "ovn-nbctl" "OVN Northbound (ovn-nbctl)" "sudo apt install ovn-central || sudo dnf install ovn-central" true

    echo ""
    echo -e "${BLUE}=== Development Utilities ===${NC}"
    check_command "git" "Git" "sudo apt install git || sudo dnf install git"
    check_command "jq" "JSON processor (jq)" "sudo apt install jq || sudo dnf install jq"
    check_command "yq" "YAML processor (yq)" "Run: sudo ./setup.sh" true
    check_command "vim" "Vim editor" "sudo apt install vim || sudo dnf install vim"
    check_command "python3" "Python 3" "sudo apt install python3 || sudo dnf install python3"

    # Run functionality tests
    test_docker
    test_kubernetes
    test_network_capabilities

    # Print summary
    echo ""
    echo "=========================================="
    echo -e "${BLUE}Summary${NC}"
    echo "=========================================="
    echo -e "Total checks: $TOTAL_CHECKS"
    echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
    echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
    echo ""

    # Print fix commands if there are failures
    if [ $FAILED_CHECKS -gt 0 ]; then
        echo -e "${YELLOW}Missing Required Tools:${NC}"
        printf '%s\n' "${MISSING_TOOLS[@]}" | sort -u | while read tool; do
            echo -e "  ${RED}✗${NC} $tool"
        done
        echo ""
        echo -e "${YELLOW}Recommended Fix:${NC}"
        echo "Run the setup script to install missing tools:"
        echo -e "  ${CYAN}sudo ./setup.sh${NC}"
        echo ""

        # Print specific fix commands
        if [ ${#FIX_COMMANDS[@]} -gt 0 ]; then
            echo -e "${YELLOW}Or install individually:${NC}"
            printf '%s\n' "${FIX_COMMANDS[@]}" | sort -u | while read cmd; do
                echo -e "  ${CYAN}$cmd${NC}"
            done
            echo ""
        fi

        exit 1
    else
        echo -e "${GREEN}✓ All required tools are installed and working!${NC}"
        echo ""
        echo "You're ready to start the labs!"
        echo ""
        echo "Next steps:"
        echo "  1. cd week1-2"
        echo "  2. cat README.md"
        echo "  3. Start with the first lab"
        echo ""
        exit 0
    fi
}

# Run main function
main "$@"
