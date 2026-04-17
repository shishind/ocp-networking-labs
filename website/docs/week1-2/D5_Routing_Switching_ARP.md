# Day 5: Routing, Switching, and ARP — How Packets Find Their Way

**Date:** Friday, March 13, 2026  
**Phase:** 1 - Core Networking Fundamentals  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Understand the difference between a switch and a router
- Read and interpret a routing table
- Understand what ARP does and why it matters
- Use `ip route` and `ip neigh` to troubleshoot connectivity
- Draw a simple network topology

---

## Plain English: How Does a Packet Know Where to Go?

When you send a message to another computer, your machine needs to answer two questions:

1. **Is the destination on my local network?** → Use a **switch** (Layer 2)
2. **Is the destination on another network?** → Use a **router** (Layer 3)

Think of it like mailing a letter:
- **Switch** = Delivering mail within your apartment building (same floor)
- **Router** = Sending mail to another city (different network)

---

## Switches vs Routers

| Device | OSI Layer | What It Does | Example |
|--------|-----------|--------------|---------|
| **Switch** | Layer 2 (Data Link) | Forwards packets within the same network using MAC addresses | Your office network switch |
| **Router** | Layer 3 (Network) | Forwards packets between different networks using IP addresses | Your home Wi-Fi router |

**In OpenShift:**
- **OVS (Open vSwitch)** = Virtual switch on each node
- **OVN (Open Virtual Network)** = Virtual router connecting pods across nodes

---

## The Routing Table — Your Computer's Map

Every Linux machine has a **routing table** — a list of instructions that say:

> "If you want to reach network X, send the packet through gateway Y"

Run this command:

```bash
ip route show
```

**Example output:**

```
default via 192.168.1.1 dev eth0
10.128.0.0/14 dev ovs0 proto kernel scope link src 10.128.1.50
172.30.0.0/16 via 10.128.0.1 dev ovs0
192.168.1.0/24 dev eth0 proto kernel scope link src 192.168.1.100
```

**What each line means:**

| Route | Meaning |
|-------|---------|
| `default via 192.168.1.1 dev eth0` | "For anything I don't know, send it to 192.168.1.1 (the gateway)" |
| `10.128.0.0/14 dev ovs0` | "For pod IPs (10.128.x.x), send directly to ovs0 (local switch)" |
| `172.30.0.0/16 via 10.128.0.1` | "For service IPs (172.30.x.x), route through 10.128.0.1" |
| `192.168.1.0/24 dev eth0` | "For my local network (192.168.1.x), send directly to eth0" |

**The "default" route is your internet gateway.** If your machine doesn't know where to send a packet, it sends it there.

---

## ARP — Translating IP Addresses to MAC Addresses

Your computer knows the **IP address** (Layer 3) of the destination, but the network card needs the **MAC address** (Layer 2).

**ARP (Address Resolution Protocol)** asks: "Who has IP 192.168.1.1? Tell me your MAC address!"

Run this command:

```bash
ip neigh show
```

**Example output:**

```
192.168.1.1 dev eth0 lladdr 00:50:56:c0:00:08 REACHABLE
10.128.1.51 dev ovs0 lladdr 02:42:0a:80:01:33 STALE
```

**What it means:**

| IP | MAC Address | State | Meaning |
|----|-------------|-------|---------|
| 192.168.1.1 | 00:50:56:c0:00:08 | REACHABLE | "I recently talked to this device, MAC is fresh" |
| 10.128.1.51 | 02:42:0a:80:01:33 | STALE | "I have this cached, but it might be old" |

**Other states:**
- **PERMANENT** = Manually added (never expires)
- **FAILED** = ARP lookup failed (device unreachable)
- **INCOMPLETE** = Currently looking up the MAC address

**Why it matters for OCP:**

If ARP fails between nodes, pods cannot reach each other. You will see packet loss.

---

## How a Packet Travels — Step by Step

Let's say you run: `curl 172.30.0.5` (a service IP in OpenShift)

**Step-by-step:**

1. **Check routing table**: "Where does 172.30.0.5 go?"  
   → Answer: `172.30.0.0/16 via 10.128.0.1 dev ovs0`

2. **Send to gateway**: "Forward this to 10.128.0.1"

3. **ARP lookup**: "What is the MAC address of 10.128.0.1?"  
   → Check `ip neigh` cache

4. **Switch forwards**: OVS sends the packet to the correct MAC

5. **Router forwards**: OVN routes to the correct pod

**If any of these steps fail, the packet is dropped.**

---

## Hands-On Lab

### Part 1: View Your Routing Table (10 minutes)

Run this command:

```bash
ip route show
```

**Your task:**

1. Find the **default gateway** (the line with `default via`)
2. Find the **local network route** (should match your IP range)
3. If you have OpenShift/Kubernetes, find the **pod network route** (10.128.0.0/14 or similar)

**Example answers:**

1. Default gateway: `192.168.1.1 dev eth0`
2. Local network: `192.168.1.0/24 dev eth0`
3. Pod network: `10.128.0.0/14 dev ovs0`

---

### Part 2: View ARP Table (10 minutes)

Run this command:

```bash
ip neigh show
```

**Your task:**

1. Find your **default gateway** in the ARP table
2. Note its **MAC address**
3. Check the **state** (REACHABLE, STALE, etc.)

**Example:**

```
192.168.1.1 dev eth0 lladdr 00:50:56:c0:00:08 REACHABLE
```

**What it means:**

- IP: `192.168.1.1` (gateway)
- MAC: `00:50:56:c0:00:08`
- State: `REACHABLE` (fresh)

---

### Part 3: Trace a Route to Google (15 minutes)

The `traceroute` command shows every router your packet passes through.

```bash
traceroute -n 8.8.8.8
```

**What the flags mean:**
- `-n` = Show IPs (don't do DNS lookups)

**Expected output:**

```
traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets
 1  192.168.1.1       1.234 ms
 2  10.0.0.1          5.678 ms
 3  172.16.0.1       10.123 ms
 4  8.8.8.8          15.456 ms
```

**What it means:**

- Hop 1: My local gateway (192.168.1.1)
- Hop 2: ISP router (10.0.0.1)
- Hop 3: Another router (172.16.0.1)
- Hop 4: Google DNS (8.8.8.8)

**Your task:**

1. Run `traceroute -n 8.8.8.8`
2. Count the number of hops
3. Identify your **first hop** (your local gateway)

**Draw it on paper:**

```
My machine (192.168.1.100)
   ↓
Gateway (192.168.1.1)
   ↓
ISP Router (10.0.0.1)
   ↓
Internet...
   ↓
Google (8.8.8.8)
```

---

### Part 4: Test Connectivity with Ping (10 minutes)

```bash
ping -c 4 8.8.8.8
```

**Expected output:**

```
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=56 time=15.3 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=56 time=15.1 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=56 time=15.4 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=56 time=15.2 ms
```

**What it means:**

- `64 bytes from 8.8.8.8` = Success! We got a reply
- `ttl=56` = Time-to-live (how many hops left before packet expires)
- `time=15.3 ms` = Round-trip time

**Your task:**

1. Ping your **default gateway**: `ping -c 4 <gateway-ip>`
2. Ping **Google DNS**: `ping -c 4 8.8.8.8`
3. Ping a **nonexistent local IP**: `ping -c 4 192.168.1.250`

**Expected results:**

1. Gateway: Success (should be very fast, < 1 ms)
2. Google: Success (should be 10-50 ms depending on location)
3. Nonexistent IP: No reply (timeout)

---

### Part 5: Draw Your Network Topology (15 minutes)

Using the information from `ip route show`, `ip neigh show`, and `traceroute`, draw your network topology.

**Example:**

```
Internet (8.8.8.8)
    ↑
    |
Gateway (192.168.1.1)
    |
    ↓
Switch (Layer 2)
    |
    ├── My Machine (192.168.1.100)
    ├── Another Device (192.168.1.101)
    └── Another Device (192.168.1.102)
```

**Your task:**

1. Draw your machine
2. Draw the default gateway
3. Draw any other devices in your ARP table
4. Label each with IP and MAC address

---

## OpenShift Routing — How Pods Talk

In OpenShift, every node has:

1. **Physical NIC** (eth0) → Connects to the datacenter network
2. **OVS Bridge** (br-ex, ovs0) → Virtual switch for pods
3. **OVN Router** → Routes between pod networks on different nodes

**Example OpenShift routing table:**

```
default via 192.168.50.1 dev eth0
10.128.0.0/14 dev ovs0 proto kernel scope link src 10.128.1.50
172.30.0.0/16 via 10.128.0.1 dev ovs0
192.168.50.0/24 dev eth0 proto kernel scope link src 192.168.50.10
```

**What it means:**

- **Pods** (10.128.x.x) → Send to OVS switch
- **Services** (172.30.x.x) → Route through OVN gateway (10.128.0.1)
- **Internet** → Use default gateway (192.168.50.1)

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What is the difference between a switch and a router?
2. What does the "default" route in a routing table mean?
3. What does ARP do?
4. What command shows your routing table?
5. What command shows your ARP cache?
6. If ARP state is "FAILED", what does that mean?

**Answers:**

1. Switch = Layer 2, forwards within same network using MAC. Router = Layer 3, forwards between networks using IP
2. Default route = "If I don't know where to send this, send it here"
3. ARP translates IP addresses to MAC addresses
4. `ip route show`
5. `ip neigh show`
6. FAILED = Device is unreachable, ARP lookup failed

---

## Today I Learned (TIL) — Write This Down

Example:

```
March 13, 2026 — Day 5: Routing, Switching, ARP

- Switch = Layer 2, same network, uses MAC. Router = Layer 3, different networks, uses IP
- Routing table = map that tells my computer where to send packets
- Default route = gateway for unknown destinations
- ARP = translates IP to MAC address
- Commands: ip route show (routing table), ip neigh show (ARP table), traceroute (see hops)
- REACHABLE = fresh, STALE = old but cached, FAILED = unreachable
```

---

## Commands Cheat Sheet

```bash
# Show routing table
ip route show

# Show ARP table (neighbor cache)
ip neigh show

# Trace route to destination
traceroute -n <ip>

# Ping test (4 packets)
ping -c 4 <ip>

# Show specific route for an IP
ip route get <ip>

# Flush ARP cache (requires root)
sudo ip neigh flush all

# Add static route
sudo ip route add 10.0.0.0/24 via 192.168.1.1 dev eth0

# Delete route
sudo ip route del 10.0.0.0/24
```

---

## What's Next?

**Tomorrow (Day 6):** NAT (Network Address Translation) — How Private IPs Access the Internet

**Practice tonight:**
- Run `ip route show` and explain every line
- Run `ip neigh show` and check the state of each entry
- Draw your home network topology

---

**End of Day 5 Lab**

Good job. Tomorrow we learn how NAT allows your private IP (192.168.x.x) to access the internet.
