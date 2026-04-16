# Day 28: Week 4 Review — Consolidate Your Knowledge

**Date:** Sunday, April 12, 2026  
**Phase:** 2 - Linux & Container Networking  
**Time:** 2 hours (self-paced review and practice)

---

## Overview

Congratulations! You have completed Week 3 and Week 4 of the OCP Networking Mastery Plan.

This week you learned:
- **Week 3:** Network namespaces, veth pairs, bridges, iptables NAT, conntrack, Docker networking
- **Week 4:** Linux bonding, NMState, tcpdump (basic and advanced), nsenter, complete packet tracing

**Today is for consolidation.** No new concepts. Just review, practice, and fill knowledge gaps.

---

## Learning Objectives

By the end of today, you will have:
- Reviewed all challenging concepts from Week 3-4
- Re-done any labs you struggled with
- Tested yourself on key skills
- Identified knowledge gaps to revisit
- Prepared for Week 5 (Kubernetes Networking)

---

## Part 1: Self-Assessment Quiz (30 minutes)

Answer these questions WITHOUT looking at your notes. Check your answers afterward.

### Week 3 Questions

1. What is a network namespace?
2. How do you create a network namespace?
3. What is a veth pair?
4. How does a veth pair connect two namespaces?
5. What is a Linux bridge?
6. What OSI layer does a bridge operate at?
7. What does DNAT stand for and what does it do?
8. What is conntrack used for?
9. How does Docker connect containers to the host network?
10. What happens when you run `docker run -p 8080:80 nginx`?

### Week 4 Questions

11. What is NIC bonding?
12. What is the difference between active-backup and LACP bonding modes?
13. What is NMState?
14. What are NNCP, NNS, and NNCE?
15. What is tcpdump?
16. How do you capture only DNS traffic with tcpdump?
17. What does the TCP flag `[S]` mean?
18. What does the TCP flag `[R]` mean?
19. What is nsenter?
20. When should you use nsenter instead of `docker exec`?

---

## Part 2: Answer Key (Check Your Answers)

### Week 3 Answers

1. An isolated copy of the Linux network stack (interfaces, routes, iptables, etc.)
2. `sudo ip netns add <name>`
3. A pair of virtual network interfaces that act like a virtual Ethernet cable
4. One end goes in one namespace, the other end in another namespace; packets sent to one end come out the other end
5. A virtual Layer 2 switch in the Linux kernel
6. Layer 2 (Data Link)
7. Destination NAT — rewrites the destination IP address in a packet
8. To track network connections and remember NAT translations for reply packets
9. Creates a veth pair (one end in container, one end on host), attaches host end to docker0 bridge, uses iptables NAT for port forwarding and internet access
10. Docker creates iptables DNAT rule to forward port 8080 on the host to port 80 in the container

### Week 4 Answers

11. Combining multiple physical network interfaces into one logical interface for redundancy and/or performance
12. active-backup: one NIC active at a time (simple, works with any switch); LACP: multiple NICs active simultaneously (requires switch LACP support)
13. A Kubernetes operator for declarative node network configuration
14. NNCP = desired config policy, NNS = actual state per node, NNCE = status of applying policy per node
15. A command-line packet capture tool for Linux
16. `sudo tcpdump -i <interface> port 53`
17. SYN flag (start of TCP connection)
18. RST flag (connection reset/refused)
19. A tool to enter Linux namespaces and run commands inside them from the host
20. When the container does not have debugging tools installed

**Scoring:**
- 18-20 correct: Excellent! You mastered the material.
- 15-17 correct: Good! Review the questions you missed.
- 12-14 correct: Fair. Re-read the relevant labs.
- Below 12: Re-do the labs from this week.

---

## Part 3: Hands-On Challenge — Build a Multi-Container Network from Scratch (45 minutes)

**Goal:** Build a network with 3 containers connected via a bridge, without using Docker.

**Requirements:**
1. Create 3 network namespaces (red, green, blue)
2. Create a bridge (br0)
3. Connect all 3 namespaces to the bridge using veth pairs
4. Assign IP addresses (10.0.0.1/24, 10.0.0.2/24, 10.0.0.3/24)
5. Verify all namespaces can ping each other
6. Add NAT so all namespaces can reach the internet
7. Test internet connectivity from all namespaces

**Steps:**

```bash
# 1. Create namespaces
sudo ip netns add red
sudo ip netns add green
sudo ip netns add blue

# 2. Create bridge
sudo ip link add br0 type bridge
sudo ip link set br0 up
sudo ip addr add 10.0.0.254/24 dev br0

# 3. Create veth pairs and connect to bridge
# Red
sudo ip link add veth-red type veth peer name br-red
sudo ip link set br-red master br0
sudo ip link set br-red up
sudo ip link set veth-red netns red
sudo ip netns exec red ip addr add 10.0.0.1/24 dev veth-red
sudo ip netns exec red ip link set veth-red up
sudo ip netns exec red ip link set lo up
sudo ip netns exec red ip route add default via 10.0.0.254

# Green
sudo ip link add veth-green type veth peer name br-green
sudo ip link set br-green master br0
sudo ip link set br-green up
sudo ip link set veth-green netns green
sudo ip netns exec green ip addr add 10.0.0.2/24 dev veth-green
sudo ip netns exec green ip link set veth-green up
sudo ip netns exec green ip link set lo up
sudo ip netns exec green ip route add default via 10.0.0.254

# Blue
sudo ip link add veth-blue type veth peer name br-blue
sudo ip link set br-blue master br0
sudo ip link set br-blue up
sudo ip link set veth-blue netns blue
sudo ip netns exec blue ip addr add 10.0.0.3/24 dev veth-blue
sudo ip netns exec blue ip link set veth-blue up
sudo ip netns exec blue ip link set lo up
sudo ip netns exec blue ip route add default via 10.0.0.254

# 4. Test internal connectivity
sudo ip netns exec red ping -c 2 10.0.0.2
sudo ip netns exec red ping -c 2 10.0.0.3
sudo ip netns exec green ping -c 2 10.0.0.3

# 5. Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# 6. Add NAT for internet access
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 ! -o br0 -j MASQUERADE
sudo iptables -A FORWARD -i br0 -j ACCEPT
sudo iptables -A FORWARD -o br0 -j ACCEPT

# 7. Test internet connectivity
sudo ip netns exec red ping -c 2 8.8.8.8
sudo ip netns exec green ping -c 2 8.8.8.8
sudo ip netns exec blue ping -c 2 8.8.8.8

# 8. Cleanup
sudo ip netns delete red
sudo ip netns delete green
sudo ip netns delete blue
sudo ip link delete br0
sudo iptables -t nat -D POSTROUTING -s 10.0.0.0/24 ! -o br0 -j MASQUERADE
sudo iptables -D FORWARD -i br0 -j ACCEPT
sudo iptables -D FORWARD -o br0 -j ACCEPT
```

**If you completed this successfully, you REALLY understand container networking.**

---

## Part 4: Re-Do the Most Challenging Lab (30 minutes)

Look back at your notes and identify the lab you found most difficult this week.

**Common challenging labs:**
- Day 17: Linux Bridge (connecting multiple namespaces)
- Day 18: iptables NAT (understanding DNAT)
- Day 19: conntrack (connection tracking)
- Day 27: Container Network Trace (complete packet path)

**Re-do that lab from scratch** without looking at the instructions. Only look if you get stuck.

---

## Part 5: Practice tcpdump Filtering (15 minutes)

Run these tcpdump challenges:

**Challenge 1: Capture only SYN packets to port 443**

```bash
sudo tcpdump -i eth0 'tcp[13] & 2 != 0 and port 443' -n -c 5
```

Generate traffic:
```bash
curl https://google.com
```

**Challenge 2: Capture DNS queries (but not replies)**

```bash
sudo tcpdump -i eth0 'udp port 53 and udp[10] & 0x80 = 0' -n -c 5
```

**Challenge 3: Capture HTTP traffic, save to file, then read it back filtering for GET requests**

```bash
# Capture
sudo tcpdump -i eth0 port 80 -w http-test.pcap -c 50

# Generate traffic
curl http://neverssl.com

# Read back
sudo tcpdump -r http-test.pcap -A | grep "GET /"
```

---

## Part 6: Knowledge Gap Identification (10 minutes)

Answer honestly:

**Concepts I still don't fully understand:**
- (Write 1-3 concepts)

**Labs I struggled with:**
- (Write 1-3 labs)

**Skills I need more practice with:**
- (Write 1-3 skills)

**Plan for next week:**
- (What will you review before starting Week 5?)

---

## Part 7: Week 3-4 Achievements Checklist

Check off what you have mastered:

**Week 3:**
- [ ] I can create and manage network namespaces
- [ ] I can create veth pairs and connect namespaces
- [ ] I can create a Linux bridge and connect multiple namespaces
- [ ] I understand iptables NAT (SNAT and DNAT)
- [ ] I understand conntrack and connection states
- [ ] I can explain how Docker networking works
- [ ] I can troubleshoot container networking issues

**Week 4:**
- [ ] I understand NIC bonding and can configure it
- [ ] I can write NMState YAML to configure node networking
- [ ] I can use tcpdump to capture and filter packets
- [ ] I can filter by TCP flags
- [ ] I can save and read pcap files
- [ ] I can use nsenter to debug containers
- [ ] I can trace a packet's complete path from container to internet

**Overall:**
- [ ] I can build a container network from scratch (without Docker)
- [ ] I can troubleshoot any layer of the container networking stack
- [ ] I am ready to move to Week 5 (Kubernetes Networking)

---

## Part 8: Week 3-4 Summary — Write This Down

In your notebook, write a one-page summary of Week 3-4:

**Template:**

```
WEEK 3-4 SUMMARY: Linux & Container Networking

Key Concepts:
- Network namespaces isolate network stacks for containers
- veth pairs connect namespaces like virtual cables
- Linux bridges switch traffic between multiple namespaces
- iptables NAT rewrites IP addresses (DNAT for Services, MASQUERADE for internet)
- conntrack tracks connections and NAT translations
- Docker combines all of these to create container networks

Tools I Learned:
- ip netns (manage namespaces)
- ip link (manage veth pairs and bridges)
- iptables (NAT and filtering)
- conntrack (view connection tracking)
- tcpdump (capture packets)
- nsenter (enter namespaces)

Real-World Applications:
- Every Kubernetes pod uses a network namespace
- OCP nodes use bonding for high availability
- NMState configures node networking declaratively
- tcpdump is critical for troubleshooting OCP networking
- nsenter lets me debug pods without tools inside the container

Most Challenging Concept:
- [Your answer]

Most Useful Skill:
- [Your answer]

What I'm Most Proud Of:
- [Your answer]
```

---

## Resources for Further Learning

**If you want to go deeper:**

1. **Network Namespaces:**
   - `man ip-netns`
   - Linux Network Namespaces (lwn.net)

2. **iptables:**
   - `man iptables`
   - iptables Tutorial (frozentux.net)

3. **tcpdump:**
   - `man tcpdump`
   - tcpdump Tutorial (danielmiessler.com)

4. **Books:**
   - "Understanding Linux Network Internals" by Christian Benvenuti
   - "Linux Network Administrator's Guide"

5. **Practice:**
   - Set up a homelab with VMs and practice container networking
   - Contribute to open-source projects (Docker, Kubernetes)

---

## What's Next?

**Week 5 starts tomorrow!**

**Phase 3: Kubernetes Networking Fundamentals**

**Tomorrow (Day 29):** CNI (Container Network Interface) — how Kubernetes manages pod networking

**Get ready for:**
- CNI plugins
- Pod networking
- Kubernetes Services (ClusterIP, NodePort, LoadBalancer)
- Network Policies
- DNS in Kubernetes

You now have the Linux foundation. Next week you will apply it to Kubernetes.

---

## Final Reflection (10 minutes)

Write down:

**Three things I learned this week that I didn't know before:**
1.
2.
3.

**Three things I will use in my OCP troubleshooting:**
1.
2.
3.

**One thing I want to learn more about:**
1.

---

**End of Week 3-4**

Congratulations! You completed Phase 2: Linux & Container Networking.

You now understand:
- How containers get network isolation (namespaces)
- How containers connect to each other (veth, bridges)
- How containers reach the internet (NAT, conntrack)
- How to debug container networking (tcpdump, nsenter)

Take a break. Rest up. Week 5 starts tomorrow with Kubernetes networking.

You are doing great. Keep going.
