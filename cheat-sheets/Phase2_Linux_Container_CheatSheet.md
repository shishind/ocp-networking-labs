# Phase 2: Linux Container Networking Command Reference
**Week 3-4 Labs | Namespaces, Bridges, Docker**

---

## Network Namespaces

### Creating & Managing Namespaces

```bash
# Create network namespace
ip netns add myns
ip netns add red
ip netns add blue

# List all namespaces
ip netns list
ip netns

# Delete namespace
ip netns del myns

# Execute command in namespace
ip netns exec myns <command>
ip netns exec myns bash
ip netns exec myns ip addr

# Alternative: enter namespace
nsenter --net=/var/run/netns/myns bash
```

### Common Operations in Namespaces

```bash
# Show interfaces in namespace
ip netns exec myns ip link show
ip netns exec myns ip addr

# Add loopback and bring it up
ip netns exec myns ip link set lo up

# Check routing in namespace
ip netns exec myns ip route

# Test connectivity from namespace
ip netns exec myns ping 8.8.8.8

# Run server in namespace
ip netns exec myns nc -l 8080

# Monitor namespace
ip netns exec myns ss -tlnp
```

---

## veth Pairs (Virtual Ethernet)

### Creating & Connecting veth Pairs

**Basic veth pair creation:**
```bash
# Create veth pair
ip link add veth0 type veth peer name veth1

# Verify creation
ip link show | grep veth

# Delete veth pair (deleting one deletes both)
ip link del veth0
```

**Connect namespace to host:**
```bash
# Create veth pair
ip link add veth0 type veth peer name veth1

# Move one end to namespace
ip link set veth1 netns myns

# Configure host side
ip addr add 10.0.0.1/24 dev veth0
ip link set veth0 up

# Configure namespace side
ip netns exec myns ip addr add 10.0.0.2/24 dev veth1
ip netns exec myns ip link set veth1 up
ip netns exec myns ip link set lo up

# Test connectivity
ping -c 2 10.0.0.2
ip netns exec myns ping -c 2 10.0.0.1
```

**Connect two namespaces:**
```bash
# Create namespaces
ip netns add red
ip netns add blue

# Create veth pair
ip link add veth-red type veth peer name veth-blue

# Move ends to respective namespaces
ip link set veth-red netns red
ip link set veth-blue netns blue

# Configure red namespace
ip netns exec red ip addr add 10.0.0.1/24 dev veth-red
ip netns exec red ip link set veth-red up
ip netns exec red ip link set lo up

# Configure blue namespace
ip netns exec blue ip addr add 10.0.0.2/24 dev veth-blue
ip netns exec blue ip link set veth-blue up
ip netns exec blue ip link set lo up

# Test connectivity
ip netns exec red ping -c 2 10.0.0.2
ip netns exec blue ping -c 2 10.0.0.1
```

---

## Linux Bridge

### Bridge Creation & Management

**Create and configure bridge:**
```bash
# Create bridge
ip link add br0 type bridge

# Bring bridge up
ip link set br0 up

# Show bridge details
ip link show br0
ip -d link show br0

# Add IP to bridge
ip addr add 10.0.0.1/24 dev br0

# Delete bridge
ip link del br0
```

**Using brctl (if available):**
```bash
# Create bridge
brctl addbr br0

# Show bridges
brctl show

# Show bridge details
brctl showmacs br0
brctl showstp br0

# Delete bridge
brctl delbr br0
```

### Adding Interfaces to Bridge

```bash
# Add interface to bridge (modern method)
ip link set veth0 master br0

# Verify
ip link show master br0

# Remove interface from bridge
ip link set veth0 nomaster

# Using brctl
brctl addif br0 veth0
brctl delif br0 veth0
```

### Complete Bridge Setup Example

**Connect 3 namespaces via bridge:**
```bash
# Create bridge
ip link add br0 type bridge
ip link set br0 up
ip addr add 10.0.0.1/24 dev br0

# Create namespaces
for ns in red blue green; do
  ip netns add $ns
  
  # Create veth pair
  ip link add veth-$ns type veth peer name br-veth-$ns
  
  # Move one end to namespace
  ip link set veth-$ns netns $ns
  
  # Attach other end to bridge
  ip link set br-veth-$ns master br0
  ip link set br-veth-$ns up
  
  # Configure namespace
  ip netns exec $ns ip link set veth-$ns up
  ip netns exec $ns ip link set lo up
done

# Assign IPs in namespaces
ip netns exec red ip addr add 10.0.0.2/24 dev veth-red
ip netns exec blue ip addr add 10.0.0.3/24 dev veth-blue
ip netns exec green ip addr add 10.0.0.4/24 dev veth-green

# Test connectivity
ip netns exec red ping -c 2 10.0.0.3
ip netns exec blue ping -c 2 10.0.0.4
```

---

## iptables NAT for Namespaces

### Enable Internet Access for Namespace

```bash
# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Add default route in namespace (assuming bridge IP is 10.0.0.1)
ip netns exec myns ip route add default via 10.0.0.1

# Add NAT rule on host
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE

# Allow forwarding
iptables -A FORWARD -i br0 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Test from namespace
ip netns exec myns ping -c 2 8.8.8.8
ip netns exec myns curl google.com
```

### Port Forwarding to Namespace

```bash
# Forward host port 8080 to namespace port 80
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.2:80

# Allow forwarding
iptables -A FORWARD -p tcp -d 10.0.0.2 --dport 80 -j ACCEPT

# Test
curl localhost:8080
```

---

## conntrack (Connection Tracking)

### View Connection Tracking

```bash
# Show all tracked connections
conntrack -L

# Count connections
conntrack -L | wc -l

# Show connections for specific IP
conntrack -L -s 192.168.1.100
conntrack -L -d 192.168.1.100

# Show specific protocol
conntrack -L -p tcp
conntrack -L -p udp

# Show connections in specific state
conntrack -L -p tcp --state ESTABLISHED
conntrack -L -p tcp --state TIME_WAIT

# Real-time monitoring
conntrack -E

# Show statistics
conntrack -S
```

### Manipulate Connection Tracking

```bash
# Delete specific connection
conntrack -D -s 192.168.1.100

# Delete all connections to specific IP
conntrack -D -d 10.0.0.2

# Delete specific port
conntrack -D -p tcp --dport 80

# Flush all connections (dangerous!)
conntrack -F

# Show connection tracking limits
sysctl net.netfilter.nf_conntrack_max
cat /proc/sys/net/netfilter/nf_conntrack_max

# View current count
cat /proc/sys/net/netfilter/nf_conntrack_count

# Increase conntrack limit
sysctl -w net.netfilter.nf_conntrack_max=100000
```

---

## Docker Networking Commands

### Docker Network Basics

```bash
# List networks
docker network ls

# Inspect network
docker network inspect bridge
docker network inspect networkname

# Create network
docker network create mynet
docker network create --subnet 172.20.0.0/16 mynet

# Remove network
docker network rm mynet

# Prune unused networks
docker network prune
```

### Container Network Operations

```bash
# Run container with default network
docker run -d --name web nginx

# Run with specific network
docker run -d --name web --network mynet nginx

# Run with custom IP
docker network create --subnet 172.20.0.0/16 mynet
docker run -d --name web --network mynet --ip 172.20.0.10 nginx

# Connect running container to network
docker network connect mynet container_name

# Disconnect from network
docker network disconnect mynet container_name

# Run with host network (share host's network namespace)
docker run -d --name web --network host nginx

# Run with no network
docker run -d --name web --network none nginx

# Publish ports
docker run -d -p 8080:80 nginx          # Host:Container
docker run -d -p 127.0.0.1:8080:80 nginx  # Bind to specific IP
docker run -d -P nginx                   # Publish all exposed ports
```

### Inspect Container Networking

```bash
# Get container IP address
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' container_name

# Get detailed network info
docker inspect container_name | jq '.[0].NetworkSettings'

# Show container ports
docker port container_name

# Enter container network namespace
docker exec -it container_name bash
docker exec container_name ip addr
docker exec container_name ip route

# Use nsenter to enter namespace
PID=$(docker inspect -f '{{.State.Pid}}' container_name)
nsenter -t $PID -n ip addr
```

### Docker Bridge Inspection

```bash
# Find Docker bridge
ip link show docker0
ip addr show docker0

# Show iptables rules created by Docker
iptables -t nat -L -n -v | grep DOCKER
iptables -L DOCKER -n -v

# Show containers on bridge
brctl show docker0
bridge link show

# Inspect Docker's iptables chains
iptables -t nat -L DOCKER -n -v
iptables -L DOCKER -n -v
```

---

## NMState & Network Bonding

### nmcli (NetworkManager CLI)

**Connection management:**
```bash
# Show all connections
nmcli connection show

# Show active connections
nmcli connection show --active

# Show device status
nmcli device status

# Show connection details
nmcli connection show "System eth0"

# Bring connection up/down
nmcli connection up eth0
nmcli connection down eth0

# Reload connections
nmcli connection reload
```

**Modify connections:**
```bash
# Modify IP address
nmcli connection modify eth0 ipv4.addresses 192.168.1.100/24
nmcli connection modify eth0 ipv4.gateway 192.168.1.1
nmcli connection modify eth0 ipv4.dns "8.8.8.8 8.8.4.4"
nmcli connection modify eth0 ipv4.method manual

# Add additional IP
nmcli connection modify eth0 +ipv4.addresses 192.168.1.101/24

# Set to DHCP
nmcli connection modify eth0 ipv4.method auto

# Apply changes
nmcli connection up eth0
```

### Linux Bonding

**Create bond:**
```bash
# Create bond interface
nmcli connection add type bond con-name bond0 ifname bond0 mode active-backup

# Add slaves to bond
nmcli connection add type ethernet slave-type bond con-name bond0-slave1 ifname eth0 master bond0
nmcli connection add type ethernet slave-type bond con-name bond0-slave2 ifname eth1 master bond0

# Configure bond IP
nmcli connection modify bond0 ipv4.addresses 192.168.1.100/24
nmcli connection modify bond0 ipv4.gateway 192.168.1.1
nmcli connection modify bond0 ipv4.method manual

# Bring up bond
nmcli connection up bond0
nmcli connection up bond0-slave1
nmcli connection up bond0-slave2

# Verify bond status
cat /proc/net/bonding/bond0
```

**Bond modes:**
- mode=0 (balance-rr): Round-robin
- mode=1 (active-backup): Active-backup (failover)
- mode=2 (balance-xor): XOR load balancing
- mode=3 (broadcast): Broadcast
- mode=4 (802.3ad): LACP
- mode=5 (balance-tlb): Adaptive transmit load balancing
- mode=6 (balance-alb): Adaptive load balancing

**Monitor bond:**
```bash
# Show bond status
cat /proc/net/bonding/bond0

# Watch bond status
watch -n 1 cat /proc/net/bonding/bond0

# Test failover (bring slave down)
nmcli connection down bond0-slave1
```

---

## tcpdump - Packet Capture

### Basic Packet Capture

```bash
# Capture on interface
tcpdump -i eth0

# Capture specific number of packets
tcpdump -i eth0 -c 10

# More verbose output
tcpdump -i eth0 -v
tcpdump -i eth0 -vv
tcpdump -i eth0 -vvv

# Show in ASCII
tcpdump -i eth0 -A

# Show in hex and ASCII
tcpdump -i eth0 -X

# Don't resolve hostnames
tcpdump -i eth0 -n

# Don't resolve hostnames or ports
tcpdump -i eth0 -nn

# Show absolute sequence numbers
tcpdump -i eth0 -S
```

### Filtering Packets

**By protocol:**
```bash
# TCP only
tcpdump -i eth0 tcp

# UDP only
tcpdump -i eth0 udp

# ICMP only
tcpdump -i eth0 icmp

# ARP only
tcpdump -i eth0 arp
```

**By host:**
```bash
# Specific host
tcpdump -i eth0 host 192.168.1.100

# Source host
tcpdump -i eth0 src host 192.168.1.100

# Destination host
tcpdump -i eth0 dst host 192.168.1.100

# Network
tcpdump -i eth0 net 192.168.1.0/24
```

**By port:**
```bash
# Specific port
tcpdump -i eth0 port 80

# Source port
tcpdump -i eth0 src port 80

# Destination port
tcpdump -i eth0 dst port 443

# Port range
tcpdump -i eth0 portrange 8000-9000
```

**Combining filters:**
```bash
# AND (both conditions)
tcpdump -i eth0 'host 192.168.1.100 and port 80'

# OR (either condition)
tcpdump -i eth0 'host 192.168.1.100 or host 192.168.1.101'

# NOT (exclude)
tcpdump -i eth0 'not port 22'

# Complex filter
tcpdump -i eth0 'tcp and dst port 80 and src net 192.168.1.0/24'
```

### Advanced tcpdump

**TCP flags:**
```bash
# SYN packets
tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0'

# SYN-ACK packets
tcpdump -i eth0 'tcp[tcpflags] & (tcp-syn|tcp-ack) == (tcp-syn|tcp-ack)'

# RST packets
tcpdump -i eth0 'tcp[tcpflags] & tcp-rst != 0'

# FIN packets
tcpdump -i eth0 'tcp[tcpflags] & tcp-fin != 0'

# PSH-ACK packets (data transfer)
tcpdump -i eth0 'tcp[tcpflags] & (tcp-push|tcp-ack) == (tcp-push|tcp-ack)'
```

**Save to file:**
```bash
# Save to pcap file
tcpdump -i eth0 -w capture.pcap

# Save with limited size (100MB)
tcpdump -i eth0 -w capture.pcap -C 100

# Rotate files (keep 5 files)
tcpdump -i eth0 -w capture.pcap -C 100 -W 5

# Read from pcap file
tcpdump -r capture.pcap

# Apply filter to saved file
tcpdump -r capture.pcap 'port 80'
```

**Snaplen and buffering:**
```bash
# Capture only headers (faster, less storage)
tcpdump -i eth0 -s 96

# Capture full packets
tcpdump -i eth0 -s 0
tcpdump -i eth0 -s 65535

# Line buffered output (better for piping)
tcpdump -i eth0 -l
```

### Practical tcpdump Examples

```bash
# Capture HTTP traffic
tcpdump -i eth0 -A 'tcp port 80 or tcp port 8080'

# Capture DNS queries
tcpdump -i eth0 -vvv 'udp port 53'

# Capture ping traffic
tcpdump -i eth0 'icmp and icmp[icmptype]=icmp-echo'

# Capture traffic between two hosts
tcpdump -i eth0 'host 192.168.1.100 and host 192.168.1.101'

# Capture new TCP connections (SYN)
tcpdump -i eth0 -nn 'tcp[tcpflags] & tcp-syn != 0 and tcp[tcpflags] & tcp-ack == 0'

# Monitor specific container (by IP)
CONTAINER_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mycontainer)
tcpdump -i docker0 host $CONTAINER_IP
```

---

## nsenter - Enter Namespaces

### Basic nsenter Usage

```bash
# Enter network namespace
nsenter --net=/var/run/netns/myns bash

# Enter all namespaces of a process
nsenter -t PID -n -m -u -i -p bash

# Enter Docker container namespace
PID=$(docker inspect -f '{{.State.Pid}}' container_name)
nsenter -t $PID -n bash

# Enter specific namespace types
nsenter -t PID -n  # Network
nsenter -t PID -m  # Mount
nsenter -t PID -u  # UTS (hostname)
nsenter -t PID -i  # IPC
nsenter -t PID -p  # PID
```

### Namespace Inspection

```bash
# List namespaces for a process
ls -l /proc/$PID/ns/

# Compare namespaces between processes
ls -l /proc/$PID1/ns/net
ls -l /proc/$PID2/ns/net

# Execute single command in namespace
nsenter -t $PID -n ip addr
nsenter -t $PID -n ss -tlnp
```

### Docker Container Namespace Access

```bash
# Get PID
PID=$(docker inspect -f '{{.State.Pid}}' container_name)

# Run network commands
nsenter -t $PID -n ip addr
nsenter -t $PID -n ip route
nsenter -t $PID -n ss -tlnp
nsenter -t $PID -n tcpdump -i eth0

# Access filesystem
nsenter -t $PID -m ls /
```

---

## Troubleshooting Workflows

### Container Cannot Reach Internet

```bash
# 1. Check container network config
docker exec container_name ip addr
docker exec container_name ip route

# 2. Check if container can reach gateway
docker exec container_name ping -c 2 <gateway_ip>

# 3. Check if container can reach outside (by IP)
docker exec container_name ping -c 2 8.8.8.8

# 4. Check DNS
docker exec container_name cat /etc/resolv.conf
docker exec container_name nslookup google.com

# 5. Check host IP forwarding
cat /proc/sys/net/ipv4/ip_forward  # Should be 1

# 6. Check NAT rules
iptables -t nat -L POSTROUTING -n -v | grep docker0

# 7. Check forwarding rules
iptables -L FORWARD -n -v | grep docker0
```

### Namespace Connectivity Issues

```bash
# 1. Verify veth pair exists
ip link show | grep veth

# 2. Check both ends are UP
ip link show veth0
ip netns exec myns ip link show veth1

# 3. Verify IPs are configured
ip addr show veth0
ip netns exec myns ip addr show veth1

# 4. Check routing
ip netns exec myns ip route

# 5. Test connectivity
ping -c 2 <namespace_ip>
ip netns exec myns ping -c 2 <host_ip>

# 6. Check iptables rules
iptables -L -v -n
iptables -t nat -L -v -n
```

### Bridge Not Working

```bash
# 1. Verify bridge exists
ip link show br0

# 2. Check bridge is UP
ip link set br0 up

# 3. List interfaces attached to bridge
ip link show master br0
brctl show br0

# 4. Verify IPs
ip addr show br0

# 5. Check if interfaces are in correct state
ip link show veth0

# 6. Enable IP forwarding if needed
echo 1 > /proc/sys/net/ipv4/ip_forward
```

---

## Performance & Monitoring

### Monitor Network Namespace

```bash
# Watch interface statistics
watch -n 1 ip netns exec myns ip -s link show

# Monitor connections
watch -n 1 ip netns exec myns ss -tunap

# Real-time packet capture
ip netns exec myns tcpdump -i eth0 -nn
```

### Monitor Docker Network

```bash
# Container network statistics
docker stats container_name

# Watch iptables packet counters
watch -n 1 'iptables -L DOCKER -v -n'

# Monitor bridge
watch -n 1 'bridge link show'
```

---

## Quick Reference

### Create Isolated Environment
```bash
ip netns add test
ip netns exec test ip link set lo up
ip netns exec test bash
```

### Quick veth Test
```bash
ip link add v1 type veth peer name v2 && ip link set v1 up && ip link set v2 up
```

### Quick Bridge Setup
```bash
ip link add br0 type bridge && ip link set br0 up
```

### Check Docker Network
```bash
docker network inspect bridge | jq '.[0].Containers'
```

### One-liner: Container IP
```bash
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' container_name
```

### One-liner: Test NAT
```bash
iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE
```
