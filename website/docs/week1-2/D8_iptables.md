# Day 8: iptables — Linux Firewall Basics

**Date:** Monday, March 16, 2026  
**Phase:** 1 - Core Networking Fundamentals (Week 2 Start)  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Understand what iptables is and why it exists
- Read iptables rules in the filter table
- Understand chains: INPUT, OUTPUT, FORWARD
- Add a test firewall rule to block a port
- Test the rule with netcat (nc)
- Delete the rule safely

---

## Plain English: What Is iptables?

**iptables** is the Linux firewall. It controls which packets are **allowed** or **blocked** on your machine.

Think of it like a security guard at a building:
- Some people are allowed in (ACCEPT)
- Some are turned away (DROP)
- Some are told "no entry" with an explanation (REJECT)

**In OpenShift:**
- iptables controls pod-to-pod traffic
- iptables implements NetworkPolicies
- iptables handles NAT (we saw this on Day 6)

**Without iptables, there would be no firewall on Linux.**

---

## The Three Tables

iptables has **three main tables**:

| Table | Purpose | Example Use |
|-------|---------|-------------|
| **filter** | Allow or block traffic | Block SSH from the internet |
| **nat** | Rewrite IP addresses (NAT) | MASQUERADE, SNAT, DNAT (Day 6) |
| **mangle** | Modify packet headers | QoS, TTL changes (advanced) |

**Today we focus on the `filter` table** — the firewall.

---

## The Three Chains in the Filter Table

The **filter** table has three **chains** (sets of rules):

| Chain | When It Runs | Example Rule |
|-------|--------------|--------------|
| **INPUT** | Packets coming TO this machine | Block SSH on port 22 |
| **OUTPUT** | Packets leaving FROM this machine | Block outbound HTTP |
| **FORWARD** | Packets routing THROUGH this machine | Block traffic between pods |

**Flow:**

```
Incoming packet to this machine:
  → INPUT chain → (accept or drop)

Outgoing packet from this machine:
  → OUTPUT chain → (accept or drop)

Packet routing through this machine (like a router):
  → FORWARD chain → (accept or drop)
```

---

## The Three Actions

When a packet matches a rule, iptables takes an **action** (called a "target"):

| Target | What It Does | User Experience |
|--------|--------------|-----------------|
| **ACCEPT** | Allow the packet | Connection succeeds |
| **DROP** | Silently discard the packet | Connection times out (no response) |
| **REJECT** | Discard and send error message | Connection refused (immediate error) |

**DROP vs REJECT:**

- **DROP** = "Ignore the doorbell and stay silent"
- **REJECT** = "Open the door and say 'go away'"

**Which is better?**

- **DROP** = More secure (attacker doesn't know if the port exists)
- **REJECT** = Better for troubleshooting (you get an error message immediately)

---

## Reading an iptables Rule

**Example rule:**

```bash
-A INPUT -p tcp --dport 22 -j ACCEPT
```

**Translation:**

| Part | Meaning |
|------|---------|
| `-A INPUT` | Append to the INPUT chain |
| `-p tcp` | Protocol is TCP |
| `--dport 22` | Destination port is 22 (SSH) |
| `-j ACCEPT` | Action: Accept the packet |

**Full meaning:** "Accept incoming TCP traffic on port 22"

---

**Another example:**

```bash
-A INPUT -s 192.168.1.0/24 -p tcp --dport 80 -j DROP
```

**Translation:**

| Part | Meaning |
|------|---------|
| `-A INPUT` | Append to the INPUT chain |
| `-s 192.168.1.0/24` | Source IP is in 192.168.1.0/24 |
| `-p tcp` | Protocol is TCP |
| `--dport 80` | Destination port is 80 (HTTP) |
| `-j DROP` | Action: Drop the packet |

**Full meaning:** "Drop incoming TCP traffic from 192.168.1.0/24 on port 80"

---

## Default Policy

If a packet **does not match any rule**, the **default policy** is applied.

**Example:**

```bash
Chain INPUT (policy ACCEPT)
```

This means: "If no rule matches, ACCEPT the packet"

**Common policies:**

- **ACCEPT** = Allow by default, block specific traffic (whitelist approach)
- **DROP** = Block by default, allow specific traffic (blacklist approach)

**OpenShift default:** Usually ACCEPT, with specific rules to block traffic.

---

## Hands-On Lab

### Part 1: View Current iptables Rules (10 minutes)

Run this command:

```bash
sudo iptables -L -n -v
```

**What the flags mean:**
- `-L` = List rules
- `-n` = Show numbers (no DNS lookup)
- `-v` = Verbose (show packet counts)

**Expected output:**

```
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
```

**Your task:**

1. Identify the **default policy** for INPUT (ACCEPT or DROP)
2. Count how many rules are in the INPUT chain
3. Count how many rules are in the OUTPUT chain

**Note:** If you are on an OpenShift node, you will see MANY rules. That's normal.

---

### Part 2: Add a Test Firewall Rule (10 minutes)

Let's block port 9999 (a port nobody uses).

**Step 1: Add the rule**

```bash
sudo iptables -A INPUT -p tcp --dport 9999 -j DROP
```

**What this does:**
- Chain: INPUT (incoming traffic)
- Protocol: TCP
- Port: 9999
- Action: DROP (silently discard)

**Step 2: Verify the rule exists**

```bash
sudo iptables -L INPUT -n -v
```

**Expected output:**

```
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
    0     0 DROP       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:9999
```

**Your task:**

1. Add the rule
2. Verify it appears in the INPUT chain
3. Note the packet count (should be 0)

---

### Part 3: Test the Firewall Rule with netcat (15 minutes)

Now let's test if the rule actually blocks traffic.

#### Step 1: Start a listener on port 9999

In one terminal, run:

```bash
nc -l 9999
```

This starts a TCP listener on port 9999.

#### Step 2: Try to connect from another terminal

In another terminal (or another machine), run:

```bash
nc -zv localhost 9999
```

**Expected result:**

```
nc: connect to localhost port 9999 (tcp) failed: Connection timed out
```

**Why?**

Because iptables is **DROPping** the packets. The connection times out because there is no response.

#### Step 3: Change DROP to REJECT

Delete the old rule and add a new one with REJECT:

```bash
sudo iptables -D INPUT -p tcp --dport 9999 -j DROP
sudo iptables -A INPUT -p tcp --dport 9999 -j REJECT
```

#### Step 4: Test again

```bash
nc -zv localhost 9999
```

**Expected result:**

```
nc: connect to localhost port 9999 (tcp) failed: Connection refused
```

**Notice the difference:**

- **DROP** = Timeout (slow)
- **REJECT** = Connection refused (immediate)

**Your task:**

1. Test with DROP and note the timeout
2. Test with REJECT and note the immediate error
3. Understand the difference

---

### Part 4: Delete the Test Rule (5 minutes)

**Important:** Always clean up test rules!

**Method 1: Delete by specification**

```bash
sudo iptables -D INPUT -p tcp --dport 9999 -j REJECT
```

**Method 2: Delete by line number**

First, list rules with line numbers:

```bash
sudo iptables -L INPUT --line-numbers
```

Output:

```
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    REJECT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:9999 reject-with icmp-port-unreachable
```

Then delete by number:

```bash
sudo iptables -D INPUT 1
```

**Your task:**

1. Delete the rule using Method 1 or Method 2
2. Verify it's gone: `sudo iptables -L INPUT -n`
3. Test that port 9999 works again: `nc -zv localhost 9999`

---

### Part 5: OpenShift iptables Rules (15 minutes)

In OpenShift, iptables is heavily used. Let's see how.

**Run this command (if on an OpenShift node):**

```bash
sudo iptables -L -n -v | head -50
```

**You will see chains like:**

- `KUBE-SERVICES`
- `KUBE-FIREWALL`
- `KUBE-FORWARD`
- `OPENSHIFT-FIREWALL-FORWARD`

These are **custom chains** created by Kubernetes/OpenShift.

**Example OpenShift rule:**

```bash
-A KUBE-SERVICES -d 172.30.0.5/32 -p tcp -m tcp --dport 80 -j KUBE-SVC-ABCD1234
```

**Translation:**

- Chain: KUBE-SERVICES
- Destination: 172.30.0.5 (service IP)
- Protocol: TCP
- Port: 80
- Action: Jump to another chain (KUBE-SVC-ABCD1234) for load balancing

**Your task (if you have access to an OpenShift node):**

1. Run `sudo iptables -L -n | grep KUBE`
2. Find a rule for a service IP (172.30.x.x)
3. Note the chain name

**If you don't have access, just understand the concept:**

OpenShift uses iptables to implement:
- Service load balancing (DNAT to pod IPs)
- NetworkPolicies (block/allow pod traffic)
- NAT for outbound internet access

---

## Common iptables Use Cases

| Use Case | Command |
|----------|---------|
| Allow SSH (port 22) | `iptables -A INPUT -p tcp --dport 22 -j ACCEPT` |
| Block SSH from internet | `iptables -A INPUT -p tcp --dport 22 -s 0.0.0.0/0 -j DROP` |
| Allow SSH only from local network | `iptables -A INPUT -p tcp --dport 22 -s 192.168.1.0/24 -j ACCEPT` |
| Block outbound HTTP | `iptables -A OUTPUT -p tcp --dport 80 -j DROP` |
| Allow all from localhost | `iptables -A INPUT -i lo -j ACCEPT` |
| Drop all other traffic | `iptables -P INPUT DROP` (set default policy) |

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What are the three main iptables tables?
2. What are the three chains in the filter table?
3. What is the difference between DROP and REJECT?
4. What does `-A INPUT` mean?
5. What does `-p tcp --dport 22` mean?
6. How do you delete an iptables rule?

**Answers:**

1. filter, nat, mangle
2. INPUT, OUTPUT, FORWARD
3. DROP = silent discard (timeout). REJECT = discard with error (connection refused)
4. Append to the INPUT chain
5. Protocol TCP, destination port 22
6. `iptables -D <chain> <rule>` or `iptables -D <chain> <line-number>`

---

## Today I Learned (TIL) — Write This Down

Example:

```
March 16, 2026 — Day 8: iptables

- iptables = Linux firewall (filter table for allow/block, nat table for NAT)
- Three chains: INPUT (incoming), OUTPUT (outgoing), FORWARD (routing through)
- Three actions: ACCEPT (allow), DROP (silent discard), REJECT (discard with error)
- DROP = timeout, REJECT = immediate connection refused
- Add rule: iptables -A INPUT -p tcp --dport 9999 -j DROP
- Delete rule: iptables -D INPUT -p tcp --dport 9999 -j DROP
- OpenShift uses iptables for services, NetworkPolicies, and NAT
```

---

## Commands Cheat Sheet

```bash
# List all rules (filter table)
sudo iptables -L -n -v

# List rules with line numbers
sudo iptables -L INPUT --line-numbers

# Add rule to block port 9999
sudo iptables -A INPUT -p tcp --dport 9999 -j DROP

# Delete rule by specification
sudo iptables -D INPUT -p tcp --dport 9999 -j DROP

# Delete rule by line number
sudo iptables -D INPUT 1

# Test if port is open
nc -zv localhost 9999

# Flush all rules (CAREFUL!)
sudo iptables -F

# Set default policy to DROP (CAREFUL!)
sudo iptables -P INPUT DROP

# Save rules (RHEL/Fedora)
sudo iptables-save > /etc/sysconfig/iptables

# Restore rules
sudo iptables-restore < /etc/sysconfig/iptables
```

---

## What's Next?

**Tomorrow (Day 9):** Common Protocols — SSH, HTTP, HTTPS, SMTP, FTP

**Practice tonight:**
- Add a test rule to block port 8888
- Test with `nc`
- Delete the rule

---

**End of Day 8 Lab**

Good job. Tomorrow we learn common protocols and their port numbers.
