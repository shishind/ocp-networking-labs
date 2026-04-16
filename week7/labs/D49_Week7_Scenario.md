# Day 49: Week 7 Scenario - Pods Cannot Communicate Across Nodes

**Week 7, Day 49: Weekend Troubleshooting Scenario**

---

## Scenario Overview

**Your Mission**: Pods on different nodes cannot communicate with each other. Pod-to-pod traffic works fine when pods are on the same node, but fails when pods are on different nodes.

This is the culmination of Week 7 - you'll use everything you've learned about OVS, OVN, flow tables, and the 4 OVN traffic patterns to diagnose and fix this critical issue.

**Symptoms**:
- Pod A on node1 can ping Pod B on node1 ✓
- Pod C on node2 can ping Pod D on node2 ✓
- Pod A on node1 CANNOT ping Pod C on node2 ✗
- Services work locally but fail cross-node ✗
- DNS works (same-node DNS pods) ✓

**Your Tools**:
- OVS commands (Days 43-44)
- OVN commands (Day 45)
- 4 OVN traffic flow framework (Day 46)
- Your understanding of how it all connects together

---

## Learning Objectives

By the end of this scenario, you will be able to:

1. Apply the 4 OVN traffic flow patterns to diagnose cross-node connectivity issues
2. Use OVS flow tables to identify where packets are being dropped
3. Verify OVN tunnel (Geneve) configuration between nodes
4. Check OVN Northbound and Southbound databases for configuration issues
5. Trace a packet hop-by-hop through the entire cross-node path
6. Fix common cross-node networking problems in OpenShift
7. Validate the fix using multiple verification methods

---

## Plain English Explanation

### Why Cross-Node Traffic is Different

Remember from Day 46 that cross-node pod-to-pod traffic follows this pattern:

```
Pod A (node1) --> veth --> br-int (node1) --> Geneve tunnel -->
  --> br-int (node2) --> veth --> Pod B (node2)
```

This is different from same-node traffic which stays entirely within br-int:

```
Pod A (node1) --> veth --> br-int (node1) --> veth --> Pod B (node1)
```

**What could go wrong?**

Cross-node traffic requires several things to work:
1. **OVN tunnels must be established** between nodes (using Geneve protocol)
2. **OVS flow tables must forward traffic to the right tunnel** on the source node
3. **The tunnel must be able to reach the other node** (firewall, network config)
4. **OVS flow tables must accept traffic from the tunnel** on the destination node
5. **OVN must know about both pods** and their locations

If any of these fail, cross-node traffic breaks while same-node traffic continues working.

### The Diagnostic Framework

We'll use a systematic approach:

**Step 1: Verify OVN knows about both pods** (Northbound DB)
- Are both pods in the OVN logical switch?
- Do they have the correct IP and MAC addresses?
- Are they associated with the right nodes?

**Step 2: Check OVN has programmed the flows** (Southbound DB)
- Are there flows for cross-node forwarding?
- Are the tunnel endpoints correct?

**Step 3: Verify OVS has the flows** (Physical flows on br-int)
- Can you find a flow that matches your pod's traffic?
- Does it have an action to send to a tunnel?

**Step 4: Check the tunnel itself**
- Does the tunnel interface exist?
- Can the nodes reach each other on the tunnel network?
- Is the Geneve port (6081) open?

**Step 5: Trace the return path**
- Same checks in reverse direction

### Common Root Causes

Based on this scenario pattern, common causes are:
- OVN tunnel ports not created (ovnkube-node not running)
- Firewall blocking Geneve (port 6081/UDP)
- MTU issues causing tunnel packets to be dropped
- OVN database sync issues
- Node network misconfiguration

---

## Hands-On Lab

### Environment Setup

You'll need:
- Access to two worker nodes (node1 and node2)
- At least two pods running on different nodes
- Ability to run `oc debug node/<nodename>`

**Set up test pods:**

```bash
# Create a test deployment with 2 replicas
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nettest
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nettest
  template:
    metadata:
      labels:
        app: nettest
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - nettest
            topologyKey: kubernetes.io/hostname
      containers:
      - name: nettools
        image: registry.redhat.io/rhel8/support-tools:latest
        command: ['sleep', '3600']
EOF

# Wait for pods to be running
oc wait --for=condition=ready pod -l app=nettest --timeout=120s

# Verify pods are on different nodes
oc get pods -l app=nettest -o wide

# Note the pod names and their nodes
POD1=$(oc get pods -l app=nettest -o jsonpath='{.items[0].metadata.name}')
POD2=$(oc get pods -l app=nettest -o jsonpath='{.items[1].metadata.name}')
NODE1=$(oc get pod $POD1 -o jsonpath='{.spec.nodeName}')
NODE2=$(oc get pod $POD2 -o jsonpath='{.spec.nodeName}')
POD1_IP=$(oc get pod $POD1 -o jsonpath='{.status.podIP}')
POD2_IP=$(oc get pod $POD2 -o jsonpath='{.status.podIP}')

echo "Pod 1: $POD1 on $NODE1 with IP $POD1_IP"
echo "Pod 2: $POD2 on $NODE2 with IP $POD2_IP"
```

### Exercise 1: Confirm the Problem

**Goal**: Verify and document the exact symptoms.

```bash
# Test same-node connectivity (should work)
# Get another pod on NODE1
OTHER_POD_NODE1=$(oc get pods -A -o wide --field-selector spec.nodeName=$NODE1 --no-headers | head -1 | awk '{print $2}')
OTHER_POD_NODE1_NS=$(oc get pods -A -o wide --field-selector spec.nodeName=$NODE1 --no-headers | head -1 | awk '{print $1}')
OTHER_POD_NODE1_IP=$(oc get pod $OTHER_POD_NODE1 -n $OTHER_POD_NODE1_NS -o jsonpath='{.status.podIP}')

# Test from POD1 to another pod on same node
oc exec $POD1 -- ping -c 3 $OTHER_POD_NODE1_IP
# Expected: SUCCESS (same node)

# Test cross-node connectivity (this is broken)
oc exec $POD1 -- ping -c 3 $POD2_IP
# Expected: FAILURE or timeout

# Try the reverse direction
oc exec $POD2 -- ping -c 3 $POD1_IP
# Expected: Also fails

# Test if DNS works (usually works because CoreDNS might be on same node)
oc exec $POD1 -- nslookup kubernetes.default
# Expected: Usually works

# Create a test file documenting symptoms
cat <<EOF > /tmp/scenario-symptoms.txt
SCENARIO: Cross-node pod communication failure
DATE: $(date)

SYMPTOMS:
- Same-node pod communication: WORKING
  POD1 ($POD1_IP) -> Other pod on $NODE1 ($OTHER_POD_NODE1_IP): SUCCESS

- Cross-node pod communication: FAILED
  POD1 on $NODE1 ($POD1_IP) -> POD2 on $NODE2 ($POD2_IP): TIMEOUT
  POD2 on $NODE2 ($POD2_IP) -> POD1 on $NODE1 ($POD1_IP): TIMEOUT

- DNS resolution: WORKING

HYPOTHESIS: Issue with cross-node forwarding (OVN tunnels or flows)
EOF

cat /tmp/scenario-symptoms.txt
```

### Exercise 2: Check OVN Layer - Logical Network (Day 45 Skills)

**Goal**: Verify OVN knows about both pods and should be routing between them.

```bash
# Access a master/control-plane node to check OVN NB database
# (OVN NB database is on the masters)
oc get nodes -l node-role.kubernetes.io/master

# Get shell on OVN master pod
OVN_MASTER_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o jsonpath='{.items[0].metadata.name}')
echo "Using OVN master pod: $OVN_MASTER_POD"

# Check OVN logical switch (this is the "cluster-wide network")
oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-nbctl show

# Look for your pods in the output
# You should see entries like:
#   switch <uuid> (node1)
#     port default_nettest-xxx
#       addresses: ["<mac> <ip>"]

# Specifically check if both pods are in the logical switch
oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-nbctl find logical_switch_port name=default_${POD1}

oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-nbctl find logical_switch_port name=default_${POD2}

# Check logical routers (should exist and connect the switches)
oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-nbctl lr-list

# Check the cluster router
oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-nbctl lr-route-list ovn_cluster_router

# Document findings
cat <<EOF >> /tmp/scenario-diagnosis.txt

=== OVN NORTHBOUND DATABASE CHECK ===
Date: $(date)

POD1 in NB DB: $(oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-nbctl find logical_switch_port name=default_${POD1} 2>/dev/null | grep -q "name" && echo "FOUND" || echo "NOT FOUND")

POD2 in NB DB: $(oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-nbctl find logical_switch_port name=default_${POD2} 2>/dev/null | grep -q "name" && echo "FOUND" || echo "NOT FOUND")

Logical routers: $(oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-nbctl lr-list | wc -l) found

CONCLUSION: OVN logical network is [ CORRECT / INCORRECT ]
EOF

cat /tmp/scenario-diagnosis.txt
```

### Exercise 3: Check OVN Southbound - Tunnel Configuration

**Goal**: Verify OVN has created tunnel endpoints between the nodes.

```bash
# Check Southbound database for chassis (nodes)
oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-sbctl show

# You should see something like:
# Chassis "node1"
#   hostname: node1.example.com
#   Encap geneve
#     ip: "<node1-IP>"
# Chassis "node2"
#   hostname: node2.example.com  
#   Encap geneve
#     ip: "<node2-IP>"

# Specifically look for tunnel encapsulation
oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-sbctl list encap

# Check if tunnels are configured correctly
oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-sbctl find chassis hostname=$NODE1
oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-sbctl find chassis hostname=$NODE2

# The key things to verify:
# 1. Both chassis exist
# 2. Both have encap type "geneve"
# 3. The IP addresses are reachable between nodes

# Get the tunnel IPs
NODE1_TUNNEL_IP=$(oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-sbctl find chassis hostname=$NODE1 | grep -A 5 "encaps" | grep "ip " | cut -d'"' -f2)
NODE2_TUNNEL_IP=$(oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-sbctl find chassis hostname=$NODE2 | grep -A 5 "encaps" | grep "ip " | cut -d'"' -f2)

echo "Node1 tunnel IP: $NODE1_TUNNEL_IP"
echo "Node2 tunnel IP: $NODE2_TUNNEL_IP"

# Document
cat <<EOF >> /tmp/scenario-diagnosis.txt

=== OVN SOUTHBOUND DATABASE CHECK ===
NODE1 chassis: $(oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-sbctl find chassis hostname=$NODE1 | grep -q "hostname" && echo "FOUND" || echo "NOT FOUND")
NODE1 tunnel IP: $NODE1_TUNNEL_IP

NODE2 chassis: $(oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-sbctl find chassis hostname=$NODE2 | grep -q "hostname" && echo "FOUND" || echo "NOT FOUND")
NODE2 tunnel IP: $NODE2_TUNNEL_IP

Tunnel type: geneve
Tunnel port: 6081/UDP

CONCLUSION: OVN tunnels [ ARE / ARE NOT ] configured
EOF

cat /tmp/scenario-diagnosis.txt
```

### Exercise 4: Verify Node-to-Node Connectivity (The Tunnel Network)

**Goal**: Check if the nodes can actually reach each other on the tunnel network.

```bash
# Test if NODE1 can reach NODE2's tunnel IP
oc debug node/$NODE1 -- chroot /host ping -c 3 $NODE2_TUNNEL_IP

# Test reverse direction
oc debug node/$NODE2 -- chroot /host ping -c 3 $NODE1_TUNNEL_IP

# Check if Geneve port (6081/UDP) is reachable
# This is tricky with UDP, but we can check if it's listening
oc debug node/$NODE1 -- chroot /host ss -ulnp | grep 6081

oc debug node/$NODE2 -- chroot /host ss -ulnp | grep 6081

# Check firewall rules (iptables or firewalld)
oc debug node/$NODE1 -- chroot /host iptables -L -n | grep 6081
oc debug node/$NODE1 -- chroot /host firewall-cmd --list-all 2>/dev/null || echo "firewalld not running"

# Check for any NetworkPolicy or firewall blocking
oc debug node/$NODE1 -- chroot /host iptables -L -n -v | grep -A 5 -B 5 "6081"

# Document findings
cat <<EOF >> /tmp/scenario-diagnosis.txt

=== NODE-TO-NODE CONNECTIVITY CHECK ===
NODE1 -> NODE2 tunnel IP ($NODE2_TUNNEL_IP): $(oc debug node/$NODE1 -- chroot /host ping -c 1 -W 2 $NODE2_TUNNEL_IP >/dev/null 2>&1 && echo "SUCCESS" || echo "FAILED")

NODE2 -> NODE1 tunnel IP ($NODE1_TUNNEL_IP): $(oc debug node/$NODE2 -- chroot /host ping -c 1 -W 2 $NODE1_TUNNEL_IP >/dev/null 2>&1 && echo "SUCCESS" || echo "FAILED")

Geneve port listening on NODE1: $(oc debug node/$NODE1 -- chroot /host ss -ulnp 2>/dev/null | grep -q 6081 && echo "YES" || echo "NO")

Geneve port listening on NODE2: $(oc debug node/$NODE2 -- chroot /host ss -ulnp 2>/dev/null | grep -q 6081 && echo "YES" || echo "NO")

CONCLUSION: Tunnel network connectivity is [ GOOD / BROKEN ]
EOF

cat /tmp/scenario-diagnosis.txt
```

**CRITICAL**: If nodes cannot ping each other's tunnel IPs, this is your problem! Jump to Exercise 8 for the fix.

### Exercise 5: Check OVS Flows on Source Node (Day 44 Skills)

**Goal**: Verify br-int has flows to forward traffic to the tunnel.

```bash
# Get shell on NODE1 (where POD1 is running)
oc debug node/$NODE1

# In the debug pod:
chroot /host

# First, find the OVS port for POD1's veth
POD1_VETH=$(ovs-vsctl list-ports br-int | grep -v patch | grep -v ovn | head -1)
echo "POD1's veth on br-int: $POD1_VETH"

# Get the OpenFlow port number for this veth
POD1_OF_PORT=$(ovs-ofctl show br-int | grep $POD1_VETH | awk '{print $1}' | cut -d'(' -f1)
echo "POD1's OpenFlow port number: $POD1_OF_PORT"

# Now look for flows that match traffic FROM this port TO POD2's IP
# Remember POD2_IP from earlier
ovs-ofctl dump-flows br-int | grep $POD2_IP

# More broadly, look at table 0 (ingress from pod)
ovs-ofctl dump-flows br-int table=0 | grep "in_port=$POD1_OF_PORT"

# Check if there are flows for tunnel forwarding
# Look for flows with output to ovn-k8s-mp0 or genev_sys_* 
ovs-ofctl dump-flows br-int | grep -E "genev|tunnel"

# List all tunnel interfaces
ip link show | grep genev

# Check tunnel ports on OVS
ovs-vsctl show | grep -A 5 "type: geneve"

# Examine a specific flow (example - your flow will be different)
# This should show an action like set_field,output:tunnel
ovs-ofctl dump-flows br-int table=0 -O OpenFlow13

# Document findings
cat <<EOF >> /tmp/scenario-diagnosis.txt

=== OVS FLOWS ON SOURCE NODE ($NODE1) ===
POD1 veth: $POD1_VETH
POD1 OpenFlow port: $POD1_OF_PORT

Flows matching POD2 IP ($POD2_IP): $(ovs-ofctl dump-flows br-int | grep -c $POD2_IP) flows found

Tunnel interfaces: $(ip link show | grep -c genev) found

Geneve tunnels on OVS: $(ovs-vsctl show | grep -c "type: geneve") found

CONCLUSION: OVS flows for cross-node forwarding [ EXIST / MISSING ]
EOF

# Exit debug pod
exit
exit

cat /tmp/scenario-diagnosis.txt
```

### Exercise 6: Check OVS Flows on Destination Node

**Goal**: Verify the destination node accepts traffic from the tunnel.

```bash
# Get shell on NODE2 (where POD2 is running)
oc debug node/$NODE2
chroot /host

# Find POD2's veth
POD2_VETH=$(ovs-vsctl list-ports br-int | grep -v patch | grep -v ovn | head -1)
echo "POD2's veth on br-int: $POD2_VETH"

# Check for flows that output to this port
POD2_OF_PORT=$(ovs-ofctl show br-int | grep $POD2_VETH | awk '{print $1}' | cut -d'(' -f1)
ovs-ofctl dump-flows br-int | grep "output:$POD2_OF_PORT"

# Check for flows accepting traffic from tunnel
ovs-ofctl dump-flows br-int | grep "genev" | grep $POD2_IP

# Look at table structure
ovs-ofctl dump-flows br-int table=0 | head -20

# Exit
exit
exit
```

### Exercise 7: Apply the 4-Flow Framework (Day 46 Skills)

**Goal**: Trace the complete path using the cross-node pod-to-pod flow pattern.

```bash
# Let's trace the path from POD1 to POD2
# According to Day 46, the flow should be:
# 1. Pod A sends packet (src: POD1_IP, dst: POD2_IP)
# 2. veth pair to br-int on NODE1
# 3. OVS flow on br-int looks up destination
# 4. Flow matches -> encapsulate in Geneve tunnel to NODE2
# 5. Packet sent to NODE2_TUNNEL_IP:6081
# 6. NODE2 receives Geneve packet
# 7. Decapsulates and sends to br-int
# 8. br-int flow forwards to POD2's veth
# 9. POD2 receives packet

# Create a detailed trace document
cat <<EOF > /tmp/cross-node-flow-trace.txt
=== CROSS-NODE POD-TO-POD FLOW TRACE ===
Source: $POD1 ($POD1_IP) on $NODE1
Destination: $POD2 ($POD2_IP) on $NODE2

EXPECTED PATH (Day 46 Framework - Flow Pattern 2):

[Step 1] Packet created in POD1
  - Source IP: $POD1_IP
  - Dest IP: $POD2_IP
  - Source MAC: <pod1-mac>
  - Dest MAC: <gateway-mac>

[Step 2] Packet exits POD1 via eth0 (inside pod netns)

[Step 3] Packet arrives on $POD1_VETH (on br-int, NODE1)
  - OpenFlow port: $POD1_OF_PORT

[Step 4] OVS br-int table=0 on NODE1
  - Match: in_port=$POD1_OF_PORT, ip, nw_dst=$POD2_IP
  - Action: Should be "encapsulate in Geneve, send to tunnel"
  - ACTUAL: [ TO BE VERIFIED ]

[Step 5] If flow exists, packet is encapsulated:
  - Outer IP src: $NODE1_TUNNEL_IP
  - Outer IP dst: $NODE2_TUNNEL_IP
  - Outer UDP port: 6081 (Geneve)
  - Inner packet: original POD1->POD2 packet

[Step 6] Encapsulated packet sent over physical network
  - NODE1 br-ex -> eth0 -> network -> NODE2 eth0 -> br-ex
  - Can this reach? [ TO BE VERIFIED ]

[Step 7] NODE2 receives on UDP port 6081
  - Listening? [ TO BE VERIFIED ]

[Step 8] NODE2 decapsulates and sends to br-int

[Step 9] OVS br-int on NODE2
  - Match: tunnel, nw_dst=$POD2_IP
  - Action: output to POD2's veth port $POD2_OF_PORT
  - ACTUAL: [ TO BE VERIFIED ]

[Step 10] Packet arrives on POD2's veth and into pod

VERIFICATION CHECKLIST:
[ ] Step 4: Flow exists on NODE1
[ ] Step 5: Geneve encapsulation configured
[ ] Step 6: NODE1 can reach NODE2 tunnel IP
[ ] Step 7: NODE2 listening on port 6081
[ ] Step 9: Flow exists on NODE2
[ ] Return path verified (reverse direction)
EOF

cat /tmp/cross-node-flow-trace.txt
```

### Exercise 8: Identify and Fix the Root Cause

**Goal**: Based on your diagnosis, identify which step is failing and fix it.

**Common scenarios and fixes:**

#### Scenario A: Nodes cannot reach each other's tunnel IPs

```bash
# DIAGNOSIS: From Exercise 4, nodes can't ping each other
# CAUSE: Network connectivity issue or firewall

# Fix 1: Check if tunnel IPs are on the correct interface
oc debug node/$NODE1 -- chroot /host ip addr show

# The tunnel IP should be on the primary interface (eth0, ens3, etc.)
# or on br-ex

# Fix 2: Check firewall (if firewalld is running)
oc debug node/$NODE1 -- chroot /host firewall-cmd --add-port=6081/udp --permanent
oc debug node/$NODE1 -- chroot /host firewall-cmd --reload

oc debug node/$NODE2 -- chroot /host firewall-cmd --add-port=6081/udp --permanent
oc debug node/$NODE2 -- chroot /host firewall-cmd --reload

# Fix 3: Check iptables directly
oc debug node/$NODE1 -- chroot /host iptables -I INPUT -p udp --dport 6081 -j ACCEPT
oc debug node/$NODE2 -- chroot /host iptables -I INPUT -p udp --dport 6081 -j ACCEPT

# Note: These iptables rules won't persist - this is for testing
# In production, you'd need to fix the underlying firewall config
```

#### Scenario B: OVN tunnels not configured (missing in ovn-sbctl)

```bash
# DIAGNOSIS: From Exercise 3, chassis not in Southbound DB
# CAUSE: ovnkube-node pods not running or unhealthy

# Check ovnkube-node pods
oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-node -o wide

# Check logs for errors
oc logs -n openshift-ovn-kubernetes -l app=ovnkube-node --tail=50

# Restart ovnkube-node on the problematic node
# Find the pod running on that node
OVN_NODE_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-node -o wide | grep $NODE1 | awk '{print $1}')
oc delete pod -n openshift-ovn-kubernetes $OVN_NODE_POD

# Wait for it to restart
oc wait --for=condition=ready pod -n openshift-ovn-kubernetes -l app=ovnkube-node --timeout=120s

# Re-check Southbound DB
oc exec -n openshift-ovn-kubernetes $OVN_MASTER_POD -- ovn-sbctl show
```

#### Scenario C: OVS flows missing on nodes

```bash
# DIAGNOSIS: From Exercise 5, no flows for cross-node forwarding
# CAUSE: OVN not programming flows, or OVS not applying them

# Check OVN controller on the node
oc debug node/$NODE1
chroot /host

# Check ovn-controller status
systemctl status ovn-controller
# or if containerized:
# crictl ps | grep ovn-controller

# Check ovn-controller logs
journalctl -u ovn-controller -n 100

# Force OVN to recompute flows
# Restart ovnkube-node pod (from Scenario B)

# Or manually restart ovs-vswitchd (careful!)
systemctl restart openvswitch
systemctl restart ovs-vswitchd
```

#### Scenario D: MTU issues causing packet drops

```bash
# DIAGNOSIS: Some packets work, others don't (especially large packets)
# CAUSE: MTU mismatch - Geneve adds ~50 bytes overhead

# Check MTU settings
oc debug node/$NODE1 -- chroot /host ip link show

# Physical interface should have MTU 1500 or higher
# br-int, br-ex should match
# Pod interfaces should be ~1400 (1450 for Geneve overhead)

# Check pod MTU
oc exec $POD1 -- ip link show eth0

# If pod MTU is 1500 but physical is also 1500, that's a problem
# (Geneve overhead causes fragmentation/drops)

# Fix: The MTU should be configured via cluster network operator
# Check the cluster network config
oc get network.config.openshift.io cluster -o yaml

# Proper MTU would be set in the network operator
# This requires cluster-level configuration change
```

### Exercise 9: Validate the Fix

**Goal**: Confirm cross-node connectivity is restored.

```bash
# Re-run the initial connectivity tests
oc exec $POD1 -- ping -c 3 $POD2_IP
# Expected: SUCCESS (3 packets received)

oc exec $POD2 -- ping -c 3 $POD1_IP
# Expected: SUCCESS

# Test with larger packets (MTU test)
oc exec $POD1 -- ping -c 3 -s 1400 $POD2_IP
# Should work if MTU is correct

oc exec $POD1 -- ping -c 3 -s 1450 $POD2_IP
# Might fail if MTU issues exist

# Test actual application connectivity
# Deploy a simple web server on POD2
oc exec $POD2 -- sh -c "echo 'Hello from POD2' > /tmp/index.html && cd /tmp && python3 -m http.server 8080 &"

# Curl from POD1
oc exec $POD1 -- curl -s http://$POD2_IP:8080/index.html
# Expected: "Hello from POD2"

# Verify using tcpdump on the nodes
# On NODE1, watch for Geneve packets going out
oc debug node/$NODE1 -- chroot /host tcpdump -i any -n port 6081 -c 10

# While tcpdump is running, generate traffic
oc exec $POD1 -- ping -c 5 $POD2_IP

# You should see Geneve packets in tcpdump output

# Create a validation report
cat <<EOF > /tmp/scenario-validation.txt
=== VALIDATION REPORT ===
Date: $(date)

CONNECTIVITY TESTS:
POD1 -> POD2 ping: $(oc exec $POD1 -- ping -c 1 -W 2 $POD2_IP >/dev/null 2>&1 && echo "PASS" || echo "FAIL")
POD2 -> POD1 ping: $(oc exec $POD2 -- ping -c 1 -W 2 $POD1_IP >/dev/null 2>&1 && echo "PASS" || echo "FAIL")

LARGE PACKET TEST (MTU):
POD1 -> POD2 (1400 bytes): $(oc exec $POD1 -- ping -c 1 -W 2 -s 1400 $POD2_IP >/dev/null 2>&1 && echo "PASS" || echo "FAIL")

APPLICATION TEST:
HTTP from POD1 to POD2: $(oc exec $POD1 -- curl -s -m 5 http://$POD2_IP:8080/index.html | grep -q "Hello" && echo "PASS" || echo "FAIL")

ROOT CAUSE IDENTIFIED: [ Document what was wrong ]

FIX APPLIED: [ Document what you changed ]

STATUS: Cross-node pod communication is now [ WORKING / STILL BROKEN ]
EOF

cat /tmp/scenario-validation.txt
```

### Exercise 10: Write the Post-Mortem

**Goal**: Document what you learned for future reference.

```bash
cat <<EOF > /tmp/scenario-postmortem.txt
=== WEEK 7 SCENARIO POST-MORTEM ===
Date: $(date)
Issue: Pods on different nodes cannot communicate

TIMELINE:
1. Issue discovered: Cross-node pod communication failing
2. Verified same-node communication working
3. Checked OVN Northbound DB: [ RESULT ]
4. Checked OVN Southbound DB: [ RESULT ]
5. Verified node-to-node connectivity: [ RESULT ]
6. Examined OVS flows on source node: [ RESULT ]
7. Examined OVS flows on destination node: [ RESULT ]
8. Applied 4-flow framework to trace packet path
9. Identified root cause: [ YOUR FINDING ]
10. Applied fix: [ YOUR FIX ]
11. Validated resolution: [ VALIDATION RESULTS ]

ROOT CAUSE ANALYSIS:
The issue was caused by: [ Detailed explanation ]

This occurred because: [ Why it happened ]

The specific component that failed was: [ OVN/OVS/Network/Firewall/etc ]

CONNECTION TO WEEK 7 LEARNING:
- This relates to Day 43 (OVS) because: [ Connection ]
- This relates to Day 44 (Flows) because: [ Connection ]
- This relates to Day 45 (OVN) because: [ Connection ]
- This relates to Day 46 (4 Flows) because: [ Connection ]

LESSONS LEARNED:
1. [ Lesson 1 ]
2. [ Lesson 2 ]
3. [ Lesson 3 ]

PREVENTION:
To prevent this in the future: [ Recommendations ]

DIAGNOSTIC COMMANDS THAT WERE MOST HELPFUL:
1. ovn-sbctl show - showed [ what ]
2. ovs-ofctl dump-flows br-int - showed [ what ]
3. ping between tunnel IPs - showed [ what ]
4. [ other commands ]

WEEK 7 FRAMEWORK APPLICATION:
The 4 OVN traffic flow patterns helped me by: [ Explanation ]

Without understanding OVS/OVN architecture, I would have: [ What would be harder ]
EOF

cat /tmp/scenario-postmortem.txt
```

---

## Self-Check Questions

### Questions

1. What are the 4 key components that must work for cross-node pod communication?
2. How do you verify that OVN knows about a pod in the Northbound database?
3. What command shows you the tunnel endpoints (chassis) in the Southbound database?
4. What protocol and port does OVN use for cross-node tunnels?
5. If nodes can't ping each other's tunnel IPs, what are two possible causes?
6. What should you see in `ovs-ofctl dump-flows br-int` for cross-node forwarding?
7. How does the packet path differ between same-node and cross-node pod communication?
8. What is the purpose of Geneve encapsulation?
9. If only large packets fail but small packets work cross-node, what's the likely cause?
10. Why is it important to trace both directions (forward and return path)?

### Answers

1. **4 key components for cross-node communication**:
   - OVN must know about both pods (Northbound DB has logical switch ports)
   - OVN must program tunnel endpoints (Southbound DB has chassis with Geneve encaps)
   - Nodes must have network connectivity to each other's tunnel IPs
   - OVS must have flows to encapsulate/decapsulate and forward packets
   All four must work; if any fails, cross-node traffic breaks.

2. **Verify pod in Northbound DB**:
   ```bash
   oc exec -n openshift-ovn-kubernetes <ovnkube-master-pod> -- \
     ovn-nbctl find logical_switch_port name=<namespace>_<podname>
   ```
   Or use `ovn-nbctl show` and look for the pod as a port on the logical switch.

3. **Show tunnel endpoints**:
   ```bash
   ovn-sbctl show
   ```
   This shows all chassis (nodes) and their encapsulation configuration including the Geneve tunnel IPs.

4. **Tunnel protocol and port**: 
   - Protocol: **Geneve** (Generic Network Virtualization Encapsulation)
   - Port: **6081/UDP**
   - OVN uses Geneve instead of VXLAN for better extensibility

5. **Nodes can't ping tunnel IPs - possible causes**:
   - **Firewall blocking**: iptables or firewalld on nodes blocking traffic between tunnel IPs
   - **Network misconfiguration**: Tunnel IPs are on wrong interface, routing issues, or network policies blocking node-to-node traffic
   - Other causes: SELinux, network plugin issues, physical network problems

6. **OVS flows for cross-node forwarding**:
   You should see flows with actions like:
   - `set_field:<tunnel-dst-ip>->tun_dst` - sets the tunnel destination
   - `output:genev_sys_6081` or similar - outputs to tunnel interface
   - Match on `nw_dst=<remote-pod-ip>` - matches destination pod IP
   Example: `nw_dst=10.128.2.5 actions=set_field:192.168.1.20->tun_dst,output:5`

7. **Same-node vs cross-node packet path**:
   - **Same-node**: Pod A -> veth -> br-int -> veth -> Pod B (stays in br-int)
   - **Cross-node**: Pod A -> veth -> br-int (node1) -> Geneve encapsulation -> tunnel over network -> br-int (node2) -> veth -> Pod B
   - Key difference: Cross-node requires encapsulation, tunnel transport, and decapsulation

8. **Purpose of Geneve encapsulation**:
   Geneve wraps the original pod-to-pod packet in a new outer packet:
   - Outer IP addresses: NODE1_IP -> NODE2_IP (so physical network can route it)
   - Outer UDP port: 6081 (Geneve port)
   - Inner packet: Original POD1_IP -> POD2_IP packet (unchanged)
   This allows pod IPs (which are virtual/overlay) to travel over the physical network.

9. **Large packets fail, small work - cause**:
   **MTU (Maximum Transmission Unit) mismatch**. 
   - Geneve adds ~50-100 bytes of overhead
   - If physical interface MTU = 1500 and pod interface MTU = 1500, encapsulated packets become > 1500 bytes and get fragmented or dropped
   - Solution: Pod MTU should be ~1400-1450 to leave room for encapsulation overhead

10. **Why trace both directions**:
    - Network can be asymmetric - forward path might work but return path fails
    - OVS flows are directional - you need flows on both nodes
    - Firewall rules might allow outbound but block inbound
    - Different nodes might have different configurations
    - A complete communication requires both request AND response to work

---

## Today I Learned (TIL)

Fill this out at the end of the scenario:

```
# Day 49: Week 7 Scenario - Cross-Node Communication Troubleshooting

## The Problem
- Pods on different nodes could not communicate
- Same-node communication worked fine
- Symptom: [ Your specific symptoms ]

## Root Cause
The actual root cause was: [ What you found ]

Located in: [ Which component/layer ]

## Diagnostic Process
The most valuable diagnostic steps were:
1. [ Step 1 ]
2. [ Step 2 ]
3. [ Step 3 ]

The commands that revealed the issue:
1. [ Command ] - showed [ what ]
2. [ Command ] - showed [ what ]

## The Fix
What I changed: [ Your fix ]

Why it worked: [ Explanation ]

## Week 7 Skills Applied
- Day 43 (OVS): [ How it helped ]
- Day 44 (Flows): [ How it helped ]
- Day 45 (OVN): [ How it helped ]
- Day 46 (4 Flows): [ How it helped ]

## Biggest Aha Moment
[ What surprised you most during troubleshooting? ]

## Connection to Real World
This scenario is realistic because: [ Why this happens in production ]

I would prevent this by: [ Prevention strategies ]

## Confidence Level
Before this scenario: [ 1-10 ]
After this scenario: [ 1-10 ]

I now understand: [ What clicked ]

I still need more practice with: [ What to review ]

## Commands I'll Remember
[ The commands you'll use again ]
```

---

## Commands Cheat Sheet

### OVN Northbound Database

```bash
# Get OVN master pod
OVN_MASTER=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o jsonpath='{.items[0].metadata.name}')

# Show complete logical network
oc exec -n openshift-ovn-kubernetes $OVN_MASTER -- ovn-nbctl show

# Find a specific pod
oc exec -n openshift-ovn-kubernetes $OVN_MASTER -- ovn-nbctl find logical_switch_port name=<namespace>_<pod>

# List all logical switches
oc exec -n openshift-ovn-kubernetes $OVN_MASTER -- ovn-nbctl ls-list

# List logical routers
oc exec -n openshift-ovn-kubernetes $OVN_MASTER -- ovn-nbctl lr-list

# Show router routes
oc exec -n openshift-ovn-kubernetes $OVN_MASTER -- ovn-nbctl lr-route-list ovn_cluster_router
```

### OVN Southbound Database

```bash
# Show all chassis (nodes) and tunnels
oc exec -n openshift-ovn-kubernetes $OVN_MASTER -- ovn-sbctl show

# List all chassis
oc exec -n openshift-ovn-kubernetes $OVN_MASTER -- ovn-sbctl list chassis

# Find specific chassis
oc exec -n openshift-ovn-kubernetes $OVN_MASTER -- ovn-sbctl find chassis hostname=<node-name>

# List tunnel encapsulations
oc exec -n openshift-ovn-kubernetes $OVN_MASTER -- ovn-sbctl list encap

# Check port bindings (logical to physical mapping)
oc exec -n openshift-ovn-kubernetes $OVN_MASTER -- ovn-sbctl list port_binding
```

### OVS Flow Analysis on Nodes

```bash
# Access node
oc debug node/<node-name>
chroot /host

# Show all bridges
ovs-vsctl show

# Dump flows from br-int
ovs-ofctl dump-flows br-int

# Search for specific IP in flows
ovs-ofctl dump-flows br-int | grep <pod-ip>

# Show flows for specific table
ovs-ofctl dump-flows br-int table=0

# Show port mappings (OpenFlow port numbers)
ovs-ofctl show br-int

# Show port statistics
ovs-ofctl dump-ports br-int

# Check tunnel interfaces
ip link show | grep genev
ovs-vsctl show | grep geneve
```

### Node Connectivity Testing

```bash
# Ping between nodes (tunnel IPs)
oc debug node/<node1> -- chroot /host ping <node2-tunnel-ip>

# Check if Geneve port is listening
oc debug node/<node> -- chroot /host ss -ulnp | grep 6081

# Check firewall rules
oc debug node/<node> -- chroot /host iptables -L -n | grep 6081
oc debug node/<node> -- chroot /host firewall-cmd --list-all

# Capture tunnel traffic
oc debug node/<node> -- chroot /host tcpdump -i any port 6081 -n

# Check MTU settings
oc debug node/<node> -- chroot /host ip link show
```

### Pod Connectivity Testing

```bash
# Basic ping test
oc exec <pod1> -- ping -c 3 <pod2-ip>

# Ping with specific packet size (MTU test)
oc exec <pod1> -- ping -c 3 -s 1400 <pod2-ip>

# Trace route
oc exec <pod1> -- traceroute <pod2-ip>

# Check pod's network interface
oc exec <pod1> -- ip addr show
oc exec <pod1> -- ip route show

# Test with curl
oc exec <pod1> -- curl -v http://<pod2-ip>:8080
```

### OVN/OVS Component Health

```bash
# Check all OVN pods
oc get pods -n openshift-ovn-kubernetes

# Check ovnkube-node on specific node
oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-node -o wide | grep <node>

# Check logs
oc logs -n openshift-ovn-kubernetes <ovnkube-node-pod>
oc logs -n openshift-ovn-kubernetes <ovnkube-master-pod>

# Restart ovnkube-node
oc delete pod -n openshift-ovn-kubernetes <ovnkube-node-pod>

# On the node, check OVS services
oc debug node/<node> -- chroot /host systemctl status openvswitch
oc debug node/<node> -- chroot /host systemctl status ovs-vswitchd
```

### Information Gathering

```bash
# List all pods and their nodes
oc get pods -A -o wide

# Get pod details including IP
oc get pod <pod> -o yaml | grep -E "podIP|hostIP|nodeName"

# Get all pod IPs in a namespace
oc get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'

# Get node IPs
oc get nodes -o wide

# Check cluster network configuration
oc get network.config.openshift.io cluster -o yaml
```

---

## What's Next

**Congratulations!** You've completed Week 7 - the deep dive into OpenShift networking internals. You've learned:

- OVS architecture and bridges (Day 43)
- OpenFlow rules and flow tables (Day 44)
- OVN architecture and databases (Day 45)
- The 4 OVN traffic flow patterns (Day 46)
- Routes and HAProxy (Day 47)
- DNS and EgressIP (Day 48)
- Real-world cross-node troubleshooting (Today)

### Week 7 Recap

You can now:
- Navigate the complete OpenShift SDN stack from OVS to OVN to pod networking
- Trace a packet through the entire cross-node path
- Read and understand OpenFlow rules
- Query OVN databases to verify configuration
- Diagnose and fix complex networking issues using the 4-flow framework

### Looking Ahead to Week 8

Week 8 focuses on **Performance & Security**:
- Network performance tuning
- NetworkPolicy deep dive
- Multi-tenancy and network isolation
- Monitoring and observability
- Advanced troubleshooting tools

### Reflection Questions

1. How does understanding OVS/OVN change your approach to troubleshooting?
2. Which of the 4 OVN traffic flows was most surprising or complex?
3. What networking issue from your past experience could you now solve with Week 7 knowledge?
4. How would you explain OVN tunneling to a colleague who only knows basic networking?

### Practice Suggestions

- Set up a lab and intentionally break different components (firewall, OVN pods, flows)
- Time yourself diagnosing issues - aim to get faster
- Create flowcharts for the 4 traffic patterns
- Document your own troubleshooting playbook based on this scenario

### Connection to the Big Picture

```
Week 1-2: Linux networking fundamentals (iptables, routing, namespaces)
Week 3: Container networking (veth, bridge, CNI)
Week 4-5: Kubernetes networking (Services, Endpoints, kube-proxy)
Week 6: OpenShift basics (SDN overview, cluster networking)
Week 7: Deep dive (OVS, OVN, flows) ← YOU ARE HERE
Week 8: Performance, security, troubleshooting
```

You now have the complete picture of how a packet travels from pod to pod, pod to service, and pod to external network in OpenShift. Everything you learned in Weeks 1-6 connects through the OVS/OVN layer you mastered this week.

**You've reached the heart of OpenShift networking. Well done!**
