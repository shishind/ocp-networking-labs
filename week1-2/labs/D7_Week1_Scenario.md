# Day 7: Weekend Scenario — "I can ping 8.8.8.8 but cannot reach my-service by name"

**Date:** Sunday, March 15, 2026  
**Phase:** 1 - Core Networking Fundamentals (Week 1 Review)  
**Time:** 2 hours (troubleshooting scenario)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Apply Week 1 knowledge to a real troubleshooting scenario
- Use the OSI model to identify the problem layer
- Systematically troubleshoot DNS issues
- Document your troubleshooting steps
- Explain the root cause to a non-technical person

---

## The Scenario

**Support Ticket #12345:**

> Subject: Cannot reach my-service by name  
> Priority: High  
> From: Developer Team
>
> We have a pod running in our OpenShift cluster. We can ping 8.8.8.8 successfully, but when we try to reach `my-service.mynamespace.svc.cluster.local`, we get a timeout.
>
> Please investigate and resolve.

**Additional Information:**
- Cluster: OCP 4.14
- Namespace: `mynamespace`
- Service name: `my-service`
- Pod IP: 10.128.1.50
- Service IP: 172.30.0.5

---

## Your Mission

You are the network troubleshooting engineer. Using ONLY the Week 1 skills you learned, you need to:

1. **Identify the problem layer** using the OSI model
2. **Determine the root cause**
3. **Explain why ping works but service name does not**
4. **Suggest a fix**

---

## Part 1: Analyze the Symptom (15 minutes)

Before you touch any commands, think through this logically.

**Given:**
- `ping 8.8.8.8` **works** ✓
- `curl my-service.mynamespace.svc.cluster.local` **fails** ✗

**Your task:**

Answer these questions on paper:

1. What OSI layer does `ping` test?
2. What OSI layer does `curl <name>` test?
3. If ping works, does that mean routing works?
4. If ping works, does that mean DNS works?
5. What is the most likely problem?

---

**Answers:**

1. Ping tests **Layer 3 (Network)** — IP connectivity
2. Curl with a name tests **Layer 7 (Application)** — HTTP and DNS
3. Yes, if ping works, routing works (Layer 3 is OK)
4. No, ping uses IP addresses, not names. DNS might be broken.
5. Most likely problem: **DNS is broken** (cannot resolve the service name)

---

## Part 2: Map to the OSI Model (10 minutes)

Fill in this table:

| Test | Works? | OSI Layer | What It Tests |
|------|--------|-----------|---------------|
| Ping 8.8.8.8 | ✓ Yes | Layer 3 | IP routing, gateway, internet connectivity |
| Ping 172.30.0.5 (service IP) | ? | Layer 3 | Can I reach the service by IP? |
| DNS lookup for my-service | ? | Layer 7 | Can DNS resolve the name to IP? |
| Curl http://my-service (by name) | ✗ No | Layer 7 | HTTP + DNS |

**Your task:**

Predict: Will `ping 172.30.0.5` work? Why or why not?

**Answer:**

If DNS is the problem, `ping 172.30.0.5` **should work** because it uses the IP directly (no DNS needed).

---

## Part 3: Hands-On Troubleshooting (60 minutes)

Now let's troubleshoot systematically. Follow these steps IN ORDER.

---

### Step 1: Test IP Connectivity to the Service (5 minutes)

Run this command:

```bash
ping -c 4 172.30.0.5
```

**Expected result:**

- **If it works:** Problem is NOT Layer 3 (routing is fine). Problem is likely DNS.
- **If it fails:** Problem IS Layer 3 (routing or firewall issue).

**Record your result:**

```
Step 1 Result:
[ ] Success — Service IP is reachable
[ ] Fail — Service IP is NOT reachable
```

---

### Step 2: Test DNS Resolution (10 minutes)

Run this command:

```bash
nslookup my-service.mynamespace.svc.cluster.local
```

**Expected output (if DNS works):**

```
Server:    172.30.0.10
Address:   172.30.0.10#53

Name:   my-service.mynamespace.svc.cluster.local
Address: 172.30.0.5
```

**Expected output (if DNS is broken):**

```
;; connection timed out; no servers could be reached
```

OR

```
** server can't find my-service.mynamespace.svc.cluster.local: NXDOMAIN
```

**Your task:**

1. Run `nslookup my-service.mynamespace.svc.cluster.local`
2. Record the result
3. If it fails, note the error message

**Record your result:**

```
Step 2 Result:
[ ] Success — DNS resolved to 172.30.0.5
[ ] Fail — DNS timeout or NXDOMAIN
```

---

### Step 3: Check DNS Server Configuration (10 minutes)

Run this command:

```bash
cat /etc/resolv.conf
```

**Expected output:**

```
nameserver 172.30.0.10
search mynamespace.svc.cluster.local svc.cluster.local cluster.local
```

**What it means:**

- `nameserver 172.30.0.10` = DNS server IP (should be the CoreDNS service)
- `search ...` = DNS search domains (allows short names like `my-service`)

**Your task:**

1. Check if `nameserver` is set
2. Check if the DNS server IP is correct (should be in the 172.30.0.0/16 range)
3. Ping the DNS server: `ping -c 4 172.30.0.10`

**Record your result:**

```
Step 3 Result:
[ ] /etc/resolv.conf is correct
[ ] /etc/resolv.conf is missing or wrong
[ ] DNS server (172.30.0.10) is reachable
[ ] DNS server (172.30.0.10) is NOT reachable
```

---

### Step 4: Test DNS with dig (10 minutes)

Run this command:

```bash
dig my-service.mynamespace.svc.cluster.local
```

**Expected output (if DNS works):**

```
;; ANSWER SECTION:
my-service.mynamespace.svc.cluster.local. 30 IN A 172.30.0.5
```

**Expected output (if DNS is broken):**

```
;; connection timed out; no servers could be reached
```

**Your task:**

1. Run `dig my-service.mynamespace.svc.cluster.local`
2. Check the ANSWER SECTION
3. If it fails, check if the DNS server is responding: `dig @172.30.0.10 google.com`

**Record your result:**

```
Step 4 Result:
[ ] dig resolved to 172.30.0.5
[ ] dig failed — DNS server is down
[ ] dig @172.30.0.10 google.com works — DNS server is alive but my-service is missing
```

---

### Step 5: Check CoreDNS Pods (10 minutes)

In OpenShift, DNS is handled by **CoreDNS** pods in the `openshift-dns` namespace.

Run this command:

```bash
oc get pods -n openshift-dns
```

**Expected output:**

```
NAME                    READY   STATUS    RESTARTS   AGE
dns-default-abcd1       2/2     Running   0          10d
dns-default-abcd2       2/2     Running   0          10d
```

**Your task:**

1. Check if CoreDNS pods are **Running**
2. Check if they are **Ready** (should be 2/2)
3. If any are not running, check the logs: `oc logs -n openshift-dns dns-default-abcd1`

**Record your result:**

```
Step 5 Result:
[ ] All CoreDNS pods are Running and Ready
[ ] CoreDNS pods are down or failing
```

---

### Step 6: Check if the Service Exists (5 minutes)

Maybe the service doesn't exist at all!

Run this command:

```bash
oc get svc -n mynamespace
```

**Expected output:**

```
NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
my-service   ClusterIP   172.30.0.5    <none>        80/TCP    5d
```

**Your task:**

1. Check if `my-service` exists
2. Check if the CLUSTER-IP matches the IP you are trying to reach
3. If the service does NOT exist, the problem is obvious

**Record your result:**

```
Step 6 Result:
[ ] Service exists — IP is 172.30.0.5
[ ] Service does NOT exist — that's the problem!
```

---

### Step 7: Test Direct Access to Service IP (5 minutes)

Let's bypass DNS and test the service directly by IP.

Run this command:

```bash
curl -I http://172.30.0.5
```

**Expected output (if service works):**

```
HTTP/1.1 200 OK
```

**Expected output (if service is down):**

```
curl: (7) Failed to connect to 172.30.0.5 port 80: Connection refused
```

**Your task:**

1. Test direct access to the service IP
2. If it works, the service is fine — problem is DNS
3. If it fails, the service is down — problem is the service, not DNS

**Record your result:**

```
Step 7 Result:
[ ] Service works — curl http://172.30.0.5 succeeded
[ ] Service is down — connection refused or timeout
```

---

## Part 4: Root Cause Analysis (15 minutes)

Based on your troubleshooting steps, fill in this table:

| Test | Result | What It Tells You |
|------|--------|-------------------|
| Ping 8.8.8.8 | Works | Internet connectivity is OK |
| Ping 172.30.0.5 | ? | Can I reach the service by IP? |
| nslookup my-service... | ? | Does DNS work? |
| /etc/resolv.conf | ? | Is DNS server configured? |
| dig my-service... | ? | Can DNS resolve the name? |
| CoreDNS pods | ? | Is CoreDNS running? |
| Service exists | ? | Does the service exist in the cluster? |
| curl http://172.30.0.5 | ? | Does the service respond? |

---

**Now answer:**

1. What is the root cause?
2. Which OSI layer is the problem?
3. Why does `ping 8.8.8.8` work but `curl my-service` does not?

**Example answers:**

**Scenario A: DNS is broken**

1. Root cause: CoreDNS pods are down or DNS server is unreachable
2. OSI Layer: Layer 7 (Application — DNS)
3. Why: Ping uses IP addresses (Layer 3), curl uses names (Layer 7 DNS)

**Scenario B: Service does not exist**

1. Root cause: The service `my-service` was never created
2. OSI Layer: Layer 7 (Application)
3. Why: Ping 8.8.8.8 works (internet is fine), but the service name cannot resolve because it doesn't exist

**Scenario C: /etc/resolv.conf is wrong**

1. Root cause: /etc/resolv.conf is missing or points to the wrong DNS server
2. OSI Layer: Layer 7 (Application — DNS configuration)
3. Why: Ping uses routing (Layer 3), curl uses DNS (Layer 7). DNS config is broken.

---

## Part 5: Explain to a Non-Technical Person (10 minutes)

Imagine you need to explain this to a developer who doesn't know networking.

Write a 3-sentence explanation:

**Example:**

> The issue is that DNS (the system that translates names to IP addresses) is not working. When you ping 8.8.8.8, you are using the IP directly, so it works. When you use the service name, your computer asks DNS for the IP, but DNS is not responding, so it fails.

**Your task:**

Write your own 3-sentence explanation based on your findings.

---

## Part 6: Suggest a Fix (10 minutes)

Based on the root cause, suggest a fix.

**Example fixes:**

| Root Cause | Fix |
|------------|-----|
| CoreDNS pods are down | Restart CoreDNS: `oc delete pod -n openshift-dns --all` (they will restart) |
| /etc/resolv.conf is missing nameserver | Edit /etc/resolv.conf and add `nameserver 172.30.0.10` |
| Service does not exist | Create the service: `oc expose deployment my-app --port=80` |
| DNS server is unreachable | Check network policy, check if DNS service (172.30.0.10) is up |

**Your task:**

Write the fix command(s) for your scenario.

---

## Part 7: Document Your Troubleshooting (20 minutes)

Good engineers document their work. Fill out this troubleshooting log:

```
Troubleshooting Log — Support Ticket #12345
Date: March 15, 2026
Engineer: [Your Name]

Symptom:
- Can ping 8.8.8.8
- Cannot reach my-service.mynamespace.svc.cluster.local by name

Steps Taken:
1. Tested ping 8.8.8.8 — Success (Layer 3 works)
2. Tested ping 172.30.0.5 — [Result]
3. Tested nslookup my-service... — [Result]
4. Checked /etc/resolv.conf — [Result]
5. Tested dig my-service... — [Result]
6. Checked CoreDNS pods — [Result]
7. Checked if service exists — [Result]
8. Tested curl http://172.30.0.5 — [Result]

Root Cause:
[Write your root cause here]

OSI Layer:
[Which layer had the problem?]

Fix Applied:
[Write the fix here]

Verification:
[How did you verify the fix worked?]

Lessons Learned:
[What did you learn from this?]
```

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. If ping works but curl by name fails, which layer is the problem?
2. What does /etc/resolv.conf control?
3. What is the default DNS service IP in OpenShift?
4. What namespace are CoreDNS pods in?
5. What command tests DNS resolution?
6. What is the difference between `ping 8.8.8.8` and `ping my-service`?

**Answers:**

1. Layer 7 (DNS issue)
2. /etc/resolv.conf controls which DNS server to use
3. 172.30.0.10 (or similar, in the 172.30.0.0/16 range)
4. openshift-dns
5. `nslookup`, `dig`, or `host`
6. `ping 8.8.8.8` uses IP (Layer 3). `ping my-service` requires DNS to resolve the name first (Layer 7)

---

## Today I Learned (TIL) — Write This Down

Example:

```
March 15, 2026 — Day 7: Weekend Scenario

- If ping works but curl by name fails, DNS is the problem (Layer 7)
- Always check /etc/resolv.conf to see which DNS server is configured
- CoreDNS pods live in openshift-dns namespace
- Use nslookup or dig to test DNS resolution
- Troubleshooting is systematic: test each layer starting from Layer 1 up
- Document everything — future you will thank you
```

---

## Commands Cheat Sheet

```bash
# Test IP connectivity
ping -c 4 <ip>

# Test DNS resolution
nslookup <hostname>
dig <hostname>

# Check DNS configuration
cat /etc/resolv.conf

# Check CoreDNS pods
oc get pods -n openshift-dns

# Check service exists
oc get svc -n <namespace>

# Test HTTP by IP (bypass DNS)
curl -I http://<service-ip>

# Check DNS server directly
dig @172.30.0.10 <hostname>

# Restart CoreDNS (if needed)
oc delete pod -n openshift-dns --all
```

---

## What's Next?

**Tomorrow (Day 8):** iptables — Linux Firewall Basics

**Week 1 Complete!** You now understand:
- OSI Model
- IP Addressing & Subnetting
- DNS
- TCP vs UDP
- Routing, Switching, ARP
- NAT
- Systematic Troubleshooting

Next week: iptables, protocols, VLANs, systemd, and more hands-on labs.

---

**End of Day 7 Lab**

Congratulations! You completed Week 1. Tomorrow you start Week 2 with iptables — Linux firewall rules.
