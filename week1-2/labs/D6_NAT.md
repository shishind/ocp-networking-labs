# Day 6: NAT — How Private IPs Access the Internet

**Date:** Saturday, March 14, 2026  
**Phase:** 1 - Core Networking Fundamentals  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Explain what NAT is and why it exists
- Understand the difference between SNAT, DNAT, and MASQUERADE
- Read iptables NAT rules
- Draw a NAT flow diagram
- Troubleshoot NAT issues in OpenShift

---

## Plain English: What Is NAT?

**NAT (Network Address Translation)** is how your computer with a private IP (like 192.168.1.100) can access the internet.

Think of it like a post office:

- Your apartment = **Private IP** (192.168.1.100)
- Post office = **Router doing NAT**
- Post office address = **Public IP** (203.0.113.50)

When you send a letter (packet) to the internet:
1. You write your private address as the return address
2. The post office (router) **rewrites** it with the public address
3. When the reply comes back, the post office **translates** it back to your private address

**Without NAT, the internet would have run out of IP addresses in the 1990s.**

---

## Why NAT Exists

There are only **4.3 billion IPv4 addresses** in the world. With NAT:
- Millions of devices can share one public IP
- Private IPs (10.x.x.x, 192.168.x.x) never appear on the internet
- Only the router's public IP is visible

**In OpenShift:**
- Pods have private IPs (10.128.x.x)
- When pods access the internet, **NAT rewrites the source IP** to the node's public IP
- Incoming traffic to services uses **DNAT** to route to the correct pod

---

## Types of NAT

| Type | Full Name | What It Does | Example |
|------|-----------|--------------|---------|
| **SNAT** | Source NAT | Changes the **source IP** of outgoing packets | Pod (10.128.1.50) → Internet appears as Node (192.168.50.10) |
| **DNAT** | Destination NAT | Changes the **destination IP** of incoming packets | Service IP (172.30.0.5) → Pod IP (10.128.1.50) |
| **MASQUERADE** | Dynamic SNAT | SNAT when the public IP changes (DHCP) | Home router with dynamic ISP IP |

---

## SNAT — Outbound NAT

**SNAT (Source NAT)** changes the **source IP** when a packet leaves your network.

**Example:**

```
Before NAT:
  Source: 192.168.1.100:54321 → Destination: 8.8.8.8:53

After NAT (at the router):
  Source: 203.0.113.50:12345 → Destination: 8.8.8.8:53
```

**The router remembers:**
- Original: 192.168.1.100:54321
- Translated: 203.0.113.50:12345

**When the reply comes back:**

```
Before NAT:
  Source: 8.8.8.8:53 → Destination: 203.0.113.50:12345

After NAT (at the router):
  Source: 8.8.8.8:53 → Destination: 192.168.1.100:54321
```

The router **translates it back** to your private IP.

---

## DNAT — Inbound NAT

**DNAT (Destination NAT)** changes the **destination IP** when a packet enters your network.

**Example:**

You have a web server on 192.168.1.10, but the public IP is 203.0.113.50.

```
Before NAT:
  Source: 1.2.3.4:54321 → Destination: 203.0.113.50:80

After NAT (at the router):
  Source: 1.2.3.4:54321 → Destination: 192.168.1.10:80
```

The router **forwards** incoming traffic on port 80 to the private web server.

**In OpenShift:**
- Service IP (172.30.0.5) → DNAT to Pod IP (10.128.1.50)

---

## MASQUERADE — Dynamic SNAT

**MASQUERADE** is SNAT for dynamic IPs (like DHCP or dial-up).

**When to use:**
- Home router with ISP-assigned IP
- Cloud VMs with dynamic public IPs
- OpenShift nodes in AWS/Azure (public IP can change)

**Difference from SNAT:**
- SNAT = "Rewrite source to **this specific IP**"
- MASQUERADE = "Rewrite source to **whatever IP this interface has right now**"

**Example iptables rule:**

```bash
-A POSTROUTING -o eth0 -j MASQUERADE
```

Translation: "For packets leaving eth0, rewrite source IP to whatever eth0's IP is"

---

## Hands-On Lab

### Part 1: View NAT Rules (10 minutes)

Run this command to see NAT rules:

```bash
sudo iptables -t nat -L -n -v
```

**What the flags mean:**
- `-t nat` = NAT table
- `-L` = List rules
- `-n` = Show numbers (no DNS lookup)
- `-v` = Verbose (show packet counts)

**Expected output:**

```
Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
  123  9876 MASQUERADE  all  --  *      eth0    192.168.1.0/24       0.0.0.0/0
```

**Your task:**

1. Find the **POSTROUTING** chain (outbound NAT)
2. Find any **MASQUERADE** rules
3. Note the **source network** (e.g., 192.168.1.0/24)
4. Note the **output interface** (e.g., eth0)

**What this rule means:**

```
-A POSTROUTING -o eth0 -s 192.168.1.0/24 -j MASQUERADE
```

Translation:
- Chain: POSTROUTING (after routing decision)
- Interface: eth0 (outbound)
- Source: 192.168.1.0/24 (local network)
- Action: MASQUERADE (rewrite source IP to eth0's IP)

---

### Part 2: Understand Each NAT Chain (15 minutes)

The NAT table has **4 chains**:

| Chain | When It Runs | What It Does | Example Use |
|-------|--------------|--------------|-------------|
| **PREROUTING** | Before routing decision | DNAT (port forwarding) | Forward port 80 to internal server |
| **INPUT** | For packets destined to this machine | Rarely used | (Usually empty) |
| **OUTPUT** | For packets from this machine | DNAT for local processes | Redirect local traffic |
| **POSTROUTING** | After routing decision | SNAT/MASQUERADE | Change source IP before sending |

**Flow:**

```
Incoming packet:
  → PREROUTING (DNAT)
  → Routing decision
  → INPUT (if for local machine) OR FORWARD (if routing through)

Outgoing packet:
  → OUTPUT (DNAT for local)
  → Routing decision
  → POSTROUTING (SNAT/MASQUERADE)
```

**Your task:**

Run this command and identify each chain:

```bash
sudo iptables -t nat -L -n -v
```

1. Find **PREROUTING** (should have DNAT rules or be empty)
2. Find **POSTROUTING** (should have MASQUERADE or SNAT)
3. Count how many rules are in each chain

---

### Part 3: Draw a NAT Flow (20 minutes)

**Scenario:**

You are on a machine with:
- Private IP: `192.168.1.100`
- Gateway: `192.168.1.1` (public IP: `203.0.113.50`)

You run: `curl http://8.8.8.8`

**Draw the packet flow on paper:**

```
Step 1: Outbound packet leaves your machine
  Source: 192.168.1.100:54321
  Destination: 8.8.8.8:80

Step 2: Packet hits gateway (POSTROUTING chain)
  NAT rewrites source:
  Source: 203.0.113.50:12345  ← (SNAT/MASQUERADE)
  Destination: 8.8.8.8:80

Step 3: Packet travels to Google
  Source: 203.0.113.50:12345
  Destination: 8.8.8.8:80

Step 4: Reply comes back
  Source: 8.8.8.8:80
  Destination: 203.0.113.50:12345

Step 5: Gateway translates back (PREROUTING chain)
  NAT rewrites destination:
  Source: 8.8.8.8:80
  Destination: 192.168.1.100:54321  ← (reverse NAT)

Step 6: Packet arrives at your machine
  Source: 8.8.8.8:80
  Destination: 192.168.1.100:54321
```

**Your task:**

Draw this on paper. Label each step. Identify where SNAT happens.

---

### Part 4: Test NAT with tcpdump (15 minutes)

Let's see NAT in action!

#### Step 1: Start tcpdump on the external interface

```bash
sudo tcpdump -i eth0 'host 8.8.8.8' -n
```

#### Step 2: In another terminal, ping Google

```bash
ping -c 4 8.8.8.8
```

#### Step 3: Go back to tcpdump output

You should see something like this:

```
IP 203.0.113.50 > 8.8.8.8: ICMP echo request, id 12345, seq 1
IP 8.8.8.8 > 203.0.113.50: ICMP echo reply, id 12345, seq 1
```

**Your task:**

1. Find the **source IP** in the outbound packet
2. Compare it to your **private IP** (run `ip addr show`)
3. Notice: Your private IP **does not appear** on the wire — only the public IP

**Why?**

Because NAT (MASQUERADE) rewrote your private IP to the public IP before sending.

---

### Part 5: OpenShift NAT Example (10 minutes)

In OpenShift, when a pod accesses the internet:

```
Pod (10.128.1.50:54321) → Internet (8.8.8.8:53)
```

**NAT happens at the node:**

```
Before NAT:
  Source: 10.128.1.50:54321
  Destination: 8.8.8.8:53

After NAT (POSTROUTING on node):
  Source: 192.168.50.10:12345  ← (Node IP)
  Destination: 8.8.8.8:53
```

**OpenShift NAT rule (example):**

```bash
-A POSTROUTING -s 10.128.0.0/14 -j MASQUERADE
```

Translation:
- Source: 10.128.0.0/14 (all pods)
- Action: MASQUERADE (rewrite to node's IP)

**Your task:**

If you have access to an OpenShift node, run:

```bash
sudo iptables -t nat -L POSTROUTING -n -v | grep 10.128
```

Find the MASQUERADE rule for pod IPs.

If you don't have access, just understand the concept.

---

## OpenShift NAT — SNAT for Pods, DNAT for Services

**Outbound (Pod → Internet):**
- Pod IP: 10.128.1.50
- NAT: SNAT to node IP (192.168.50.10)

**Inbound (Client → Service):**
- Service IP: 172.30.0.5
- NAT: DNAT to pod IP (10.128.1.50)

**Why this matters:**

If NAT breaks:
- Pods cannot reach the internet (SNAT issue)
- Services cannot route to pods (DNAT issue)

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What does NAT stand for?
2. What is the difference between SNAT and DNAT?
3. What is MASQUERADE and when do you use it?
4. Which iptables chain handles outbound NAT?
5. Which iptables chain handles inbound NAT (port forwarding)?
6. In OpenShift, when a pod accesses 8.8.8.8, what IP appears on the internet?

**Answers:**

1. Network Address Translation
2. SNAT = change source IP (outbound). DNAT = change destination IP (inbound)
3. MASQUERADE = dynamic SNAT for interfaces with changing IPs (DHCP, cloud)
4. POSTROUTING
5. PREROUTING
6. The node's IP (not the pod IP)

---

## Today I Learned (TIL) — Write This Down

Example:

```
March 14, 2026 — Day 6: NAT

- NAT = rewriting IP addresses so private IPs can access the internet
- SNAT = change source IP (outbound). DNAT = change destination IP (inbound)
- MASQUERADE = SNAT for dynamic IPs
- POSTROUTING chain = outbound NAT (SNAT/MASQUERADE)
- PREROUTING chain = inbound NAT (DNAT/port forwarding)
- In OpenShift: pod IPs are SNATed to node IP when accessing internet
- Command: sudo iptables -t nat -L -n -v
```

---

## Commands Cheat Sheet

```bash
# View NAT table
sudo iptables -t nat -L -n -v

# View POSTROUTING chain (outbound NAT)
sudo iptables -t nat -L POSTROUTING -n -v

# View PREROUTING chain (inbound NAT)
sudo iptables -t nat -L PREROUTING -n -v

# Add MASQUERADE rule (outbound NAT)
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Add DNAT rule (port forwarding)
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 192.168.1.10:80

# Delete all NAT rules (CAREFUL!)
sudo iptables -t nat -F

# Save iptables rules (Fedora/RHEL)
sudo iptables-save > /etc/sysconfig/iptables
```

---

## What's Next?

**Tomorrow (Day 7):** Weekend Scenario — "I can ping 8.8.8.8 but cannot reach my-service by name"

**Practice tonight:**
- Run `sudo iptables -t nat -L -n -v` and identify every rule
- Draw a NAT flow diagram for your home network

---

**End of Day 6 Lab**

Good job. Tomorrow is the Weekend Scenario — your first real troubleshooting challenge using Week 1 knowledge.
