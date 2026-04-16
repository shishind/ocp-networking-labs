# Day 24: tcpdump Basics — Capturing and Filtering Network Traffic

**Date:** Wednesday, April 8, 2026  
**Phase:** 2 - Linux & Container Networking  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Explain what tcpdump is and when to use it
- Capture packets on a specific interface
- Filter traffic by protocol, port, and IP address
- Read and interpret tcpdump output
- Apply tcpdump to troubleshoot OCP networking issues

---

## Plain English: What Is tcpdump?

Imagine you are a detective investigating a crime.

You need to see EXACTLY what happened: who said what, when, and to whom.

**tcpdump** is like a security camera for your network. It records every packet that goes by, showing you:
- Source and destination IPs
- Ports
- Protocols
- Data (if not encrypted)

**Why does this matter for OCP?**

When troubleshooting networking issues in OpenShift, you need to SEE the packets:
- Is the packet leaving the pod?
- Is it reaching the service?
- Is it getting NAT-ed correctly?
- Is there a reply?

tcpdump answers all of these questions.

**Real-world use cases:**
- "The pod cannot reach the database" → Use tcpdump to see if packets are leaving the pod
- "Service is slow" → Use tcpdump to measure latency
- "DNS is broken" → Use tcpdump to see if DNS queries are getting responses

---

## What Is tcpdump?

**tcpdump** is a command-line packet capture tool for Linux.

It uses **libpcap** to capture packets from network interfaces and display them in real-time.

Key features:
- Capture packets from any interface
- Filter by protocol, IP, port, etc.
- Save captures to a file (pcap format)
- Read saved captures
- Works on physical interfaces, veth interfaces, bridges, etc.

**tcpdump is THE tool** for network troubleshooting on Linux.

---

## tcpdump Output Format

Basic tcpdump output looks like this:

```
10:30:45.123456 IP 192.168.1.10.54321 > 8.8.8.8.53: Flags [S], seq 12345, win 64240, length 0
```

**Field-by-field:**

| Field | Meaning |
|-------|---------|
| `10:30:45.123456` | Timestamp |
| `IP` | Protocol (IP, ARP, IPv6, etc.) |
| `192.168.1.10.54321` | Source IP and port |
| `>` | Direction (→) |
| `8.8.8.8.53` | Destination IP and port |
| `Flags [S]` | TCP flags (S = SYN) |
| `seq 12345` | TCP sequence number |
| `win 64240` | TCP window size |
| `length 0` | Payload length |

---

## Common TCP Flags

| Flag | Meaning |
|------|---------|
| **S** | SYN (start of connection) |
| **S.** or **SA** | SYN-ACK (acknowledgment of SYN) |
| **.** (dot) | ACK (acknowledgment) |
| **P** | PSH (push data) |
| **F** | FIN (close connection) |
| **R** | RST (reset connection, abrupt close) |

**Example TCP handshake:**

```
[S]      Client → Server (SYN)
[S.]     Server → Client (SYN-ACK)
[.]      Client → Server (ACK)
```

---

## Hands-On Lab

### Part 1: Install tcpdump (If Not Already Installed) (5 minutes)

```bash
# Check if tcpdump is installed
which tcpdump

# If not installed:
# RHEL/Fedora/CentOS:
sudo dnf install tcpdump

# Ubuntu/Debian:
sudo apt install tcpdump
```

---

### Part 2: Capture All Traffic on an Interface (10 minutes)

```bash
# Capture on eth0 (replace with your interface name)
sudo tcpdump -i eth0
```

**Expected output:**

You will see packets flying by in real-time. This is ALL traffic on eth0.

Press **Ctrl+C** to stop.

**Too much output?**

Yes! Without filters, tcpdump shows everything. Next, we will learn how to filter.

---

### Part 3: Filter by Protocol (10 minutes)

**Capture only ICMP (ping) traffic:**

```bash
# In one terminal, start tcpdump
sudo tcpdump -i eth0 icmp

# In another terminal, ping something
ping -c 3 8.8.8.8
```

**Expected output:**

```
10:35:12.123456 IP 192.168.1.10 > 8.8.8.8: ICMP echo request, id 1234, seq 1, length 64
10:35:12.135678 IP 8.8.8.8 > 192.168.1.10: ICMP echo reply, id 1234, seq 1, length 64
```

**What do you see?**

- Echo request (your ping)
- Echo reply (Google's response)

---

### Part 4: Filter by Port (10 minutes)

**Capture only DNS traffic (port 53):**

```bash
# In one terminal, start tcpdump
sudo tcpdump -i eth0 port 53

# In another terminal, make a DNS query
nslookup google.com
```

**Expected output:**

```
10:40:15.123456 IP 192.168.1.10.45678 > 8.8.8.8.53: 12345+ A? google.com. (28)
10:40:15.135678 IP 8.8.8.8.53 > 192.168.1.10.45678: 12345 1/0/0 A 142.250.80.46 (44)
```

**What do you see?**

- A query for google.com (A record)
- A reply with IP 142.250.80.46

---

### Part 5: Filter by IP Address (10 minutes)

**Capture only traffic to/from 8.8.8.8:**

```bash
# Capture traffic to/from 8.8.8.8
sudo tcpdump -i eth0 host 8.8.8.8

# Test
ping -c 2 8.8.8.8
```

**Expected output:**

You will see only packets involving 8.8.8.8 (both directions).

---

### Part 6: Combine Filters (10 minutes)

You can combine filters using `and`, `or`, and `not`.

**Capture HTTP traffic (port 80) to a specific IP:**

```bash
sudo tcpdump -i eth0 host 93.184.216.34 and port 80
```

**Capture everything EXCEPT SSH (port 22):**

```bash
sudo tcpdump -i eth0 not port 22
```

**Capture DNS OR HTTP:**

```bash
sudo tcpdump -i eth0 port 53 or port 80
```

---

### Part 7: Show More Details (-v, -vv, -vvv) (10 minutes)

```bash
# Default output
sudo tcpdump -i eth0 icmp -c 3

# Verbose (-v)
sudo tcpdump -i eth0 -v icmp -c 3

# More verbose (-vv)
sudo tcpdump -i eth0 -vv icmp -c 3

# Most verbose (-vvv)
sudo tcpdump -i eth0 -vvv icmp -c 3
```

**What changes?**

More verbosity shows more packet details (TTL, checksums, flags, options, etc.).

**Use `-v` for most troubleshooting.**

---

### Part 8: Show Packet Contents (-X, -A) (10 minutes)

**Show packet contents in hex and ASCII:**

```bash
sudo tcpdump -i eth0 -X port 80 -c 1
```

Make an HTTP request:

```bash
curl http://example.com
```

**Expected output:**

You will see the raw HTTP request and response in hex and ASCII.

**Warning:** Do NOT capture HTTPS this way — you will only see encrypted garbage.

---

### Part 9: Limit Number of Packets (-c) (5 minutes)

```bash
# Capture only 10 packets
sudo tcpdump -i eth0 -c 10
```

**Why use this?**

To avoid overwhelming output when you only need a sample.

---

### Part 10: Capture Traffic on a Specific Pod's Interface (15 minutes)

**This is critical for OCP troubleshooting.**

First, find the pod's veth interface on the host:

```bash
# Start a test container
sudo docker run -d --name test-web nginx

# Get the container's PID
CONTAINER_PID=$(sudo docker inspect -f '{{.State.Pid}}' test-web)

# Find the container's eth0 interface number
CONTAINER_IF=$(sudo nsenter -t $CONTAINER_PID -n ip link show eth0 | head -1 | cut -d: -f1)

# Find the corresponding veth on the host
HOST_VETH=$(ip link show | grep "^$CONTAINER_IF:" | awk '{print $2}' | cut -d@ -f1)

echo "Host veth interface: $HOST_VETH"
```

Now capture traffic on that veth:

```bash
# Capture traffic on the pod's veth interface
sudo tcpdump -i $HOST_VETH -n
```

In another terminal, make a request to the container:

```bash
# Get container IP
CONTAINER_IP=$(sudo docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' test-web)

# Make a request
curl http://$CONTAINER_IP
```

**Expected output:**

You will see the HTTP request and response flowing through the veth interface.

**This technique is EXACTLY how you debug pod networking in OCP.**

---

### Part 11: Clean Up (5 minutes)

```bash
# Stop and remove the test container
sudo docker stop test-web
sudo docker rm test-web
```

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What is tcpdump?
2. How do you capture only DNS traffic?
3. How do you filter traffic by IP address?
4. What does the `[S]` flag mean in TCP?
5. How do you capture traffic on a pod's veth interface?

**Answers:**

1. A command-line packet capture tool for Linux
2. `sudo tcpdump -i <interface> port 53`
3. `sudo tcpdump -i <interface> host <IP>`
4. SYN flag (start of TCP connection)
5. Find the pod's veth interface on the host and run `sudo tcpdump -i <veth-interface>`

---

## Today I Learned (TIL) — Write This Down

In your notebook, write 5 bullet points:

- What did I learn today?
- What surprised me?
- What do I still not understand?

Example:

```
April 8, 2026 — Day 24: tcpdump Basics

- tcpdump captures packets in real-time
- I can filter by protocol (icmp), port (53), or IP (host 8.8.8.8)
- -v shows more details, -X shows packet contents
- TCP flags: S=SYN, .=ACK, P=PSH, F=FIN, R=RST
- I can capture traffic on a pod's veth interface to debug OCP networking
```

---

## Commands Cheat Sheet

**tcpdump Basics:**

```bash
# Capture on an interface
sudo tcpdump -i <interface>

# Filter by protocol
sudo tcpdump -i <interface> icmp
sudo tcpdump -i <interface> tcp
sudo tcpdump -i <interface> udp

# Filter by port
sudo tcpdump -i <interface> port 53
sudo tcpdump -i <interface> port 80

# Filter by IP
sudo tcpdump -i <interface> host 8.8.8.8
sudo tcpdump -i <interface> src 8.8.8.8
sudo tcpdump -i <interface> dst 8.8.8.8

# Combine filters
sudo tcpdump -i <interface> host 8.8.8.8 and port 53
sudo tcpdump -i <interface> port 80 or port 443
sudo tcpdump -i <interface> not port 22

# Show more details
sudo tcpdump -i <interface> -v     # Verbose
sudo tcpdump -i <interface> -vv    # More verbose
sudo tcpdump -i <interface> -vvv   # Most verbose

# Show packet contents
sudo tcpdump -i <interface> -X     # Hex and ASCII
sudo tcpdump -i <interface> -A     # ASCII only

# Limit number of packets
sudo tcpdump -i <interface> -c 10

# Disable name resolution (faster, shows IPs instead of hostnames)
sudo tcpdump -i <interface> -n
```

**Useful Combinations:**

```bash
# Capture DNS traffic with details
sudo tcpdump -i eth0 -vn port 53

# Capture HTTP traffic, show contents
sudo tcpdump -i eth0 -A port 80

# Capture ICMP, limit to 5 packets
sudo tcpdump -i eth0 icmp -c 5

# Capture traffic to Google DNS, no name resolution
sudo tcpdump -i eth0 -n host 8.8.8.8
```

---

## What's Next?

**Tomorrow (Day 25):** tcpdump Advanced — TCP flags, saving to file, reading pcaps

**Why it matters:** Today you learned basic filtering. Tomorrow you will learn advanced techniques like filtering TCP flags, saving captures for analysis, and reading them in Wireshark.

---

**End of Day 24 Lab**

Great work. You now know the basics of tcpdump. Tomorrow we go deeper.
