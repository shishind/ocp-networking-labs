# Day 21: Weekend Scenario — "Docker Container Cannot Reach Internet"

**Date:** Sunday, April 5, 2026  
**Phase:** 2 - Linux & Container Networking  
**Time:** 2 hours (hands-on troubleshooting scenario)

---

## Scenario Overview

**Your role:** Junior OpenShift Network Engineer

**Problem reported:**

A developer reports: "I started a Docker container, but it cannot reach the internet. Ping to 8.8.8.8 fails, and curl to google.com also fails. Please help!"

**Your task:**

Use everything you learned this week to diagnose and fix the problem:
- Network namespaces (Day 15)
- veth pairs (Day 16)
- Linux bridges (Day 17)
- iptables NAT (Day 18)
- conntrack (Day 19)
- Docker networking (Day 20)

---

## Learning Objectives

By the end of this scenario, you will be able to:
- Systematically troubleshoot container networking issues
- Verify each component of the network path
- Use namespaces, ip commands, iptables, and conntrack for debugging
- Apply the OSI model to isolate the problem
- Document your findings in a professional way

---

## Setup: Create the Broken Environment

Run these commands to set up the broken scenario:

```bash
# Start a test container
sudo docker run -d --name broken-container nginx

# Get the container's PID
CONTAINER_PID=$(sudo docker inspect -f '{{.State.Pid}}' broken-container)

# Intentionally break the network (simulate the problem)
# We will delete the default route from the container
sudo nsenter -t $CONTAINER_PID -n ip route del default
```

**What did we break?**

We removed the default route from the container's namespace. The container no longer knows how to reach the internet.

---

## Part 1: Reproduce the Problem (10 minutes)

First, verify the problem exists.

```bash
# Try to ping from inside the container
sudo docker exec broken-container ping -c 3 8.8.8.8
```

**Expected output:**

```
ping: connect: Network is unreachable
```

The problem is confirmed. Now start troubleshooting.

---

## Part 2: Use the OSI Model to Plan Your Approach (5 minutes)

Before diving in, plan your approach using the OSI model:

| Layer | Question | Tool |
|-------|----------|------|
| L1 (Physical) | Is the interface up? | `ip link` |
| L2 (Data Link) | Is the veth pair connected? | `ip link`, `bridge fdb` |
| L3 (Network) | Does the container have an IP? Routes? | `ip addr`, `ip route` |
| L4 (Transport) | Are iptables blocking traffic? | `iptables -L` |
| L7 (Application) | Is DNS working? | `nslookup`, `dig` |

**Start at Layer 3** (most common networking issues are routing or IP problems).

---

## Part 3: Check the Container's Network Namespace (10 minutes)

```bash
# Get the container's PID
CONTAINER_PID=$(sudo docker inspect -f '{{.State.Pid}}' broken-container)
echo "Container PID: $CONTAINER_PID"

# Enter the namespace and check interfaces
sudo nsenter -t $CONTAINER_PID -n ip addr show
```

**Question 1:** Does the container have an IP address on eth0?

**Expected answer:** Yes — should have 172.17.0.x

**Question 2:** Is the interface UP?

**Expected answer:** Yes — should show `state UP`

So Layer 1 and Layer 2 are OK. The interface is up and has an IP.

---

## Part 4: Check the Routing Table (10 minutes)

```bash
# Check the container's routing table
sudo nsenter -t $CONTAINER_PID -n ip route show
```

**Expected output:**

```
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.2
```

**Question 3:** Do you see a default route?

**Expected answer:** NO — there is no `default via ...` entry.

**This is the problem!**

Without a default route, the container does not know where to send packets destined for the internet (like 8.8.8.8).

---

## Part 5: Verify What the Route Should Be (10 minutes)

Check what a working container's routing table looks like:

```bash
# Start a working container for comparison
sudo docker run -d --name working-container nginx

# Check its routing table
WORKING_PID=$(sudo docker inspect -f '{{.State.Pid}}' working-container)
sudo nsenter -t $WORKING_PID -n ip route show
```

**Expected output:**

```
default via 172.17.0.1 dev eth0
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.3
```

**Key difference:**

The working container has `default via 172.17.0.1 dev eth0`.

This tells the container: "For any destination you do not have a specific route for, send it to 172.17.0.1 (the docker0 bridge)."

---

## Part 6: Fix the Problem (10 minutes)

Add the missing default route:

```bash
# Add the default route back to the broken container
sudo nsenter -t $CONTAINER_PID -n ip route add default via 172.17.0.1
```

Verify it was added:

```bash
# Check the routing table again
sudo nsenter -t $CONTAINER_PID -n ip route show
```

**Expected output:**

```
default via 172.17.0.1 dev eth0
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.2
```

Perfect! The default route is back.

---

## Part 7: Test the Fix (10 minutes)

```bash
# Test ping from inside the container
sudo docker exec broken-container ping -c 3 8.8.8.8
```

**Expected output:**

```
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=117 time=10.5 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=117 time=10.3 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=117 time=10.4 ms
```

Success! The container can now reach the internet.

---

## Part 8: Trace the Full Packet Path (15 minutes)

Now that it works, trace the full packet path to understand HOW it works.

**Packet path for ping to 8.8.8.8:**

1. **Container:** Packet created, dest=8.8.8.8
2. **Routing decision:** Container checks routing table, finds `default via 172.17.0.1`
3. **Container eth0:** Packet sent to 172.17.0.1 via eth0
4. **veth pair:** Packet exits container's eth0, enters host's veth interface
5. **docker0 bridge:** veth forwards packet to docker0
6. **Host routing:** docker0 forwards to host's routing table
7. **iptables MASQUERADE:** Source IP rewritten from 172.17.0.2 to host's public IP
8. **Host eth0:** Packet leaves host via physical interface
9. **Internet:** Packet reaches 8.8.8.8
10. **Reply:** 8.8.8.8 sends reply back
11. **Host eth0:** Reply arrives
12. **conntrack:** Remembers the NAT rewrite, rewrites dest back to 172.17.0.2
13. **docker0 bridge:** Routes to container's veth
14. **veth pair:** Packet enters container's eth0
15. **Container:** Receives ICMP reply

Verify each step:

```bash
# 1. Container's routing table
sudo nsenter -t $CONTAINER_PID -n ip route show

# 2. docker0 IP
ip addr show docker0

# 3. iptables MASQUERADE rule
sudo iptables -t nat -L POSTROUTING -n -v | grep 172.17

# 4. conntrack entry
sudo nsenter -t $CONTAINER_PID -n ping -c 1 8.8.8.8 &
sudo conntrack -L | grep 8.8.8.8
```

---

## Part 9: Additional Troubleshooting Practice (20 minutes)

Let's create and fix additional problems.

### Problem A: Interface is Down

```bash
# Break it: bring down the container's eth0
sudo nsenter -t $CONTAINER_PID -n ip link set eth0 down

# Test
sudo docker exec broken-container ping -c 1 8.8.8.8
# Should fail

# Fix it
sudo nsenter -t $CONTAINER_PID -n ip link set eth0 up

# Test
sudo docker exec broken-container ping -c 1 8.8.8.8
# Should work
```

### Problem B: Wrong IP Address

```bash
# Break it: change the container's IP
sudo nsenter -t $CONTAINER_PID -n ip addr del 172.17.0.2/16 dev eth0
sudo nsenter -t $CONTAINER_PID -n ip addr add 192.168.99.99/24 dev eth0

# Test
sudo docker exec broken-container ping -c 1 8.8.8.8
# Should fail (wrong subnet)

# Fix it
sudo nsenter -t $CONTAINER_PID -n ip addr del 192.168.99.99/24 dev eth0
sudo nsenter -t $CONTAINER_PID -n ip addr add 172.17.0.2/16 dev eth0

# Test
sudo docker exec broken-container ping -c 1 8.8.8.8
# Should work
```

### Problem C: iptables Blocking Traffic

```bash
# Break it: drop all traffic from the container
sudo iptables -I FORWARD -s 172.17.0.2 -j DROP

# Test
sudo docker exec broken-container ping -c 1 8.8.8.8
# Should fail (no reply)

# Fix it
sudo iptables -D FORWARD -s 172.17.0.2 -j DROP

# Test
sudo docker exec broken-container ping -c 1 8.8.8.8
# Should work
```

---

## Part 10: Document Your Findings (10 minutes)

As a professional troubleshooter, you need to document your findings.

**Template:**

```
INCIDENT REPORT: Docker Container Network Connectivity Failure

DATE: April 5, 2026
REPORTED BY: Developer
INVESTIGATED BY: [Your Name]

PROBLEM:
Container "broken-container" could not reach the internet. 
Ping to 8.8.8.8 failed with "Network is unreachable".

ROOT CAUSE:
Missing default route in container's network namespace.
The container had no route to send traffic outside its local subnet.

INVESTIGATION STEPS:
1. Verified interface was UP and had IP (172.17.0.2/16) - OK
2. Checked routing table - MISSING default route
3. Compared with working container - confirmed default route should be "via 172.17.0.1"
4. Added missing route - problem resolved

RESOLUTION:
sudo nsenter -t <PID> -n ip route add default via 172.17.0.1

PREVENTIVE MEASURES:
- Investigate why the default route was missing
- Check if Docker daemon has issues
- Review container startup logs

VERIFICATION:
Ping to 8.8.8.8 now succeeds.
Curl to google.com works.
```

---

## Part 11: Clean Up (5 minutes)

```bash
# Stop and remove containers
sudo docker stop broken-container working-container
sudo docker rm broken-container working-container

# Verify
sudo docker ps -a
```

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What was the root cause of the problem?
2. Which OSI layer was the problem at?
3. What command did you use to check the routing table?
4. What is the purpose of the default route?
5. What tools did you use to troubleshoot?

**Answers:**

1. Missing default route in the container's network namespace
2. Layer 3 (Network layer — routing)
3. `sudo nsenter -t <PID> -n ip route show`
4. Tells the system where to send traffic when there is no specific route
5. ip addr, ip route, nsenter, docker inspect, iptables, conntrack

---

## Today I Learned (TIL) — Write This Down

In your notebook, write 5 bullet points:

- What did I learn today?
- What surprised me?
- What do I still not understand?

Example:

```
April 5, 2026 — Day 21: Docker Troubleshooting Scenario

- A missing default route causes "Network is unreachable" errors
- Always start troubleshooting at Layer 3 (IP and routing)
- nsenter lets me debug inside a container's namespace
- Comparing a working vs broken container helps isolate the problem
- Documenting findings is critical for professional troubleshooting
```

---

## Troubleshooting Cheat Sheet

**Systematic Container Network Troubleshooting:**

```bash
# Step 1: Get container PID
CONTAINER_PID=$(sudo docker inspect -f '{{.State.Pid}}' <container>)

# Step 2: Check interfaces (Layer 1-2)
sudo nsenter -t $CONTAINER_PID -n ip link show
sudo nsenter -t $CONTAINER_PID -n ip addr show

# Step 3: Check routing (Layer 3)
sudo nsenter -t $CONTAINER_PID -n ip route show

# Step 4: Check connectivity
sudo nsenter -t $CONTAINER_PID -n ping -c 3 <IP>

# Step 5: Check iptables
sudo iptables -L -n -v
sudo iptables -t nat -L -n -v

# Step 6: Check conntrack
sudo conntrack -L | grep <container-ip>

# Step 7: Check docker0 bridge
ip addr show docker0
ip link show master docker0
```

**Common Problems and Fixes:**

| Problem | Symptom | Fix |
|---------|---------|-----|
| Interface down | No connectivity | `ip link set eth0 up` |
| No IP address | `ip addr` shows no inet | `ip addr add <IP>/<mask> dev eth0` |
| No default route | "Network unreachable" | `ip route add default via <gateway>` |
| iptables blocking | Packets sent but no reply | Check `iptables -L -n -v` |
| Wrong subnet | Cannot reach gateway | Assign correct IP in docker0 subnet |

---

## What's Next?

**Week 4 starts tomorrow!**

**Tomorrow (Day 22):** Linux Bonding — why nodes need it, how to configure

**Why it matters:** OCP nodes use bonding for high availability and redundancy. You will learn how to configure bonded interfaces and troubleshoot failover.

---

**End of Week 3**

Congratulations! You completed Week 3. You now understand:
- Network namespaces
- veth pairs
- Linux bridges
- iptables NAT
- conntrack
- Docker networking

Next week you will learn about node-level networking (bonding, NMState) and advanced packet capture with tcpdump.

Take a break. You earned it.
