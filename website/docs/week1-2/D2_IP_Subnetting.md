# Day 2: IP Addresses & Subnetting

**Date:** Tuesday, March 10, 2026  
**Phase:** 1 - Core Networking Fundamentals  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Understand what an IP address is and how it works
- Calculate how many addresses are in a given network using CIDR notation
- Find your machine's IP address and understand what it means
- Explain why OpenShift reserves specific IP ranges

---

## Plain English: What Is an IP Address?

Every device on a network has an IP address — like a home address. Without it, nobody knows where to deliver the message.

When you open a website, your computer sends a message to another computer's IP address, which sends back the website.

In OpenShift:
- Every **pod** gets an IP address
- Every **service** gets an IP address
- Every **node** has an IP address

If you cannot reach something, the first question is: **what is its IP address, and can I reach it?**

---

## IPv4 Address — Four Numbers Separated by Dots

An IP address looks like this: `192.168.1.100`

It is actually **four numbers** separated by dots, where each number is between **0 and 255**.

Why 255? Because each number is **8 bits** (1 byte), and 8 bits can represent 256 values (0-255).

**Total:** 4 bytes = 32 bits

So an IP address is a **32-bit number** that humans read as four decimal numbers.

Example:
```
192.168.1.100
↓
11000000.10101000.00000001.01100100  (in binary)
```

You do not need to memorize binary. You just need to know:
- **IP address = 32 bits**
- **Each number = 8 bits (0-255)**

---

## CIDR Notation — How Many Addresses Are in the Network?

When you see `/24` after an IP address, that is **CIDR notation**. It tells you **HOW MANY** addresses are in the network.

Example: `10.128.0.0/14`

The `/14` tells you: **14 bits are used for the network, 18 bits are left for hosts**

Why? Because 32 total bits - 14 network bits = **18 host bits**

**Formula:**
- Number of addresses = 2^(number of host bits)
- `/14` → 32 - 14 = 18 host bits → 2^18 = **262,144 addresses**

### Common CIDR Examples:

| CIDR | Host Bits | Number of Addresses | Example Use |
|------|-----------|---------------------|-------------|
| /24 | 8 | 256 | Small network (home, office) |
| /16 | 16 | 65,536 | Medium network |
| /14 | 18 | 262,144 | OpenShift Pod IP range (10.128.0.0/14) |
| /8 | 24 | 16,777,216 | Huge network |

---

## Private IP Ranges (Memorize These)

Not all IP addresses appear on the public internet. Some ranges are **private** — they never leave your local network.

**The 3 Private IP Ranges:**

1. `10.0.0.0/8` → 10.0.0.0 to 10.255.255.255 (16 million addresses)
2. `172.16.0.0/12` → 172.16.0.0 to 172.31.255.255 (1 million addresses)
3. `192.168.0.0/16` → 192.168.0.0 to 192.168.255.255 (65,536 addresses)

**Why it matters for OCP:**

OpenShift reserves specific IP ranges:
- **Pod IPs:** 10.128.0.0/14 (262,144 addresses for pods)
- **Service IPs:** 172.30.0.0/16 (65,536 addresses for services)

You will see these **in every OCP cluster**. Now you know what they mean.

---

## Hands-On Lab

### Part 1: Find Your IP Address (10 minutes)

Run this command on your Linux machine:

```bash
ip addr show
```

**Expected output:**

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
```

**Your task:**

1. Identify your **main network interface** (usually `eth0`, `ens3`, or `enp0s3`)
2. Find its **IP address** (the number after `inet`)
3. Note the **CIDR notation** (e.g., `/16`)
4. Calculate: **How many addresses are in this network?**

**Example Answer:**

- Interface: `eth0`
- IP: `172.17.0.2`
- CIDR: `/16`
- Calculation: 32 - 16 = 16 host bits → 2^16 = **65,536 addresses**

---

### Part 2: Calculate CIDR Ranges (15 minutes)

Answer these questions using the CIDR formula:

#### Question 1:
How many IP addresses are in `10.128.0.0/14`?

**Your work:**
- CIDR: `/14`
- Host bits: 32 - 14 = 18
- Addresses: 2^18 = ?

**Answer:** 262,144 addresses

---

#### Question 2:
How many IP addresses are in `192.168.1.0/24`?

**Your work:**
- CIDR: `/24`
- Host bits: 32 - 24 = 8
- Addresses: 2^8 = ?

**Answer:** 256 addresses

---

#### Question 3:
You have a network `172.30.0.0/16`. How many services can you create in OpenShift (assuming each service gets one IP)?

**Your work:**
- CIDR: `/16`
- Host bits: 32 - 16 = 16
- Addresses: 2^16 = ?

**Answer:** 65,536 services (this is the OpenShift Service IP range)

---

### Part 3: Verify Your Understanding (10 minutes)

Run this command:

```bash
ip route show
```

**Expected output:**

```
default via 172.17.0.1 dev eth0
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.2
```

**Your task:**

1. Find the line with your network interface (e.g., `eth0`)
2. Note the network range (e.g., `172.17.0.0/16`)
3. Calculate how many devices can be on this network

**Answer:**
- Network: `172.17.0.0/16`
- Host bits: 16
- Total addresses: 2^16 = **65,536 devices**

---

### Part 4: OpenShift IP Ranges (10 minutes)

In OpenShift, these IP ranges are **always reserved**:

**Pod IPs:** `10.128.0.0/14`  
**Service IPs:** `172.30.0.0/16`

**Your task:**

1. Calculate how many pods can exist in a cluster
2. Calculate how many services can exist in a cluster

**Answers:**

1. **Pods:** 10.128.0.0/14 → 32 - 14 = 18 host bits → 2^18 = **262,144 pods**
2. **Services:** 172.30.0.0/16 → 32 - 16 = 16 host bits → 2^16 = **65,536 services**

Now you know the hard limits of an OpenShift cluster!

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What is an IPv4 address made of?
2. What does `/24` mean in CIDR notation?
3. How many addresses are in a `/16` network?
4. What are the 3 private IP ranges?
5. What IP range does OpenShift use for Pod IPs?

**Answers:**

1. Four 8-bit numbers (0-255), total 32 bits
2. 24 bits for network, 8 bits for hosts → 256 addresses
3. 32 - 16 = 16 host bits → 2^16 = 65,536 addresses
4. 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
5. 10.128.0.0/14

---

## Today I Learned (TIL) — Write This Down

In your notebook, write 5 bullet points:

Example:

```
March 10, 2026 — Day 2: IP Addresses & Subnetting

- An IP address is a 32-bit number written as four numbers (0-255) separated by dots
- CIDR notation /24 means 256 addresses, /16 means 65,536 addresses
- Formula: 2^(32 - CIDR number) = total addresses
- OpenShift uses 10.128.0.0/14 for pods (262,144 IPs) and 172.30.0.0/16 for services (65,536 IPs)
- Private IP ranges never appear on the public internet
```

---

## CIDR Quick Reference

**Powers of 2 (memorize these):**

```
2^8  = 256
2^10 = 1,024
2^16 = 65,536
2^18 = 262,144
2^24 = 16,777,216
```

**Common CIDRs:**

```
/24 → 256 addresses
/23 → 512 addresses
/16 → 65,536 addresses
/14 → 262,144 addresses (OpenShift Pod IPs)
/8  → 16,777,216 addresses
```

---

## What's Next?

**Tomorrow (Day 3):** DNS — The Phone Book of the Internet

**Practice tonight:**
- Run `ip addr show` and calculate your network size
- Visit practicalnetworking.net and try the subnetting exercises

---

**End of Day 2 Lab**

Good job. Tomorrow we learn how names become IP addresses — DNS.
