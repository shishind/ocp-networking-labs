# Day 3: DNS — The Phone Book of the Internet

**Date:** Wednesday, March 11, 2026  
**Phase:** 1 - Core Networking Fundamentals  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Explain what DNS does and why it is critical
- Trace a DNS resolution from root DNS to final answer
- Troubleshoot DNS issues in OpenShift
- Understand DNS record types (A, CNAME, SRV, TTL)

---

## Plain English: What Is DNS?

DNS translates a name (like `my-service.mynamespace.svc.cluster.local`) into an IP address.

Without DNS, you have to remember millions of IP numbers — impossible.

**In OpenShift, 90% of connectivity issues start with a DNS failure.** If CoreDNS breaks, EVERYTHING breaks.

---

## How DNS Works

When you type `google.com`, here is what happens:

1. Your computer asks a **DNS server**: "What is the IP for google.com?"
2. The DNS server looks it up and replies: "8.8.8.8"
3. Your computer connects to 8.8.8.8

Simple, right?

But **HOW** does the DNS server know the answer? That is what we will trace today.

---

## The DNS Hierarchy — Root → TLD → Authoritative

DNS works like a phone book with multiple levels:

1. **Root DNS** (`.`) → Knows where to find `.com`, `.net`, `.org`
2. **TLD DNS** (`.com`) → Knows where to find `google.com`
3. **Authoritative DNS** (`google.com`) → Knows the IP for `www.google.com`

Think of it like an address:
- Root DNS = "Which country?"
- TLD DNS = "Which city?"
- Authoritative DNS = "Which street?"

---

## DNS Record Types

| Type | What It Does | Example |
|------|--------------|---------|
| **A** | Name → IPv4 address | google.com → 8.8.8.8 |
| **AAAA** | Name → IPv6 address | google.com → 2001:4860:4860::8888 |
| **CNAME** | Name → another name (alias) | www.google.com → google.com |
| **SRV** | Service → hostname + port | Used by Kubernetes for service discovery |
| **TTL** | How long to cache the answer (seconds) | 300 = cache for 5 minutes |

**Why it matters for OCP:**

- **A records**: Map service names to ClusterIPs
- **SRV records**: Kubernetes uses these for headless services
- **TTL**: If you change a DNS record, old answers might be cached

---

## Hands-On Lab

### Part 1: Run a Simple DNS Lookup (5 minutes)

Run this command:

```bash
dig google.com
```

**Expected output:**

```
;; QUESTION SECTION:
;google.com.			IN	A

;; ANSWER SECTION:
google.com.		300	IN	A	142.250.185.46

;; Query time: 12 msec
;; SERVER: 8.8.8.8#53(8.8.8.8)
```

**Your task:**

1. Find the **IP address** returned
2. Find the **TTL** (how long this answer is cached)
3. Find the **DNS server** used (usually 8.8.8.8 or your router)

**Answers:**

1. IP: `142.250.185.46` (may vary)
2. TTL: `300` seconds (5 minutes)
3. Server: `8.8.8.8`

---

### Part 2: Trace DNS from Root to Answer (15 minutes)

Run this command:

```bash
dig +trace google.com
```

This shows EVERY step from root DNS to final answer.

**Expected output (simplified):**

```
.			518400	IN	NS	a.root-servers.net.
↓
com.			172800	IN	NS	a.gtld-servers.net.
↓
google.com.		172800	IN	NS	ns1.google.com.
↓
google.com.		300	IN	A	142.250.185.46
```

**Your task:**

1. Draw the DNS hierarchy on paper
2. Label each level: Root → TLD → Authoritative
3. Write down the final IP address

**What you should see:**

```
Root DNS (.)
  ↓ "Ask .com DNS"
TLD DNS (.com)
  ↓ "Ask google.com DNS"
Authoritative DNS (google.com)
  ↓ "The answer is 142.250.185.46"
```

---

### Part 3: Query a Specific DNS Server (10 minutes)

You can query ANY DNS server directly.

**OpenShift uses CoreDNS** inside the cluster. Let's simulate querying it.

Run this command to query Google's DNS directly:

```bash
dig @8.8.8.8 google.com
```

The `@8.8.8.8` means: "Ask this DNS server specifically"

**Your task:**

1. Query Google's DNS: `dig @8.8.8.8 google.com`
2. Query Cloudflare's DNS: `dig @1.1.1.1 google.com`
3. Compare the answers — are they the same?

**Answer:** Yes, they should return the same IP (but TTL might differ)

---

### Part 4: Simulate an OpenShift DNS Lookup (15 minutes)

In OpenShift, pods query **CoreDNS** for service names.

Let's simulate this on your Linux machine.

#### Step 1: Check your DNS server

```bash
cat /etc/resolv.conf
```

**Expected output:**

```
nameserver 8.8.8.8
nameserver 1.1.1.1
```

This tells you which DNS servers your machine uses.

#### Step 2: Query a fake service name

In OpenShift, a service name looks like:

```
my-service.mynamespace.svc.cluster.local
```

Let's see what happens when you query it:

```bash
dig my-service.mynamespace.svc.cluster.local
```

**Expected output:**

```
;; QUESTION SECTION:
;my-service.mynamespace.svc.cluster.local. IN A

;; ANSWER SECTION:
(empty — no such name exists)

;; SERVER: 8.8.8.8#53(8.8.8.8)
```

**Why did it fail?**

Because `cluster.local` is an **internal OpenShift domain**. Your public DNS server (8.8.8.8) does not know about it.

**In a real OCP cluster:**

Pods use **CoreDNS** (running at `172.30.0.10` typically) which DOES know about `cluster.local`.

---

### Part 5: Test DNS Resolution End-to-End (10 minutes)

Run these commands and note the result:

```bash
nslookup google.com
```

**Expected output:**

```
Server:		8.8.8.8
Address:	8.8.8.8#53

Non-authoritative answer:
Name:	google.com
Address: 142.250.185.46
```

**Your task:**

1. What DNS server did you use?
2. What IP was returned?
3. Try: `nslookup nonexistent-domain-12345.com` — what happens?

**Answers:**

1. Server: `8.8.8.8` (or your default DNS)
2. IP: `142.250.185.46` (may vary)
3. Error: `NXDOMAIN` — name does not exist

---

## OpenShift DNS — How It Works

In OpenShift:

1. Every pod has `/etc/resolv.conf` pointing to **CoreDNS** (e.g., `nameserver 172.30.0.10`)
2. CoreDNS runs inside the cluster in namespace `openshift-dns`
3. When a pod asks for `my-service.mynamespace.svc.cluster.local`, CoreDNS:
   - Looks up the Service
   - Returns its **ClusterIP**
   - The pod connects to that IP

**If CoreDNS breaks, EVERYTHING breaks.**

That is why 90% of OCP connectivity issues start with DNS.

---

## Common DNS Issues in OpenShift

| Symptom | OSI Layer | Likely Cause |
|---------|-----------|--------------|
| "Cannot resolve my-service" | Layer 7 (DNS) | CoreDNS pods are down |
| "Can reach by IP but not by name" | Layer 7 (DNS) | DNS service is misconfigured |
| "NXDOMAIN" | Layer 7 (DNS) | Service name is wrong or does not exist |
| "Timeout waiting for DNS" | Layer 7 (DNS) | NetworkPolicy is blocking port 53 |

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What does DNS do?
2. What are the 3 levels of DNS hierarchy?
3. What is an A record?
4. What is a CNAME record?
5. In OpenShift, what DNS server do pods use?
6. What happens if CoreDNS breaks?

**Answers:**

1. Translates names to IP addresses
2. Root DNS → TLD DNS → Authoritative DNS
3. Maps a name to an IPv4 address
4. Maps a name to another name (alias)
5. CoreDNS (running inside the cluster)
6. ALL pod-to-service communication breaks

---

## Today I Learned (TIL) — Write This Down

Example:

```
March 11, 2026 — Day 3: DNS

- DNS translates names to IP addresses
- DNS hierarchy: Root (.) → TLD (.com) → Authoritative (google.com)
- dig +trace shows every step from root to answer
- A record = name → IP, CNAME = name → name
- In OpenShift, pods use CoreDNS for all name resolution
- If CoreDNS breaks, nothing works
```

---

## DNS Commands Cheat Sheet

```bash
# Simple lookup
dig google.com

# Full trace from root
dig +trace google.com

# Query specific DNS server
dig @8.8.8.8 google.com

# Query specific record type
dig google.com A
dig google.com AAAA
dig google.com CNAME

# Reverse lookup (IP → name)
dig -x 8.8.8.8

# nslookup (older tool, same idea)
nslookup google.com
```

---

## What's Next?

**Tomorrow (Day 4):** TCP vs UDP — How Messages Are Actually Sent

**Practice tonight:**
- Run `dig +trace` on 5 different websites
- Draw the DNS hierarchy each time

---

**End of Day 3 Lab**

Good job. Tomorrow we learn how TCP and UDP differ — and why it matters for troubleshooting.
