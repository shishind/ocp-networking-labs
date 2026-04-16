# Day 4: TCP vs UDP — How Messages Are Actually Sent

**Date:** Thursday, March 12, 2026  
**Phase:** 1 - Core Networking Fundamentals  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Explain the difference between TCP and UDP
- Understand the TCP 3-way handshake
- Identify TCP flags in a packet capture
- List common ports and their protocols
- Troubleshoot connection issues using port information

---

## Plain English: TCP vs UDP

Think of TCP like a phone call — you establish a connection, talk, then hang up. UDP is like sending a postcard — you throw it and hope it arrives.

**TCP (Transmission Control Protocol):**
- Reliable, ordered, guaranteed delivery
- Used by HTTP, HTTPS, SSH
- Has a "handshake" before sending data

**UDP (User Datagram Protocol):**
- Fast but no guarantee
- Used by DNS (port 53), metrics, video streaming
- No handshake — just send

---

## The TCP 3-Way Handshake

Before TCP sends any data, it establishes a connection with a **3-way handshake**:

```
Client                    Server
   |                         |
   |--- SYN -------------->  |  "Can I connect?"
   |                         |
   |<-- SYN-ACK -----------  |  "Yes, you can connect"
   |                         |
   |--- ACK -------------->  |  "Great, I'm connected"
   |                         |
   [Connection established]
```

**What the flags mean:**

- **SYN** = Synchronize (start connection)
- **ACK** = Acknowledge (confirm receipt)
- **FIN** = Finish (close connection)
- **RST** = Reset (abort connection immediately)

---

## Ports — The Door Number in an Apartment Building

An IP address is like a building address. A port is like the apartment number.

Example:
- IP: `172.30.0.5` (the building)
- Port: `80` (the apartment)

When you connect to `172.30.0.5:80`, you are saying:
"Send this message to building 172.30.0.5, apartment 80"

---

## Common Ports (Memorize These)

| Port | Protocol | What It Does |
|------|----------|--------------|
| 22 | SSH | Secure shell (remote login) |
| 53 | DNS | Name resolution (UDP + TCP) |
| 80 | HTTP | Web traffic (plain text) |
| 443 | HTTPS | Web traffic (encrypted) |
| 3306 | MySQL | Database |
| 5432 | PostgreSQL | Database |
| 6443 | Kubernetes API | OpenShift API server |
| 8080 | HTTP (alt) | Common development port |

**In OpenShift:**
- Services expose on **specific ports**
- Pods listen on **specific ports**
- If the port is wrong, the connection fails

---

## Hands-On Lab

### Part 1: List All Listening Ports (10 minutes)

Run this command on your Linux machine:

```bash
ss -tulpn
```

**What the flags mean:**
- `-t` = TCP
- `-u` = UDP
- `-l` = Listening
- `-p` = Process name
- `-n` = Show numbers (no DNS lookup)

**Expected output:**

```
Netid State  Recv-Q Send-Q Local Address:Port  Peer Address:Port Process
tcp   LISTEN 0      128    0.0.0.0:22           0.0.0.0:*     users:(("sshd",pid=123))
tcp   LISTEN 0      128    127.0.0.1:631        0.0.0.0:*     users:(("cupsd",pid=456))
udp   UNCONN 0      0      0.0.0.0:68           0.0.0.0:*     users:(("dhclient",pid=789))
```

**Your task:**

1. Find which process is listening on port 22
2. Find all UDP listening ports
3. Find all TCP listening ports

**Answers:**

1. Port 22: `sshd` (SSH server)
2. UDP ports: typically 68 (DHCP client), 53 (DNS)
3. TCP ports: 22 (SSH), 631 (CUPS printing), etc.

---

### Part 2: Test TCP Connection with tcpdump (20 minutes)

Let's see a real TCP 3-way handshake!

#### Step 1: Start tcpdump in one terminal

```bash
sudo tcpdump -i any 'port 443' -n
```

This captures all traffic on port 443 (HTTPS).

#### Step 2: In another terminal, make an HTTPS connection

```bash
curl -I https://google.com
```

#### Step 3: Go back to the tcpdump output

You should see something like this:

```
IP 192.168.1.100.54321 > 142.250.185.46.443: Flags [S], seq 123456
IP 142.250.185.46.443 > 192.168.1.100.54321: Flags [S.], seq 789012, ack 123457
IP 192.168.1.100.54321 > 142.250.185.46.443: Flags [.], ack 789013
```

**Your task:**

1. Identify the **SYN** packet (flag `[S]`)
2. Identify the **SYN-ACK** packet (flag `[S.]`)
3. Identify the **ACK** packet (flag `[.]`)

**Draw it on paper:**

```
My machine (192.168.1.100:54321)
   |--- SYN --------> Google (142.250.185.46:443)
   |<-- SYN-ACK ---- Google
   |--- ACK --------> Google
   [Connected!]
```

---

### Part 3: Test if a Port is Open with nc (netcat) (10 minutes)

The `nc` (netcat) command tests if a TCP port is open.

```bash
nc -zv localhost 22
```

**What the flags mean:**
- `-z` = Zero I/O mode (just test, don't send data)
- `-v` = Verbose (show result)

**Expected output:**

```
Connection to localhost 22 port [tcp/ssh] succeeded!
```

**Your task:**

1. Test port 22 (SSH): `nc -zv localhost 22`
2. Test port 80 (HTTP): `nc -zv localhost 80`
3. Test port 9999 (should fail): `nc -zv localhost 9999`

**Expected results:**

1. Port 22: Success (SSH is running)
2. Port 80: Fail (no web server running)
3. Port 9999: Fail (nothing listening)

---

### Part 4: Understand TCP Flags (15 minutes)

TCP packets have **flags** that indicate their purpose:

| Flag | Symbol | Meaning |
|------|--------|---------|
| SYN | `[S]` | Start connection |
| ACK | `[.]` | Acknowledge |
| SYN-ACK | `[S.]` | Start + Acknowledge |
| FIN | `[F]` | Finish connection |
| RST | `[R]` | Reset (abort) |
| PSH | `[P]` | Push (send data now) |

**Common patterns:**

```
SYN → SYN-ACK → ACK = Successful connection
SYN → RST = Connection refused (port closed)
SYN → (timeout) = Firewall blocking
```

#### Lab Exercise:

Run this tcpdump to see flags:

```bash
sudo tcpdump -i any 'tcp' -n -c 10
```

Then in another terminal:

```bash
curl http://google.com
```

**Your task:**

1. Find the SYN packet
2. Find the SYN-ACK packet
3. Find the FIN packet (connection close)

---

### Part 5: UDP vs TCP - See the Difference (10 minutes)

#### Test DNS (UDP port 53):

```bash
sudo tcpdump -i any 'udp port 53' -n -c 3 &
dig google.com
```

**What you will see:**

```
IP 192.168.1.100.54321 > 8.8.8.8.53: UDP, query google.com A
IP 8.8.8.8.53 > 192.168.1.100.54321: UDP, reply google.com A 142.250.185.46
```

**Notice:** No handshake! UDP just sends and receives.

**Your task:**

1. Compare this to the TCP handshake you saw earlier
2. Notice: UDP = 1 request + 1 response. TCP = SYN, SYN-ACK, ACK, then data

**Why does DNS use UDP?**

Because it is FAST. No handshake needed for a simple question-and-answer.

---

## OpenShift Ports — What You Need to Know

| Component | Port | Protocol | Purpose |
|-----------|------|----------|---------|
| API Server | 6443 | TCP | Kubernetes API |
| Ingress HTTP | 80 | TCP | Routes (plain) |
| Ingress HTTPS | 443 | TCP | Routes (TLS) |
| CoreDNS | 53 | UDP/TCP | DNS queries |
| etcd | 2379, 2380 | TCP | Cluster database |
| Kubelet | 10250 | TCP | Node agent |

**If any of these ports are blocked by a firewall, OCP breaks.**

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What is the difference between TCP and UDP?
2. What are the 3 steps of the TCP handshake?
3. What does SYN mean? SYN-ACK? ACK?
4. What does RST mean?
5. What port does SSH use? DNS? HTTPS?
6. How do you test if port 8080 is open on localhost?

**Answers:**

1. TCP = reliable, ordered. UDP = fast, no guarantee
2. SYN → SYN-ACK → ACK
3. SYN = start, SYN-ACK = start + acknowledge, ACK = acknowledge
4. RST = reset/abort connection
5. SSH = 22, DNS = 53, HTTPS = 443
6. `nc -zv localhost 8080`

---

## Today I Learned (TIL) — Write This Down

Example:

```
March 12, 2026 — Day 4: TCP vs UDP

- TCP = reliable, 3-way handshake. UDP = fast, no handshake
- TCP handshake: SYN → SYN-ACK → ACK
- Flags: [S]=SYN, [.]=ACK, [R]=RST, [F]=FIN
- Port = apartment number, IP = building address
- Common ports: 22 (SSH), 53 (DNS), 80 (HTTP), 443 (HTTPS), 6443 (K8s API)
- Use: ss -tulpn to see listening ports, nc -zv to test if port is open
```

---

## Commands Cheat Sheet

```bash
# List all listening ports
ss -tulpn

# Test if port is open (TCP)
nc -zv <host> <port>

# Capture TCP traffic on port 443
sudo tcpdump -i any 'tcp port 443' -n

# Capture UDP traffic on port 53 (DNS)
sudo tcpdump -i any 'udp port 53' -n

# Capture SYN packets only
sudo tcpdump -i any 'tcp[tcpflags] & tcp-syn != 0' -n

# Show only TCP flags
sudo tcpdump -i any 'tcp' -n -v
```

---

## What's Next?

**Tomorrow (Day 5):** Routing, Switching, ARP — How Packets Find Their Way

**Practice tonight:**
- Run `ss -tulpn` and identify every port
- Use `nc` to test ports 22, 80, 443

---

**End of Day 4 Lab**

Good job. Tomorrow we learn how packets find their way across networks — routing and ARP.
