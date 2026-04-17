# Day 19: conntrack — Linux Connection Tracking

**Date:** Friday, April 3, 2026  
**Phase:** 2 - Linux & Container Networking  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Explain what connection tracking (conntrack) is and why it is needed
- Read and interpret conntrack entries
- Understand connection states (NEW, ESTABLISHED, RELATED)
- Troubleshoot NAT issues using conntrack
- Understand why stateful firewalls matter

---

## Plain English: What Is Connection Tracking?

Imagine you run a mail room. Letters arrive, and you need to know:
- Is this a NEW letter (start of a conversation)?
- Is this a REPLY to an earlier letter?
- Which earlier letter is it replying to?

Without tracking, you would not know. You would treat every letter as new and unrelated.

**Connection tracking (conntrack)** is how Linux remembers network connections.

When a packet arrives, Linux checks:
- Is this a NEW connection?
- Is this part of an ESTABLISHED connection?
- Is this RELATED to an existing connection?

This is CRITICAL for:
- **Stateful firewalls:** Allow replies but block new connections
- **NAT:** Remember IP rewrites so replies get rewritten back
- **Troubleshooting:** See exactly which connections are active

**Why does this matter for OCP?**

Every Kubernetes Service uses NAT. Every NAT rewrite is tracked by conntrack.

When you troubleshoot a Service that is not working, you check:
1. Does the iptables rule exist? (Day 18)
2. Is conntrack creating an entry? (Today)
3. Is the reply being rewritten correctly? (Today)

Without conntrack, NAT would not work.

---

## What Is conntrack?

**conntrack** is the Linux kernel subsystem that tracks network connections.

It maintains a **connection tracking table** that stores:
- Source IP and port
- Destination IP and port
- Protocol (TCP, UDP, ICMP)
- Connection state (NEW, ESTABLISHED, RELATED)
- NAT translations (if any)
- Timeouts

Every packet that arrives is checked against this table.

---

## Connection States

conntrack recognizes several states:

| State | Meaning | Example |
|-------|---------|---------|
| **NEW** | First packet of a new connection | SYN packet in TCP |
| **ESTABLISHED** | Part of an existing connection | SYN-ACK, ACK, data packets |
| **RELATED** | Related to an existing connection | FTP data connection, ICMP error |
| **INVALID** | Does not belong to any known connection | Malformed packets |

**Why this matters:**

Stateful firewalls use these states. You can write iptables rules like:
- Allow ESTABLISHED and RELATED (replies are OK)
- Drop NEW from outside (block incoming connections)

This is more secure than allowing all traffic.

---

## How conntrack Works with NAT

When iptables rewrites an IP address (NAT), conntrack remembers the translation:

1. **Original packet:** src=10.0.0.1:5000, dst=172.30.0.5:80
2. **After DNAT:** src=10.0.0.1:5000, dst=10.128.0.50:8080
3. **conntrack entry created:**
   - Original: 10.0.0.1:5000 → 172.30.0.5:80
   - Reply: 10.128.0.50:8080 → 10.0.0.1:5000
4. **When reply arrives:** conntrack rewrites it back so the client sees 172.30.0.5:80 as the source

Without conntrack, the reply would show src=10.128.0.50, and the client would reject it because it never contacted that IP.

---

## Hands-On Lab

### Part 1: View the Connection Tracking Table (5 minutes)

```bash
# View all active connections
sudo conntrack -L

# Count the number of entries
sudo conntrack -L | wc -l
```

**Expected output:**

You will see a list of all active connections. Each line represents one connection.

**Question:** How many connections are active on your system right now?

---

### Part 2: Understand a conntrack Entry (10 minutes)

Let's decode a typical entry:

```
tcp      6 431999 ESTABLISHED src=192.168.1.100 dst=8.8.8.8 sport=54321 dport=443 src=8.8.8.8 dst=192.168.1.100 sport=443 dport=54321 [ASSURED] mark=0 use=1
```

**Field-by-field breakdown:**

| Field | Meaning |
|-------|---------|
| `tcp` | Protocol |
| `6` | Protocol number (6 = TCP) |
| `431999` | Timeout (seconds until entry expires) |
| `ESTABLISHED` | Connection state |
| `src=192.168.1.100` | Original source IP |
| `dst=8.8.8.8` | Original destination IP |
| `sport=54321` | Original source port |
| `dport=443` | Original destination port |
| `src=8.8.8.8` | Reply source IP |
| `dst=192.168.1.100` | Reply destination IP |
| `sport=443` | Reply source port |
| `dport=54321` | Reply destination port |
| `[ASSURED]` | Connection has seen traffic in both directions |

**Key insight:**

The entry shows BOTH directions of the connection. This is how Linux knows which replies belong to which connections.

---

### Part 3: Filter conntrack by Protocol (10 minutes)

```bash
# Show only TCP connections
sudo conntrack -L -p tcp

# Show only UDP connections
sudo conntrack -L -p udp

# Show only ICMP
sudo conntrack -L -p icmp
```

**Question:** Which protocol has the most connections on your system?

**Answer:** Usually TCP (for SSH, HTTP, etc.).

---

### Part 4: Filter conntrack by IP Address (10 minutes)

```bash
# Show connections to a specific IP
sudo conntrack -L | grep 8.8.8.8

# Show connections from your IP
sudo conntrack -L | grep <your-ip>
```

**Example:**

```bash
# Ping Google DNS and watch conntrack
ping -c 3 8.8.8.8 &
sudo conntrack -L | grep 8.8.8.8
```

**Expected output:**

You should see an ICMP connection entry for the ping.

---

### Part 5: Watch conntrack in Real-Time (10 minutes)

```bash
# Monitor conntrack events in real-time
sudo conntrack -E
```

Now open another terminal and make a connection:

```bash
# In another terminal:
curl http://example.com
```

**Expected output:**

In the conntrack terminal, you will see NEW and ESTABLISHED events as the connection is created.

**What you should see:**

1. `[NEW]` entry when the connection starts
2. `[UPDATE]` entries as packets flow
3. `[DESTROY]` entry when the connection closes

Press Ctrl+C to stop monitoring.

---

### Part 6: Create a Connection with NAT and Track It (15 minutes)

Let's combine yesterday's NAT knowledge with conntrack.

```bash
# Start a simple web server
sudo python3 -m http.server 8080 &

# Create a DNAT rule (redirect 10.0.0.100:80 to 127.0.0.1:8080)
sudo iptables -t nat -A OUTPUT -p tcp -d 10.0.0.100 --dport 80 -j DNAT --to-destination 127.0.0.1:8080

# In one terminal, monitor conntrack
sudo conntrack -E &

# In another terminal, make a request
curl http://10.0.0.100
```

**What to look for in conntrack:**

```
[NEW] tcp      6 120 SYN_SENT src=<your-ip> dst=10.0.0.100 sport=<random> dport=80 src=127.0.0.1 dst=<your-ip> sport=8080 dport=<random>
```

**Notice:**

- **Original packet:** dst=10.0.0.100:80
- **After DNAT:** src=127.0.0.1:8080 (reply direction)

conntrack remembers the NAT translation.

---

### Part 7: View NAT Entries Specifically (10 minutes)

```bash
# Show only connections that have been NATed
sudo conntrack -L | grep 10.0.0.100
```

**Expected output:**

```
tcp      6 115 TIME_WAIT src=127.0.0.1 dst=10.0.0.100 sport=<port> dport=80 src=127.0.0.1 dst=127.0.0.1 sport=8080 dport=<port>
```

**What does this mean?**

- **Original:** Client contacted 10.0.0.100:80
- **After DNAT:** Traffic was rewritten to 127.0.0.1:8080
- **Reply:** 127.0.0.1:8080 replied back to the client

conntrack made sure the reply was rewritten correctly.

---

### Part 8: Delete a Specific Connection (10 minutes)

Sometimes you need to clear a stuck connection.

```bash
# List connections to find one to delete
sudo conntrack -L -p tcp | grep ESTABLISHED | head -1

# Delete a specific connection (example)
sudo conntrack -D -p tcp --src <src-ip> --dst <dst-ip>
```

**Warning:** This forcibly closes the connection. Use only for troubleshooting.

**Use case:**

If a NAT entry is stuck or incorrect, deleting it forces a fresh connection.

---

### Part 9: Check conntrack Table Size and Limits (10 minutes)

conntrack has limits. If the table fills up, new connections are dropped.

```bash
# Show current number of entries
sudo conntrack -L | wc -l

# Show maximum allowed entries
sudo sysctl net.netfilter.nf_conntrack_max

# Show current count (faster than conntrack -L)
cat /proc/sys/net/netfilter/nf_conntrack_count
```

**Expected output:**

```
net.netfilter.nf_conntrack_max = 65536
```

**What if the table is full?**

You will see errors like:
```
nf_conntrack: table full, dropping packet
```

**Solution:**

Increase the limit:
```bash
sudo sysctl -w net.netfilter.nf_conntrack_max=131072
```

---

### Part 10: Clean Up (5 minutes)

```bash
# Stop the Python web server
sudo pkill -f "python3 -m http.server"

# Remove the DNAT rule
sudo iptables -t nat -D OUTPUT -p tcp -d 10.0.0.100 --dport 80 -j DNAT --to-destination 127.0.0.1:8080

# Verify NAT rule is gone
sudo iptables -t nat -L OUTPUT -n -v
```

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What is conntrack?
2. What are the four main connection states?
3. Why is conntrack needed for NAT?
4. How do you view all active connections?
5. What happens if the conntrack table fills up?

**Answers:**

1. Linux connection tracking subsystem that remembers network connections
2. NEW, ESTABLISHED, RELATED, INVALID
3. conntrack remembers NAT rewrites so reply packets get rewritten back correctly
4. `sudo conntrack -L`
5. New connections are dropped (table full error)

---

## Today I Learned (TIL) — Write This Down

In your notebook, write 5 bullet points:

- What did I learn today?
- What surprised me?
- What do I still not understand?

Example:

```
April 3, 2026 — Day 19: conntrack

- conntrack tracks all network connections (source, dest, ports, state)
- Connection states: NEW, ESTABLISHED, RELATED, INVALID
- conntrack remembers NAT rewrites for reply packets
- conntrack -E shows real-time connection events
- If the conntrack table fills up, new connections are dropped
```

---

## Commands Cheat Sheet

**conntrack Commands:**

```bash
# View all connections
sudo conntrack -L

# Count connections
sudo conntrack -L | wc -l

# Filter by protocol
sudo conntrack -L -p tcp
sudo conntrack -L -p udp

# Filter by IP
sudo conntrack -L | grep <IP>

# Monitor in real-time
sudo conntrack -E

# Delete a specific connection
sudo conntrack -D -p <proto> --src <src-ip> --dst <dst-ip>

# Flush entire table (careful!)
sudo conntrack -F

# Show table size
cat /proc/sys/net/netfilter/nf_conntrack_count

# Show max table size
cat /proc/sys/net/netfilter/nf_conntrack_max

# Increase max table size
sudo sysctl -w net.netfilter.nf_conntrack_max=<new-value>
```

**iptables with Connection States:**

```bash
# Allow ESTABLISHED and RELATED, drop NEW from outside
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -m state --state NEW -i eth0 -j DROP
```

---

## What's Next?

**Tomorrow (Day 20):** Docker Networking — putting it all together

**Why it matters:** You now understand namespaces, veth pairs, bridges, iptables NAT, and conntrack. Tomorrow you will see how Docker combines all of these to create container networking.

---

**End of Day 19 Lab**

Great work. You now understand how Linux tracks connections. Tomorrow we see Docker networking in action.
