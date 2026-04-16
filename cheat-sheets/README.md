# OCP Networking Labs - Command Reference Cheat Sheets

This directory contains comprehensive command reference cheat sheets for all phases of the OCP Networking Labs. These are designed to be practical, quick-reference guides for troubleshooting and working with networking in OpenShift.

---

## 📚 Available Cheat Sheets

### 🎯 [Master Commands Quick Reference](Master_Commands_QuickRef.md)
**Start here!** One-page essential commands across all phases.

- Quick troubleshooting workflows
- Most common commands
- "When things break" guide
- One-liner utilities

**Use when:** You need a quick answer, first response to an issue, or a command reminder.

---

### 📡 [Phase 1: Core Networking](Phase1_Core_Networking_CheatSheet.md)
**Week 1-2 | Foundation Skills**

Commands covered:
- OSI model quick reference
- IP addressing & CIDR calculations
- DNS (dig, nslookup, systemd-resolved)
- TCP/UDP ports (ss, nc, telnet)
- Routing (ip route, ip addr, ARP)
- NAT & iptables
- systemd & journalctl
- Interface management
- VLAN configuration
- Time sync (chrony)

**Use when:** 
- Troubleshooting basic network connectivity
- Working with routing and addressing
- Debugging DNS issues
- Managing firewall rules
- Checking system services

---

### 🐳 [Phase 2: Linux Container Networking](Phase2_Linux_Container_CheatSheet.md)
**Week 3-4 | Container Foundation**

Commands covered:
- Network namespaces (ip netns)
- veth pairs (virtual ethernet)
- Linux bridges (brctl, ip link)
- iptables NAT for containers
- Connection tracking (conntrack)
- Docker networking
- NMState & bonding (nmcli)
- tcpdump packet capture
- nsenter (namespace entry)

**Use when:**
- Debugging container networking
- Working with network namespaces
- Setting up bridges and veth pairs
- Capturing packets with tcpdump
- Understanding Docker networking
- Testing container connectivity

---

### ☸️ [Phase 3: Kubernetes Networking](Phase3_Kubernetes_CheatSheet.md)
**Week 5-6 | Kubernetes Core**

Commands covered:
- kubectl/oc basics
- Service management & debugging
- Endpoint troubleshooting
- DNS (CoreDNS)
- NetworkPolicy
- CNI (Calico, Flannel, Weave)
- kube-proxy & IPVS
- Pod networking
- Ingress & LoadBalancer

**Use when:**
- Services not working
- DNS resolution failures
- NetworkPolicy issues
- Pod-to-pod connectivity problems
- CNI plugin debugging
- Testing Kubernetes services

---

### 🎛️ [Phase 4: OpenShift Networking](Phase4_OpenShift_CheatSheet.md)
**Week 7 | OpenShift Deep Dive**

Commands covered:
- OVS (Open vSwitch) - ovs-vsctl, ovs-ofctl
- OVN (Open Virtual Network) - ovn-nbctl, ovn-sbctl
- The 4 traffic flows in OpenShift
- Routes & HAProxy
- DNS Operator
- EgressIP configuration
- EgressFirewall
- NetworkPolicy (OpenShift specifics)

**Use when:**
- Debugging OpenShift routes
- Working with OVS/OVN
- Configuring EgressIP
- HAProxy/router issues
- Understanding traffic flows
- OpenShift-specific networking

---

## 🚀 How to Use These Cheat Sheets

### For Learning
1. Start with **Master Commands Quick Reference** to get familiar with essential commands
2. Progress through **Phase 1-4** in order as you complete the labs
3. Practice commands in the lab environment
4. Refer back when you encounter specific technologies

### For Troubleshooting
1. **Start with symptoms**: Check the Master Quick Reference troubleshooting workflows
2. **Identify the layer**: Is it DNS, routing, service, pod networking, or routes?
3. **Go to the relevant phase**: Use the detailed phase cheat sheet for comprehensive commands
4. **Follow the workflow**: Each cheat sheet has "Troubleshooting Workflow" sections

### For Reference
- Keep these open while working on labs
- Use Ctrl+F (or Cmd+F) to search for specific commands
- Bookmark frequently used sections
- Print the Master Quick Reference for quick access

---

## 📖 Quick Navigation Guide

### "I'm having this problem..."

| Problem | Cheat Sheet | Section |
|---------|-------------|---------|
| Can't ping another host | Phase 1 | IP Addressing, Routing |
| DNS not working | Phase 1 or 3 | DNS Commands |
| Service returns no endpoints | Phase 3 | Service & Endpoint Debugging |
| Container can't reach internet | Phase 2 | Troubleshooting Workflows |
| Route returns 503 | Phase 4 | Route Troubleshooting |
| NetworkPolicy blocking | Phase 3 or 4 | NetworkPolicy |
| Pod-to-pod timeout | Phase 3 or 4 | Pod Network Debugging |
| EgressIP not working | Phase 4 | EgressIP Troubleshooting |
| iptables rules not working | Phase 1 or 2 | NAT & iptables |
| OVS flows confusing | Phase 4 | OVS Commands |

### "I need to..."

| Task | Cheat Sheet | Section |
|------|-------------|---------|
| Create a network namespace | Phase 2 | Network Namespaces |
| Set up a veth pair | Phase 2 | veth Pairs |
| Configure a Linux bridge | Phase 2 | Linux Bridge |
| Capture packets | Phase 2 | tcpdump |
| Debug a Kubernetes service | Phase 3 | Service Management |
| Test DNS resolution | Phase 1, 3, or 4 | DNS Commands |
| Create a route | Phase 4 | Route Management |
| Set up EgressIP | Phase 4 | EgressIP Configuration |
| View OVN topology | Phase 4 | OVN Commands |
| Check kube-proxy | Phase 3 | kube-proxy & IPVS |

---

## 💡 Tips for Effective Use

### Command Structure Understanding

Most commands follow patterns:

**Display/View:**
```bash
<tool> <action> <resource>
kubectl get pods
ovs-vsctl show
ip addr show
```

**Modify/Create:**
```bash
<tool> <action> <resource> <parameters>
kubectl create service clusterip myapp --tcp=80
ip link add veth0 type veth peer name veth1
ovs-ofctl add-flow br-int "..."
```

**Debug/Troubleshoot:**
```bash
<tool> describe <resource>
<tool> logs <resource>
<tool> exec <resource> -- <command>
```

### Troubleshooting Philosophy

1. **Start broad, narrow down**
   - Check if pods are running
   - Then check if service exists
   - Then check if endpoints exist
   - Then test actual connectivity

2. **Eliminate variables**
   - Test by IP before testing by name (eliminates DNS)
   - Test from another pod (eliminates source pod issues)
   - Test different services (isolates the problem)

3. **Follow the packet**
   - Where does the packet enter?
   - What happens at each hop?
   - Where does it fail?
   - Use tcpdump to verify

4. **Check the basics**
   - Is it running?
   - Are labels correct?
   - Is DNS working?
   - Is there a NetworkPolicy?

### Reading the Cheat Sheets

**Command Format:**
```bash
# Comment explaining what it does
command --option value

# Specific example
ip addr add 192.168.1.100/24 dev eth0
```

**Workflow Sections:**
Numbered steps to follow in order when troubleshooting specific issues.

**Tables:**
Quick reference for values, options, or comparisons.

**Tips & Notes:**
Important information, common gotchas, or best practices.

---

## 🔧 Setting Up Your Environment

### Keep Cheat Sheets Accessible

**Option 1: Local copy**
```bash
# Clone the repo
git clone <repo-url>

# Navigate to cheat sheets
cd ocp-networking-labs/cheat-sheets

# Open in your editor
code .  # VS Code
vim Master_Commands_QuickRef.md
```

**Option 2: Print frequently used sections**
- Master Commands Quick Reference (print this one!)
- Phase-specific troubleshooting workflows
- Command quick reference tables

**Option 3: Browser bookmarks**
- Bookmark each cheat sheet in your browser
- Create a "OCP Networking" bookmark folder

### Practice Environment

Use these cheat sheets while working through the labs:

```bash
# Example workflow:
1. Read lab instructions
2. Open relevant cheat sheet
3. Try commands from cheat sheet
4. Complete lab exercise
5. Refer back to cheat sheet when stuck
```

---

## 📈 Suggested Learning Path

### Week 1-2: Foundation
- Read **Master Quick Reference**
- Work through **Phase 1** cheat sheet
- Practice: Basic networking commands, DNS, routing, iptables
- Goal: Comfortable with fundamental networking

### Week 3-4: Containers
- Review **Master Quick Reference**
- Study **Phase 2** cheat sheet
- Practice: Namespaces, veth pairs, bridges, tcpdump
- Goal: Understand container networking primitives

### Week 5-6: Kubernetes
- Keep **Master Quick Reference** open
- Deep dive **Phase 3** cheat sheet
- Practice: Services, DNS, NetworkPolicy, debugging
- Goal: Debug Kubernetes networking issues

### Week 7: OpenShift
- Use **Master Quick Reference** for basics
- Master **Phase 4** cheat sheet
- Practice: OVS/OVN, Routes, EgressIP
- Goal: Expert-level OpenShift networking

---

## 🎯 Command Frequency Guide

### Use Daily
```bash
oc get pods
oc describe pod <name>
oc logs <name>
oc exec <pod> -- <command>
oc get svc
oc get endpoints
```

### Use Regularly
```bash
oc get routes
oc get networkpolicy
ip addr
ip route
tcpdump
nslookup / dig
```

### Use When Needed
```bash
ovs-vsctl show
ovs-ofctl dump-flows
ovn-nbctl show
iptables -L -v -n
conntrack -L
```

### Use Rarely (But Good to Know)
```bash
ip netns add
ovn-trace
ovs-appctl ofproto/trace
iptables-save
```

---

## 🆘 Emergency Quick Reference

### Service Down
```bash
oc get svc <name> && oc get ep <name>
oc get pods --show-labels
oc run -it --rm test --image=busybox --restart=Never -- wget -qO- http://service
```

### DNS Broken
```bash
oc get pods -n openshift-dns
oc exec <pod> -- nslookup kubernetes.default
oc logs -n openshift-dns <coredns-pod>
```

### Route 503
```bash
oc get route <name>
oc get ep <service-name>
oc get pods
oc logs -n openshift-ingress <router-pod> | grep <route>
```

### Connectivity Issues
```bash
oc exec <pod> -- ping 8.8.8.8
oc exec <pod> -- nslookup google.com
oc get networkpolicy
oc get egressfirewall
```

---

## 📝 Contributing & Feedback

These cheat sheets are living documents. If you find:
- Missing commands
- Errors or outdated information
- Sections that need clarification
- Better ways to organize information

Please provide feedback or submit improvements!

---

## 🔗 Additional Resources

### Related Documentation
- [Main OCP Networking Labs README](../README.md)
- Individual lab files in `week*/labs/` directories
- OpenShift documentation
- Kubernetes documentation

### External References
- `man ip` - IP command manual
- `man iptables` - iptables manual
- `ovs-vsctl --help` - OVS help
- `kubectl explain` - Kubernetes resource documentation
- `oc explain` - OpenShift resource documentation

---

## 🏁 Final Notes

**Remember:**
- These are reference materials, not tutorials
- Practice makes perfect - run these commands!
- Understand what commands do before running in production
- When in doubt, start with the Master Quick Reference
- The best way to learn is to break things (in a lab!) and fix them

**Most important command:**
```bash
--help
```

Every tool has a help flag. Use it liberally!

---

**Happy troubleshooting!** 🚀
