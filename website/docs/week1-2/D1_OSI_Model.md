# Day 1: OSI Model — The Universal Language of Networking

**Date:** Monday, March 9, 2026  
**Phase:** 1 - Core Networking Fundamentals  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Explain what each OSI layer does with a real-world example
- Map a network request to the correct OSI layer
- Use the OSI model to troubleshoot network issues in OCP

---

## Plain English: What Is Networking?

A network is just computers talking to each other. That is it.

When you open a website, your computer sends a message to another computer far away, which sends back the website.

Everything in OpenShift networking — pods, services, routes — is just computers sending messages to each other.

Your job as a network troubleshooter is to figure out WHY a message is not getting through.

To do that, you need to understand HOW messages travel. That is what the OSI model teaches you.

---

## The OSI Model — The 7-Layer Framework

The OSI model is a 7-layer framework that describes **WHAT** happens at each step when a message travels across a network. Every networking engineer in the world uses it to communicate. When someone says "it's a Layer 3 issue" — you need to know what that means.

Think of this like learning the alphabet before learning to read. You **cannot skip it**.

---

## The 7 Layers — From Top to Bottom

| Layer | Name | Real World Example | OCP Relevance |
|-------|------|-------------------|---------------|
| **7** | **Application** | The actual website you see in your browser | DNS, HTTP, TLS — Routes and Ingress live here |
| **6** | **Presentation** | Encrypting your credit card number | TLS certificates on OCP Routes |
| **5** | **Session** | Keeping you logged in to a website | TCP connection state management |
| **4** | **Transport** | Post office sorting mail by recipient | TCP/UDP ports — iptables and OVN ACLs work here |
| **3** | **Network** | Street address on an envelope | IP addresses, routing tables — OVN logical routers |
| **2** | **Data Link** | Name on the front door of a house | MAC addresses, ARP, VLANs — OVS bridges work here |
| **1** | **Physical** | The actual road the post van drives on | Ethernet cables, NICs on your OCP nodes |

---

## Why It Matters for You

When a pod cannot reach a service in OCP, you ask: **Is this a DNS issue (Layer 7)? A routing issue (Layer 3)? A firewall rule (Layer 4)?**

The OSI model tells you **WHERE to look**.

---

## Hands-On Lab

### Part 1: Draw the OSI Model from Memory (10 minutes)

1. Close this document
2. On a blank piece of paper, draw the 7 layers from memory
3. Write one real-world example for each layer
4. Check your answer against the table above

**If you cannot do this — re-read the table and try again. This is foundational.**

---

### Part 2: Map a curl Request to Every Layer (20 minutes)

Run this command on your Linux machine:

```bash
curl -v http://my-service.mynamespace.svc.cluster.local
```

Now map EACH step of this request to the correct OSI layer:

#### Your Task:

Fill in the table below by mapping each step to its OSI layer:

| Step | What Happens | OSI Layer |
|------|--------------|-----------|
| 1 | User types the URL in the command | ? |
| 2 | Computer looks up the IP for 'my-service.mynamespace.svc.cluster.local' | ? |
| 3 | Computer checks routing table to find where to send the packet | ? |
| 4 | Computer opens a TCP connection on port 80 | ? |
| 5 | Computer sends an HTTP GET request | ? |
| 6 | The server's MAC address is found using ARP | ? |
| 7 | The packet is sent over the Ethernet cable | ? |

**Answers:**

1. Application (Layer 7)
2. Application (Layer 7 — DNS)
3. Network (Layer 3)
4. Transport (Layer 4)
5. Application (Layer 7 — HTTP)
6. Data Link (Layer 2)
7. Physical (Layer 1)

---

### Part 3: Real OCP Troubleshooting Scenario (15 minutes)

Read this support case:

> **Case:** "I can reach the service IP 172.30.0.5 directly, but I cannot reach it by name 'my-service.mynamespace.svc.cluster.local'"

**Your task:**

1. Which OSI layer is the problem?
2. What tool would you use to troubleshoot it?
3. What is the most likely root cause?

**Answer:**

1. **Layer 7 — Application layer (DNS)**
2. **Tool:** `dig` or `nslookup` to test DNS resolution
3. **Root cause:** DNS is broken. Maybe CoreDNS pods are down, or the DNS service is misconfigured

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What does Layer 3 (Network) handle?
2. What does Layer 4 (Transport) handle?
3. What does Layer 7 (Application) handle?
4. If a pod cannot reach a service by name, which layer is the problem?
5. If a pod cannot reach a service IP, which layer is the problem?

**Answers:**

1. IP addresses, routing
2. TCP/UDP ports, connections
3. HTTP, DNS, TLS — actual applications
4. Layer 7 (DNS issue)
5. Layer 3 or 4 (routing or firewall issue)

---

## Today I Learned (TIL) — Write This Down

In your notebook, write 5 bullet points:

- What did I learn today?
- What surprised me?
- What do I still not understand?

Example:

```
March 9, 2026 — Day 1: OSI Model

- The OSI model is a 7-layer framework that describes how messages travel across a network
- Layer 3 = IP addresses and routing
- Layer 4 = TCP/UDP ports and connections
- Layer 7 = DNS, HTTP, TLS
- When troubleshooting, I need to ask: which layer is the problem?
```

---

## What's Next?

**Tomorrow (Day 2):** IP Addresses & Subnetting — how to calculate network ranges

**Resources to review tonight:**
- CompTIA Network+ OSI Model section (redhat.udemy.com)
- Professor Messer Network+ Course on YouTube

---

## Quick Reference Card

**OSI Layer Cheat Sheet:**

```
L7 - Application  → DNS, HTTP, TLS
L6 - Presentation → Encryption, encoding
L5 - Session      → Connection state
L4 - Transport    → TCP/UDP ports
L3 - Network      → IP addresses, routing
L2 - Data Link    → MAC addresses, ARP, VLANs
L1 - Physical     → Cables, NICs
```

Save this. You will refer to it **every single day** for the next 8 weeks.

---

**End of Day 1 Lab**

Good job. Tomorrow we dive into IP addresses and subnetting.
