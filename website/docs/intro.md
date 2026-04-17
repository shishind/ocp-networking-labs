---
sidebar_position: 1
title: Welcome to OCP Networking Labs
---

# OCP Networking Labs

## Choose Your Starting Point

Not everyone needs to start from scratch. Pick the week that matches your current knowledge level:

---

## 📚 Where Should You Start?

### 🌱 Complete Beginner - Start at Week 1

**If you:**
- Are new to networking
- Don't know what OSI, TCP/IP, or DNS mean
- Want to learn from the ground up

**👉 [Start Week 1: Core Networking →](/week1-2/D1_OSI_Model)**

Topics: OSI Model, IP/Subnetting, DNS, TCP/UDP, Routing, NAT, iptables

---

### 🐧 Know Networking, New to Containers - Start at Week 3

**If you:**
- Understand basic networking (IP, DNS, routing)
- Want to learn how containers work
- Need to understand Linux networking primitives

**👉 [Start Week 3: Linux & Container Networking →](/week3-4/D15_Network_Namespaces)**

Topics: Network namespaces, veth pairs, bridges, Docker networking, tcpdump

---

### ☸️ Know Containers, New to Kubernetes - Start at Week 5

**If you:**
- Understand Docker/container networking
- Want to learn Kubernetes networking
- Need to troubleshoot K8s Services and DNS

**👉 [Start Week 5: Kubernetes Networking →](/week5-6/D29_kind_Setup)**

Topics: K8s Services, CoreDNS, NetworkPolicy, CNI plugins, Ingress

---

### 🔴 Know Kubernetes, Need OpenShift - Start at Week 7

**If you:**
- Understand Kubernetes networking well
- Want to master OVS/OVN in OpenShift
- Need to troubleshoot production OCP clusters

**👉 [Start Week 7: OpenShift Deep Dive →](/week7/D43_OVS_Fundamentals)**

Topics: Open vSwitch, OVN architecture, the 4 Traffic Flows, Routes, HAProxy

---

## 📊 Course Overview

### Phase 1: Core Networking (Week 1-2)
**14 labs** covering OSI, IP, DNS, TCP/UDP, Routing, NAT, iptables, VLANs

[View Week 1-2 Labs →](/week1-2/README)

### Phase 2: Linux & Containers (Week 3-4)
**14 labs** covering namespaces, veth, bridges, Docker, bonding, tcpdump

[View Week 3-4 Labs →](/week3-4/README)

### Phase 3: Kubernetes (Week 5-6)
**14 labs** covering Services, CoreDNS, NetworkPolicy, CNI, kube-proxy

[View Week 5-6 Labs →](/week5-6/README)

### Phase 4: OpenShift Deep Dive (Week 7)
**7 labs** covering OVS, OVN, Routes, the 4 Traffic Flows, EgressIP

[View Week 7 Labs →](/week7/README)

---

## 📋 Quick Access: Cheat Sheets

Need quick command reference? Jump straight to the cheat sheets:

- [Master Commands (All Phases)](/cheat-sheets/Master_Commands_QuickRef)
- [Phase 1: Core Networking Commands](/cheat-sheets/Phase1_Core_Networking_CheatSheet)
- [Phase 2: Linux & Container Commands](/cheat-sheets/Phase2_Linux_Container_CheatSheet)
- [Phase 3: Kubernetes Commands](/cheat-sheets/Phase3_Kubernetes_CheatSheet)
- [Phase 4: OpenShift Commands](/cheat-sheets/Phase4_OpenShift_CheatSheet)

---

## 🚀 Getting Started

### Clone the Repository

```bash
git clone https://github.com/shishind/ocp-networking-labs.git
cd ocp-networking-labs
cat README.md  # Read the full guide
```

### Or Download as ZIP

[Download ZIP →](https://github.com/shishind/ocp-networking-labs/archive/refs/heads/main.zip)

---

## ⏱️ Daily Learning Routine (1.5 Hours)

No matter where you start, follow this routine:

1. **Learn (45 min):** Read the day's lab markdown file
2. **Practice (45 min):** Do ALL exercises - type every command yourself
3. **Reflect (15 min):** Write 5 bullet points - "What did I learn today?"

---

## 💡 Learning Principles

- **Don't skip ahead** - Each week builds on the previous
- **Type every command** - No copy-paste!
- **Consistency beats intensity** - 1.5 hours daily
- **Weekend scenarios** - Test your understanding
- **Write TIL notes** - Build your knowledge base

---

## 📊 What You Get

- ✅ **49 hands-on labs** across 7 weeks
- ✅ **268+ practical exercises** with real commands
- ✅ **880+ documented commands** for troubleshooting
- ✅ **8 comprehensive cheat sheets** for quick reference
- ✅ **Weekend scenarios** to test your skills
- ✅ **Self-assessment checklists** for each week

---

## 🛠️ Prerequisites

Based on where you start:

**Week 1-2:** Just a Linux machine  
**Week 3-4:** Linux + `docker` or `podman`  
**Week 5-6:** Linux + Docker + `kubectl` + `kind`  
**Week 7:** Access to an OpenShift cluster (free Red Hat Developer Sandbox)

---

## 🧪 Self-Assessment: Where Do You Stand?

Answer these questions to find your starting point:

**Can you explain:**
- What the OSI model is? → **No?** Start Week 1
- How DNS resolution works? → **No?** Start Week 1
- What a network namespace is? → **No?** Start Week 3
- How a Kubernetes Service works? → **No?** Start Week 5
- What OVN logical switches are? → **No?** Start Week 7

---

## 🎯 Learning Path Recommendation

### Option 1: Complete Path (7 weeks)
Start Week 1 → Week 2 → ... → Week 7  
**Best for:** Building solid fundamentals from scratch

### Option 2: Fast Track to OCP (3 weeks)
Week 5 → Week 6 → Week 7  
**Best for:** Experienced K8s users learning OpenShift

### Option 3: OCP Only (1 week)
Week 7 only  
**Best for:** K8s experts who need OVS/OVN specifics

### Option 4: Custom Path
Pick the weeks you need, but follow them in order  
**Best for:** Filling specific knowledge gaps

---

## 🤝 Community & Support

- **GitHub Repository:** [shishind/ocp-networking-labs](https://github.com/shishind/ocp-networking-labs)
- **Issues:** [Report bugs or ask questions](https://github.com/shishind/ocp-networking-labs/issues)
- **Discussions:** [Share your experience](https://github.com/shishind/ocp-networking-labs/discussions)

---

## 📜 License

This content is licensed under the [MIT License](https://github.com/shishind/ocp-networking-labs/blob/main/LICENSE). Free to use and share.

---

## 🚀 Ready to Start?

**Choose your path above** and click the link to begin!

Remember:
- Type every command yourself
- Do all the exercises
- Write your daily TIL notes
- Test yourself with weekend scenarios

Good luck! You've got this. 🎓
