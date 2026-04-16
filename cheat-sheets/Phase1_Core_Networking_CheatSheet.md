# Phase 1: Core Networking Command Reference
**Week 1-2 Labs | Fundamentals**

---

## Quick Reference: OSI Model

| Layer | Name | Protocol Examples | Troubleshooting Focus |
|-------|------|-------------------|----------------------|
| 7 | Application | HTTP, DNS, SSH | Application logs, protocol errors |
| 6 | Presentation | SSL/TLS, JPEG | Encryption issues, data format |
| 5 | Session | NetBIOS, RPC | Connection persistence |
| 4 | Transport | TCP, UDP | Port connectivity, packet loss |
| 3 | Network | IP, ICMP, OSPF | Routing, IP addressing |
| 2 | Data Link | Ethernet, ARP | MAC addresses, switching |
| 1 | Physical | Cables, NICs | Cable, interface status |

---

## IP Addressing & Subnetting

### CIDR Quick Calculation
```bash
# Calculate network details for CIDR
ipcalc 192.168.1.0/24

# Show network and broadcast addresses
ipcalc -n 192.168.1.0/24
ipcalc -b 192.168.1.0/24

# Check if IP is in subnet
ipcalc --network 192.168.1.45/24
```

### Common Subnet Masks
| CIDR | Subnet Mask | Usable IPs | Common Use |
|------|-------------|------------|------------|
| /32 | 255.255.255.255 | 1 | Single host |
| /31 | 255.255.255.254 | 2 | Point-to-point |
| /30 | 255.255.255.252 | 2 | Point-to-point |
| /29 | 255.255.255.248 | 6 | Small LAN |
| /28 | 255.255.255.240 | 14 | Small subnet |
| /27 | 255.255.255.224 | 30 | Department |
| /26 | 255.255.255.192 | 62 | Large dept |
| /24 | 255.255.255.0 | 254 | Standard LAN |
| /23 | 255.255.254.0 | 510 | Double LAN |
| /22 | 255.255.252.0 | 1022 | Large network |
| /16 | 255.255.0.0 | 65534 | Class B |
| /8 | 255.0.0.0 | 16777214 | Class A |

### IP Address Management
```bash
# Show all IP addresses
ip addr show
ip a

# Show specific interface
ip addr show eth0

# Add IP address
ip addr add 192.168.1.100/24 dev eth0

# Delete IP address
ip addr del 192.168.1.100/24 dev eth0

# Show brief summary
ip -br addr

# Show only IPv4
ip -4 addr

# Show only IPv6
ip -6 addr
```

---

## DNS Commands

### When DNS is Broken - Troubleshooting Steps

**1. Check DNS resolution:**
```bash
# Test basic resolution
nslookup google.com
dig google.com

# Check which DNS server is being used
cat /etc/resolv.conf

# Test specific DNS server
dig @8.8.8.8 google.com
nslookup google.com 8.8.8.8
```

**2. Detailed DNS queries:**
```bash
# Get all DNS records
dig google.com ANY

# Query specific record types
dig google.com A          # IPv4 address
dig google.com AAAA       # IPv6 address
dig google.com MX         # Mail servers
dig google.com NS         # Name servers
dig google.com TXT        # Text records
dig google.com SOA        # Start of Authority
dig google.com CNAME      # Canonical name

# Short answer only
dig google.com +short

# Trace DNS resolution path
dig google.com +trace

# Reverse DNS lookup
dig -x 8.8.8.8
nslookup 8.8.8.8
```

**3. Advanced dig options:**
```bash
# Show full details
dig google.com +noall +answer +stats

# Query over TCP instead of UDP
dig google.com +tcp

# Set custom timeout
dig google.com +time=5

# Query all DNS servers for domain
dig NS google.com +short | while read ns; do dig @$ns google.com; done
```

### DNS Cache Management
```bash
# Flush systemd-resolved cache
systemd-resolve --flush-caches

# Check systemd-resolved statistics
systemd-resolve --statistics

# Query systemd-resolved
resolvectl query google.com
resolvectl status
```

---

## TCP/UDP & Port Commands

### Port Listening & Connections

**ss (Socket Statistics) - Modern replacement for netstat:**
```bash
# Show all TCP connections
ss -ta

# Show all UDP connections
ss -ua

# Show listening sockets only
ss -tl         # TCP listening
ss -ul         # UDP listening

# Show all (listening + established)
ss -tuln       # TCP/UDP, listening, numeric

# Show with process information
ss -tlnp       # Requires root/sudo

# Show specific port
ss -tlnp | grep :80
ss -tlnp sport = :80

# Show summary statistics
ss -s

# Show TCP sockets in specific state
ss -t state established
ss -t state listening
ss -t state time-wait

# Show sockets using specific protocol
ss -t '( dport = :80 or sport = :80 )'
```

**netcat (nc) - Network Swiss Army Knife:**
```bash
# Listen on port
nc -l 8080

# Connect to port
nc example.com 80

# Test if port is open
nc -zv example.com 80

# Port scan range
nc -zv example.com 80-85

# UDP mode
nc -u example.com 53

# Create simple chat server
nc -l 9999

# Send file over network
nc -l 9999 < file.txt        # Receiver
nc receiver_ip 9999 > file.txt  # Sender

# Simple HTTP test
echo -e "GET / HTTP/1.0\r\n\r\n" | nc example.com 80
```

**telnet - Test TCP connections:**
```bash
# Test if service is responding
telnet example.com 80
telnet example.com 22

# Test SMTP server
telnet mail.example.com 25
```

### Process & Port Mapping
```bash
# Find which process is using a port
lsof -i :80
lsof -i :8080
lsof -i tcp:80

# Find all network connections for a process
lsof -i -a -p 1234

# Show all listening ports with processes
netstat -tlnp
ss -tlnp

# Check if port is in use
lsof -i :8080 || echo "Port is free"
```

---

## Routing Commands

### Route Table Management

**Display routes:**
```bash
# Show routing table
ip route show
ip route

# Show routing table with cache
ip route show cache

# Show specific route
ip route get 8.8.8.8

# Show routes for specific interface
ip route show dev eth0

# Show only default route
ip route | grep default
```

**Add/Modify/Delete routes:**
```bash
# Add default gateway
ip route add default via 192.168.1.1

# Add specific route
ip route add 10.0.0.0/8 via 192.168.1.254

# Add route through specific interface
ip route add 172.16.0.0/16 dev eth1

# Delete route
ip route del 10.0.0.0/8

# Replace/change existing route
ip route replace default via 192.168.1.2

# Add route with metric (priority)
ip route add default via 192.168.1.1 metric 100
```

**Persistent routing (RHEL/Fedora):**
```bash
# Add persistent route
nmcli connection modify eth0 +ipv4.routes "10.0.0.0/8 192.168.1.254"

# Show connection routes
nmcli connection show eth0 | grep route
```

### ARP (Address Resolution Protocol)

```bash
# Show ARP cache
ip neigh show
ip neigh

# Show ARP for specific interface
ip neigh show dev eth0

# Clear ARP cache
ip neigh flush all

# Add static ARP entry
ip neigh add 192.168.1.100 lladdr aa:bb:cc:dd:ee:ff dev eth0

# Delete ARP entry
ip neigh del 192.168.1.100 dev eth0

# Show ARP statistics
cat /proc/net/arp
```

### Interface Management

```bash
# Show all interfaces
ip link show

# Bring interface up/down
ip link set eth0 up
ip link set eth0 down

# Show interface statistics
ip -s link show eth0

# Set MTU
ip link set eth0 mtu 1500

# Set MAC address
ip link set eth0 address aa:bb:cc:dd:ee:ff

# Enable/disable promiscuous mode
ip link set eth0 promisc on
ip link set eth0 promisc off
```

---

## NAT & iptables Commands

### Basic iptables Structure
```
iptables [-t table] COMMAND [chain] [match] [target]
Tables: filter (default), nat, mangle, raw
Chains: INPUT, OUTPUT, FORWARD, PREROUTING, POSTROUTING
```

### NAT Configuration

**Source NAT (SNAT) / Masquerade:**
```bash
# Enable IP forwarding (required for NAT)
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -w net.ipv4.ip_forward=1

# Make persistent
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# SNAT - change source IP to specific address
iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to-source 203.0.113.5

# MASQUERADE - use interface's IP (dynamic IP)
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# MASQUERADE specific subnet
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o eth0 -j MASQUERADE
```

**Destination NAT (DNAT) / Port Forwarding:**
```bash
# Forward external port to internal server
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 192.168.1.10:80

# Port forwarding with different port
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 192.168.1.10:80

# Forward to specific interface
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 443 -j DNAT --to-destination 192.168.1.10:443
```

### Firewall Rules (Filter Table)

**View rules:**
```bash
# List all rules
iptables -L -v -n

# List with line numbers
iptables -L --line-numbers

# List specific chain
iptables -L INPUT -v -n

# List NAT rules
iptables -t nat -L -v -n

# Show rules as commands
iptables-save
```

**Basic filtering:**
```bash
# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP/HTTPS
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow from specific IP
iptables -A INPUT -s 192.168.1.100 -j ACCEPT

# Allow from subnet
iptables -A INPUT -s 192.168.1.0/24 -j ACCEPT

# Drop specific IP
iptables -A INPUT -s 203.0.113.50 -j DROP

# Set default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
```

**Delete/Insert rules:**
```bash
# Delete rule by number
iptables -D INPUT 5

# Delete specific rule
iptables -D INPUT -s 192.168.1.100 -j ACCEPT

# Insert rule at specific position
iptables -I INPUT 1 -p tcp --dport 22 -j ACCEPT

# Flush all rules
iptables -F
iptables -t nat -F

# Flush specific chain
iptables -F INPUT
```

### iptables Persistence

```bash
# Save current rules (RHEL/Fedora)
iptables-save > /etc/sysconfig/iptables

# Restore saved rules
iptables-restore < /etc/sysconfig/iptables

# Save using service
service iptables save

# Enable iptables service
systemctl enable iptables
systemctl start iptables
```

---

## systemd & Service Management

### systemctl Commands

**Service control:**
```bash
# Start/stop/restart service
systemctl start servicename
systemctl stop servicename
systemctl restart servicename
systemctl reload servicename

# Enable/disable service (start on boot)
systemctl enable servicename
systemctl disable servicename

# Check service status
systemctl status servicename
systemctl is-active servicename
systemctl is-enabled servicename

# Show service dependencies
systemctl list-dependencies servicename
```

**System information:**
```bash
# List all services
systemctl list-units --type=service

# List active services
systemctl list-units --type=service --state=active

# List failed services
systemctl list-units --state=failed

# Show all unit files
systemctl list-unit-files

# Show service file location
systemctl cat servicename

# Edit service file
systemctl edit servicename

# Reload systemd configuration
systemctl daemon-reload
```

### journalctl - Log Viewing

**Basic log viewing:**
```bash
# View all logs
journalctl

# Follow logs (like tail -f)
journalctl -f

# View logs since boot
journalctl -b

# View logs from previous boot
journalctl -b -1

# View logs from specific service
journalctl -u servicename
journalctl -u sshd

# Follow specific service logs
journalctl -u servicename -f
```

**Time-based filtering:**
```bash
# Logs since specific time
journalctl --since "2026-04-16 10:00:00"
journalctl --since "1 hour ago"
journalctl --since "yesterday"
journalctl --since "10 min ago"

# Logs between time range
journalctl --since "2026-04-16 10:00" --until "2026-04-16 11:00"

# Today's logs
journalctl --since today
```

**Output formatting:**
```bash
# Show only errors
journalctl -p err

# Priority levels: emerg, alert, crit, err, warning, notice, info, debug
journalctl -p warning

# JSON output
journalctl -o json
journalctl -o json-pretty

# Show newest entries first
journalctl -r

# Show last N lines
journalctl -n 50

# Kernel messages only
journalctl -k
```

**Advanced filtering:**
```bash
# Filter by process ID
journalctl _PID=1234

# Filter by user
journalctl _UID=1000

# Filter by executable
journalctl /usr/bin/sshd

# Combine filters
journalctl -u sshd -p err --since "1 hour ago"

# Show log disk usage
journalctl --disk-usage

# Vacuum old logs
journalctl --vacuum-time=30d
journalctl --vacuum-size=1G
```

---

## VLAN Commands

```bash
# Create VLAN interface
ip link add link eth0 name eth0.100 type vlan id 100

# Bring VLAN interface up
ip link set eth0.100 up

# Add IP to VLAN
ip addr add 192.168.100.1/24 dev eth0.100

# Delete VLAN interface
ip link delete eth0.100

# Show VLAN configuration
cat /proc/net/vlan/config
ip -d link show eth0.100
```

---

## Time Synchronization (chrony)

```bash
# Check chrony status
chronyc tracking

# Show NTP sources
chronyc sources
chronyc sources -v

# Show source statistics
chronyc sourcestats

# Manually force time sync
chronyc makestep

# Check if chronyd is running
systemctl status chronyd

# View chrony logs
journalctl -u chronyd

# Test NTP connectivity
chronyc activity
```

---

## Network Troubleshooting Workflow

### Step 1: Interface Check
```bash
ip link show
ip addr show
```

### Step 2: Connectivity Test
```bash
ping -c 4 8.8.8.8              # Internet
ping -c 4 192.168.1.1          # Gateway
```

### Step 3: Routing Check
```bash
ip route show
ip route get 8.8.8.8
```

### Step 4: DNS Check
```bash
dig google.com
cat /etc/resolv.conf
```

### Step 5: Port/Service Check
```bash
ss -tlnp
systemctl status servicename
```

### Step 6: Firewall Check
```bash
iptables -L -v -n
iptables -t nat -L -v -n
```

### Step 7: Logs Check
```bash
journalctl -f
journalctl -u servicename
dmesg | tail
```

---

## Common Port Numbers Reference

| Port | Protocol | Service |
|------|----------|---------|
| 20/21 | TCP | FTP |
| 22 | TCP | SSH |
| 23 | TCP | Telnet |
| 25 | TCP | SMTP |
| 53 | TCP/UDP | DNS |
| 67/68 | UDP | DHCP |
| 80 | TCP | HTTP |
| 110 | TCP | POP3 |
| 123 | UDP | NTP |
| 143 | TCP | IMAP |
| 443 | TCP | HTTPS |
| 465/587 | TCP | SMTP (TLS) |
| 993 | TCP | IMAP (TLS) |
| 995 | TCP | POP3 (TLS) |
| 3306 | TCP | MySQL |
| 5432 | TCP | PostgreSQL |
| 6443 | TCP | Kubernetes API |
| 8080 | TCP | HTTP Alt |

---

## Quick Tips

**Check connectivity to port:**
```bash
nc -zv hostname 80 || telnet hostname 80 || curl -v telnet://hostname:80
```

**Quick NAT test:**
```bash
# Check if NAT is working
curl ifconfig.me                 # Shows your public IP
```

**Interface troubleshooting one-liner:**
```bash
ip link show && ip addr show && ip route show
```

**Find what's using network bandwidth:**
```bash
# Install iftop if available
iftop -i eth0
```

**Test DNS resolution chain:**
```bash
# Test local -> DNS server -> authoritative
dig google.com +trace +all
```
