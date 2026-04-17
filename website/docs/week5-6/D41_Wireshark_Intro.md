# Day 41: Introduction to Wireshark for Kubernetes

## Learning Objectives
By the end of this lab, you will:
- Understand when packet capture is necessary for troubleshooting
- Capture packets from Kubernetes pods and nodes
- Open and analyze pcap files in Wireshark
- Use Wireshark filters to find relevant traffic
- Follow TCP streams to understand application protocols

## Plain English Explanation

**What Is Wireshark?**

Wireshark is the "X-ray machine" for network traffic. It lets you see every packet flowing through a network interface - the raw bits and bytes that make up HTTP requests, DNS queries, TCP connections, etc.

**When Do You Need Wireshark?**

Most of the time, kubectl commands and logs are enough. But sometimes you hit a wall:
- "The connection hangs for 30 seconds, then fails"
- "I see the request in the client logs but not in the server logs"
- "The TLS handshake fails but I don't know why"
- "Packets are being dropped but I don't know where"

These are packet-level problems that require packet-level tools.

**The Wireshark Workflow**:

1. **Capture**: Record packets to a .pcap file using tcpdump
2. **Transfer**: Copy the .pcap file to your laptop
3. **Analyze**: Open in Wireshark, filter, and investigate

**Key Wireshark Concepts**:

- **pcap**: Packet Capture file format (.pcap or .pcapng)
- **Filter**: Display only packets matching criteria (e.g., "tcp.port == 80")
- **Follow Stream**: Reconstruct a TCP conversation (see the full HTTP request/response)
- **Protocol Dissection**: Wireshark understands HTTP, DNS, TLS, etc., and shows fields

**In OpenShift**: The same techniques apply. Capture from pods or nodes, analyze in Wireshark.

## Hands-On Lab

### Exercise 1: Install Wireshark (Local Machine)

**Goal**: Get Wireshark installed on your laptop.

**Linux**:
```bash
# Debian/Ubuntu
sudo apt-get update && sudo apt-get install -y wireshark

# RHEL/Fedora
sudo dnf install -y wireshark-qt

# Run Wireshark
wireshark &
```

**macOS**:
```bash
# Using Homebrew
brew install --cask wireshark

# Or download from https://www.wireshark.org/download.html
```

**Windows**:
- Download from: https://www.wireshark.org/download.html
- Run the installer

**Verify installation**:
- Open Wireshark
- You should see a GUI with a list of network interfaces

### Exercise 2: Capture Packets from a Kubernetes Pod

**Goal**: Capture HTTP traffic from a pod and save to a pcap file.

```bash
# Create a client pod
kubectl run client --image=nicolaka/netshoot --command -- sleep 3600

# Create a server pod
kubectl run server --image=nginx

# Wait for them
kubectl wait --for=condition=Ready pod/client pod/server --timeout=60s

# Get the server's IP
SERVER_IP=$(kubectl get pod server -o jsonpath='{.status.podIP}')
```

**Start tcpdump in the client pod**:
```bash
# Start tcpdump in the background
kubectl exec client -- tcpdump -i any -w /tmp/capture.pcap port 80 &

# Give it a second to start
sleep 2
```

**Generate traffic**:
```bash
# Make HTTP requests from the client
kubectl exec client -- curl -s http://$SERVER_IP >/dev/null
kubectl exec client -- curl -s http://$SERVER_IP/not-found >/dev/null
kubectl exec client -- curl -s http://$SERVER_IP >/dev/null
```

**Stop tcpdump**:
```bash
# Find the tcpdump process
kubectl exec client -- pkill tcpdump

# Give it a moment to write the file
sleep 2
```

**Download the pcap file**:
```bash
# Copy the pcap file from the pod to your laptop
kubectl cp client:/tmp/capture.pcap ./capture.pcap

# Verify the file exists
ls -lh capture.pcap

# Output: Should be a few KB
```

### Exercise 3: Open and Explore the pcap in Wireshark

**Goal**: Load the pcap and understand the Wireshark interface.

```bash
# Open the pcap in Wireshark
wireshark capture.pcap &
```

**Wireshark Interface Overview**:

1. **Packet List Pane** (top): Shows all packets, one per line
   - Columns: No., Time, Source, Destination, Protocol, Length, Info
   
2. **Packet Details Pane** (middle): Shows the selected packet's protocol layers
   - Frame, Ethernet, IP, TCP, HTTP, etc.
   
3. **Packet Bytes Pane** (bottom): Raw hexadecimal and ASCII of the packet

**Explore the capture**:
- Scroll through the packet list
- Click on a packet to see details
- Expand protocol layers in the details pane (e.g., Internet Protocol → see source/dest IPs)

### Exercise 4: Use Display Filters

**Goal**: Filter the packet list to see only relevant traffic.

**Filter by HTTP**:
```
http
```

Type this in the filter box at the top and press Enter.

**Result**: Only HTTP packets are shown. You'll see:
- HTTP GET requests
- HTTP 200 OK responses
- HTTP 404 Not Found responses

**Filter by IP address**:
```
ip.addr == <SERVER_IP>
```

Replace `<SERVER_IP>` with your server pod's actual IP.

**Result**: Only packets to/from that IP.

**Filter by TCP port**:
```
tcp.port == 80
```

**Result**: All TCP traffic on port 80 (including SYN, ACK, data, FIN).

**Combine filters with AND**:
```
http and ip.src == <CLIENT_IP>
```

**Result**: Only HTTP packets sent FROM the client.

**Combine filters with OR**:
```
tcp.port == 80 or tcp.port == 443
```

**Result**: HTTP or HTTPS traffic.

**Common Filters**:

| Filter | Description |
|--------|-------------|
| `http` | HTTP traffic only |
| `dns` | DNS queries and responses |
| `tcp.port == 80` | TCP on port 80 |
| `ip.addr == 10.244.1.5` | Packets to/from this IP |
| `tcp.flags.syn == 1` | TCP SYN packets (connection starts) |
| `tcp.flags.reset == 1` | TCP RST packets (connection reset) |
| `tcp.analysis.retransmission` | Retransmitted packets (network issues) |
| `http.request.method == "GET"` | HTTP GET requests only |
| `http.response.code == 404` | HTTP 404 responses |

### Exercise 5: Follow a TCP Stream

**Goal**: Reconstruct the full HTTP conversation.

**In Wireshark**:
1. Clear any filters
2. Find an HTTP GET request in the packet list
3. Right-click on it
4. Select **Follow → TCP Stream**

**Result**: A new window opens showing the entire conversation:

```
GET / HTTP/1.1
Host: 10.244.1.5
User-Agent: curl/7.68.0
Accept: */*

HTTP/1.1 200 OK
Server: nginx/1.21.0
Date: Thu, 15 Jan 2024 12:00:00 GMT
Content-Type: text/html
Content-Length: 615

<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

**What you're seeing**:
- Client request (in red/blue depending on settings)
- Server response (in opposite color)
- The full HTTP conversation, not fragmented across packets

This is incredibly useful for debugging protocol issues!

**Close the TCP stream window** when done.

### Exercise 6: Capture and Analyze DNS Traffic

**Goal**: See DNS queries and responses.

**Capture DNS traffic**:
```bash
# Start tcpdump for DNS (port 53)
kubectl exec client -- tcpdump -i any -w /tmp/dns.pcap port 53 &

sleep 2

# Make a DNS query
kubectl exec client -- nslookup kubernetes

# Stop tcpdump
kubectl exec client -- pkill tcpdump
sleep 2

# Download the pcap
kubectl cp client:/tmp/dns.pcap ./dns.pcap
```

**Open in Wireshark**:
```bash
wireshark dns.pcap &
```

**Filter for DNS**:
```
dns
```

**Examine a DNS query packet**:
1. Click on a packet with "Standard query"
2. Expand "Domain Name System (query)" in the details pane
3. Look at:
   - Transaction ID
   - Queries: What name is being queried?
   - Flags

**Examine a DNS response packet**:
1. Click on the corresponding "Standard query response" packet
2. Expand "Domain Name System (response)"
3. Look at:
   - Answers: The IP address(es) returned
   - TTL (Time to Live): How long to cache this response

### Exercise 7: Identify Network Issues with Wireshark

**Goal**: Use Wireshark to detect retransmissions and connection resets.

**Simulate packet loss** (artificially):
```bash
# Create a pod that will timeout
kubectl run slow-server --image=nginx

# Get its IP
SLOW_IP=$(kubectl get pod slow-server -o jsonpath='{.status.podIP}')

# Access a node and add a delay
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
docker exec -it $NODE_NAME bash
```

**Inside the node**:
```bash
# Install tc (traffic control)
apt-get update && apt-get install -y iproute2

# Add 2-second delay to packets (simulates slow network)
tc qdisc add dev eth0 root netem delay 2000ms

# Exit the node
exit
```

**Capture traffic with delay**:
```bash
kubectl exec client -- tcpdump -i any -w /tmp/slow.pcap host $SLOW_IP &

sleep 2

# Try to access the slow server
kubectl exec client -- curl --max-time 5 http://$SLOW_IP

# Stop tcpdump
kubectl exec client -- pkill tcpdump
sleep 2

# Download
kubectl cp client:/tmp/slow.pcap ./slow.pcap
```

**Analyze in Wireshark**:
```bash
wireshark slow.pcap &
```

**Look for issues**:
- Filter: `tcp.analysis.retransmission`
- You should see retransmitted packets (TCP trying to recover from lost packets)
- Filter: `tcp.analysis.flags`
- Shows TCP analysis flags (duplicate ACKs, out-of-order, etc.)

**Clean up the delay**:
```bash
# Remove the delay
docker exec -it $NODE_NAME tc qdisc del dev eth0 root
```

### Exercise 8: Wireshark Statistics

**Goal**: Get high-level insights from a capture.

**In Wireshark** (with any pcap open):

**Statistics → Protocol Hierarchy**:
- Shows breakdown by protocol (e.g., 80% HTTP, 20% DNS)

**Statistics → Conversations**:
- Lists all IP-to-IP conversations
- Shows bytes transferred, packets, duration
- Useful to find which IPs are talking the most

**Statistics → I/O Graph**:
- Shows packets/bytes over time
- Useful to see bursts or patterns

**Statistics → HTTP → Requests**:
- Lists all HTTP requests
- Shows method, host, URI, response code

## Self-Check Questions

### Question 1
When should you use Wireshark instead of kubectl logs?

**Answer**: Use Wireshark when:
- You need to see packets that never reach the application (e.g., dropped before the app sees them)
- You're debugging network-level issues (TCP retransmissions, timeouts, TLS handshake failures)
- Application logs don't show enough detail about the network conversation
- You need to prove what's happening on the wire vs what the app thinks is happening

### Question 2
You capture packets with `tcpdump port 80` but don't see any HTTP traffic in Wireshark. Why?

**Answer**: Possible reasons:
1. The traffic isn't actually using port 80 (check with `tcpdump -i any -nn` to see all ports)
2. The capture was on the wrong interface
3. The traffic is encrypted (HTTPS on port 443, not HTTP on port 80)
4. The filter syntax was wrong in tcpdump

### Question 3
What's the difference between a capture filter (tcpdump) and a display filter (Wireshark)?

**Answer**:
- **Capture filter** (tcpdump): Determines what gets saved to the pcap file. Can't be changed after capture.
- **Display filter** (Wireshark): Determines what you see in the UI. Can be changed anytime. All packets are still in the pcap.

Example: Capture with `tcpdump -i any` (everything), then in Wireshark filter with `http` (view only HTTP).

### Question 4
You see many packets with `[TCP Retransmission]` in Wireshark. What does this indicate?

**Answer**: Packets are being lost or delayed, so TCP is resending them. Causes:
- Network congestion
- Packet loss (bad network hardware, wireless issues)
- Firewall dropping packets
- High latency

Investigate with Statistics → I/O Graph to see if it's consistent or bursty.

### Question 5
How can you tell from a pcap file which side (client or server) closed a TCP connection?

**Answer**: Look for TCP FIN packets:
- Filter: `tcp.flags.fin == 1`
- The side that sends FIN first is initiating the close
- Check the source IP to determine if it's the client or server

## Today I Learned (TIL)

Fill this out at the end of the day:

```
Date: _______________

Wireshark filters I learned:
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

Packets I captured:
_______________________________________________

Most useful Wireshark feature:
_______________________________________________

Network issue I identified:
_______________________________________________

Biggest "aha" moment:
_______________________________________________
_______________________________________________

How this applies to production:
_______________________________________________
_______________________________________________
```

## Commands Cheat Sheet

```bash
# tcpdump - Capture packets
kubectl exec <pod> -- tcpdump -i any -w /tmp/capture.pcap <filter>

# Common tcpdump filters
port 80                    # HTTP traffic
port 53                    # DNS traffic
host 10.244.1.5           # To/from specific IP
tcp                        # TCP only
udp                        # UDP only
icmp                       # ICMP (ping)
'tcp[tcpflags] & tcp-syn != 0'  # TCP SYN packets

# tcpdump options
-i any                     # Capture on all interfaces
-w <file>                  # Write to file
-nn                        # Don't resolve IPs/ports
-c 100                     # Capture 100 packets then stop
-s 0                       # Capture full packets (not just headers)

# Download pcap from pod
kubectl cp <pod>:/tmp/capture.pcap ./capture.pcap

# Open in Wireshark
wireshark <file>.pcap

# Common Wireshark display filters
http                       # HTTP traffic
dns                        # DNS queries/responses
tcp.port == 80            # TCP port 80
ip.addr == 10.244.1.5     # Specific IP
tcp.flags.syn == 1        # TCP SYN packets
tcp.flags.reset == 1      # TCP RST packets
tcp.analysis.retransmission  # Retransmissions
http.request.method == "GET"  # HTTP GET requests
http.response.code == 200     # HTTP 200 responses

# Wireshark functions
Right-click → Follow → TCP Stream     # See full conversation
Statistics → Protocol Hierarchy       # Protocol breakdown
Statistics → Conversations            # IP-to-IP stats
Statistics → HTTP → Requests          # All HTTP requests
```

## What's Next

Tomorrow (Day 42), you have the **Week 6 Review Scenario**: "Can you explain how a ClusterIP Service works without notes?"

This is your chance to synthesize everything you've learned:
- The 4 rules of Kubernetes networking
- How Services, Endpoints, and kube-proxy work together
- DNS resolution flow
- NetworkPolicy enforcement
- Packet-level debugging

Come prepared to explain the full journey of a packet from pod to Service to backend pod!

**Preparation**: Review your TIL notes from this week. Practice explaining concepts out loud.

---

**Pro Tip**: Keep a collection of "known good" pcap files (e.g., successful HTTP request, successful DNS query, successful TLS handshake). When troubleshooting, you can compare a "broken" pcap to a "good" one to spot differences. This comparison technique is incredibly powerful.
