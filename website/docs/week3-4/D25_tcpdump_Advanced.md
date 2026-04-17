# Day 25: tcpdump Advanced — TCP Flags, Saving to File, Wireshark

**Date:** Thursday, April 9, 2026  
**Phase:** 2 - Linux & Container Networking  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Filter packets by TCP flags (SYN, ACK, FIN, RST)
- Save packet captures to files (.pcap format)
- Read and analyze saved captures
- Transfer captures to Wireshark for detailed analysis
- Use tcpdump for advanced OCP troubleshooting scenarios

---

## Plain English: Why Advanced tcpdump Matters

Yesterday you learned basic tcpdump filtering (by port, IP, protocol).

Today you will learn advanced techniques that professional network engineers use:

1. **Filter by TCP flags** — Find connection attempts (SYN), resets (RST), or closures (FIN)
2. **Save to file** — Capture packets for later analysis or sharing with colleagues
3. **Analyze in Wireshark** — Use a GUI tool for deep packet inspection

**Real-world scenarios:**
- "Why are connections failing?" → Filter for RST packets
- "Why is the three-way handshake not completing?" → Filter for SYN packets without SYN-ACK replies
- "I need to share this capture with the network team" → Save to .pcap file

---

## TCP Flags Deep Dive

**TCP flags are single bits in the TCP header:**

| Flag | Bit | Name | Purpose |
|------|-----|------|---------|
| **SYN** | S | Synchronize | Start a new connection |
| **ACK** | . | Acknowledge | Acknowledge received data |
| **PSH** | P | Push | Push data to application immediately |
| **FIN** | F | Finish | Close connection gracefully |
| **RST** | R | Reset | Abort connection |
| **URG** | U | Urgent | Urgent data (rarely used) |

**Common flag combinations:**

| Flags | Meaning |
|-------|---------|
| **[S]** | SYN (connection request) |
| **[S.]** | SYN-ACK (connection accepted) |
| **[.]** | ACK (acknowledgment) |
| **[P.]** | PSH-ACK (data transfer) |
| **[F.]** | FIN-ACK (graceful close) |
| **[R]** | RST (connection reset/refused) |

---

## Hands-On Lab

### Part 1: Filter by TCP Flags — Find SYN Packets (10 minutes)

**SYN packets** indicate new connection attempts.

```bash
# Filter for SYN packets only (tcp[13] & 2 != 0)
sudo tcpdump -i eth0 'tcp[13] & 2 != 0' -n

# Simpler syntax (some tcpdump versions):
sudo tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0' -n
```

**Explanation:**
- `tcp[13]` = byte 13 of the TCP header (flags field)
- `& 2` = bitmask for SYN flag
- `!= 0` = if SYN is set

Now generate some SYN packets:

```bash
# In another terminal, try to connect to a closed port
telnet 192.168.1.1 9999
```

**Expected output:**

```
10:45:12.123456 IP 192.168.1.10.54321 > 192.168.1.1.9999: Flags [S], seq 12345
```

You will see SYN packets being sent, but if the port is closed, you will also see RST replies.

---

### Part 2: Filter for RST Packets (Connection Refused/Reset) (10 minutes)

**RST packets** indicate connection failures or resets.

```bash
# Filter for RST packets
sudo tcpdump -i eth0 'tcp[13] & 4 != 0' -n
```

Generate RST packets:

```bash
# Try to connect to a closed port
curl http://127.0.0.1:9999
```

**Expected output:**

```
10:50:15.123456 IP 127.0.0.1.9999 > 127.0.0.1.54322: Flags [R.], seq 0
```

The RST flag means "I'm not listening on this port, go away."

**Use case:** If you see RST packets when debugging OCP, it means:
- The service is not listening on that port
- A firewall is blocking the connection
- The connection was forcibly closed

---

### Part 3: Filter for SYN but NOT ACK (Incomplete Handshakes) (10 minutes)

**SYN without ACK** means the handshake did not complete.

```bash
# Filter for SYN packets that are NOT SYN-ACK
sudo tcpdump -i eth0 'tcp[13] = 2' -n
```

**Explanation:**
- `tcp[13] = 2` means ONLY the SYN flag is set (not SYN-ACK)

**Use case:** If you see many SYN packets without SYN-ACK replies, it means:
- The server is not responding
- Packets are being dropped
- Firewall is blocking replies

---

### Part 4: Save Packets to a File (10 minutes)

Instead of viewing packets in real-time, you can save them to a file for later analysis.

```bash
# Save to a file called capture.pcap
sudo tcpdump -i eth0 -w capture.pcap

# Let it run for 10 seconds, then press Ctrl+C
```

Generate some traffic:

```bash
# In another terminal:
ping -c 5 8.8.8.8
curl http://example.com
nslookup google.com
```

Stop tcpdump (Ctrl+C).

Verify the file was created:

```bash
ls -lh capture.pcap
```

**Expected output:**

```
-rw-r--r--. 1 root root 12K Apr  9 11:00 capture.pcap
```

---

### Part 5: Read a Saved Capture File (10 minutes)

```bash
# Read the saved capture
sudo tcpdump -r capture.pcap
```

**Expected output:**

You will see all the packets you captured, just like when you captured them live.

**Filter while reading:**

```bash
# Show only DNS traffic from the saved file
sudo tcpdump -r capture.pcap port 53

# Show only ICMP from the saved file
sudo tcpdump -r capture.pcap icmp
```

**Use case:** Share capture.pcap with a colleague, and they can analyze it without needing access to your system.

---

### Part 6: Save and Filter in One Command (10 minutes)

You can filter while saving to reduce file size.

```bash
# Capture only HTTP traffic and save to file
sudo tcpdump -i eth0 port 80 -w http-only.pcap

# Let it run while you generate HTTP traffic
curl http://example.com
curl http://neverssl.com

# Stop tcpdump (Ctrl+C)

# Read it back
sudo tcpdump -r http-only.pcap -n
```

---

### Part 7: Rotate Capture Files (Large Captures) (10 minutes)

For long captures, you can rotate files to prevent one huge file.

```bash
# Rotate files every 10MB, keep max 5 files
sudo tcpdump -i eth0 -w capture.pcap -C 10 -W 5

# This creates:
# capture.pcap0
# capture.pcap1
# capture.pcap2
# capture.pcap3
# capture.pcap4
```

**Use case:** Long-term monitoring without filling up disk space.

---

### Part 8: Add Timestamps to Filenames (10 minutes)

```bash
# Create a capture with timestamp in filename
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
sudo tcpdump -i eth0 -w capture_$TIMESTAMP.pcap -c 50
```

**Expected output:**

```
capture_20260409_110523.pcap
```

**Use case:** Organize multiple captures for troubleshooting sessions.

---

### Part 9: Transfer Capture to Wireshark (15 minutes)

**Wireshark** is a GUI tool for deep packet analysis.

**Step 1: Save a capture**

```bash
sudo tcpdump -i eth0 -w ocp-debug.pcap -c 100
```

Generate some traffic.

**Step 2: Transfer to your workstation**

```bash
# On your workstation:
scp user@server:/path/to/ocp-debug.pcap .
```

**Step 3: Open in Wireshark**

```bash
wireshark ocp-debug.pcap
```

**What can you do in Wireshark?**
- Follow TCP streams
- See packet contents in a nice format
- Apply complex filters
- View statistics (packet rates, retransmissions, etc.)

---

### Part 10: Combine Advanced Filters (15 minutes)

**Capture SYN packets to port 80:**

```bash
sudo tcpdump -i eth0 'tcp[13] & 2 != 0 and port 80' -n
```

**Capture packets to 8.8.8.8 but NOT DNS:**

```bash
sudo tcpdump -i eth0 'host 8.8.8.8 and not port 53' -n
```

**Capture HTTP or HTTPS:**

```bash
sudo tcpdump -i eth0 'port 80 or port 443' -n
```

**Capture TCP packets with payload (not just handshakes):**

```bash
# tcp[13] & 8 != 0 means PSH flag is set
sudo tcpdump -i eth0 'tcp[13] & 8 != 0' -n
```

---

## Real-World OCP Troubleshooting Scenario

**Problem:** "Pods cannot connect to an external database."

**Troubleshooting steps using tcpdump:**

1. **Find the pod's veth interface** (see Day 20)
2. **Capture SYN packets** leaving the pod:
   ```bash
   sudo tcpdump -i <veth> 'tcp[13] & 2 != 0 and host <db-ip>' -n
   ```
3. **Look for:**
   - SYN packets leaving (proves pod is trying to connect)
   - SYN-ACK replies (proves DB is responding)
   - No reply (proves packets are being dropped)
4. **If no SYN-ACK:** Check firewalls, security groups, network policies
5. **If you see RST:** DB is rejecting connections (check authentication, DB config)

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What does the SYN flag indicate?
2. What does the RST flag indicate?
3. How do you save packets to a file?
4. How do you read a saved pcap file?
5. What is Wireshark used for?

**Answers:**

1. Start of a new TCP connection
2. Connection refused/reset (abrupt close)
3. `sudo tcpdump -i <interface> -w <filename>.pcap`
4. `sudo tcpdump -r <filename>.pcap`
5. GUI tool for deep packet analysis

---

## Today I Learned (TIL) — Write This Down

In your notebook, write 5 bullet points:

- What did I learn today?
- What surprised me?
- What do I still not understand?

Example:

```
April 9, 2026 — Day 25: tcpdump Advanced

- I can filter by TCP flags (SYN, RST, FIN) to find specific connection issues
- -w saves packets to a file, -r reads them back
- I can transfer .pcap files to Wireshark for GUI analysis
- Seeing SYN without SYN-ACK means the handshake is failing
- tcpdump -C rotates files to prevent filling up disk
```

---

## Commands Cheat Sheet

**Advanced tcpdump Filters:**

```bash
# Filter by TCP flags
sudo tcpdump -i eth0 'tcp[13] & 2 != 0' -n    # SYN packets
sudo tcpdump -i eth0 'tcp[13] & 4 != 0' -n    # RST packets
sudo tcpdump -i eth0 'tcp[13] & 1 != 0' -n    # FIN packets
sudo tcpdump -i eth0 'tcp[13] = 2' -n         # SYN only (not SYN-ACK)
sudo tcpdump -i eth0 'tcp[13] & 8 != 0' -n    # PSH (data packets)

# Save to file
sudo tcpdump -i eth0 -w capture.pcap
sudo tcpdump -i eth0 -w capture.pcap -c 100   # Limit to 100 packets

# Read from file
sudo tcpdump -r capture.pcap
sudo tcpdump -r capture.pcap port 53          # Filter while reading

# Rotate files
sudo tcpdump -i eth0 -w capture.pcap -C 10 -W 5   # 10MB files, max 5

# Timestamp in filename
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
sudo tcpdump -i eth0 -w capture_$TIMESTAMP.pcap -c 50

# Advanced combinations
sudo tcpdump -i eth0 'tcp[13] & 2 != 0 and port 443' -n   # SYN to HTTPS
sudo tcpdump -i eth0 'host 8.8.8.8 and not port 53' -n    # Non-DNS to 8.8.8.8
```

**TCP Flag Bitmasks:**

```
tcp[13] byte (TCP flags):
  1 = FIN
  2 = SYN
  4 = RST
  8 = PSH
 16 = ACK
 32 = URG

Examples:
tcp[13] = 2      → SYN only
tcp[13] = 18     → SYN-ACK (2 + 16)
tcp[13] & 2 != 0 → Any packet with SYN flag set
```

---

## What's Next?

**Tomorrow (Day 26):** nsenter — entering a pod's network namespace

**Why it matters:** You learned how to capture packets on a veth interface. Tomorrow you will learn how to "jump inside" a pod's network namespace and run commands AS IF you were inside the pod — critical for OCP debugging.

---

**End of Day 25 Lab**

Excellent work. You now have advanced tcpdump skills. Tomorrow you learn nsenter for pod debugging.
