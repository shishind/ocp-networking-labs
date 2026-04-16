# Week 7: Phase 4 - OpenShift Networking Deep Dive

## Overview

**Welcome to Week 7 - The week everything comes together!**

This is the most critical week of the OCP Networking Mastery Plan. Everything you've learned in Weeks 1-6 connects through the OVS/OVN layer you'll master this week.

By the end of Week 7, you'll understand:
- How Open vSwitch (OVS) connects all networking components in OpenShift
- How OpenFlow rules control packet forwarding at a granular level
- How OVN (Open Virtual Network) orchestrates the entire SDN stack
- The 4 fundamental traffic flow patterns that handle ALL OpenShift networking
- How Routes and HAProxy provide ingress to your applications
- How DNS and Egress work in OpenShift

**Week Duration**: 7 days (Days 43-49)  
**Skill Level**: Advanced  
**Prerequisites**: Completion of Weeks 1-6 (especially Week 3 veth pairs and Week 5 Services)

---

## Learning Path

### Foundation Days (Days 43-45): Understanding the Platform

These days build your understanding of the OpenShift SDN architecture from the bottom up.

#### [Day 43: OVS Fundamentals](./D43_OVS_Fundamentals.md)
**Focus**: Open vSwitch bridges and ports

**What you'll learn**:
- The role of OVS in OpenShift networking
- br-int (integration bridge) - where all pod traffic connects
- br-ex (external bridge) - the gateway to the outside world
- How veth pairs from Week 3 connect to br-int
- OVS topology and port mappings

**Key Commands**: `ovs-vsctl show`, `ovs-vsctl list-ports br-int`, `ovs-ofctl show br-int`

**Lab Exercises**:
1. Explore OVS bridges on a worker node
2. Map br-int ports to running pods
3. Examine br-ex and physical network connection
4. Trace the complete path from pod to physical network
5. Monitor OVS statistics in real-time
6. Draw your node's complete OVS topology

**Connection to previous weeks**: See how veth pairs (Week 3) connect to OVS bridges, and how Services (Week 5) traffic flows through br-int.

---

#### [Day 44: OVS Flow Tables](./D44_OVS_Flow_Tables.md)
**Focus**: OpenFlow rules - the "program" that controls OVS

**What you'll learn**:
- How OpenFlow rules make forwarding decisions
- Flow table structure (match conditions and actions)
- Reading and understanding flow syntax
- How to find the specific flow handling your pod's traffic
- Flow priorities and table pipelines

**Key Commands**: `ovs-ofctl dump-flows br-int`, `ovs-ofctl dump-flows br-int table=X`, `ovs-appctl ofproto/trace`

**Lab Exercises**:
1. Dump and read OVS flow tables
2. Find the flow responsible for specific pod traffic
3. Trace a packet through the flow pipeline
4. Understand flow priorities and matching
5. Decode flow actions (set_field, output, resubmit)
6. Compare flows for different traffic types

**Connection to previous weeks**: See how iptables rules (Week 2) and kube-proxy rules (Week 5) relate to OVS flows.

**Why this matters**: OVS flows are programmed by OVN (Day 45). Understanding flows helps you debug when OVN's programming doesn't work as expected.

---

#### [Day 45: OVN Architecture](./D45_OVN_Architecture.md)
**Focus**: OVN - the SDN controller that programs OVS

**What you'll learn**:
- OVN architecture (Northbound DB, Southbound DB, controllers)
- ovnkube-master - the control plane
- ovnkube-node - the data plane agent on each node
- How OVN creates logical networks on top of physical OVS
- Logical switches, logical routers, and logical ports

**Key Commands**: `ovn-nbctl show`, `ovn-sbctl show`, `ovn-nbctl list logical_switch`, `ovn-sbctl list chassis`

**Lab Exercises**:
1. Explore OVN Northbound database (logical network view)
2. Explore OVN Southbound database (physical implementation view)
3. Map pods to OVN logical switch ports
4. Examine OVN logical routers and routes
5. Verify OVN chassis (nodes) and tunnel configuration
6. Understand how OVN programs OVS flows

**Connection to previous weeks**: See how Kubernetes Services (Week 5) map to OVN logical load balancers.

**The big picture**: 
```
Kubernetes API
     ↓
ovnkube-master (reads Services, Pods, etc.)
     ↓
OVN Northbound DB (logical network: "I want pod A to reach pod B")
     ↓
OVN Central (translates logical to physical)
     ↓
OVN Southbound DB (physical instructions: "encapsulate and send via tunnel")
     ↓
ovnkube-node (on each worker)
     ↓
OVS flows (actual packet forwarding rules)
     ↓
br-int (the switch that executes the flows)
```

---

### The Critical Day (Day 46): The 4 Traffic Flow Patterns

#### [Day 46: OVN Traffic Flows](./D46_OVN_Traffic_Flows.md)
**Focus**: The 4 fundamental traffic patterns that explain ALL OpenShift networking

**What you'll learn**:
- **Flow 1**: Pod-to-pod on same node (stays in br-int)
- **Flow 2**: Pod-to-pod across nodes (Geneve tunnel)
- **Flow 3**: Pod-to-Service (OVN load balancing)
- **Flow 4**: Pod-to-external (NAT and routing)
- Step-by-step packet traces for each flow
- How to trace any packet through the system

**Why Day 46 is critical**: These 4 flows explain EVERYTHING. Every packet in OpenShift follows one of these patterns. Master these, and you can troubleshoot any networking issue.

**Lab Exercises**:
1. Trace Flow 1: Same-node pod-to-pod communication
2. Trace Flow 2: Cross-node pod-to-pod communication (Geneve tunneling)
3. Trace Flow 3: Pod accessing a Service (load balancing)
4. Trace Flow 4: Pod accessing external IP (egress NAT)
5. Write out each flow from memory
6. Practice identifying which flow applies to different scenarios

**Connection to previous weeks**: 
- Flow 1 uses veth pairs (Week 3) and OVS (Day 43)
- Flow 2 adds tunneling and OVN (Day 45)
- Flow 3 implements Services (Week 5) via OVN load balancers
- Flow 4 uses NAT (Week 2) and routing (Week 1)

**Study tip**: Draw these 4 flows on paper multiple times until you can reproduce them from memory. They're the foundation for everything else.

---

### Application Days (Days 47-48): Using the Platform

Now that you understand the platform, learn how applications use it.

#### [Day 47: Routes and HAProxy](./D47_Routes_HAProxy.md)
**Focus**: Ingress - how external traffic reaches your applications

**What you'll learn**:
- OpenShift Routes (Layer 7 ingress)
- HAProxy router architecture
- Route types: edge, passthrough, re-encrypt
- TLS termination strategies
- How Routes map to HAProxy configuration

**Key Concepts**:
- **Edge route**: TLS terminates at router, HTTP to pod
- **Passthrough route**: TLS goes directly to pod
- **Re-encrypt route**: TLS terminates at router, new TLS to pod

**Lab Exercises**:
1. Deploy an application with a Service
2. Create an edge route (TLS at router)
3. Create a passthrough route (TLS to pod)
4. Create a re-encrypt route (double encryption)
5. Test each route type with curl
6. Examine HAProxy configuration

**Connection to Day 46**: Routes use Flow 3 (pod-to-Service) internally, but add HAProxy for external ingress.

---

#### [Day 48: DNS and EgressIP](./D48_DNS_EgressIP.md)
**Focus**: DNS resolution and egress IP management

**What you'll learn**:
- DNS Operator and CoreDNS architecture
- How pods resolve service names
- EgressIP - controlling outbound source IP
- EgressNetworkPolicy - restricting outbound access
- EgressFirewall vs NetworkPolicy

**Lab Exercises**:
1. Verify DNS Operator and CoreDNS pods
2. Test service name resolution from pods
3. Assign an EgressIP to a namespace
4. Verify outbound traffic uses the EgressIP
5. Create an EgressNetworkPolicy to restrict access
6. Troubleshoot DNS resolution issues

**Connection to Day 46**: DNS queries use Flow 3 (pod-to-Service to CoreDNS). Egress uses Flow 4 (pod-to-external with NAT).

---

### Integration Day (Day 49): Putting It All Together

#### [Day 49: Week 7 Scenario](./D49_Week7_Scenario.md)
**Focus**: Real-world troubleshooting scenario - "Pods cannot communicate across nodes"

**The Challenge**:
- Pods on different nodes cannot communicate
- Same-node communication works fine
- Services fail cross-node
- You must diagnose and fix using Week 7 skills

**What you'll do**:
1. Verify and document symptoms
2. Check OVN Northbound DB (logical network)
3. Check OVN Southbound DB (tunnels and chassis)
4. Verify node-to-node network connectivity
5. Examine OVS flows on source and destination nodes
6. Apply the 4-flow framework to trace the packet
7. Identify the root cause
8. Fix the issue
9. Validate the fix
10. Write a post-mortem

**Common root causes**:
- OVN tunnels not configured (ovnkube-node not running)
- Firewall blocking Geneve (port 6081/UDP)
- MTU issues causing packet drops
- OVN database sync issues
- Network misconfiguration

**Skills applied**: Everything from Days 43-48, plus systematic troubleshooting methodology.

**Why this scenario**: Cross-node communication is the most complex case - it requires OVS, OVN, flows, tunnels, and node networking to all work together. Fix this, and you can fix anything.

---

## Daily Lab Structure

Each day's lab follows this format:

1. **Learning Objectives** - What you'll master today
2. **Plain English Explanation** - Complex concepts explained clearly
3. **Hands-On Lab** - 5-6 practical exercises with real commands
4. **Self-Check Questions** - Test your understanding (with answers)
5. **Today I Learned (TIL)** - Reflection template
6. **Commands Cheat Sheet** - Quick reference for today's commands
7. **What's Next** - Connection to tomorrow's topic

---

## Week 7 Learning Outcomes

By the end of Week 7, you will be able to:

### Knowledge
- Explain the complete OpenShift SDN stack from OVS to OVN to pod networking
- Describe how the 4 traffic flow patterns handle all networking scenarios
- Understand the relationship between OVN logical networks and OVS physical flows
- Explain how Routes, Services, and DNS work together for application access

### Skills
- Navigate OVS bridges and ports on any OpenShift node
- Read and interpret OpenFlow rules in flow tables
- Query OVN Northbound and Southbound databases
- Trace a packet hop-by-hop through any of the 4 traffic patterns
- Diagnose cross-node communication issues
- Verify tunnel configuration and health
- Create and manage Routes with different TLS configurations
- Configure EgressIP and EgressNetworkPolicy

### Troubleshooting
- Diagnose why pods can't communicate across nodes
- Identify which layer (OVS, OVN, network, firewall) has the problem
- Use the 4-flow framework to systematically trace issues
- Fix common OVN/OVS problems (missing flows, broken tunnels, MTU issues)
- Validate fixes using multiple verification methods

---

## Prerequisites

### Required Knowledge (from previous weeks)
- **Week 1-2**: Linux networking (iptables, routing, NAT, namespaces)
- **Week 3**: Container networking (veth pairs, bridge networking, CNI)
- **Week 4-5**: Kubernetes networking (Services, Endpoints, kube-proxy, DNS)
- **Week 6**: OpenShift SDN overview and cluster networking concepts

### Required Tools
- Access to an OpenShift cluster (4.x)
- Ability to run `oc debug node/<nodename>` (cluster-admin or equivalent)
- SSH or debug access to worker nodes
- Ability to deploy test pods and services

### Recommended Setup
```bash
# Verify cluster access
oc whoami
oc get nodes

# Verify you can debug nodes
oc debug node/<worker-node-name>

# Install helpful tools in debug pods
oc debug node/<node> -- chroot /host yum install -y tcpdump
```

---

## Study Tips for Week 7

### This Week is Different
Week 7 is conceptually dense. You're learning the "operating system" of OpenShift networking. Take your time and be patient with yourself.

### Recommended Approach

**Days 43-45 (Foundation)**:
- Read each day's explanation fully before starting labs
- Draw diagrams as you go - OVS topology, flow tables, OVN architecture
- Don't rush - understanding is more important than speed
- Make notes about how concepts connect to previous weeks

**Day 46 (Critical Day)**:
- Budget extra time - this is the most important day
- Do each traffic flow trace multiple times
- Draw the 4 flows on paper from memory
- Create flashcards for each flow pattern
- This day is worth reviewing even after Week 7

**Days 47-48 (Application)**:
- These should feel easier after Days 43-46
- Focus on how these features use the underlying flows
- Practice creating and testing each configuration

**Day 49 (Integration)**:
- Treat this like a real production incident
- Take detailed notes at each diagnostic step
- Don't skip to the solution - work through it systematically
- Write the post-mortem even if you get stuck

### Learning Techniques

**Visual Learners**:
- Draw the OVS topology for your cluster
- Create flowcharts for the 4 traffic patterns
- Sketch how packets flow through each layer

**Hands-on Learners**:
- Run every command in the labs
- Try variations (what if I change X?)
- Break things intentionally and fix them

**Reading/Writing Learners**:
- Fill out all TIL templates
- Write explanations in your own words
- Create your own cheat sheets

### Common Challenges

**Challenge 1**: "OVS flow syntax is confusing"
- Start with simple flows and build up
- Use the Day 44 decoder to translate each part
- Focus on match conditions first, then actions

**Challenge 2**: "I can't remember all 4 flows"
- Draw them out multiple times
- Teach them to someone else (rubber duck debugging)
- Create mnemonics or stories for each flow

**Challenge 3**: "I don't understand how OVN and OVS relate"
- Think: OVN is the "planner", OVS is the "worker"
- OVN says "what should happen", OVS does "how it happens"
- Review the Day 45 architecture diagram

**Challenge 4**: "The scenario (Day 49) is too complex"
- Break it into smaller steps
- Use the 4-flow framework to eliminate possibilities
- Don't try to solve it all at once - diagnose first, then fix

---

## How Week 7 Connects to the Overall Plan

```
Phase 1 (Weeks 1-2): Foundation
├─ Linux networking fundamentals
└─ iptables, routing, namespaces

Phase 2 (Weeks 3-4): Container Networking  
├─ veth pairs, bridges
└─ CNI plugins

Phase 3 (Weeks 5-6): Kubernetes Networking
├─ Services and Endpoints
├─ kube-proxy and load balancing
└─ DNS and NetworkPolicy

Phase 4 (Week 7): OpenShift Deep Dive ← YOU ARE HERE
├─ OVS: Where veth pairs connect
├─ OVN: How Services are implemented
├─ Flows: The "program" that makes it work
└─ 4 Patterns: The complete picture

Phase 5 (Week 8): Performance & Security
├─ Performance tuning (uses Week 7 knowledge)
├─ Security policies (builds on OVN)
└─ Advanced troubleshooting (applies 4 flows)
```

**Week 7 is the integration point**: Everything you learned in Weeks 1-6 connects through the OVS/OVN layer. After this week, you'll see the complete picture of how a packet travels from source to destination in OpenShift.

---

## Quick Reference: The 4 Traffic Flow Patterns

### Flow 1: Pod-to-Pod (Same Node)
```
Pod A --eth0--> veth --br-int--> veth --eth0--> Pod B
```
**Key Point**: Never leaves br-int, fastest path

---

### Flow 2: Pod-to-Pod (Cross Node)
```
Pod A --veth--> br-int (node1) --Geneve--> network --Geneve--> br-int (node2) --veth--> Pod B
```
**Key Point**: Geneve tunnel encapsulates the packet, tunnel IPs are node IPs

---

### Flow 3: Pod-to-Service
```
Pod A --veth--> br-int --OVN LB--> {Pod B, Pod C, Pod D} (one selected)
```
**Key Point**: OVN load balancer (not kube-proxy) selects endpoint, then follows Flow 1 or 2

---

### Flow 4: Pod-to-External
```
Pod A --veth--> br-int --NAT--> br-ex --eth0--> external network
```
**Key Point**: Source NAT changes pod IP to node IP or EgressIP

---

## Essential Commands Quick Reference

### OVS Bridge Commands
```bash
ovs-vsctl show                    # Complete OVS configuration
ovs-vsctl list-br                 # List all bridges
ovs-vsctl list-ports br-int       # List ports on br-int
ovs-ofctl show br-int             # Show OpenFlow port mappings
ovs-ofctl dump-flows br-int       # Dump all flow rules
```

### OVN Commands
```bash
# On OVN master pod:
ovn-nbctl show                    # Logical network (Northbound DB)
ovn-sbctl show                    # Physical implementation (Southbound DB)
ovn-nbctl list logical_switch     # List logical switches
ovn-sbctl list chassis            # List nodes and tunnels
```

### Node Access
```bash
oc debug node/<node-name>         # Get shell on node
chroot /host                      # Access host filesystem
```

### Diagnostic Commands
```bash
# Connectivity tests
oc exec <pod> -- ping <target-ip>

# Network interfaces
oc exec <pod> -- ip addr show
oc exec <pod> -- ip route show

# DNS
oc exec <pod> -- nslookup <service-name>

# Service endpoints
oc get endpoints <service-name>
```

---

## Resources

### Reference Materials
- [OpenShift SDN Architecture](https://docs.openshift.com/container-platform/latest/networking/openshift_sdn/about-openshift-sdn.html)
- [OVN-Kubernetes Architecture](https://docs.openshift.com/container-platform/latest/networking/ovn_kubernetes_network_provider/about-ovn-kubernetes.html)
- [OVS Documentation](http://www.openvswitch.org/support/dist-docs/)
- [OVN Documentation](https://www.ovn.org/support/dist-docs/)

### Week 7 Lab Files
- [Day 43: OVS Fundamentals](./D43_OVS_Fundamentals.md) - Bridges and ports
- [Day 44: OVS Flow Tables](./D44_OVS_Flow_Tables.md) - OpenFlow rules
- [Day 45: OVN Architecture](./D45_OVN_Architecture.md) - SDN controller
- [Day 46: OVN Traffic Flows](./D46_OVN_Traffic_Flows.md) - The 4 patterns ⭐
- [Day 47: Routes and HAProxy](./D47_Routes_HAProxy.md) - Ingress
- [Day 48: DNS and EgressIP](./D48_DNS_EgressIP.md) - DNS and egress
- [Day 49: Week 7 Scenario](./D49_Week7_Scenario.md) - Troubleshooting challenge

---

## Week 7 Completion Checklist

Use this to track your progress through the week:

```
Week 7 Progress Tracker

Foundation Days:
[ ] Day 43: OVS Fundamentals
    [ ] Can explain br-int vs br-ex
    [ ] Can list ports on br-int
    [ ] Can map veth pairs to pods
    [ ] Drew OVS topology diagram
    
[ ] Day 44: OVS Flow Tables
    [ ] Can read OpenFlow rules
    [ ] Can find flow for specific traffic
    [ ] Understand match conditions
    [ ] Understand flow actions
    
[ ] Day 45: OVN Architecture
    [ ] Understand Northbound vs Southbound DB
    [ ] Can query OVN databases
    [ ] Understand logical vs physical networks
    [ ] Know role of ovnkube-master and ovnkube-node

Critical Day:
[ ] Day 46: OVN Traffic Flows ⭐ MOST IMPORTANT
    [ ] Can trace Flow 1 (same-node pod-to-pod)
    [ ] Can trace Flow 2 (cross-node pod-to-pod)
    [ ] Can trace Flow 3 (pod-to-service)
    [ ] Can trace Flow 4 (pod-to-external)
    [ ] Can draw all 4 flows from memory
    [ ] Understand Geneve tunneling

Application Days:
[ ] Day 47: Routes and HAProxy
    [ ] Created edge route
    [ ] Created passthrough route
    [ ] Created re-encrypt route
    [ ] Tested TLS termination
    
[ ] Day 48: DNS and EgressIP
    [ ] Verified DNS operator
    [ ] Configured EgressIP
    [ ] Created EgressNetworkPolicy
    [ ] Tested egress restrictions

Integration Day:
[ ] Day 49: Week 7 Scenario
    [ ] Diagnosed cross-node communication issue
    [ ] Used OVN commands to check configuration
    [ ] Used OVS commands to check flows
    [ ] Applied 4-flow framework
    [ ] Fixed the issue
    [ ] Validated the fix
    [ ] Wrote post-mortem

Overall Week 7:
[ ] Completed all 7 daily labs
[ ] Filled out all TIL templates
[ ] Can explain how OVS, OVN, and flows connect
[ ] Can troubleshoot cross-node networking issues
[ ] Ready for Week 8 (Performance & Security)
```

---

## Getting Help

### If You Get Stuck

1. **Re-read the Plain English Explanation** - Often the answer is there
2. **Check the Commands Cheat Sheet** - Make sure you're using the right syntax
3. **Review Previous Weeks** - Many concepts build on earlier material
4. **Draw It Out** - Visualizing often clarifies confusion
5. **Take a Break** - Complex topics sometimes need time to sink in

### Common Issues and Solutions

**Issue**: "I can't access nodes with oc debug"
- **Solution**: Check your cluster-admin permissions, or ask your cluster admin for debug access

**Issue**: "ovs-vsctl commands don't work in debug pod"
- **Solution**: Make sure you ran `chroot /host` after entering the debug pod

**Issue**: "OVN commands fail with 'command not found'"
- **Solution**: OVN commands must be run inside the ovnkube-master or ovnkube-node pods, not on nodes directly

**Issue**: "I don't have test pods to experiment with"
- **Solution**: Create simple test pods:
  ```bash
  oc run testpod --image=registry.redhat.io/rhel8/support-tools:latest -- sleep 3600
  ```

**Issue**: "The 4 flows are overwhelming"
- **Solution**: Master them one at a time. Flow 1 is simplest, start there. Don't move to Flow 2 until Flow 1 makes sense.

---

## What Makes Week 7 Special

Week 7 is where you go from **using** OpenShift networking to **understanding** it. You're no longer just running commands - you're seeing how every component connects:

- How your pod's `eth0` (Week 3) connects through a veth pair to br-int (Day 43)
- How br-int uses OpenFlow rules (Day 44) programmed by OVN (Day 45)
- How Services (Week 5) are implemented as OVN load balancers (Day 46)
- How ingress Routes (Day 47) and egress NAT (Day 48) fit into the flows
- How to diagnose complex issues using the complete picture (Day 49)

After Week 7, you'll never look at OpenShift networking the same way. You'll see the elegant design behind it all.

**This is the week where it all clicks. Enjoy the journey!**

---

## Next Steps

After completing Week 7:

1. **Review and Reinforce**: The 4 flows are critical - review Day 46 again after a few days
2. **Practice**: Set up scenarios and practice troubleshooting
3. **Move to Week 8**: Performance tuning, security, and advanced troubleshooting
4. **Real-World Application**: Apply Week 7 knowledge to your actual cluster issues

---

**Ready to begin?** Start with [Day 43: OVS Fundamentals](./D43_OVS_Fundamentals.md)

**Questions?** Review the "Getting Help" section above or revisit previous weeks' material.

**Remember**: This is advanced material. Take your time, be patient, and focus on understanding over speed. The investment you make this week will pay off in every OpenShift networking task you do in the future.

Good luck, and enjoy mastering the heart of OpenShift networking!
