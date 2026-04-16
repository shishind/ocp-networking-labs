# OCP Networking Mastery Labs
## Complete 8-Week Beginner-to-Expert Hands-On Training

**Duration:** 8 Weeks / 54 working days  
**Start:** March 9, 2026 | **End:** May 1, 2026  
**Goal:** Troubleshoot OCP Networking cases independently

---

## How This Plan Works

This is a complete transformation from **zero networking knowledge** to **expert OCP network troubleshooter** in 8 weeks.

### Key Principles

- **Start from absolute zero** — no prior networking needed
- **Every day = 45 min learn + 45 min hands-on lab**
- **Each phase builds directly on the one before it**
- **Plain English explanations before technical depth**
- **Real commands you will use in actual OCP incidents**

---

## Your Daily Routine (1.5 Hours — Non-Negotiable)

### The 3-Block Daily Routine

#### BLOCK 1 — 45 minutes — LEARN
- Watch the video or read the resource listed for that day
- Use a notebook. Write notes by hand. Do not type — writing forces your brain to understand, not just copy
- If you do not understand something, mark it with a circle and keep going. Come back at the end

#### BLOCK 2 — 45 minutes — DO THE LAB
- Open your Linux machine or lab environment
- Reproduce exactly what you just learned. Type every command yourself. Never copy-paste
- If something breaks — GOOD. Try to fix it before Googling. This is how real learning happens

#### BLOCK 3 — 15 minutes — WRITE A SUMMARY
- In your own words, write 5 bullet points: What did I learn today?
- This takes 15 minutes but saves you hours of revision later
- Build a 'Today I Learned' (TIL) file. One entry per day for 54 days

---

## Weekend Rule

- **Saturday:** Review the full week. Re-do any lab you struggled with. Fill gaps in your notes
- **Sunday:** One complete scenario from start to finish — break something in your lab and fix it using what you learned that week

---

## What NOT to Do

- Do not skip the lab. Reading without doing = forgetting within 48 hours
- Do not rush ahead to Week 5 because it sounds interesting. Week 1 is the foundation of everything
- Do not copy-paste commands. Type every single one. Your fingers need to learn too
- Do not Google the answer immediately when stuck. Spend 15 minutes struggling first. The struggle is the learning
- Do not do 3 hours in one day and then skip 2 days. Consistency beats intensity

---

## 5 Phases — What You Will Master

### Phase 1: Core Networking — From Zero to Confident (Weeks 1-2)
**What:** OSI Model, IP addresses, DNS, TCP/UDP, routing, NAT, iptables  
**Why:** This is your foundation. Every single thing you learn in Weeks 3-8 will refer back to what you learn here. You cannot skip it

### Phase 2: Linux & Container Networking (Weeks 3-4)
**What:** Network namespaces, veth pairs, bridges, OVS, Docker networking, tcpdump  
**Why:** OpenShift runs on Linux. Every container is a Linux process. This phase teaches you the Linux building blocks that make containers work — and which you MUST understand to troubleshoot OCP

### Phase 3: Kubernetes Networking (Weeks 5-6)
**What:** The 4 rules of K8s networking, Services (ClusterIP, NodePort, LoadBalancer), CoreDNS, NetworkPolicy, CNI plugins, Ingress  
**Why:** Kubernetes is the engine that runs OpenShift. This phase teaches you how pods get IPs, how Services route traffic, how DNS works inside a cluster. Every concept here maps directly onto what OCP does

### Phase 4: OpenShift Networking Deep Dive (Week 7)
**What:** Open vSwitch (OVS), OVN logical networks, the 4 OVN traffic flows, BR-EX, Routes, HAProxy, DNS Operator, EgressIP, NetworkPolicy + OVN ACLs  
**Why:** This is the phase everything has been building towards. OpenShift adds its own powerful layer on top of Kubernetes. Now you have enough foundation to understand it deeply — not just memorise commands

### Phase 5: tcpdump & Packet Analysis (Week 8)
**What:** tcpdump mastery, Wireshark, diagnosing common issues from packets  
**Why:** This is the elite skill that separates senior engineers from junior ones. When logs tell you nothing — packets tell you everything. After this week, you will be able to definitively prove the root cause of any network issue using raw packet captures

---

## Lab Environment — Set This Up Before Monday

### What you need:

**Option A:** Vsphere  
**Option B:** Any cloud VM — AWS t2.micro or GCP e2-micro are free tier  
**Option C:** If you already have a Linux machine — use it as-is

### Install these tools on your Linux machine:

```bash
sudo apt update && sudo apt install -y net-tools iproute2 tcpdump iptables dnsutils \
  traceroute bridge-utils nmap conntrack
# For container labs:
curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker $USER
# For Kubernetes labs (Week 5-6):
curl -Lo kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64 && chmod +x kind && \
  sudo mv kind /usr/local/bin/
```

### For OpenShift (Week 7-8):

Sign up for a FREE Red Hat Developer Sandbox at `developers.redhat.com/developer-sandbox` — you get a real OpenShift cluster for free. Do this NOW so it is ready when you reach Week 7

---

## The 8-Week Roadmap

### PHASE 1 — CORE NETWORKING FUNDAMENTALS

#### Week 1: March 9 - March 13, 2026

| Day | Date | Topic | Hands-On Lab |
|-----|------|-------|--------------|
| D1 | Mon Mar 9 | OSI Model — all 7 layers | Draw all 7 layers from memory. Map a 'curl http://my-service' call to every layer |
| D2 | Tue Mar 10 | IP addresses, CIDR notation, private ranges | Run: ip addr show. Find your IP. Calculate: how many addresses in 10.128.0.0/14? |
| D3 | Wed Mar 11 | DNS — how name resolution works end to end | Run: dig +trace google.com. Watch the full journey from root DNS to answer. Draw it. |
| D4 | Thu Mar 12 | TCP vs UDP, ports, the 3-way handshake | Run: ss -tulpn. List every listening port. Run tcpdump and see a real TCP handshake |
| D5 | Fri Mar 13 | Switches, routers, ARP, routing tables | Run: ip route show. Run: ip neigh show (ARP table). Draw your network topology |
| D6 | Sat Mar 14 | NAT — SNAT, DNAT, MASQUERADE | Run: iptables -t nat -L -n -v. Understand each rule. Draw a NAT flow on paper |
| D7 | Sun Mar 15 | WEEK 1 REVIEW + Mini scenario | Scenario: 'I can ping 8.8.8.8 but cannot reach my-service by name.' Where is the problem? |

#### Week 2: March 16 - March 22, 2026

| Day | Date | Topic | Hands-On Lab |
|-----|------|-------|--------------|
| D8 | Mon Mar 16 | iptables — filter table, chains, ACCEPT/DROP/REJECT | Add a test rule: block port 9999. Test it with nc. Then delete the rule |
| D9 | Tue Mar 17 | Protocols: SSH, HTTP, HTTPS, SMTP, FTP — what they do and their ports | Curl a website with -v flag. Read every header. Identify which OSI layer each is at |
| D10 | Wed Mar 18 | VLANs — what they are and why OCP nodes use them | Create a VLAN interface on your Linux VM: ip link add link eth0 name eth0.10 type vlan id 10 |
| D11 | Thu Mar 19 | chronyD — NTP time sync, why it matters for OCP | Run: chronyc tracking. chronyc sources. What happens when time drifts in OCP clusters? |
| D12 | Fri Mar 20 | systemd, daemons, journalctl — monitoring services | Run: systemctl status NetworkManager. Read the journal: journalctl -u NetworkManager -n 50 |
| D13 | Sat Mar 21 | Cgroups — how Linux limits resources per process | Find a process. Check its Cgroup: cat /proc/<PID>/cgroup. Read memory limit in_bytes |
| D14 | Sun Mar 22 | WEEK 1-2 REVIEW + Full scenario | Scenario: 'Port 443 is not reachable on my server.' Debug using only the commands from this week |

---

### PHASE 2 — LINUX & CONTAINER NETWORKING

#### Week 3: March 23 - March 27, 2026

| Day | Date | Topic | Hands-On Lab |
|-----|------|-------|--------------|
| D15 | Mon Mar 23 | Network namespaces — what they are and why containers use them | Create a namespace: ip netns add myns. List it: ip netns list. Run a command inside it |
| D16 | Tue Mar 24 | veth pairs — creating and connecting namespaces | Create veth pair: ip link add veth0 type veth peer veth1. Move veth1 into myns. Ping between them |
| D17 | Wed Mar 25 | Linux bridge — connecting multiple namespaces together | Create a bridge. Attach 3 veth ends to it. Verify all 3 namespaces can ping each other |
| D18 | Thu Mar 26 | iptables NAT table — how Kubernetes Services really work | Run: iptables -t nat -L -n -v. Find a DNAT rule. Understand what it does. Trace a request manually |
| D19 | Fri Mar 27 | conntrack — Linux connection tracking | Run: conntrack -L. What does each entry show? Why does this matter for stateful firewalls? |
| D20 | Sat Mar 28 | Docker networking — containers in practice | Run container: docker run -p 8080:80 nginx. Find the iptables rule it created. trace the packet path |
| D21 | Sun Mar 29 | WEEK 3 REVIEW — end-to-end container scenario | Scenario: docker container cannot reach the internet. Debug using namespaces, iptables, and tcpdump |

#### Week 4: March 30 - April 3, 2026

| Day | Date | Topic | Hands-On Lab |
|-----|------|-------|--------------|
| D22 | Mon Mar 30 | Linux Bonding — why nodes need it, how to configure it | Create bond0 in active-backup mode. Verify: cat /proc/net/bonding/bond0. Check failover behaviour |
| D23 | Tue Mar 31 | NMState — declarative node network config in OCP | Write an NMState YAML to create a bond. Apply it. Check the NNCE for status |
| D24 | Wed Apr 1 | tcpdump — basic capture and filtering | Capture DNS traffic: tcpdump -i any 'udp port 53'. Capture HTTP: tcpdump -i any 'port 80'. Read the output |
| D25 | Thu Apr 2 | tcpdump — advanced: TCP flags, saving to file | Filter SYN packets: tcpdump 'tcp[tcpflags] & tcp-syn!=0'. Save capture: -w /tmp/cap.pcap. Open in Wireshark |
| D26 | Fri Apr 3 | nsenter — entering a pod's network namespace | Find a container PID: docker inspect <id> | grep Pid. Enter its namespace: nsenter -t <PID> -n. Run ip addr |
| D27 | Sat Apr 4 | Scenario lab — trace a full container networking path | Start a container. Trace its packet from container eth0 → veth → bridge → host → internet using tcpdump |
| D28 | Sun Apr 5 | WEEK 3-4 REVIEW + gap filling | Re-do any lab from this week you found difficult. Make sure you can do all items on the self-check list |

---

### PHASE 3 — KUBERNETES NETWORKING

#### Week 5: April 6 - April 11, 2026

| Day | Date | Topic | Hands-On Lab |
|-----|------|-------|--------------|
| D29 | Mon Apr 6 | Set up kind cluster (local Kubernetes) | Install kind. Create a 2-node cluster. kubectl get nodes. kubectl get pods -A |
| D30 | Tue Apr 7 | K8s networking model — 4 rules, pod IPs | Deploy 2 pods. Note their IPs. Ping between them using kubectl exec |
| D31 | Wed Apr 8 | ClusterIP Service — how it works at the iptables level | Create a Service. Find its ClusterIP. Find the iptables DNAT rule it created: iptables -t nat -L -n | grep <ClusterIP> |
| D32 | Thu Apr 9 | CoreDNS — DNS inside the cluster | From a pod: nslookup kubernetes.default. cat /etc/resolv.conf. What DNS server does it use? |
| D33 | Fri Apr 10 | Endpoints — how Services know which pods to route to | oc/kubectl get endpoints <svc>. Now delete a pod. Watch the endpoint update |
| D34 | Sat Apr 11 | NodePort + Ingress — external access | Expose a service as NodePort. Access it from outside the cluster. Deploy nginx ingress controller |
| D35 | Sun Apr 12 | WEEK 5 REVIEW — Service troubleshooting scenario | Scenario: Service returns 'connection refused'. Debug using endpoints, iptables, pod logs |

#### Week 6: April 14 - April 17, 2026

| Day | Date | Topic | Hands-On Lab |
|-----|------|-------|--------------|
| D36 | Mon Apr 13 | NetworkPolicy — deny-all then allow specific traffic | Apply deny-all ingress. Test pods cannot reach each other. Add allow rule. Verify it works |
| D37 | Tue Apr 14 | CNI deep dive — what happens when a pod starts | Watch CNI logs as a pod starts. Trace veth creation on the node. Inspect CNI config files |
| D38 | Wed Apr 15 | Kubernetes DNS troubleshooting | Break DNS (rename a service). Debug from inside a pod. Find and fix the issue |
| D39 | Thu Apr 16 | kube-proxy / IPVS — how Services are programmed | Check kube-proxy mode. List IPVS rules: ipvsadm -ln. Compare to iptables rules |
| D40 | Fri Apr 17 | Full troubleshooting scenario — pod cannot reach Service | Complete scenario: broken service. Use: get endpoints, describe svc, exec curl, check NetworkPolicy |
| D41 | Sat Apr 18 | Wireshark intro — opening and reading a pcap file | Download a sample pcap from Wireshark Wiki. Open it. Apply filter: ip.addr == X. Follow TCP stream |
| D42 | Sun Apr 19 | WEEK 5-6 REVIEW — K8s networking confidence check | Can you explain how a ClusterIP Service works without notes? If not — re-read Topic 15 today |

---

### PHASE 4 — OPENSHIFT NETWORKING DEEP DIVE

#### Week 7: April 20 - April 24, 2026

| Day | Date | Topic | Hands-On Lab |
|-----|------|-------|--------------|
| D43 | Mon Apr 20 | OVS fundamentals — br-int, br-ex, ports, flows | On an OCP node: ovs-vsctl show. Identify every bridge, port, and interface. Draw the topology |
| D44 | Tue Apr 21 | OVS flow tables — reading OpenFlow rules | ovs-ofctl dump-flows br-int. Find the rule that handles a specific pod's traffic. Explain it |
| D45 | Wed Apr 22 | OVN architecture — NB/SB DB, ovnkube-master, ovnkube-node | oc get pods -n openshift-ovn-kubernetes. ovn-nbctl show. Map the logical topology to real pods |
| D46 | Thu Apr 23 | OVN traffic flows — trace all 4 patterns step by step | For each of the 4 flows, trace a packet hop by hop. Write the path down on paper from memory |
| D47 | Fri Apr 24 | Routes: create edge, passthrough, reencrypt. Test each one | Deploy an app. Create all 3 route types. Test TLS termination. Check HAProxy config in router pod |
| D48 | Sat Apr 25 | DNS Operator, EgressIP, EgressNetworkPolicy | Check DNS operator status. Assign EgressIP to a namespace. Verify outbound IP changes |
| D49 | Sun Apr 26 | Full OCP troubleshooting simulation — cross-node pod connectivity broken | Given: pods on different nodes cannot communicate. Diagnose using the 4-flow framework + OVN tools |

---

### PHASE 5 — TCPDUMP & PACKET ANALYSIS

#### Week 8: April 27 - May 1, 2026

| Day | Date | Topic | Hands-On Lab |
|-----|------|-------|--------------|
| D50 | Mon Apr 27 | tcpdump output format — reading flags, timestamps, IPs | Capture traffic on your machine. Identify SYN, SYN-ACK, ACK, RST packets by their flags |
| D51 | Tue Apr 28 | Capturing on an OCP node — br-ex, br-int, GENEVE tunnel | oc debug node/<node>. Capture on br-ex. Copy file off node. Open in Wireshark |
| D52 | Wed Apr 29 | Wireshark filters + following streams + statistics | Open your capture. Apply filter: tcp.flags.reset==1. Follow a TCP stream. Use Statistics menu |
| D53 | Thu Apr 30 | Full packet analysis lab — diagnose a pre-built broken scenario | Given a pcap of a broken OCP scenario: identify the failure, the exact packet, and the root cause |
| D54 | Fri May 1 | GRADUATION DAY — Final challenge scenario | End-to-end scenario combining ALL 8 weeks: broken OCP cluster networking. Diagnose and fix it |

---

## Weekly Self-Assessment Checklists

At the end of each week, honestly answer these questions. If you cannot answer them without notes — go back and review before moving to the next week. Moving forward without the foundation will make the next week harder, not easier.

### End of Week 2 — Can You...

- Explain what each OSI layer does with a real example for each one?
- Calculate how many IP addresses are in a /24 network? A /16?
- Explain what DNS does and trace a resolution end to end?
- Describe the TCP 3-way handshake? What is SYN, SYN-ACK, ACK?
- Run ip route show and explain every line of output?
- Explain what NAT is and why containers need it?
- List the iptables chains and what traffic each one handles?

### End of Week 4 — Can You...

- Create two network namespaces and ping between them using a veth pair?
- Explain what a Linux bridge is and how a container attaches to it?
- Find the iptables DNAT rule that a Docker port mapping creates?
- Capture traffic on a specific interface with tcpdump and filter by host?
- Enter a container's network namespace and run ip addr from inside it?
- Explain what Linux Bonding is and why OCP nodes use it?

### End of Week 6 — Can You...

- Explain how a Kubernetes ClusterIP Service works at the iptables level?
- Find which pod IPs are backing a Service using kubectl get endpoints?
- Test DNS from inside a pod and interpret the result?
- Write a NetworkPolicy that denies all ingress except from a specific namespace?
- Explain what a CNI plugin does when a pod starts?

### End of Week 7 — Can You...

- Run ovs-vsctl show on an OCP node and explain every line?
- Trace a packet through all 4 OVN traffic flows from memory — without notes?
- Explain what BR-EX is, where it sits, and why it exists?
- Create an edge, passthrough, and re-encrypt Route in OCP? Test each one?
- Diagnose why an OCP Route is not working step by step?
- Check if the network operator or DNS operator is degraded?

### End of Week 8 (Graduation) — Can You...

- Look at a tcpdump output and identify the packet type from the flags?
- Open a pcap in Wireshark, filter for RST packets, and explain what caused them?
- Distinguish between: connection refused (RST), timeout (retransmits), DNS failure (NXDOMAIN)?
- Capture traffic on a live OCP node and retrieve the file for Wireshark analysis?
- Given a broken OCP networking scenario — find the root cause within 15 minutes?

---

## A Final Word — From Zero to OCP Network Troubleshooter in 8 Weeks

You started this plan with zero networking knowledge.

If you followed every week, ran every lab, and wrote your daily TIL notes — you now understand networking at a deeper level than most engineers who have been in the field for years.

The secret was not memorising commands.  
The secret was understanding WHY packets move — and WHY they stop.

Take that understanding into every OCP support case.  
Ask: Which of the 4 flows is this? Where exactly is the packet stopping?  
Run the right command. Read the output. State the root cause with evidence.

That is what a great OCP network engineer does. Now you are one.

---

## Lab Directory Structure

```
ocp-networking-labs/
├── week1-2/          # Phase 1: Core Networking
│   ├── labs/         # Daily hands-on labs (D1-D14)
│   ├── scenarios/    # Weekend troubleshooting scenarios
│   └── resources/    # Cheat sheets, diagrams, references
├── week3-4/          # Phase 2: Linux & Container Networking
│   ├── labs/         # Daily hands-on labs (D15-D28)
│   ├── scenarios/    # Weekend troubleshooting scenarios
│   └── resources/    # Cheat sheets, diagrams, references
├── week5-6/          # Phase 3: Kubernetes Networking
│   ├── labs/         # Daily hands-on labs (D29-D42)
│   ├── scenarios/    # Weekend troubleshooting scenarios
│   └── resources/    # Cheat sheets, diagrams, references
├── week7/            # Phase 4: OpenShift Networking Deep Dive
│   ├── labs/         # Daily hands-on labs (D43-D49)
│   ├── scenarios/    # Weekend troubleshooting scenarios
│   └── resources/    # Cheat sheets, diagrams, references
└── week8/            # Phase 5: tcpdump & Packet Analysis
    ├── labs/         # Daily hands-on labs (D50-D54)
    ├── scenarios/    # Weekend troubleshooting scenarios
    └── resources/    # Cheat sheets, diagrams, references
```

---

**Start Date:** Monday, March 9, 2026  
**Your First Lab:** `week1-2/labs/D1_OSI_Model.md`

Good luck. Type every command. Struggle before Googling. Write your TIL notes.

You've got this.
