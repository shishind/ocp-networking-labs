# Week 3-4 Labs: Linux & Container Networking

**Phase 2 of the OCP Networking Mastery Plan**

---

## Overview

This directory contains hands-on labs for **Week 3-4: Linux & Container Networking**. These labs teach you the Linux networking primitives that OpenShift uses under the hood.

By the end of these two weeks, you will understand:
- How containers get network isolation (namespaces)
- How containers connect to each other (veth pairs, bridges)
- How Kubernetes Services work (iptables NAT)
- How to debug container networking (tcpdump, nsenter)

---

## Week 3: Container Networking Fundamentals (Days 15-21)

### Day 15: Network Namespaces
**File:** [D15_Network_Namespaces.md](D15_Network_Namespaces.md)

**Topics:**
- What network namespaces are
- Why containers use them
- Creating and managing namespaces

**Lab Highlights:**
- Create a network namespace
- Run commands inside a namespace
- Compare namespace vs host network stack

**Key Commands:**
```bash
sudo ip netns add myns
sudo ip netns exec myns ip addr show
```

---

### Day 16: veth Pairs
**File:** [D16_veth_Pairs.md](D16_veth_Pairs.md)

**Topics:**
- What veth pairs are (virtual Ethernet cables)
- How they connect namespaces
- How containers use them

**Lab Highlights:**
- Create a veth pair
- Connect two namespaces
- Test connectivity with ping

**Key Commands:**
```bash
sudo ip link add veth-red type veth peer name veth-blue
sudo ip link set veth-red netns red
```

---

### Day 17: Linux Bridge
**File:** [D17_Linux_Bridge.md](D17_Linux_Bridge.md)

**Topics:**
- What a Linux bridge is (virtual switch)
- How to connect multiple namespaces
- How Docker uses bridges

**Lab Highlights:**
- Create a bridge
- Connect 3 namespaces to the bridge
- Verify full connectivity

**Key Commands:**
```bash
sudo ip link add br0 type bridge
sudo ip link set veth1 master br0
```

---

### Day 18: iptables NAT
**File:** [D18_iptables_NAT.md](D18_iptables_NAT.md)

**Topics:**
- What NAT is (Network Address Translation)
- DNAT vs SNAT
- How Kubernetes Services use DNAT

**Lab Highlights:**
- View iptables NAT rules
- Find Docker port forwarding rules
- Create a manual DNAT rule

**Key Commands:**
```bash
sudo iptables -t nat -L -n -v
sudo iptables -t nat -A OUTPUT -p tcp -d 10.0.0.100 --dport 80 -j DNAT --to-destination 127.0.0.1:80
```

---

### Day 19: conntrack
**File:** [D19_conntrack.md](D19_conntrack.md)

**Topics:**
- What connection tracking is
- Connection states (NEW, ESTABLISHED, RELATED)
- Why NAT needs conntrack

**Lab Highlights:**
- View active connections
- Monitor connections in real-time
- Understand NAT translations

**Key Commands:**
```bash
sudo conntrack -L
sudo conntrack -E  # Real-time monitoring
```

---

### Day 20: Docker Networking
**File:** [D20_Docker_Networking.md](D20_Docker_Networking.md)

**Topics:**
- How Docker combines all the pieces
- docker0 bridge
- Port forwarding with iptables

**Lab Highlights:**
- Inspect docker0 bridge
- Find container's veth interface
- Trace packet path from container to internet

**Key Commands:**
```bash
docker inspect -f '{{.State.Pid}}' <container>
sudo nsenter -t <PID> -n ip addr show
```

---

### Day 21: Week 3 Scenario
**File:** [D21_Week3_Scenario.md](D21_Week3_Scenario.md)

**Scenario:** "Docker container cannot reach internet"

**Skills Practiced:**
- Systematic troubleshooting
- Using namespaces, iptables, conntrack
- Documenting findings

**Lab Highlights:**
- Reproduce the problem
- Use OSI model to plan troubleshooting
- Fix missing default route
- Trace complete packet path

---

## Week 4: Node Networking & Packet Capture (Days 22-28)

### Day 22: Linux Bonding
**File:** [D22_Linux_Bonding.md](D22_Linux_Bonding.md)

**Topics:**
- What NIC bonding is
- Bonding modes (active-backup, LACP)
- Why OCP nodes need it

**Lab Highlights:**
- Create a bond interface
- Add slave interfaces
- Test failover

**Key Commands:**
```bash
sudo ip link add bond0 type bond mode active-backup
sudo ip link set eth0 master bond0
cat /proc/net/bonding/bond0
```

---

### Day 23: NMState
**File:** [D23_NMState.md](D23_NMState.md)

**Topics:**
- What NMState is (declarative network config)
- NNCP, NNS, NNCE resources
- How OCP manages node networking

**Lab Highlights:**
- Write a NodeNetworkConfigurationPolicy
- Create a bond using YAML
- Check configuration status

**Key Commands:**
```bash
oc get nncp
oc get nns <node-name> -o yaml
oc get nnce
```

---

### Day 24: tcpdump Basics
**File:** [D24_tcpdump_Basics.md](D24_tcpdump_Basics.md)

**Topics:**
- What tcpdump is (packet capture tool)
- Basic filtering (protocol, port, IP)
- Reading tcpdump output

**Lab Highlights:**
- Capture packets on an interface
- Filter by protocol (ICMP, TCP, UDP)
- Filter by port and IP address

**Key Commands:**
```bash
sudo tcpdump -i eth0 icmp
sudo tcpdump -i eth0 port 53
sudo tcpdump -i eth0 host 8.8.8.8
```

---

### Day 25: tcpdump Advanced
**File:** [D25_tcpdump_Advanced.md](D25_tcpdump_Advanced.md)

**Topics:**
- Filtering by TCP flags (SYN, RST, FIN)
- Saving to pcap files
- Reading captures in Wireshark

**Lab Highlights:**
- Filter for SYN packets
- Find incomplete TCP handshakes
- Save captures to files
- Transfer to Wireshark

**Key Commands:**
```bash
sudo tcpdump -i eth0 'tcp[13] & 2 != 0' -n  # SYN packets
sudo tcpdump -i eth0 -w capture.pcap
sudo tcpdump -r capture.pcap
```

---

### Day 26: nsenter
**File:** [D26_nsenter.md](D26_nsenter.md)

**Topics:**
- What nsenter is (namespace enter)
- How to debug containers without tools inside them
- Entering a pod's network namespace

**Lab Highlights:**
- Find a container's PID
- Enter the network namespace
- Run network commands from the host

**Key Commands:**
```bash
CONTAINER_PID=$(docker inspect -f '{{.State.Pid}}' <container>)
sudo nsenter -t $CONTAINER_PID -n ip addr show
sudo nsenter -t $CONTAINER_PID -n tcpdump -i eth0
```

---

### Day 27: Container Network Trace
**File:** [D27_Container_Network_Trace.md](D27_Container_Network_Trace.md)

**Topics:**
- Complete packet path from container to internet
- Using tcpdump at multiple points
- Understanding NAT and conntrack in practice

**Lab Highlights:**
- Run tcpdump at 4 capture points
- Trace outbound and inbound packets
- Verify NAT translations
- Intentionally break the path to learn

**Key Skills:**
- Multi-point packet capture
- NAT verification with conntrack
- Systematic packet tracing

---

### Day 28: Week 4 Review
**File:** [D28_Week4_Scenario.md](D28_Week4_Scenario.md)

**Activities:**
- Self-assessment quiz (20 questions)
- Build a multi-container network from scratch
- Re-do challenging labs
- Practice tcpdump filtering
- Identify knowledge gaps

**Goals:**
- Consolidate learning
- Fill gaps before Week 5
- Test readiness for Kubernetes networking

---

## Prerequisites

**Required for all labs:**
- Linux system (RHEL 8/9, Fedora, Ubuntu, or CentOS Stream)
- Root or sudo access
- Basic command-line skills

**Required for specific labs:**
- Docker (Days 20-21, 26-27)
- OpenShift cluster with NMState operator (Day 23)
- Multiple network interfaces (Day 22 - optional)

---

## Lab Format

Each lab follows this structure:

1. **Learning Objectives** — What you will be able to do
2. **Plain English Explanation** — Concept explained simply
3. **Detailed Hands-On Lab** — 5-10 parts with step-by-step commands
4. **Self-Check Questions** — Test your understanding
5. **Today I Learned (TIL)** — Reflection template
6. **Commands Cheat Sheet** — Quick reference
7. **What's Next** — Preview of tomorrow's lab

---

## Time Commitment

**Per day:** 1.5-2 hours (45-60 min learning + 45-60 min hands-on)

**Total for Week 3-4:** Approximately 20-25 hours

---

## Learning Path

**Recommended order:**
1. Complete Week 3 (Days 15-21) before starting Week 4
2. Do not skip labs — each builds on previous knowledge
3. Complete hands-on exercises, not just reading
4. Write your TIL notes daily
5. Review on Day 28 before moving to Week 5

---

## Key Takeaways

After completing Week 3-4, you will understand:

**Technical Skills:**
- Network namespaces and isolation
- veth pairs and virtual networking
- Linux bridges and Layer 2 switching
- iptables NAT (SNAT, DNAT, MASQUERADE)
- Connection tracking with conntrack
- Docker networking architecture
- Linux bonding for HA
- NMState for declarative node config
- tcpdump for packet capture and analysis
- nsenter for container debugging

**Conceptual Understanding:**
- How container networking works under the hood
- Why Kubernetes uses these primitives
- How to trace packets through the stack
- How to troubleshoot systematically

**Practical Applications:**
- Debug OCP pod networking issues
- Understand how Services work (DNAT)
- Capture and analyze network traffic
- Configure node networking declaratively
- Troubleshoot without tools inside containers

---

## Common Issues and Solutions

**Issue:** "I don't have two network interfaces for bonding lab (Day 22)"
**Solution:** You can still follow along conceptually. The other labs don't require multiple NICs.

**Issue:** "I don't have an OpenShift cluster for NMState lab (Day 23)"
**Solution:** Read through the lab. Apply the concepts when you have cluster access.

**Issue:** "tcpdump shows permission denied"
**Solution:** Always run tcpdump with sudo: `sudo tcpdump ...`

**Issue:** "I can't find the veth interface for my container"
**Solution:** Check Day 20 and Day 27 labs for the exact commands to find veth interfaces.

**Issue:** "Docker commands fail"
**Solution:** Ensure Docker is installed and running: `sudo systemctl start docker`

---

## Additional Resources

**Man Pages:**
```bash
man ip-netns
man ip-link
man iptables
man tcpdump
man nsenter
```

**Online Resources:**
- [Linux Network Namespaces](https://lwn.net/Articles/580893/)
- [iptables Tutorial](https://www.frozentux.net/iptables-tutorial/iptables-tutorial.html)
- [tcpdump Tutorial](https://danielmiessler.com/study/tcpdump/)
- [Docker Networking Deep Dive](https://docs.docker.com/network/)

**Books:**
- "Understanding Linux Network Internals" by Christian Benvenuti
- "TCP/IP Illustrated, Volume 1" by W. Richard Stevens

---

## Next Steps

After completing Week 3-4:

1. **Review Day 28** — Consolidate your knowledge
2. **Self-assess** — Ensure you can answer all quiz questions
3. **Practice** — Re-do challenging labs
4. **Move to Week 5** — Kubernetes Networking Fundamentals

**Week 5 Preview:**
- CNI (Container Network Interface)
- Pod networking in Kubernetes
- Kubernetes Services deep dive
- Network Policies
- CoreDNS

---

## Getting Help

**If you get stuck:**
1. Re-read the "Plain English" explanation
2. Check the "Commands Cheat Sheet"
3. Review the "Self-Check Questions"
4. Consult man pages (`man ip-netns`, etc.)
5. Search for error messages online
6. Join OpenShift community forums

---

**Good luck with your labs!**

Remember: The goal is not to memorize commands, but to **understand how the pieces fit together**.

Every Kubernetes pod uses these primitives. Master them, and you master container networking.

---

**[Back to Main README](../../README.md)**
