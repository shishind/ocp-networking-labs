# Day 46: OVN Traffic Flows

**Week 7, Day 46: Phase 4 - OpenShift Networking Deep Dive**

---

## Learning Objectives

By the end of this lab, you will be able to:

1. Trace the 4 fundamental traffic patterns in OpenShift networking
2. Follow packets hop-by-hop through the complete OVN/OVS stack
3. Understand when and why tunneling (VXLAN/Geneve) is used
4. Identify the role of each component in packet forwarding
5. Diagnose traffic flow issues using complete end-to-end tracing
6. Write packet paths from memory for troubleshooting

---

## Plain English Explanation

### The Four Fundamental Traffic Patterns

In OpenShift, every network connection falls into one of these four patterns:

**Pattern 1: Pod-to-Pod (Same Node)**
- Simplest case
- Both pods on same worker node
- Packets stay within the node, never leave the physical host
- No tunneling needed

**Pattern 2: Pod-to-Pod (Different Nodes)**
- Most common case
- Pods on different worker nodes
- Packets must traverse the physical network between nodes
- Uses overlay tunneling (VXLAN or Geneve)

**Pattern 3: Pod-to-External (Egress)**
- Pod accessing the internet or external services
- Packets must leave the cluster
- Uses NAT (from Week 2!) to translate pod IP to node IP
- Goes through br-ex to physical network

**Pattern 4: External-to-Pod (Ingress)**
- External client accessing a service in the cluster
- Uses Routes/Ingress (which you'll deep dive tomorrow)
- Involves load balancing and reverse proxying
- Often through router pods

Today we'll trace each pattern hop-by-hop, seeing how everything from this week (and previous weeks) fits together.

### Why Understanding Traffic Flows Matters

When you hear "Pod A can't reach Pod B," your brain should immediately:

1. **Identify the pattern**: Same node? Different nodes? External?
2. **Know the path**: What components should the packet traverse?
3. **Check each hop**: Where does the packet fail to arrive?

This is the culmination of everything you've learned:
- **Week 1-2**: Linux networking fundamentals (namespaces, iptables, routing)
- **Week 3**: Network interfaces and veth pairs
- **Week 5**: Services and kube-proxy
- **Day 43**: OVS bridges and ports
- **Day 44**: OVS flow tables
- **Day 45**: OVN architecture and control plane

Now we put it ALL together.

### Key Concepts Refresher

**Overlay Network:**
- Virtual network on top of physical network
- Pods have IPs from a private range (10.128.0.0/14)
- Physical network doesn't know about pod IPs
- Tunneling encapsulates pod packets inside node packets

**Tunneling (VXLAN/Geneve):**
```
Original packet: [Pod A IP][Pod B IP][Data]
Encapsulated:    [Node A IP][Node B IP][Tunnel Header[Pod A IP][Pod B IP][Data]]
```

**NAT (Network Address Translation):**
- Translates pod IP to node IP for external communication
- Remember Week 2: SNAT changes source IP, DNAT changes destination IP
- Used for egress so external systems see node IPs, not pod IPs

**The Complete Stack (Bottom to Top):**
1. Physical NIC (eth0)
2. OVS bridge (br-int, br-ex)
3. OVN logical networks
4. veth pairs
5. Pod network namespace
6. Application in container

---

## Hands-On Lab

### Prerequisites

- Completed Days 43-45
- At least 2 running pods in your cluster (preferably on different nodes)
- Admin access to debug nodes
- Patience - we're doing detailed tracing!

### Lab Setup

```bash
# Create test pods if you don't have any
oc create namespace traffic-test

# Pod 1 on default node
oc run pod-a -n traffic-test --image=registry.access.redhat.com/ubi9/ubi-minimal:latest -- sleep 3600

# Wait for pod-a to be running
oc wait --for=condition=Ready pod/pod-a -n traffic-test --timeout=60s

# Pod 2 on a different node (if possible)
NODE1=$(oc get pod -n traffic-test pod-a -o jsonpath='{.spec.nodeName}')
NODE2=$(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[1].metadata.name}')

oc run pod-b -n traffic-test --image=registry.access.redhat.com/ubi9/ubi-minimal:latest \
  --overrides='{"spec":{"nodeName":"'$NODE2'"}}' -- sleep 3600

# Get pod IPs and nodes
echo "=== Test Environment ==="
oc get pods -n traffic-test -o wide
POD_A_IP=$(oc get pod -n traffic-test pod-a -o jsonpath='{.status.podIP}')
POD_B_IP=$(oc get pod -n traffic-test pod-b -o jsonpath='{.status.podIP}')
echo "Pod A: $POD_A_IP on $NODE1"
echo "Pod B: $POD_B_IP on $NODE2"
```

---

### Exercise 1: Pattern 1 - Pod-to-Pod (Same Node)

**Objective**: Trace a packet between two pods on the same node.

```bash
# First, ensure you have two pods on the same node
# If pod-a and pod-b are on different nodes, create a third pod
NODE1=$(oc get pod -n traffic-test pod-a -o jsonpath='{.spec.nodeName}')

oc run pod-c -n traffic-test --image=registry.access.redhat.com/ubi9/ubi-minimal:latest \
  --overrides='{"spec":{"nodeName":"'$NODE1'"}}' -- sleep 3600

POD_A_IP=$(oc get pod -n traffic-test pod-a -o jsonpath='{.status.podIP}')
POD_C_IP=$(oc get pod -n traffic-test pod-c -o jsonpath='{.status.podIP}')

echo "Pod A: $POD_A_IP"
echo "Pod C: $POD_C_IP"
echo "Both on node: $NODE1"

# Generate traffic
oc exec -n traffic-test pod-a -- ping -c 3 $POD_C_IP

# Now trace the path
# Access the node
oc debug node/$NODE1
chroot /host

# Step 1: Find Pod A's veth
ip addr | grep $POD_A_IP -B2
# Note the veth name, e.g., veth12345678

VETH_A="<veth-name-from-above>"
OFPORT_A=$(ovs-vsctl get interface $VETH_A ofport)
echo "Pod A ofport: $OFPORT_A"

# Step 2: Find Pod C's veth
ip addr | grep $POD_C_IP -B2
VETH_C="<veth-name-from-above>"
OFPORT_C=$(ovs-vsctl get interface $VETH_C ofport)
echo "Pod C ofport: $OFPORT_C"

# Step 3: Trace the packet through OVS
ovs-appctl ofproto/trace br-int \
  in_port=$OFPORT_A,icmp,nw_src=$POD_A_IP,nw_dst=$POD_C_IP

# Step 4: Check relevant flows
ovs-ofctl dump-flows br-int | grep "in_port=$OFPORT_A"
ovs-ofctl dump-flows br-int | grep "output:$OFPORT_C"
```

**Expected Path (Same Node):**

```
Pod A (10.128.0.5)
    ↓
[eth0 in pod-a netns]
    ↓
[veth-a in host netns] --- ofport=$OFPORT_A
    ↓
[br-int flows]
    - Match: in_port=$OFPORT_A, nw_dst=10.128.0.6
    - Action: output:$OFPORT_C
    ↓
[veth-c in host netns] --- ofport=$OFPORT_C
    ↓
[eth0 in pod-c netns]
    ↓
Pod C (10.128.0.6)
```

**Key Observations:**
- No tunneling - packets stay on br-int
- Simple L2 switching between veths
- OVN knows both pods are local, so direct forwarding
- Fastest path possible

**Exercise:** Document each hop with the actual values from your cluster.

---

### Exercise 2: Pattern 2 - Pod-to-Pod (Different Nodes)

**Objective**: Trace a packet between pods on different nodes, including tunnel encapsulation.

```bash
# Use pod-a and pod-b which should be on different nodes
POD_A_IP=$(oc get pod -n traffic-test pod-a -o jsonpath='{.status.podIP}')
POD_B_IP=$(oc get pod -n traffic-test pod-b -o jsonpath='{.status.podIP}')
NODE1=$(oc get pod -n traffic-test pod-a -o jsonpath='{.spec.nodeName}')
NODE2=$(oc get pod -n traffic-test pod-b -o jsonpath='{.spec.nodeName}')

# Get node IPs (for tunnel endpoints)
NODE1_IP=$(oc get node $NODE1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
NODE2_IP=$(oc get node $NODE2 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

echo "Pod A: $POD_A_IP on $NODE1 ($NODE1_IP)"
echo "Pod B: $POD_B_IP on $NODE2 ($NODE2_IP)"

# Generate traffic
oc exec -n traffic-test pod-a -- ping -c 3 $POD_B_IP

# === Trace on Source Node (NODE1) ===
oc debug node/$NODE1
chroot /host

# Find Pod A's veth and ofport
VETH_A=$(ip addr | grep $POD_A_IP -B2 | grep -o "veth[^:@]*" | head -1)
OFPORT_A=$(ovs-vsctl get interface $VETH_A ofport)

# Find tunnel port
TUNNEL_PORT=$(ovs-vsctl show | grep -A2 "type: geneve" | grep "name:" | awk '{print $2}' | tr -d '"')
TUNNEL_OFPORT=$(ovs-vsctl get interface $TUNNEL_PORT ofport)

echo "Pod A veth: $VETH_A (ofport $OFPORT_A)"
echo "Tunnel port: $TUNNEL_PORT (ofport $TUNNEL_OFPORT)"

# Trace packet from Pod A
ovs-appctl ofproto/trace br-int \
  in_port=$OFPORT_A,icmp,nw_src=$POD_A_IP,nw_dst=$POD_B_IP

# Check tunnel-related flows
ovs-ofctl dump-flows br-int | grep "set_field.*tun_id"
ovs-ofctl dump-flows br-int | grep "set_field.*tun_dst"

# Check what tunnel ID is used for Pod B's network
MASTER_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o jsonpath='{.items[0].metadata.name}')
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- \
  ovn-sbctl find port_binding | grep -A5 "$POD_B_IP" | grep tunnel_key

exit
exit

# === Trace on Destination Node (NODE2) ===
oc debug node/$NODE2
chroot /host

# Find Pod B's veth
VETH_B=$(ip addr | grep $POD_B_IP -B2 | grep -o "veth[^:@]*" | head -1)
OFPORT_B=$(ovs-vsctl get interface $VETH_B ofport)

# Find tunnel port
TUNNEL_PORT=$(ovs-vsctl show | grep -A2 "type: geneve" | grep "name:" | awk '{print $2}' | tr -d '"')

# Check incoming tunnel traffic
ovs-ofctl dump-flows br-int | grep "tun_src=$NODE1_IP"
ovs-ofctl dump-flows br-int | grep "output:$OFPORT_B"

# Trace incoming packet (from tunnel)
ovs-appctl ofproto/trace br-int \
  in_port=$TUNNEL_PORT,icmp,tun_src=$NODE1_IP,nw_src=$POD_A_IP,nw_dst=$POD_B_IP
```

**Expected Path (Different Nodes):**

```
=== On Node 1 ===
Pod A (10.128.0.5)
    ↓
[eth0 in pod-a netns]
    ↓
[veth-a] → ofport=$OFPORT_A
    ↓
[br-int flows]
    - Match: in_port=$OFPORT_A, nw_dst=10.128.0.6
    - Action: set_field:100->tun_id, set_field:$NODE2_IP->tun_dst
    - Action: output:$TUNNEL_OFPORT
    ↓
[Geneve/VXLAN tunnel port]
    - Encapsulation happens here
    - Inner packet: [Pod A IP][Pod B IP][ICMP data]
    - Outer packet: [Node1 IP][Node2 IP][Tunnel Header[Inner packet]]
    ↓
[Physical NIC] → onto physical network

=== Physical Network ===
Packet travels from Node1 to Node2

=== On Node 2 ===
[Physical NIC] receives encapsulated packet
    ↓
[Geneve/VXLAN tunnel port]
    - Decapsulation happens here
    - Removes outer headers, extracts inner packet
    - Reads tunnel ID: 100
    ↓
[br-int flows]
    - Match: tun_id=100, nw_dst=10.128.0.6
    - Action: output:$OFPORT_B
    ↓
[veth-b] → ofport=$OFPORT_B
    ↓
[eth0 in pod-b netns]
    ↓
Pod B (10.128.0.6)
```

**Key Observations:**
- Tunneling is transparent to pods (they see normal IP packets)
- Tunnel ID (VNI) identifies which logical network the packet belongs to
- Physical network only sees node IPs, not pod IPs
- This is how overlay networking works!

**Connection to Previous Learning:**
- **Week 1**: This is why pod IPs aren't routable outside the cluster
- **Week 3**: The veth pairs connect pods to this tunnel infrastructure
- **Day 44**: The flows with `tun_id` and `tun_dst` actions - this is what they do!

---

### Exercise 3: Pattern 3 - Pod-to-External (Egress)

**Objective**: Trace a packet from a pod to an external IP (internet).

```bash
POD_A_IP=$(oc get pod -n traffic-test pod-a -o jsonpath='{.status.podIP}')
NODE1=$(oc get pod -n traffic-test pod-a -o jsonpath='{.spec.nodeName}')
NODE1_IP=$(oc get node $NODE1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

# Generate egress traffic
oc exec -n traffic-test pod-a -- ping -c 3 8.8.8.8

# Trace on the node
oc debug node/$NODE1
chroot /host

# Step 1: Find pod's veth
VETH_A=$(ip addr | grep $POD_A_IP -B2 | grep -o "veth[^:@]*" | head -1)
OFPORT_A=$(ovs-vsctl get interface $VETH_A ofport)

# Step 2: Trace packet from pod to external IP
ovs-appctl ofproto/trace br-int \
  in_port=$OFPORT_A,icmp,nw_src=$POD_A_IP,nw_dst=8.8.8.8

# Step 3: Check flows for external traffic
ovs-ofctl dump-flows br-int | grep "8.8.8.8"

# Step 4: Check patch port to br-ex
ovs-vsctl show | grep patch

# Step 5: Check br-ex flows
ovs-ofctl dump-flows br-ex

# Step 6: Check iptables NAT rules (remember Week 2!)
iptables -t nat -L POSTROUTING -n -v | grep $POD_A_IP

# Step 7: Check routing table
ip route show

# Step 8: Capture actual packet (optional - advanced)
# This shows the packet AFTER NAT
tcpdump -i eth0 -n icmp and host 8.8.8.8 -c 3
```

**Expected Path (Egress):**

```
Pod A (10.128.0.5)
    ↓
[eth0 in pod-a netns]
    ↓
[veth-a] → br-int
    ↓
[br-int flows]
    - Match: nw_dst=8.8.8.8 (external IP)
    - Action: goto patch port
    ↓
[patch-br-int-to-br-ex] → [patch-br-ex-to-br-int]
    ↓
[br-ex]
    ↓
[iptables NAT]
    - POSTROUTING chain
    - SNAT: 10.128.0.5 → $NODE1_IP (masquerade)
    ↓
[eth0] → Physical network
    ↓
Internet (sees packet from $NODE1_IP, not pod IP)
```

**Key Observations:**
- OVN flows route external traffic to br-ex
- iptables NAT translates pod IP to node IP (SNAT/Masquerade)
- External systems never see pod IPs
- Return traffic is translated back (connection tracking from Week 2!)

**Verification:**

```bash
# On external system or another node, you would see:
# Source IP: $NODE1_IP (NOT $POD_A_IP)

# Check connection tracking
conntrack -L | grep 8.8.8.8 | grep $POD_A_IP
# Shows the NAT translation mapping
```

---

### Exercise 4: Pattern 4 - External-to-Pod (Ingress via Service)

**Objective**: Trace external traffic reaching a pod through a Service.

```bash
# Create a service for pod-a
oc expose pod pod-a -n traffic-test --port 8080 --target-port 8080

# Get service IP
SVC_IP=$(oc get svc pod-a -n traffic-test -o jsonpath='{.spec.clusterIP}')
echo "Service IP: $SVC_IP"

# For this exercise, we'll simulate from another pod (easier than true external)
oc exec -n traffic-test pod-b -- curl -m 5 http://$SVC_IP:8080 || echo "Expected - no app listening"

# Trace the path
NODE1=$(oc get pod -n traffic-test pod-a -o jsonpath='{.spec.nodeName}')
oc debug node/$NODE1
chroot /host

# Step 1: Check OVN load balancer configuration
MASTER_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o jsonpath='{.items[0].metadata.name}')
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl find load_balancer | grep -A10 "$SVC_IP"

# Step 2: Check iptables rules for service
iptables -t nat -L -n -v | grep $SVC_IP

# Step 3: Find flows for service IP
ovs-ofctl dump-flows br-int | grep $SVC_IP

# Step 4: Check kube-proxy mode
oc get configmap -n openshift-network-operator cluster -o yaml | grep mode

# Step 5: Check connection tracking for service
conntrack -L | grep $SVC_IP
```

**Expected Path (Ingress - via Service):**

This depends on whether you're using OVN-Kubernetes load balancing or kube-proxy:

**With OVN Load Balancer:**
```
External Request → NodePort
    ↓
[eth0] → [br-ex]
    ↓
[br-int flows with load balancer action]
    - Match: nw_dst=$SVC_IP, tp_dst=8080
    - Action: DNAT to pod IP (load balanced)
    - ct(commit,table=X) - connection tracking
    ↓
[Normal pod routing] (like Pattern 1 or 2)
    ↓
Pod A
```

**With kube-proxy iptables:**
```
External Request → NodePort
    ↓
[eth0]
    ↓
[iptables NAT - PREROUTING]
    - Match: -d $SVC_IP -p tcp --dport 8080
    - Action: DNAT to $POD_A_IP
    ↓
[Routing decision - pod IP is in local network]
    ↓
[br-ex] → [br-int] → [veth-a]
    ↓
Pod A
```

**Key Observations:**
- Service IP is virtual - it doesn't exist on any interface
- Load balancing happens at either OVN layer or iptables layer
- DNAT changes destination from service IP to actual pod IP
- Return traffic is automatically translated back (connection tracking)

---

### Exercise 5: Write Traffic Paths from Memory

**Objective**: Internalize the traffic patterns by writing them without reference.

```bash
# Without looking at notes, document these paths:

# 1. Pod-to-Pod (same node)
# Write: Pod A → ??? → ??? → ??? → Pod B

# 2. Pod-to-Pod (different nodes)
# Write: Pod A → ??? → ??? → ??? → [Physical Network] → ??? → ??? → Pod B

# 3. Pod-to-External
# Write: Pod → ??? → ??? → ??? → [NAT: IP changes from ??? to ???] → ???

# 4. External-to-Pod (via Service)
# Write: External → ??? → [DNAT: IP changes from ??? to ???] → ??? → Pod
```

**Check your answers against the paths documented in previous exercises.**

**Practice Troubleshooting:**

For each path, identify where you would check if traffic fails:

```bash
# Pod-to-Pod (same node) troubleshooting checklist:
# [ ] Pod A veth exists and is in br-int
# [ ] Pod B veth exists and is in br-int
# [ ] Flows exist for routing between ofports
# [ ] NetworkPolicy not blocking traffic

# Pod-to-Pod (different nodes) troubleshooting checklist:
# [ ] All of the above, plus:
# [ ] Tunnel port exists and is UP
# [ ] Tunnel flows set correct tun_dst
# [ ] Physical network allows UDP 6081 (Geneve) or 4789 (VXLAN)
# [ ] ovnkube-node healthy on both nodes

# Pod-to-External troubleshooting checklist:
# [ ] Pod has default route
# [ ] br-int → br-ex patch port exists
# [ ] iptables NAT rules configured
# [ ] Node has route to external IP
# [ ] Physical network allows egress

# External-to-Pod troubleshooting checklist:
# [ ] Service exists and has endpoints
# [ ] Load balancer configured (OVN or iptables)
# [ ] Ingress route/LB configured
# [ ] NetworkPolicy allows ingress
```

---

### Exercise 6: Complete End-to-End Trace

**Objective**: Perform a complete trace using all tools learned this week.

```bash
# Scenario: Pod-a pings Pod-b (on different nodes)

POD_A="pod-a"
POD_B="pod-b"
NS="traffic-test"

echo "=== KUBERNETES LAYER ==="
oc get pod -n $NS $POD_A -o wide
oc get pod -n $NS $POD_B -o wide

POD_A_IP=$(oc get pod -n $NS $POD_A -o jsonpath='{.status.podIP}')
POD_B_IP=$(oc get pod -n $NS $POD_B -o jsonpath='{.status.podIP}')
NODE_A=$(oc get pod -n $NS $POD_A -o jsonpath='{.spec.nodeName}')
NODE_B=$(oc get pod -n $NS $POD_B -o jsonpath='{.spec.nodeName}')

echo "=== OVN NORTHBOUND (LOGICAL) ==="
MASTER_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o jsonpath='{.items[0].metadata.name}')
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl find logical_switch_port | grep -A5 "$POD_A_IP"
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl find logical_switch_port | grep -A5 "$POD_B_IP"

echo "=== OVN SOUTHBOUND (PHYSICAL MAPPING) ==="
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- \
  ovn-sbctl find port_binding | grep -A8 "$POD_A_IP"
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- \
  ovn-sbctl find port_binding | grep -A8 "$POD_B_IP"

echo "=== OVS ON NODE A (SOURCE) ==="
oc debug node/$NODE_A -- chroot /host bash -c "
  VETH=\$(ip addr | grep $POD_A_IP -B2 | grep -o 'veth[^:@]*' | head -1)
  OFPORT=\$(ovs-vsctl get interface \$VETH ofport)
  echo 'Pod A veth: '\$VETH' ofport: '\$OFPORT
  ovs-ofctl dump-flows br-int | grep 'in_port='\$OFPORT | head -3
"

echo "=== OVS ON NODE B (DESTINATION) ==="
oc debug node/$NODE_B -- chroot /host bash -c "
  VETH=\$(ip addr | grep $POD_B_IP -B2 | grep -o 'veth[^:@]*' | head -1)
  OFPORT=\$(ovs-vsctl get interface \$VETH ofport)
  echo 'Pod B veth: '\$VETH' ofport: '\$OFPORT
  ovs-ofctl dump-flows br-int | grep 'output:'\$OFPORT | head -3
"

echo "=== GENERATE TRAFFIC ==="
oc exec -n $NS $POD_A -- ping -c 3 $POD_B_IP

echo "=== VERIFY CONNECTIVITY ==="
if oc exec -n $NS $POD_A -- ping -c 1 -W 2 $POD_B_IP > /dev/null 2>&1; then
  echo "✓ Connectivity working!"
else
  echo "✗ Connectivity failed - investigate above layers"
fi
```

This exercise ties together everything from the week!

---

## Self-Check Questions

### Questions

1. **What is the fundamental difference between same-node and cross-node pod communication?**

2. **Why is tunneling necessary for cross-node pod communication?**

3. **In egress traffic, at what point does the source IP change from pod IP to node IP?**

4. **What information does the tunnel ID (VNI) carry in encapsulated packets?**

5. **If Pod A on Node1 can ping Pod B on Node2, but not Pod C on Node3, where would you start troubleshooting?**

6. **How does connection tracking enable bidirectional communication through NAT?**

7. **What role does br-ex play in egress traffic that br-int doesn't handle?**

8. **Why do external systems never see pod IPs directly?**

---

### Answers

1. **Same-node vs cross-node communication:**
   - **Same-node**: Packets stay entirely within the node. Both pod veth interfaces connect to the same br-int bridge. OVS flows simply forward from one ofport to another. No tunneling, no encapsulation. Simple L2 switching.
   - **Cross-node**: Packets must traverse the physical network. OVS flows on source node encapsulate the pod packet inside a tunnel packet (Geneve/VXLAN). Physical network carries encapsulated packet between nodes. Destination node decapsulates and delivers to target pod.
   - **Key difference**: Tunneling and encapsulation for cross-node; direct switching for same-node.

2. **Why tunneling is necessary:**
   - **Pod IPs are not routable** on the physical network. Physical routers don't have routes to 10.128.0.0/14.
   - **Overlay network**: Pods exist in a virtual network on top of the physical network.
   - **Tunneling encapsulates** pod packets inside node packets: outer headers have node IPs (routable), inner headers have pod IPs.
   - **Physical network** sees only node-to-node traffic, is unaware of pods.
   - **Alternative would require** configuring physical network with routes for every pod subnet on every node - impractical and insecure.
   - **Enables network isolation** and multi-tenancy without physical network changes.

3. **When source IP changes (egress NAT):**
   - Source IP changes in the **iptables NAT POSTROUTING chain** after the packet leaves br-ex.
   - **Sequence**:
     1. Pod sends packet: src=10.128.0.5, dst=8.8.8.8
     2. Travels through veth → br-int → patch port → br-ex (still pod IP)
     3. **iptables POSTROUTING**: SNAT/MASQUERADE changes src to node IP
     4. Exits eth0: src=192.168.1.10 (node IP), dst=8.8.8.8
   - **Connection tracking** records the translation so return traffic can be de-NAT'd.

4. **Tunnel ID (VNI) meaning:**
   - **Virtual Network Identifier (VNI)** identifies which **logical network** the encapsulated packet belongs to.
   - In OpenShift with OVN: Each logical switch (usually one per node) has a unique VNI.
   - **Purpose**: Allows multiple isolated networks to share the same physical infrastructure.
   - **Example**: VNI 100 for worker-1 pods, VNI 200 for worker-2 pods, VNI 300 for isolated tenant network.
   - **On receiving node**: OVN checks VNI to determine which logical network, then routes to appropriate pod.
   - **Security**: Pods on VNI 100 can't see packets on VNI 200 even if sharing physical network.

5. **Troubleshooting selective connectivity failure:**
   - **Start with**: What's different about Node3 vs Node2?
   - **Checklist**:
     1. **Check Node3 health**: `oc get nodes` - is Node3 Ready?
     2. **Check ovnkube-node on Node3**: `oc get pods -n openshift-ovn-kubernetes -o wide | grep node3`
     3. **Check tunnel connectivity to Node3**: On Node1, check if tunnel flows have correct tun_dst for Node3
     4. **Physical network**: Can Node1 reach Node3's IP? `oc debug node/node1 -- chroot /host ping <node3-ip>`
     5. **Firewall**: Is UDP 6081 (Geneve) allowed between Node1 and Node3?
     6. **OVN SB database**: Does Node3 chassis exist? `ovn-sbctl chassis-list | grep node3`
     7. **Compare working vs broken**: Diff OVS flows for Node2 destination vs Node3 destination
   - **Most likely causes**: Node3 ovnkube-node pod down, firewall blocking Geneve, or physical network partition.

6. **Connection tracking for bidirectional NAT:**
   - **Connection tracking (conntrack)** maintains a state table of all active connections.
   - **Outbound packet**: NAT happens, conntrack records: "Pod 10.128.0.5:54321 ↔ 8.8.8.8:443 is translated to Node 192.168.1.10:54321 ↔ 8.8.8.8:443"
   - **Return packet** arrives: src=8.8.8.8:443, dst=192.168.1.10:54321
   - **conntrack lookup**: Finds matching connection, knows to reverse the NAT
   - **Packet rewritten**: dst changed from 192.168.1.10 to 10.128.0.5
   - **Delivered to pod**: Pod sees response from 8.8.8.8, unaware of NAT
   - **Stateful**: Only works for established connections; conntrack expires after timeout

7. **br-ex role in egress:**
   - **br-int**: Handles pod overlay network. All pod veth interfaces connect here. Routes between pods.
   - **br-ex**: Handles external connectivity. Connects to physical NIC (eth0). Gateway to outside world.
   - **Why br-ex needed**:
     - Physical NIC (eth0) must be on a bridge to work with OVS
     - br-ex provides clean separation: overlay network (br-int) vs external network (br-ex)
     - iptables NAT rules typically match traffic on br-ex or eth0, not br-int
     - br-ex can have different flows/policies for external traffic
   - **Path**: Pod → br-int (overlay routing) → patch port → br-ex (external routing) → NAT → eth0 → physical network

8. **Why external systems never see pod IPs:**
   - **Security**: Exposing pod IPs externally would allow direct attacks on pods, bypassing services and network policies.
   - **Portability**: Pod IPs change when pods restart or move. External systems can't rely on them.
   - **IP exhaustion**: Pod CIDR (10.128.0.0/14) might overlap with other private networks external systems use.
   - **NAT provides abstraction**: External systems talk to stable node IPs or service IPs.
   - **Controlled ingress**: Only Services/Routes are exposed, with load balancing and policies applied.
   - **Implementation**: Egress NAT rewrites pod IP to node IP before leaving cluster. Ingress goes through Services which DNAT to pods.

---

## Today I Learned (TIL)

### Template

```
Date: _______________

# Day 46: OVN Traffic Flows

## Four Traffic Patterns Mastered
1. Pod-to-Pod (same node): ___________________________________
2. Pod-to-Pod (different nodes): _____________________________
3. Pod-to-External: __________________________________________
4. External-to-Pod: __________________________________________

## Complete Path I Can Write from Memory
Choose one pattern and write the complete path:

Pattern: __________________

Path:
Step 1: _____________________________________________________
Step 2: _____________________________________________________
Step 3: _____________________________________________________
Step 4: _____________________________________________________
Step 5: _____________________________________________________

## Most Interesting Discovery
What surprised me today:
______________________________________________________________

## Troubleshooting Scenario Practiced
Problem: _____________________________________________________
How I diagnosed it: __________________________________________
What I learned: ______________________________________________

## Commands Used Most
1. ___________________________________________________________
2. ___________________________________________________________
3. ___________________________________________________________

## Connection to Entire Week
- Day 43: OVS bridges and ports → The physical structure
- Day 44: OVS flows → The forwarding logic  
- Day 45: OVN NB/SB databases → The control plane
- Day 46: Traffic patterns → Putting it ALL together!

## Questions/Areas to Review
1. _____________________________________________________________
2. _____________________________________________________________

## Tomorrow's Preview
Tomorrow I'll learn about Routes and HAProxy - how external HTTP(S) traffic
reaches pods, building on the ingress pattern I learned today.
```

---

## Commands Cheat Sheet

### Traffic Tracing Workflow

```bash
# === Setup: Get Pod and Node Information ===

POD_NAME="<pod-name>"
POD_NAMESPACE="<namespace>"
POD_IP=$(oc get pod -n $POD_NAMESPACE $POD_NAME -o jsonpath='{.status.podIP}')
NODE=$(oc get pod -n $POD_NAMESPACE $POD_NAME -o jsonpath='{.spec.nodeName}')
NODE_IP=$(oc get node $NODE -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')


# === Layer 1: Kubernetes Objects ===

oc get pod -n $POD_NAMESPACE $POD_NAME -o wide
oc get svc -n $POD_NAMESPACE
oc describe pod -n $POD_NAMESPACE $POD_NAME


# === Layer 2: OVN Northbound (Logical View) ===

MASTER_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o jsonpath='{.items[0].metadata.name}')

# Find logical switch port for pod
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl find logical_switch_port | grep -A5 "$POD_IP"

# Check load balancers (for services)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl lb-list


# === Layer 3: OVN Southbound (Physical Mapping) ===

# Find port binding (which node)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- \
  ovn-sbctl find port_binding | grep -A8 "$POD_IP"

# Check chassis
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- \
  ovn-sbctl chassis-list

# Show logical flows
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- \
  ovn-sbctl lflow-list | grep "$POD_IP"


# === Layer 4: OVS Flows ===

oc debug node/$NODE
chroot /host

# Find veth and ofport
VETH=$(ip addr | grep $POD_IP -B2 | grep -o "veth[^:@]*" | head -1)
OFPORT=$(ovs-vsctl get interface $VETH ofport)

# Check flows for this pod
ovs-ofctl dump-flows br-int | grep "in_port=$OFPORT"
ovs-ofctl dump-flows br-int | grep "nw_src=$POD_IP"
ovs-ofctl dump-flows br-int | grep "output:$OFPORT"

# Trace a packet
ovs-appctl ofproto/trace br-int \
  in_port=$OFPORT,icmp,nw_src=$POD_IP,nw_dst=<dest-ip>


# === Layer 5: Linux Networking ===

# Check veth pair
ip link show $VETH
ethtool -S $VETH | grep peer_ifindex

# Check routing
ip route show

# Check NAT rules
iptables -t nat -L -n -v | grep $POD_IP

# Check connection tracking
conntrack -L | grep $POD_IP

# Packet capture
tcpdump -i $VETH -n icmp
```

### Quick Diagnosis by Symptom

```bash
# === Pod can't reach other pod on same node ===

# 1. Check both veths exist
oc debug node/$NODE -- chroot /host ip addr | grep $POD_IP

# 2. Check both are in br-int
oc debug node/$NODE -- chroot /host ovs-vsctl list-ports br-int | grep veth

# 3. Check flows between them
oc debug node/$NODE -- chroot /host ovs-ofctl dump-flows br-int | grep $POD_IP

# 4. Check NetworkPolicy
oc get networkpolicy -A


# === Pod can't reach pod on different node ===

# 1. Check tunnel port exists
oc debug node/$NODE -- chroot /host ovs-vsctl show | grep geneve

# 2. Check tunnel flows
oc debug node/$NODE -- chroot /host ovs-ofctl dump-flows br-int | grep tun_dst

# 3. Check physical connectivity
oc debug node/$NODE1 -- chroot /host ping -c 3 $NODE2_IP

# 4. Check Geneve UDP port (6081)
oc debug node/$NODE1 -- chroot /host nc -zuv $NODE2_IP 6081

# 5. Check ovnkube-node on both nodes
oc get pods -n openshift-ovn-kubernetes -o wide | grep ovnkube-node


# === Pod can't reach external IP ===

# 1. Check pod has default route
oc exec -n $NS $POD -- ip route

# 2. Check patch port br-int → br-ex
oc debug node/$NODE -- chroot /host ovs-vsctl show | grep patch

# 3. Check NAT rules
oc debug node/$NODE -- chroot /host iptables -t nat -L POSTROUTING -n

# 4. Check node can reach external IP
oc debug node/$NODE -- chroot /host ping -c 3 8.8.8.8

# 5. Check DNS if using hostname
oc exec -n $NS $POD -- nslookup google.com


# === External can't reach pod via Service ===

# 1. Check service exists and has endpoints
oc get svc -n $NS
oc get endpoints -n $NS

# 2. Check service IP in load balancer
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl find load_balancer | grep $SVC_IP

# 3. Check iptables service rules
oc debug node/$NODE -- chroot /host iptables -t nat -L | grep $SVC_IP

# 4. Check route exists (for ingress)
oc get route -n $NS

# 5. Check router pods
oc get pods -n openshift-ingress
```

---

## What's Next

### Tomorrow: Day 47 - Routes and HAProxy

You've mastered packet-level tracing. Tomorrow you'll learn the application-level routing layer.

**Preview:**
- OpenShift Routes vs Kubernetes Ingress
- HAProxy router architecture
- Edge, passthrough, and re-encrypt routes
- TLS termination strategies
- HAProxy configuration inspection

**Connection:**
Today you learned Pattern 4 (External-to-Pod) at the network level. Tomorrow you'll learn how HTTP/HTTPS traffic is routed to the right pod using Routes.

### Week 7 Progress

- **Day 43**: OVS structure ✓
- **Day 44**: OVS flows ✓
- **Day 45**: OVN architecture ✓
- **Day 46**: Complete traffic flows ✓
- **Day 47**: Routes and HAProxy (tomorrow)
- **Day 48**: DNS and Egress policies
- **Day 49**: Real-world troubleshooting scenario

You now understand the **complete network stack** from pod to physical network. The remaining days build services on top of this foundation!

---

**Congratulations!** You can now trace any packet through the entire OpenShift networking stack. This is advanced knowledge that sets you apart. Practice these traces until you can do them without reference - this skill is invaluable for troubleshooting production issues.
