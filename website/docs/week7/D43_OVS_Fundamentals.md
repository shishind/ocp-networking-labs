# Day 43: OVS Fundamentals

**Week 7, Day 43: Phase 4 - OpenShift Networking Deep Dive**

---

## Learning Objectives

By the end of this lab, you will be able to:

1. Understand the role of Open vSwitch (OVS) in OpenShift networking
2. Identify and explain the purpose of br-int and br-ex bridges
3. Navigate OVS bridge configurations using ovs-vsctl commands
4. Map OVS ports to pod network interfaces (veth pairs from Week 3)
5. Draw a complete network topology showing how OVS connects all components
6. Troubleshoot OVS bridge connectivity issues

---

## Plain English Explanation

### What is Open vSwitch (OVS)?

Think of Open vSwitch as a software-based network switch that runs inside your OpenShift nodes. Just like a physical network switch in a data center connects multiple devices, OVS connects all the virtual network interfaces on a node.

**Why OVS instead of regular Linux networking?**

Regular Linux bridges work fine for simple scenarios, but OpenShift needs:
- **High performance**: OVS is optimized for virtual environments
- **Flow-based forwarding**: Instead of just MAC learning, OVS uses programmable flow tables
- **Network virtualization**: OVS integrates with OVN (which we'll cover later) to create logical networks
- **Monitoring and troubleshooting**: Rich tools to inspect what's happening

### The Two Main Bridges

OpenShift uses two primary OVS bridges on each node:

**1. br-int (Integration Bridge)**
- The "internal hub" for all pod networking
- Every pod's veth pair (remember Week 3?) connects here
- Handles pod-to-pod communication within and across nodes
- Integrates with OVN logical networks
- Think of it as the "inside" network switch

**2. br-ex (External Bridge)**
- The "gateway to the outside world"
- Connects to the physical network interface (like eth0 or ens3)
- Handles traffic going to/from external networks
- Used for NodePort, LoadBalancer services, and egress traffic
- Think of it as the "outside" network switch

### How They Work Together

Here's the flow when a pod talks to the internet:

1. Pod sends packet → veth pair → **br-int** (internal bridge)
2. br-int processes packet using OVN rules → determines it needs external access
3. Packet flows through patch port → **br-ex** (external bridge)
4. br-ex sends packet → physical NIC → external network

**Connection to Previous Weeks:**
- **Week 2-3**: You learned about network namespaces and veth pairs. OVS bridges are where one end of those veth pairs connects!
- **Week 3**: The `ip link` commands showed veth interfaces. Now you'll see the other side in OVS.
- **Week 5**: Services create iptables rules that work alongside OVS to route traffic.

### OVS Ports Explained

When you run `ovs-vsctl show`, you'll see various port types:

- **Internal ports**: Virtual interfaces owned by OVS itself (like br-int, br-ex)
- **veth ports**: One end of pod veth pairs (the other end is in the pod's netns)
- **Patch ports**: Connect two OVS bridges together (like br-int to br-ex)
- **Physical ports**: Real network interfaces (eth0, ens3, etc.)

---

## Hands-On Lab

### Prerequisites

- Access to an OpenShift cluster with debug/privileged pod capability
- Cluster admin or equivalent permissions
- Understanding of network namespaces and veth pairs (Week 3)

### Lab Setup

We'll use a debug pod to access the OVS tools on a node. This is the standard way to inspect OVS on OpenShift since the tools run in containers.

---

### Exercise 1: Access OVS on a Node

**Objective**: Get shell access to explore OVS on an OpenShift node.

```bash
# Get list of nodes
oc get nodes

# Choose a worker node and start a debug pod
NODE_NAME=$(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[0].metadata.name}')
echo "Using node: $NODE_NAME"

# Start privileged debug session
oc debug node/$NODE_NAME

# Once inside the debug pod, switch to host namespace
chroot /host

# Verify OVS is running
systemctl status ovs-vswitchd
systemctl status ovsdb-server

# Check OVS version
ovs-vsctl --version
```

**Expected Output:**
- You should see OVS version 2.x running
- Both ovs-vswitchd (the switch daemon) and ovsdb-server (the database) should be active

**Understanding:**
- `ovs-vswitchd`: The actual switch that forwards packets
- `ovsdb-server`: Stores the configuration (bridges, ports, flows)

---

### Exercise 2: Identify OVS Bridges and Ports

**Objective**: Explore the OVS configuration and identify all bridges and ports.

```bash
# Display complete OVS configuration
ovs-vsctl show

# List all bridges
ovs-vsctl list-br

# For each bridge, show its ports
ovs-vsctl list-ports br-int
ovs-vsctl list-ports br-ex

# Get detailed information about br-int
ovs-vsctl list bridge br-int

# Show interface statistics
ovs-vsctl list interface
```

**Sample Output Analysis:**

```
Bridge br-int
    fail_mode: secure
    datapath_type: system
    Port ovn-k8s-mp0
        Interface ovn-k8s-mp0
            type: internal
    Port patch-br-int-to-br-ex
        Interface patch-br-int-to-br-ex
            type: patch
            options: {peer=patch-br-ex-to-br-int}
    Port veth1234abcd
        Interface veth1234abcd
    Port br-int
        Interface br-int
            type: internal

Bridge br-ex
    Port patch-br-ex-to-br-int
        Interface patch-br-ex-to-br-int
            type: patch
            options: {peer=patch-br-int-to-br-ex}
    Port br-ex
        Interface br-ex
            type: internal
    Port eth0
        Interface eth0
```

**What This Tells Us:**

1. **br-int ports**:
   - `ovn-k8s-mp0`: OVN management port (for node-to-OVN communication)
   - `patch-br-int-to-br-ex`: Connection to external bridge
   - `veth1234abcd`: Pod network interface (one end of veth pair)
   - `br-int`: The bridge's own internal interface

2. **br-ex ports**:
   - `patch-br-ex-to-br-int`: Connection to internal bridge
   - `eth0`: Physical network interface
   - `br-ex`: The bridge's own internal interface

---

### Exercise 3: Map OVS Ports to Pods

**Objective**: Correlate OVS veth ports with actual running pods.

```bash
# List all ports on br-int (in the debug pod)
ovs-vsctl list-ports br-int | grep veth > /tmp/ovs-ports.txt

# Exit debug pod temporarily (Ctrl+D or exit)
exit
exit

# From your regular terminal, get pod network info
oc get pods -A -o wide | head -20

# Pick a pod to investigate
POD_NAME="<your-pod-name>"
POD_NAMESPACE="<namespace>"

# Get the pod's network namespace and veth pair
oc exec -n $POD_NAMESPACE $POD_NAME -- ip link show

# Start debug pod again to correlate
oc debug node/$NODE_NAME
chroot /host

# Find veth pairs
ip link show | grep veth

# For a specific veth, find its peer
VETH_NAME="veth1234abcd"  # Replace with actual name from ovs-vsctl
ethtool -S $VETH_NAME | grep peer_ifindex

# Find what interface has that index
PEER_INDEX=<number-from-above>
ip link | grep "^$PEER_INDEX:"
```

**Understanding the Connection:**
- One end of veth pair: Inside pod's network namespace (eth0 from pod's perspective)
- Other end of veth pair: In host namespace, plugged into br-int
- This is the physical manifestation of what you learned in Week 3!

---

### Exercise 4: Inspect OVS Port Details

**Objective**: Deep dive into port configurations and statistics.

```bash
# Get detailed info about all interfaces on br-int
ovs-vsctl list interface | less

# For a specific port, get detailed stats
PORT_NAME="veth1234abcd"  # Use actual port name
ovs-vsctl list interface $PORT_NAME

# Check port statistics
ovs-vsctl get interface $PORT_NAME statistics

# Check for errors
ovs-vsctl get interface $PORT_NAME error

# Show MAC address learning (FDB - forwarding database)
ovs-appctl fdb/show br-int

# Show interface information including ofport (OpenFlow port number)
ovs-vsctl --columns=name,ofport,ofport_request list interface
```

**Key Fields to Understand:**
- `ofport`: OpenFlow port number (used in flow rules - tomorrow's topic!)
- `statistics`: RX/TX packets, bytes, errors, drops
- `mac_in_use`: MAC address of the interface
- `error`: Any errors on the port
- `admin_state`: up or down

**Troubleshooting Tip:**
If a pod can't communicate:
1. Check if its veth port shows up in `ovs-vsctl list-ports br-int`
2. Check if the port's `admin_state` is "up"
3. Check for errors in statistics
4. Verify the ofport is a valid number (not -1)

---

### Exercise 5: Explore Bridge Connectivity

**Objective**: Understand how bridges connect to each other and the physical network.

```bash
# Show the patch ports connecting br-int and br-ex
ovs-vsctl show | grep -A3 patch

# Get detailed info about the patch connection
ovs-vsctl list port patch-br-int-to-br-ex
ovs-vsctl list port patch-br-ex-to-br-int

# Verify the peer relationship
ovs-vsctl get interface patch-br-int-to-br-ex options

# Check if physical interface is properly connected to br-ex
ovs-vsctl list-ports br-ex

# Get info about the physical port
ovs-vsctl list port eth0

# Check the physical interface configuration
ip addr show eth0
ip addr show br-ex
```

**Understanding Patch Ports:**
- Patch ports are like a "virtual cable" between two bridges
- Traffic entering one patch port immediately exits its peer
- This is how packets move from br-int to br-ex and vice versa
- The `options: {peer=...}` field defines the connection

---

### Exercise 6: Draw the Complete Topology

**Objective**: Create a comprehensive network topology diagram based on your findings.

```bash
# Gather all the information
echo "=== BRIDGES ==="
ovs-vsctl list-br

echo -e "\n=== BR-INT PORTS ==="
ovs-vsctl list-ports br-int

echo -e "\n=== BR-EX PORTS ==="
ovs-vsctl list-ports br-ex

echo -e "\n=== PATCH CONNECTIONS ==="
ovs-vsctl show | grep -A2 patch

echo -e "\n=== PHYSICAL INTERFACES ==="
ip addr show | grep -E "^[0-9]+: (eth|ens|br-)"

# Save to file for documentation
ovs-vsctl show > /tmp/ovs-topology.txt
ip addr show > /tmp/ip-config.txt
```

**Now draw this topology on paper or in a text editor:**

```
External Network
       |
    [eth0] (Physical NIC)
       |
   +---+---+
   | br-ex |  (External Bridge)
   +---+---+
       |
   [patch-br-ex-to-br-int] <---> [patch-br-int-to-br-ex]
                                      |
                                  +---+---+
                                  | br-int|  (Integration Bridge)
                                  +---+---+
                                      |
                    +-----------------+-----------------+
                    |                 |                 |
              [veth-pod1]       [veth-pod2]      [ovn-k8s-mp0]
                    |                 |                 |
                  Pod 1             Pod 2          OVN Management
             (netns: pod1)      (netns: pod2)
```

**Add these details to your diagram:**
1. Which node you're on
2. At least 3 pod veth connections
3. The patch port connection
4. The physical interface
5. Label each component with its purpose

---

## Self-Check Questions

### Questions

1. **What is the primary difference between br-int and br-ex?**

2. **How does a veth pair from a pod connect to OVS?**

3. **What would happen if the patch port between br-int and br-ex failed?**

4. **Why does OpenShift use OVS instead of regular Linux bridges?**

5. **If you see a veth port in `ovs-vsctl list-ports br-int`, how can you determine which pod it belongs to?**

6. **What does an ofport value of -1 indicate?**

7. **How can you verify that the physical network interface is properly connected to br-ex?**

---

### Answers

1. **Primary difference between br-int and br-ex:**
   - **br-int (Integration Bridge)**: Handles all internal pod-to-pod communication. All pod veth pairs connect here. It integrates with OVN logical networks for overlay networking.
   - **br-ex (External Bridge)**: Provides external connectivity. It connects to the physical network interface and handles traffic to/from outside the cluster (egress, ingress, NodePort services).

2. **How veth pairs connect to OVS:**
   - One end of the veth pair exists in the pod's network namespace (appears as eth0 inside the pod)
   - The other end exists in the host's network namespace
   - That host-side veth interface is added as a port to the br-int bridge using `ovs-vsctl add-port`
   - This creates the connection: Pod → veth → br-int → OVN/network

3. **If patch port between br-int and br-ex failed:**
   - Pods would lose external connectivity (no internet access)
   - Pods couldn't reach services outside the cluster
   - NodePort and LoadBalancer services would fail
   - Pod-to-pod communication within the cluster would still work (that only uses br-int)
   - Ingress traffic couldn't reach pods

4. **Why OVS instead of regular Linux bridges:**
   - **Performance**: OVS is optimized for virtualized environments with high packet rates
   - **Flow-based processing**: Programmable OpenFlow rules for complex routing decisions
   - **Network virtualization**: Native integration with OVN for overlay networks (VXLAN/Geneve tunnels)
   - **Monitoring**: Rich tooling (ovs-vsctl, ovs-ofctl, ovs-appctl) for troubleshooting
   - **Advanced features**: QoS, mirroring, tunneling, flow-based security

5. **Determining which pod a veth port belongs to:**
   - Method 1: Find the peer interface index using `ethtool -S veth1234 | grep peer_ifindex`, then search for that index in pod network namespaces
   - Method 2: Compare creation timestamps between OVS ports and pod start times
   - Method 3: Use `ip netns` to list all network namespaces, exec into each, and check for the peer veth
   - Method 4: Check OVN database which maintains pod-to-port mappings: `ovn-nbctl list logical_switch_port`

6. **ofport value of -1 indicates:**
   - The port is not properly connected or configured
   - OpenFlow can't use this port (it has no valid OpenFlow port number)
   - This usually indicates a problem: the interface is down, misconfigured, or failed to initialize
   - Check interface status with `ovs-vsctl list interface <name>` and look for errors

7. **Verify physical interface connection to br-ex:**
   - Check it appears in `ovs-vsctl list-ports br-ex`
   - Verify the port status: `ovs-vsctl list port eth0` shows it's configured
   - Check interface is up: `ovs-vsctl list interface eth0` shows `admin_state: up`
   - Verify IP address was moved from eth0 to br-ex: `ip addr show` (br-ex should have the IP that eth0 previously had)
   - Check for packet statistics: `ovs-vsctl get interface eth0 statistics` shows RX/TX activity

---

## Today I Learned (TIL)

### Template

```
Date: _______________

# Day 43: OVS Fundamentals

## Key Concepts Mastered
- [ ] Can identify br-int and br-ex bridges using ovs-vsctl
- [ ] Understand the purpose of each bridge
- [ ] Can map veth ports to running pods
- [ ] Can explain patch port connections
- [ ] Drew complete network topology

## Important Commands Learned
1. ovs-vsctl show - ________________________________
2. ovs-vsctl list-ports <bridge> - ________________________________
3. ovs-vsctl list interface <port> - ________________________________

## Real-World Application
How I would use this knowledge:
_____________________________________________________________
_____________________________________________________________

## Connection to Previous Learning
This connects to Week 3 (veth pairs) because:
_____________________________________________________________
_____________________________________________________________

## Questions/Confusions to Explore
1. _____________________________________________________________
2. _____________________________________________________________

## Tomorrow's Preview
Tomorrow I'll learn about OVS flow tables and OpenFlow rules - how OVS actually
makes forwarding decisions using programmable flow rules.
```

---

## Commands Cheat Sheet

### Essential OVS Commands

```bash
# === Basic OVS Information ===

# Show complete OVS configuration
ovs-vsctl show

# List all bridges
ovs-vsctl list-br

# List ports on a bridge
ovs-vsctl list-ports <bridge-name>

# Check OVS version
ovs-vsctl --version
ovs-vswitchd --version


# === Bridge Operations ===

# Get bridge information
ovs-vsctl list bridge <bridge-name>

# Get all bridge details
ovs-vsctl list bridge


# === Port and Interface Information ===

# List all interfaces
ovs-vsctl list interface

# Get specific interface details
ovs-vsctl list interface <interface-name>

# Get specific field from interface
ovs-vsctl get interface <interface-name> <field>
# Examples:
ovs-vsctl get interface veth123 ofport
ovs-vsctl get interface veth123 statistics
ovs-vsctl get interface veth123 mac_in_use

# List all ports with their OpenFlow port numbers
ovs-vsctl --columns=name,ofport list interface

# Get port information
ovs-vsctl list port <port-name>


# === Statistics and Monitoring ===

# Show MAC learning table (forwarding database)
ovs-appctl fdb/show <bridge-name>

# Show interface statistics
ovs-vsctl get interface <interface-name> statistics

# Show datapath information
ovs-appctl dpif/show

# Show coverage statistics
ovs-appctl coverage/show


# === Troubleshooting ===

# Check service status
systemctl status ovs-vswitchd
systemctl status ovsdb-server

# View logs
journalctl -u ovs-vswitchd -f
journalctl -u ovsdb-server -f

# Verify database consistency
ovsdb-client dump

# Check datapath flows (kernel level)
ovs-appctl dpctl/dump-flows


# === OpenShift/Debug Pod Access ===

# Start debug session on node
oc debug node/<node-name>

# Once in debug pod
chroot /host

# Find veth peer
ethtool -S <veth-name> | grep peer_ifindex

# List network interfaces
ip link show | grep veth


# === Useful Filters and Formatting ===

# Show only specific columns
ovs-vsctl --columns=name,ofport,error list interface

# Find specific port type
ovs-vsctl show | grep -A3 "type: patch"

# List veth ports only
ovs-vsctl list-ports br-int | grep veth

# Count ports on a bridge
ovs-vsctl list-ports br-int | wc -l
```

### Quick Reference: OVS Architecture

```
ovs-vswitchd (daemon)
    |
    +-- Datapath (kernel module or userspace)
    |   +-- Fast path for packet forwarding
    |   +-- Uses flow cache
    |
    +-- OpenFlow tables
        +-- Flow rules for packet processing

ovsdb-server (daemon)
    |
    +-- Stores configuration
    +-- Bridges, ports, interfaces
    +-- Accessed via ovs-vsctl
```

### Quick Diagnosis Guide

```bash
# Problem: Pod networking not working

# Step 1: Check if pod's veth is in OVS
NODE=<pod's node>
oc debug node/$NODE
chroot /host
ovs-vsctl list-ports br-int | grep veth

# Step 2: Check port status
ovs-vsctl list interface <veth-name>
# Look for: admin_state=up, ofport != -1, no errors

# Step 3: Check bridge connectivity
ovs-vsctl show | grep patch
# Verify patch ports exist and are connected

# Step 4: Check physical connectivity
ovs-vsctl list-ports br-ex
ip addr show br-ex
ip addr show eth0
```

---

## What's Next

### Tomorrow: Day 44 - OVS Flow Tables

You've learned the **structure** of OVS (bridges, ports, connections). Tomorrow you'll learn the **logic** - how OVS actually decides what to do with packets using OpenFlow rules.

**Preview:**
- Reading and understanding OpenFlow flow tables
- Using `ovs-ofctl dump-flows` to see forwarding rules
- Tracing how a specific packet gets processed
- Understanding match conditions and actions
- Connecting flows to actual pod traffic

**Preparation:**
- Review the veth port names you discovered today
- Pick a specific pod whose traffic you want to trace tomorrow
- Think about: "When a packet arrives at br-int from a pod, how does OVS know where to send it?"

### Week 7 Connection

This week builds on everything you've learned:
- **Days 43-44**: OVS fundamentals and flows (the data plane)
- **Days 45-46**: OVN architecture and traffic flows (the control plane)
- **Days 47-48**: Routes, DNS, and egress (services that use OVS/OVN)
- **Day 49**: Weekend scenario putting it all together

By Friday, you'll understand the complete path of every packet in OpenShift!

---

**Remember**: OVS is complex, but it's just software doing network switching. Every component has a purpose. When troubleshooting, think:
1. Is the port connected? (today's focus)
2. Do the flows route correctly? (tomorrow)
3. Is OVN configuration correct? (Day 45-46)

You've got this!
