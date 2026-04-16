# Day 18: iptables NAT — How Kubernetes Services Really Work

**Date:** Thursday, April 2, 2026  
**Phase:** 2 - Linux & Container Networking  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Explain what NAT (Network Address Translation) is and why it is used
- Understand the iptables NAT table and how it rewrites packets
- Find and interpret DNAT rules used by Kubernetes Services
- Trace how a request to a ClusterIP gets rewritten to a pod IP
- Understand the difference between SNAT and DNAT

---

## Plain English: What Is NAT?

Imagine you send a letter to "The President, The White House".

That is not a real person's name — it is an **alias**. Somewhere, a secretary rewrites the envelope to say "Joe Biden, Oval Office, Room 2" and delivers it to the actual person.

When you get a reply, the secretary rewrites it back to "From: The President" so you never see the real internal name.

This is **Network Address Translation (NAT)** — rewriting the source or destination IP address in a packet.

**Why does this matter for OCP?**

When you create a Kubernetes Service with IP `172.30.0.5`, that IP does not actually exist on any interface. It is a **virtual IP**.

When a pod sends traffic to `172.30.0.5:80`, iptables **rewrites** the destination IP to a real pod IP like `10.128.0.50:8080`.

The pod thinks it is talking to `172.30.0.5`, but iptables secretly redirects it to the actual pod.

This is how ClusterIP Services work in Kubernetes.

---

## What Is NAT?

**NAT (Network Address Translation)** is a technique where the Linux kernel rewrites the source or destination IP address in a packet.

Two types:
- **SNAT (Source NAT):** Rewrite the source IP
- **DNAT (Destination NAT):** Rewrite the destination IP

**Example use cases:**
- **Home router:** Your internal devices use 192.168.1.x, but the router uses SNAT to rewrite them to your public IP when going to the internet
- **Kubernetes Services:** When you hit a ClusterIP, DNAT rewrites it to a pod IP
- **Docker port forwarding:** `docker run -p 8080:80` uses DNAT to forward port 8080 to port 80 inside the container

---

## How iptables Implements NAT

iptables has multiple **tables**:
- **filter table:** Allow or drop packets (default table)
- **nat table:** Rewrite IP addresses (SNAT, DNAT)
- **mangle table:** Modify packet headers

The **nat table** has three chains:
- **PREROUTING:** DNAT happens here (before routing decision)
- **POSTROUTING:** SNAT happens here (after routing decision)
- **OUTPUT:** For locally generated packets

**Key concept:**

When a packet arrives, iptables checks the nat table BEFORE the routing decision. This allows it to change the destination IP, which then affects where the packet gets routed.

---

## How Kubernetes Services Use DNAT

When you create a Service in Kubernetes:

1. Kubernetes assigns a ClusterIP (e.g., `172.30.0.5`)
2. kube-proxy (or OVN-Kubernetes) creates iptables rules
3. When a pod sends traffic to `172.30.0.5:80`, iptables rewrites it to a backend pod IP (e.g., `10.128.0.50:8080`)
4. The pod receives the traffic and sends a reply
5. iptables rewrites the source IP back to `172.30.0.5` so the client thinks the reply came from the Service

This is **transparent** to the application — it just sees the Service IP.

---

## Hands-On Lab

### Part 1: View the NAT Table (5 minutes)

```bash
# View the NAT table
sudo iptables -t nat -L -n -v
```

**Expected output:**

You will see three chains:
- PREROUTING
- INPUT
- OUTPUT
- POSTROUTING

**Question:** What does `-t nat` mean?

**Answer:** `-t nat` specifies the NAT table (instead of the default filter table).

---

### Part 2: Understand the Output (10 minutes)

The output shows chains and rules. Each rule has:
- **pkts:** Number of packets matched
- **bytes:** Number of bytes matched
- **target:** What to do (ACCEPT, DROP, SNAT, DNAT, MASQUERADE, etc.)
- **prot:** Protocol (tcp, udp, all)
- **source:** Source IP
- **destination:** Destination IP
- **Additional info:** Ports, interfaces, etc.

Look for rules with target **DNAT** or **MASQUERADE**.

**MASQUERADE** is a special type of SNAT that automatically uses the outgoing interface's IP.

---

### Part 3: Find Docker NAT Rules (If Docker Is Installed) (10 minutes)

If you have Docker installed, it creates NAT rules for port forwarding.

```bash
# Start an nginx container with port forwarding
sudo docker run -d -p 8080:80 --name test-nginx nginx

# Check the NAT table again
sudo iptables -t nat -L -n -v | grep 8080
```

**Expected output:**

You should see a DNAT rule like:

```
DNAT  tcp  --  0.0.0.0/0  0.0.0.0/0  tcp dpt:8080 to:172.17.0.2:80
```

**What does this mean?**

When traffic arrives on port 8080 (on any interface), iptables rewrites the destination to `172.17.0.2:80` (the container's IP and port).

This is how `docker run -p 8080:80` works.

---

### Part 4: Test the Port Forwarding (10 minutes)

```bash
# Test from the host
curl localhost:8080
```

**Expected output:**

You should see the nginx welcome page.

**What happened?**

1. Your curl sent a request to `127.0.0.1:8080`
2. iptables (DNAT rule) rewrote the destination to `172.17.0.2:80`
3. The packet was routed to the container
4. nginx responded
5. iptables rewrote the source IP back to `127.0.0.1:8080`
6. curl received the response

---

### Part 5: Trace the Packet Manually (15 minutes)

Let's trace exactly what happens:

```bash
# Get the container's IP
sudo docker inspect test-nginx | grep IPAddress
```

**Expected output:**

```
"IPAddress": "172.17.0.2"
```

Now look at the full iptables rule:

```bash
# Show the DOCKER chain in the NAT table
sudo iptables -t nat -L DOCKER -n -v
```

**Expected output:**

```
Chain DOCKER (2 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 RETURN     all  --  docker0 *       0.0.0.0/0            0.0.0.0/0
    1    60 DNAT       tcp  --  !docker0 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8080 to:172.17.0.2:80
```

**What does this mean?**

- **!docker0:** Match packets NOT coming from the docker0 interface
- **tcp dpt:8080:** Match TCP traffic destined for port 8080
- **to:172.17.0.2:80:** Rewrite destination to 172.17.0.2:80

This rule intercepts traffic to port 8080 and redirects it to the container.

---

### Part 6: View Connection Tracking (10 minutes)

iptables uses **conntrack** (connection tracking) to remember which packets belong to which connection.

```bash
# View active connections
sudo conntrack -L | grep 8080
```

**Expected output:**

```
tcp      6 85 TIME_WAIT src=127.0.0.1 dst=127.0.0.1 sport=52436 dport=8080 src=172.17.0.2 dst=127.0.0.1 sport=80 dport=52436 [ASSURED] mark=0 use=1
```

**What does this mean?**

- **Original packet:** src=127.0.0.1, dst=127.0.0.1:8080
- **After DNAT:** src=127.0.0.1, dst=172.17.0.2:80
- **Reply packet:** src=172.17.0.2:80, dst=127.0.0.1:52436
- **After reverse NAT:** src=127.0.0.1:8080, dst=127.0.0.1:52436

conntrack remembers the rewrite so it can reverse it for the reply.

---

### Part 7: Simulate Kubernetes Service NAT (15 minutes)

Let's manually create a DNAT rule like Kubernetes would.

First, stop the Docker container:

```bash
sudo docker stop test-nginx
sudo docker rm test-nginx
```

Now create a manual DNAT rule:

```bash
# Create a DNAT rule to redirect 10.0.0.100:80 to 127.0.0.1:80
sudo iptables -t nat -A OUTPUT -p tcp -d 10.0.0.100 --dport 80 -j DNAT --to-destination 127.0.0.1:80
```

Start a simple HTTP server:

```bash
# Start a simple HTTP server on port 80
sudo python3 -m http.server 80 &
```

Test the DNAT rule:

```bash
# Try to reach the fake IP 10.0.0.100
curl http://10.0.0.100
```

**Expected result:**

You should get a directory listing from the Python HTTP server.

**What happened?**

Even though 10.0.0.100 does not exist, iptables rewrote the destination to 127.0.0.1:80, so the request worked.

This is EXACTLY how Kubernetes ClusterIP Services work.

---

### Part 8: View the Rule You Created (10 minutes)

```bash
# View the OUTPUT chain in the NAT table
sudo iptables -t nat -L OUTPUT -n -v
```

**Expected output:**

You should see your DNAT rule:

```
DNAT  tcp  --  *  *  0.0.0.0/0  10.0.0.100  tcp dpt:80 to:127.0.0.1:80
```

This shows that packets destined for 10.0.0.100:80 get rewritten to 127.0.0.1:80.

---

### Part 9: Clean Up (5 minutes)

```bash
# Stop the Python HTTP server
sudo pkill -f "python3 -m http.server"

# Delete the DNAT rule
sudo iptables -t nat -D OUTPUT -p tcp -d 10.0.0.100 --dport 80 -j DNAT --to-destination 127.0.0.1:80

# Verify it is gone
sudo iptables -t nat -L OUTPUT -n -v
```

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What does NAT stand for?
2. What is the difference between SNAT and DNAT?
3. Which iptables table handles NAT?
4. How does a Kubernetes ClusterIP Service work?
5. What is conntrack used for?

**Answers:**

1. Network Address Translation
2. SNAT rewrites the source IP, DNAT rewrites the destination IP
3. The nat table
4. iptables DNAT rules rewrite the ClusterIP to a backend pod IP
5. conntrack remembers NAT rewrites so it can reverse them for reply packets

---

## Today I Learned (TIL) — Write This Down

In your notebook, write 5 bullet points:

- What did I learn today?
- What surprised me?
- What do I still not understand?

Example:

```
April 2, 2026 — Day 18: iptables NAT

- NAT rewrites IP addresses in packets (source or destination)
- DNAT rewrites the destination IP (used for Kubernetes Services)
- iptables nat table has PREROUTING, OUTPUT, and POSTROUTING chains
- Kubernetes ClusterIP is just a DNAT rule — the IP does not really exist
- conntrack remembers NAT rewrites so replies get rewritten back
```

---

## Commands Cheat Sheet

**iptables NAT Table:**

```bash
# View the NAT table
sudo iptables -t nat -L -n -v

# View a specific chain
sudo iptables -t nat -L <CHAIN> -n -v

# Common chains:
# PREROUTING   - DNAT for incoming packets
# POSTROUTING  - SNAT for outgoing packets
# OUTPUT       - DNAT for locally generated packets

# Add a DNAT rule
sudo iptables -t nat -A <CHAIN> -p tcp -d <DEST_IP> --dport <PORT> -j DNAT --to-destination <NEW_IP:NEW_PORT>

# Add an SNAT rule
sudo iptables -t nat -A POSTROUTING -s <SOURCE_IP> -j SNAT --to-source <NEW_IP>

# Delete a rule
sudo iptables -t nat -D <CHAIN> <rule-specification>

# View connection tracking
sudo conntrack -L

# Filter conntrack by port
sudo conntrack -L | grep <PORT>
```

**Example: Create a DNAT rule like Kubernetes:**

```bash
# Redirect traffic to fake Service IP 10.96.0.1:80 to real pod 10.244.0.5:8080
sudo iptables -t nat -A OUTPUT -p tcp -d 10.96.0.1 --dport 80 -j DNAT --to-destination 10.244.0.5:8080
```

---

## What's Next?

**Tomorrow (Day 19):** conntrack — Linux connection tracking in depth

**Why it matters:** You saw conntrack briefly today. Tomorrow you will dive deep into how Linux tracks connections, why stateful firewalls matter, and how to troubleshoot NAT issues.

---

**End of Day 18 Lab**

Excellent work. You just learned the secret behind Kubernetes Services. Tomorrow we go deeper into connection tracking.
