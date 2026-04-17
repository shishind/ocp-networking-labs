# Day 44: OVS Flow Tables

**Week 7, Day 44: Phase 4 - OpenShift Networking Deep Dive**

---

## Learning Objectives

By the end of this lab, you will be able to:

1. Understand OpenFlow flow tables and their role in packet forwarding
2. Read and interpret OpenFlow rules using ovs-ofctl commands
3. Trace packet processing through multiple flow tables
4. Identify flow rules responsible for specific pod traffic
5. Correlate flow actions with network behavior (forwarding, dropping, tunneling)
6. Debug connectivity issues using flow table analysis

---

## Plain English Explanation

### What Are Flow Tables?

Yesterday you learned about OVS bridges and ports - the **structure** of the network. Today we're learning about flow tables - the **brain** that makes forwarding decisions.

Think of flow tables like a very detailed instruction manual:

**Traditional Network Switch:**
- "If packet has MAC address X, send it out port 5"
- Simple MAC learning table

**OVS with OpenFlow:**
- "If packet comes from port 3, AND has IP 10.128.0.5, AND is going to 10.128.1.10, THEN set tunnel ID to 100, AND send to tunnel port, AND record this in statistics"
- Programmable, complex, powerful

### Why Flow Tables?

In a traditional network switch, the only decision is "which port?" based on MAC address. But OpenShift needs to:

- Route between overlay networks (different subnets on the same physical network)
- Enforce network policies (allow/deny traffic)
- Handle NAT for services
- Track connections for load balancing
- Tunnel traffic between nodes using VXLAN/Geneve

Flow tables make all this possible by allowing **programmable packet processing**.

### How Flow Tables Work

When a packet arrives at an OVS bridge:

1. **Match**: OVS checks the packet against flow rules in order of priority
2. **Action**: When a match is found, OVS executes the associated actions
3. **Pipeline**: Actions might include "goto next table" - packets can traverse multiple tables
4. **Default**: If no match, use the default flow (often "drop" or "send to controller")

**Example Flow Rule (we'll break this down today):**

```
priority=100,ip,in_port=5,nw_src=10.128.0.5,nw_dst=10.128.1.10 actions=set_field:100->tun_id,output:10
```

**In English:**
- Priority: 100 (higher = checked first)
- Match: IP packet from port 5, source IP 10.128.0.5, destination 10.128.1.10
- Actions: Set tunnel ID to 100, send out port 10

### Connection to Previous Learning

**Week 2 (iptables/NAT):**
- iptables rules: Match packets by IP/port, take actions (ACCEPT, REJECT, DNAT)
- OVS flows: Similar concept but at Layer 2-3, more focused on forwarding

**Week 3 (veth pairs):**
- Yesterday you saw veth ports in OVS with ofport numbers
- Today you'll see those ofport numbers in flow rules!

**Week 5 (Services):**
- Services use iptables for load balancing
- OVS flows handle the actual packet forwarding to/from service endpoints

### Flow Table Structure

OVS uses multiple tables in sequence (a **pipeline**):

- **Table 0**: Initial classification (which network? which direction?)
- **Table 1-N**: Progressive processing (policy enforcement, routing decisions)
- **Final table**: Output action (send to port, tunnel, or drop)

OpenShift's OVN creates these tables automatically. You don't write flows manually, but understanding them is crucial for troubleshooting.

---

## Hands-On Lab

### Prerequisites

- Completed Day 43 (OVS Fundamentals)
- Access to OpenShift cluster with debug pod capability
- Familiarity with basic networking concepts (IP, MAC, ports)

### Lab Setup

We'll use the same debug pod approach as yesterday to access OVS flow tables.

---

### Exercise 1: View All Flow Tables

**Objective**: Get comfortable with ovs-ofctl and see the overall flow table structure.

```bash
# Start debug session on a worker node
NODE_NAME=$(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[0].metadata.name}')
oc debug node/$NODE_NAME
chroot /host

# View all flows on br-int
ovs-ofctl dump-flows br-int

# Count total number of flows
ovs-ofctl dump-flows br-int | wc -l

# View flows organized by table
ovs-ofctl dump-flows br-int --names | less

# Show flows with statistics
ovs-ofctl dump-flows br-int --names --no-stats=false

# View flows on br-ex
ovs-ofctl dump-flows br-ex
```

**Understanding the Output:**

Each line represents one flow rule. Example:

```
cookie=0xdeff105, duration=3600.123s, table=0, n_packets=1523, n_bytes=152300, priority=100,ip,in_port=5,nw_src=10.128.0.5 actions=goto_table:10
```

**Breaking it down:**
- `cookie=0xdeff105`: Unique identifier (set by OVN)
- `duration=3600.123s`: How long this flow has existed
- `table=0`: Which flow table this rule is in
- `n_packets=1523`: Number of packets that matched this rule
- `n_bytes=152300`: Total bytes that matched this rule
- `priority=100`: Rule priority (higher = checked first)
- `ip,in_port=5,nw_src=10.128.0.5`: Match conditions
- `actions=goto_table:10`: What to do when matched

**Key Insight:**
- High `n_packets` = this rule is actively used
- Zero packets = rule exists but hasn't matched (yet)

---

### Exercise 2: Understand Flow Matching Criteria

**Objective**: Learn to read different types of match conditions.

```bash
# Show only table 0 flows (initial classification)
ovs-ofctl dump-flows br-int table=0

# Show flows sorted by priority
ovs-ofctl dump-flows br-int --sort=priority | less

# Look for flows matching specific criteria
ovs-ofctl dump-flows br-int | grep "in_port=5"
ovs-ofctl dump-flows br-int | grep "nw_src=10.128"
ovs-ofctl dump-flows br-int | grep "dl_type=0x0800"  # IPv4 packets
```

**Common Match Fields:**

```bash
# Let's decode common match fields you'll see:

# Layer 2 (Ethernet)
# dl_src=aa:bb:cc:dd:ee:ff      - Source MAC address
# dl_dst=aa:bb:cc:dd:ee:ff      - Destination MAC address
# dl_type=0x0800                - EtherType (0x0800 = IPv4, 0x86dd = IPv6)

# Layer 3 (IP)
# nw_src=10.128.0.5             - Source IP address
# nw_dst=10.128.1.10            - Destination IP address
# nw_proto=6                    - IP protocol (6=TCP, 17=UDP, 1=ICMP)

# Layer 4 (TCP/UDP)
# tp_src=80                     - Source port
# tp_dst=443                    - Destination port

# OpenFlow Metadata
# in_port=5                     - Incoming OpenFlow port number
# tun_id=100                    - Tunnel ID (for VXLAN/Geneve)

# Special
# reg0=0x1                      - OpenFlow register 0 (used for internal state)
# metadata=0x5                  - Metadata field
```

**Exercise:** Find a flow in your output and identify:
- What layer(s) it matches on (L2, L3, L4)
- What specific criteria it checks
- What action it takes

---

### Exercise 3: Trace a Packet Through Flow Tables

**Objective**: Follow a packet's journey through the flow pipeline.

```bash
# First, get a pod IP to trace
exit  # Exit debug pod temporarily
exit

# Get a running pod
POD_NAME=$(oc get pods -n default -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$POD_NAME" ]; then
  # Create a test pod if none exists
  oc run test-pod --image=registry.access.redhat.com/ubi9/ubi-minimal:latest -- sleep 3600
  POD_NAME="test-pod"
fi

POD_IP=$(oc get pod -n default $POD_NAME -o jsonpath='{.status.podIP}')
echo "Tracing pod: $POD_NAME with IP: $POD_IP"

# Get another pod IP as destination
DEST_POD=$(oc get pods -A -o jsonpath='{.items[1].metadata.name}')
DEST_IP=$(oc get pod -A -o jsonpath='{.items[1].status.podIP}')
echo "Destination: $DEST_POD with IP: $DEST_IP"

# Back to debug pod
NODE_NAME=$(oc get pod -n default $POD_NAME -o jsonpath='{.spec.nodeName}')
oc debug node/$NODE_NAME
chroot /host

# Use ovs-appctl to trace a packet
POD_IP="<insert-pod-ip>"  # Replace with actual IP from above
DEST_IP="<insert-dest-ip>"  # Replace with actual destination IP

# Trace an ICMP packet from pod to destination
ovs-appctl ofproto/trace br-int in_port=5,icmp,nw_src=$POD_IP,nw_dst=$DEST_IP

# Trace a TCP packet to port 8080
ovs-appctl ofproto/trace br-int in_port=5,tcp,nw_src=$POD_IP,nw_dst=$DEST_IP,tp_dst=8080
```

**Understanding the Trace Output:**

The trace shows every table the packet visits and every action taken:

```
Flow: icmp,in_port=5,nw_src=10.128.0.5,nw_dst=10.128.1.10

bridge("br-int")
----------------
 0. in_port=5,nw_src=10.128.0.5, priority 100
    goto_table:10
10. ip,nw_dst=10.128.1.10, priority 50
    set_field:100->tun_id
    goto_table:20
20. tun_id=100, priority 100
    output:10

Final flow: tun_id=100,icmp,in_port=5,nw_src=10.128.0.5,nw_dst=10.128.1.10
Datapath actions: set(tunnel(tun_id=0x64,dst=192.168.1.20)),output:10
```

**What this tells us:**
1. **Table 0**: Packet matched rule for in_port=5, moved to table 10
2. **Table 10**: Matched destination IP, set tunnel ID to 100, moved to table 20
3. **Table 20**: Matched tunnel ID, output to port 10
4. **Final action**: Encapsulate in tunnel to 192.168.1.20, send out port 10

This shows the packet will be tunneled to another node!

---

### Exercise 4: Find Flow Rules for Specific Pod Traffic

**Objective**: Identify which flows handle a specific pod's traffic.

```bash
# Get the pod's veth port and ofport number (from Day 43)
POD_IP="10.128.0.5"  # Replace with your pod's IP

# Find flows matching this pod's IP as source
ovs-ofctl dump-flows br-int | grep "nw_src=$POD_IP"

# Find flows matching this pod's IP as destination
ovs-ofctl dump-flows br-int | grep "nw_dst=$POD_IP"

# Find the veth port for this pod
ip addr | grep $POD_IP -B2 | grep "veth"

# Get the ofport for this veth
VETH_NAME="<veth-name-from-above>"
OFPORT=$(ovs-vsctl get interface $VETH_NAME ofport)
echo "Pod's ofport: $OFPORT"

# Find flows using this ofport
ovs-ofctl dump-flows br-int | grep "in_port=$OFPORT"
ovs-ofctl dump-flows br-int | grep "output:$OFPORT"
```

**Analysis Questions:**
1. What table(s) handle incoming traffic to this pod?
2. What table(s) handle outgoing traffic from this pod?
3. Are any tunnel actions involved (suggesting pod is on different node)?
4. What's the priority of the flows handling this pod?

---

### Exercise 5: Understand Common Flow Actions

**Objective**: Learn to interpret different actions in flow rules.

```bash
# Find flows with different action types

# 1. Output actions (send to port)
ovs-ofctl dump-flows br-int | grep "actions=output"

# 2. Goto table actions (continue processing)
ovs-ofctl dump-flows br-int | grep "actions=goto_table"

# 3. Set field actions (modify packet)
ovs-ofctl dump-flows br-int | grep "set_field"

# 4. Drop actions (explicit)
ovs-ofctl dump-flows br-int | grep "actions=drop"

# 5. Normal action (use traditional L2 learning)
ovs-ofctl dump-flows br-int | grep "actions=NORMAL"

# 6. Resubmit actions (reprocess in another table)
ovs-ofctl dump-flows br-int | grep "resubmit"

# 7. Learn actions (dynamic flow creation)
ovs-ofctl dump-flows br-int | grep "learn"
```

**Common Actions Explained:**

```bash
# output:5
#   Send packet out OpenFlow port 5

# output:in_port
#   Send packet back out the port it came in (rare but useful for loops)

# goto_table:10
#   Continue processing in table 10

# set_field:100->tun_id
#   Set tunnel ID to 100 (for overlay networking)

# set_field:192.168.1.10->tun_dst
#   Set tunnel destination to 192.168.1.10

# mod_dl_src:aa:bb:cc:dd:ee:ff
#   Change source MAC address (NAT at L2)

# mod_nw_src:10.128.0.1
#   Change source IP address (NAT at L3)

# strip_vlan
#   Remove VLAN tag

# drop
#   Discard packet (explicit drop)

# NORMAL
#   Process using traditional switch behavior (MAC learning)
```

---

### Exercise 6: Analyze Flow Statistics for Troubleshooting

**Objective**: Use flow statistics to diagnose network issues.

```bash
# Show flows with packet counts (sorted by most active)
ovs-ofctl dump-flows br-int | sort -t',' -k4 -nr | head -20

# Find flows that have NEVER matched (might indicate misconfiguration)
ovs-ofctl dump-flows br-int | grep "n_packets=0"

# Watch flows in real-time (update statistics)
watch -n 2 'ovs-ofctl dump-flows br-int | grep "nw_src=10.128.0.5"'

# Clear flow statistics to see fresh counters
ovs-ofctl dump-flows br-int > /tmp/flows_before.txt

# Generate some traffic (from outside the debug pod)
# (Open another terminal)
# oc exec -n default $POD_NAME -- ping -c 5 8.8.8.8

# Check which flows incremented
ovs-ofctl dump-flows br-int > /tmp/flows_after.txt
diff /tmp/flows_before.txt /tmp/flows_after.txt
```

**Troubleshooting with Flow Stats:**

**Scenario 1: Pod can't reach internet**
```bash
# Check if packets are leaving the pod
ovs-ofctl dump-flows br-int | grep "in_port=$POD_OFPORT"
# Look for n_packets increasing

# Check if packets reach br-ex
ovs-ofctl dump-flows br-ex | grep "nw_src=$POD_IP"
# If zero packets, issue is between br-int and br-ex

# Check patch port flows
ovs-ofctl dump-flows br-int | grep "patch"
```

**Scenario 2: Pod-to-pod communication fails**
```bash
# Check flows for source pod
ovs-ofctl dump-flows br-int | grep "nw_src=$POD1_IP,nw_dst=$POD2_IP"

# Check if tunnel flows are working
ovs-ofctl dump-flows br-int | grep "set_field.*tun_id"

# Check for explicit drops
ovs-ofctl dump-flows br-int | grep "drop" | grep "$POD1_IP"
```

**Scenario 3: High latency**
```bash
# Check for flows causing packet recirculation (inefficient)
ovs-ofctl dump-flows br-int | grep "resubmit"

# Check kernel datapath flows (should be cached)
ovs-appctl dpctl/dump-flows | wc -l
# Low count might indicate flow cache thrashing
```

---

## Self-Check Questions

### Questions

1. **What is the difference between a flow table and a forwarding database (FDB)?**

2. **In a flow rule with priority=100 and another with priority=50, which is evaluated first?**

3. **What does `n_packets=0` indicate about a flow rule?**

4. **Explain this flow action: `set_field:100->tun_id,output:5`**

5. **How can you determine if a packet is being dropped by OVS flows?**

6. **What's the purpose of the `goto_table` action?**

7. **If you see high packet counts on flows in table 0 but zero in table 10, what might be wrong?**

8. **How do OVS flows relate to the veth pairs and ofports you learned about yesterday?**

---

### Answers

1. **Flow table vs. Forwarding Database:**
   - **FDB (Forwarding Database)**: Traditional L2 switch MAC learning table. Simple: "MAC address → port number" mapping. Dynamic, learned from traffic.
   - **Flow table**: Programmable, multi-field matching (L2-L4). Can match on IP, TCP ports, VLAN, tunnels, etc. Actions beyond simple forwarding: modify packets, tunnel, drop, etc. Static (programmed by controller) or dynamic (learn actions).
   - **In OVS**: Flow tables supersede FDB for most decisions. You can use `actions=NORMAL` to fall back to traditional FDB behavior.

2. **Priority evaluation:**
   - **Higher priority is evaluated first**. Priority=100 is checked before priority=50.
   - If priority=100 matches, its action executes (unless action is `goto_table`).
   - Priority=50 only considered if priority=100 doesn't match.
   - Think of it like iptables: more specific rules (higher priority) before general rules.

3. **n_packets=0 meaning:**
   - The flow rule exists but **no packets have matched it yet**.
   - Possible reasons:
     - Newly installed rule, traffic hasn't occurred yet (normal)
     - Rule is for error/edge case that hasn't happened (normal)
     - Rule is misconfigured and will never match (problem)
     - Higher priority rule is matching first, preventing this rule from being reached (check rule ordering)

4. **Flow action explanation:**
   ```
   set_field:100->tun_id,output:5
   ```
   - **set_field:100->tun_id**: Set the tunnel ID field to 100. This is metadata used for overlay networking (VXLAN/Geneve). Indicates the packet belongs to virtual network 100.
   - **output:5**: Send the packet out OpenFlow port 5.
   - **Combined meaning**: Tag this packet for tunnel network 100, then send it out port 5 (which is likely a tunnel port to another node).

5. **Determining if packets are dropped:**
   - **Method 1**: Look for explicit drop actions: `ovs-ofctl dump-flows br-int | grep "actions=drop"`
   - **Method 2**: Check for packets that enter but don't exit: Compare `n_packets` on ingress flows vs egress flows for the same traffic
   - **Method 3**: Use packet trace: `ovs-appctl ofproto/trace` - if it ends with "drop" or no output action, packet is dropped
   - **Method 4**: Check default/miss behavior: If no flow matches and table has no default, packet is dropped
   - **Method 5**: Check datapath: `ovs-appctl dpctl/dump-flows` shows kernel drops

6. **Purpose of goto_table action:**
   - **Pipeline processing**: Allows packet to continue through multiple flow tables sequentially.
   - **Separation of concerns**: Different tables handle different aspects (table 0: classification, table 10: policy, table 20: routing, table 30: output).
   - **Modularity**: OVN can update specific tables without rewriting all flows.
   - **Example**: `actions=goto_table:10` means "I've done my processing, now let table 10 handle the next step."
   - Without `goto_table`, packet processing would end after first match (unless using resubmit).

7. **High table 0 packets, zero in table 10:**
   - **Problem**: Packets are matching in table 0 but not reaching table 10.
   - **Possible causes**:
     - Table 0 flows are dropping packets: `actions=drop`
     - Table 0 flows output directly: `actions=output:X` (skipping table 10)
     - Table 0 flows go to different table: `actions=goto_table:15` (bypassing table 10)
     - Table 0 flows are incomplete/misconfigured: Missing `goto_table` action entirely
   - **Diagnosis**: `ovs-ofctl dump-flows br-int table=0` and check actions of high-count flows

8. **OVS flows and veth pairs/ofports:**
   - **Yesterday (Day 43)**: You learned veth pairs connect pods to br-int, and each veth has an ofport number.
   - **Today**: Those ofport numbers appear in flow rules!
   - **Connection**:
     - `ovs-vsctl get interface veth123 ofport` → returns "5"
     - Flow rule: `in_port=5,nw_src=10.128.0.5 actions=...` → This rule handles traffic FROM the pod on veth123
     - Flow rule: `nw_dst=10.128.0.5 actions=output:5` → This rule sends traffic TO the pod on veth123
   - **Complete picture**: Physical connection (veth) + logical forwarding (flows) = pod networking

---

## Today I Learned (TIL)

### Template

```
Date: _______________

# Day 44: OVS Flow Tables

## Key Concepts Mastered
- [ ] Can read OpenFlow flow rules
- [ ] Understand flow matching criteria (in_port, nw_src, nw_dst, etc.)
- [ ] Can interpret flow actions (output, goto_table, set_field)
- [ ] Successfully traced a packet through multiple tables
- [ ] Used flow statistics for troubleshooting

## Important Commands Learned
1. ovs-ofctl dump-flows <bridge> - ________________________________
2. ovs-appctl ofproto/trace - ________________________________
3. ovs-ofctl dump-flows <bridge> table=N - ________________________________

## Real-World Troubleshooting Scenario
Problem I diagnosed:
_____________________________________________________________

Flows I examined:
_____________________________________________________________

What I learned:
_____________________________________________________________

## Connection to Day 43
The ofport numbers I found yesterday (e.g., port 5 for pod X) appeared in
these flow rules:
_____________________________________________________________

## Most Interesting Flow Rule I Found
Rule: _____________________________________________________________

What it does: _____________________________________________________________

Why it matters: _____________________________________________________________

## Questions/Confusions to Explore
1. _____________________________________________________________
2. _____________________________________________________________

## Tomorrow's Preview
Tomorrow I'll learn about OVN (Open Virtual Network) - the control plane that
CREATES these flows automatically. You'll understand the architecture behind
the flows you analyzed today.
```

---

## Commands Cheat Sheet

### Essential ovs-ofctl Commands

```bash
# === Viewing Flows ===

# Dump all flows on a bridge
ovs-ofctl dump-flows <bridge>

# Dump flows from specific table
ovs-ofctl dump-flows <bridge> table=<number>

# Show flows with human-readable port names
ovs-ofctl dump-flows <bridge> --names

# Show flows sorted by priority
ovs-ofctl dump-flows <bridge> --sort=priority

# Show flows with statistics
ovs-ofctl dump-flows <bridge> --no-stats=false


# === Filtering Flows ===

# Filter by specific match criteria
ovs-ofctl dump-flows <bridge> | grep "in_port=5"
ovs-ofctl dump-flows <bridge> | grep "nw_src=10.128.0.5"
ovs-ofctl dump-flows <bridge> | grep "nw_dst=10.128.1.10"

# Find flows with specific actions
ovs-ofctl dump-flows <bridge> | grep "output:"
ovs-ofctl dump-flows <bridge> | grep "goto_table"
ovs-ofctl dump-flows <bridge> | grep "set_field"
ovs-ofctl dump-flows <bridge> | grep "drop"

# Find unused flows (no packets matched)
ovs-ofctl dump-flows <bridge> | grep "n_packets=0"

# Find most active flows
ovs-ofctl dump-flows <bridge> | sort -t',' -k4 -nr | head -20


# === Packet Tracing ===

# Trace an ICMP packet
ovs-appctl ofproto/trace <bridge> \
  in_port=<port>,icmp,nw_src=<src-ip>,nw_dst=<dst-ip>

# Trace a TCP packet
ovs-appctl ofproto/trace <bridge> \
  in_port=<port>,tcp,nw_src=<src-ip>,nw_dst=<dst-ip>,tp_dst=<port>

# Trace a UDP packet
ovs-appctl ofproto/trace <bridge> \
  in_port=<port>,udp,nw_src=<src-ip>,nw_dst=<dst-ip>,tp_dst=<port>

# Trace with full packet hex
ovs-appctl ofproto/trace <bridge> <hex-packet>


# === Flow Statistics ===

# Clear flow statistics
ovs-ofctl del-flows <bridge> --strict

# Watch flows in real-time
watch -n 2 'ovs-ofctl dump-flows <bridge> | grep <pattern>'

# Compare flow stats before/after
ovs-ofctl dump-flows <bridge> > /tmp/before.txt
# ... generate traffic ...
ovs-ofctl dump-flows <bridge> > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt


# === Datapath Flows (Kernel Cache) ===

# Show kernel datapath flows
ovs-appctl dpctl/dump-flows

# Show datapath statistics
ovs-appctl dpctl/show

# Clear datapath flows
ovs-appctl dpctl/del-flows


# === OpenFlow Table Information ===

# Show table features
ovs-ofctl dump-tables <bridge>

# Show aggregate statistics per table
ovs-ofctl dump-aggregate <bridge> table=<number>


# === Combining with Other Tools ===

# Find ofport for a veth
ovs-vsctl get interface <veth-name> ofport

# Find flows for specific pod
POD_IP="10.128.0.5"
VETH=$(ip addr | grep $POD_IP -B2 | grep -o "veth[^:]*")
OFPORT=$(ovs-vsctl get interface $VETH ofport)
ovs-ofctl dump-flows br-int | grep "in_port=$OFPORT"
ovs-ofctl dump-flows br-int | grep "nw_src=$POD_IP"
```

### Flow Rule Syntax Quick Reference

```bash
# Match Fields
in_port=<number>              # Incoming OpenFlow port
dl_src=<mac>                  # Source MAC
dl_dst=<mac>                  # Destination MAC
dl_type=<hex>                 # EtherType (0x0800=IPv4, 0x86dd=IPv6)
nw_src=<ip>                   # Source IP
nw_dst=<ip>                   # Destination IP
nw_proto=<number>             # IP protocol (6=TCP, 17=UDP, 1=ICMP)
tp_src=<port>                 # Source TCP/UDP port
tp_dst=<port>                 # Destination TCP/UDP port
tun_id=<number>               # Tunnel ID
metadata=<number>             # Metadata field
reg0=<number>                 # Register 0 (OVN uses registers for state)

# Actions
output:<port>                 # Send to port
output:in_port                # Send back to input port
goto_table:<number>           # Continue in another table
resubmit(,<table>)           # Reprocess in another table
drop                          # Discard packet
NORMAL                        # Use traditional L2 switching
set_field:<value>-><field>   # Modify field
mod_dl_src:<mac>             # Change source MAC
mod_dl_dst:<mac>             # Change dest MAC
mod_nw_src:<ip>              # Change source IP
mod_nw_dst:<ip>              # Change dest IP
mod_tp_src:<port>            # Change source port
mod_tp_dst:<port>            # Change dest port
strip_vlan                    # Remove VLAN tag
push_vlan:<ethertype>        # Add VLAN tag
```

### Troubleshooting Workflow

```bash
# Problem: Pod can't communicate

# Step 1: Find pod's ofport
POD_IP="<pod-ip>"
VETH=$(ip addr | grep $POD_IP -B2 | grep -o "veth[^:]*")
OFPORT=$(ovs-vsctl get interface $VETH ofport)
echo "Pod is on port: $OFPORT"

# Step 2: Check flows for this pod
echo "=== Outgoing flows (from pod) ==="
ovs-ofctl dump-flows br-int | grep "in_port=$OFPORT"

echo "=== Incoming flows (to pod) ==="
ovs-ofctl dump-flows br-int | grep "output:$OFPORT"

# Step 3: Trace a packet
ovs-appctl ofproto/trace br-int \
  in_port=$OFPORT,icmp,nw_src=$POD_IP,nw_dst=8.8.8.8

# Step 4: Check for drops
ovs-ofctl dump-flows br-int | grep "drop" | grep -E "($POD_IP|in_port=$OFPORT)"

# Step 5: Check statistics
ovs-ofctl dump-flows br-int | grep "in_port=$OFPORT" | grep "n_packets"
# If zero, packets aren't leaving pod
```

---

## What's Next

### Tomorrow: Day 45 - OVN Architecture

Today you learned how to **read** the flows. Tomorrow you'll learn **who writes them**.

**Preview:**
- OVN (Open Virtual Network) architecture
- Northbound and Southbound databases
- ovnkube-master and ovnkube-node components
- How OVN translates logical networks into OVS flows
- The relationship between Kubernetes resources and OVN objects

**Key Insight:**
When you create a Pod in OpenShift:
1. Kubernetes API creates Pod object
2. **OVN Northbound DB** records logical port
3. **OVN Controller** translates to flows
4. **OVS** receives the flows you studied today

**Preparation:**
- Review the flows you found today - tomorrow you'll learn where they come from
- Think about: "Who decides what flows to install? How do they know what pods exist?"

### Week 7 Progress

- **Day 43**: OVS structure (bridges, ports) ✓
- **Day 44**: OVS logic (flows, forwarding) ✓
- **Day 45**: OVN control plane (tomorrow)
- **Day 46**: Complete traffic flow tracing
- **Day 47-48**: Services using OVS/OVN
- **Day 49**: Real-world troubleshooting scenario

You now understand the **data plane** (how packets are forwarded). Tomorrow you'll understand the **control plane** (how forwarding decisions are made).

---

**Pro Tip**: Save interesting flow rules you found today. Tomorrow, you'll use `ovn-nbctl` and `ovn-sbctl` to see how those flows were generated from OVN's logical network configuration!
