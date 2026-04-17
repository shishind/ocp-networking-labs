# Week 1-2: Core Networking Fundamentals - Lab Files

This directory contains all hands-on lab exercises for Weeks 1-2 of the OCP Networking Mastery Plan.

## Week 1: Foundation Concepts (Days 1-7)

### Day 1: OSI Model
**File:** `D1_OSI_Model.md`  
**Topics:** 7-layer framework, mapping real traffic to layers, troubleshooting with OSI model  
**Lab:** Map a curl request to every layer, troubleshoot DNS vs routing issues

### Day 2: IP Addresses & Subnetting
**File:** `D2_IP_Subnetting.md`  
**Topics:** IPv4 addresses, CIDR notation, private IP ranges, subnetting calculations  
**Lab:** Calculate network sizes, understand OpenShift IP ranges (10.128.0.0/14, 172.30.0.0/16)

### Day 3: DNS
**File:** `D3_DNS.md`  
**Topics:** DNS resolution, A/AAAA/CNAME/PTR records, CoreDNS in OpenShift  
**Lab:** Use dig and nslookup, troubleshoot DNS issues, understand cluster DNS

### Day 4: TCP vs UDP
**File:** `D4_TCP_UDP.md`  
**Topics:** TCP 3-way handshake, TCP flags, UDP, common ports  
**Lab:** Capture TCP handshake with tcpdump, test ports with nc, understand flags

### Day 5: Routing, Switching, ARP
**File:** `D5_Routing_Switching_ARP.md`  
**Topics:** Switches vs routers, routing tables, ARP, network topology  
**Lab:** Read routing table, view ARP cache, trace routes, draw network topology

### Day 6: NAT
**File:** `D6_NAT.md`  
**Topics:** SNAT, DNAT, MASQUERADE, iptables NAT table  
**Lab:** View NAT rules, understand pod NAT, draw NAT flow diagrams

### Day 7: Week 1 Scenario
**File:** `D7_Week1_Scenario.md`  
**Topics:** Full troubleshooting exercise using Week 1 concepts  
**Scenario:** "I can ping 8.8.8.8 but cannot reach my-service by name" (DNS troubleshooting)

---

## Week 2: Linux Networking Essentials (Days 8-14)

### Day 8: iptables
**File:** `D8_iptables.md`  
**Topics:** Filter table, INPUT/OUTPUT/FORWARD chains, ACCEPT/DROP/REJECT  
**Lab:** Add firewall rule, test with nc, delete rule, understand OpenShift iptables

### Day 9: Common Protocols
**File:** `D9_Protocols.md`  
**Topics:** SSH, HTTP, HTTPS, SMTP, FTP, DNS protocols and ports  
**Lab:** Analyze HTTP with curl -v, test protocols, map to OSI layers

### Day 10: VLANs
**File:** `D10_VLANs.md`  
**Topics:** Virtual LANs, 802.1Q tagging, trunk vs access ports  
**Lab:** Create VLAN interface, assign IP, capture VLAN tags with tcpdump

### Day 11: chrony and NTP
**File:** `D11_chronyD.md`  
**Topics:** Time synchronization, NTP, chrony, stratum levels  
**Lab:** Check time sync status, view NTP sources, troubleshoot time drift

### Day 12: systemd and journalctl
**File:** `D12_systemd.md`  
**Topics:** Service management, systemd units, logs  
**Lab:** Start/stop/enable services, read logs, troubleshoot failing services

### Day 13: Cgroups
**File:** `D13_Cgroups.md`  
**Topics:** Control groups, resource limits (CPU, memory), cgroups v1 vs v2  
**Lab:** View process cgroups, check resource limits, understand container isolation

### Day 14: Week 2 Scenario
**File:** `D14_Week2_Scenario.md`  
**Topics:** Full troubleshooting exercise using Weeks 1-2 concepts  
**Scenario:** "Port 443 not reachable on my server" (firewall, service, routing troubleshooting)

---

## Lab Structure

Each lab follows the same consistent format:

1. **Learning Objectives** - What you will learn
2. **Plain English Explanation** - Core concepts explained simply
3. **Hands-On Lab** - Multiple practical exercises
4. **Self-Check Questions** - Test your understanding (with answers)
5. **Today I Learned (TIL)** - Template for note-taking
6. **Commands Cheat Sheet** - Quick reference
7. **What's Next** - Preview of tomorrow's topic

---

## How to Use These Labs

1. **Read the entire lab first** before running any commands
2. **Complete all exercises** - hands-on practice is critical
3. **Write down your TIL** - this helps retention
4. **Answer self-check questions** without looking at notes
5. **Keep a troubleshooting journal** for scenario labs (Days 7 and 14)

---

## Time Commitment

- **Each lab:** 1.5 hours (45 min theory + 45 min hands-on)
- **Scenario labs (Days 7, 14):** 2 hours each
- **Total for Weeks 1-2:** ~23 hours

---

## Prerequisites

- Access to a Linux system (RHEL 9, Fedora, CentOS Stream)
- Root/sudo access for network commands
- Basic command-line familiarity

**Optional but recommended:**
- Access to an OpenShift cluster
- Podman or Docker for container exercises

---

## Key Commands by Topic

**Networking:**
- `ip addr`, `ip route`, `ip neigh`
- `ss -tulpn`, `nc -zv`
- `ping`, `traceroute`

**DNS:**
- `dig`, `nslookup`, `host`
- `cat /etc/resolv.conf`

**Firewall:**
- `iptables -L -n -v`
- `firewall-cmd --list-all`

**Services:**
- `systemctl status/start/stop/restart`
- `journalctl -u <service>`

**Packet Capture:**
- `tcpdump -i any`

**Time Sync:**
- `chronyc tracking`, `chronyc sources`

---

## Next Steps

After completing Week 1-2, proceed to:
- **Week 3-4:** Linux & Container Networking (namespaces, veth pairs, bridges)
- **Week 5-6:** Kubernetes Networking (CNI, Services, Ingress)
- **Week 7:** OpenShift Networking Deep Dive (OVN, SDN, NetworkPolicy)
- **Week 8:** Advanced Troubleshooting (tcpdump mastery, Wireshark)

---

**Created:** March 2026  
**OCP Networking Mastery Plan - Phase 1: Core Networking Fundamentals**
