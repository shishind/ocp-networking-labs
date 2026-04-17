# Day 45: OVN Architecture

**Week 7, Day 45: Phase 4 - OpenShift Networking Deep Dive**

---

## Learning Objectives

By the end of this lab, you will be able to:

1. Understand OVN (Open Virtual Network) architecture and components
2. Explain the role of Northbound (NB) and Southbound (SB) databases
3. Navigate ovnkube-master and ovnkube-node pods in OpenShift
4. Query OVN databases to understand logical network topology
5. Correlate Kubernetes resources (Pods, Services) with OVN logical objects
6. Trace how changes flow from Kubernetes API → OVN → OVS flows

---

## Plain English Explanation

### What is OVN?

For the past two days, you've been looking at the **data plane** - how packets actually move through OVS bridges and flows. Today we're looking at the **control plane** - who decides what those bridges and flows should be.

**OVN (Open Virtual Network)** is the "network controller" for OpenShift. Think of it as the intelligent brain that:

- Understands what pods exist and where they are
- Creates logical networks (subnets) for different purposes
- Translates logical network concepts into OVS flow rules
- Keeps everything synchronized across all nodes

**Without OVN:**
- You'd manually configure OVS on every node
- Adding a pod would require manually updating flows on multiple nodes
- Networking would be a nightmare in a dynamic Kubernetes environment

**With OVN:**
- Create a pod → OVN automatically configures networking
- Delete a pod → OVN automatically cleans up
- Add a service → OVN automatically sets up load balancing
- Everything stays synchronized

### The OVN Architecture

OVN has a hierarchical architecture with three layers:

```
┌─────────────────────────────────────────────────────────┐
│  Kubernetes API (Pods, Services, NetworkPolicies)       │
└─────────────────┬───────────────────────────────────────┘
                  │
                  │ ovnkube-master watches K8s API
                  ↓
┌─────────────────────────────────────────────────────────┐
│  OVN Northbound Database (NB DB)                        │
│  "What we want" - Logical view                          │
│  - Logical switches (like K8s networks)                 │
│  - Logical ports (like pod interfaces)                  │
│  - Logical routers (like gateways)                      │
│  - ACLs (like NetworkPolicies)                          │
└─────────────────┬───────────────────────────────────────┘
                  │
                  │ ovn-northd translates
                  ↓
┌─────────────────────────────────────────────────────────┐
│  OVN Southbound Database (SB DB)                        │
│  "How to do it" - Physical view                         │
│  - Datapath bindings (logical to physical mapping)      │
│  - Port bindings (which pod on which node)              │
│  - Flows (logical flows, not yet OVS flows)             │
└─────────────────┬───────────────────────────────────────┘
                  │
                  │ ovn-controller (on each node)
                  ↓
┌─────────────────────────────────────────────────────────┐
│  OVS Flows (what you studied on Day 44)                 │
│  Actual OpenFlow rules in br-int                        │
└─────────────────────────────────────────────────────────┘
```

### Key Components in OpenShift

**1. ovnkube-master (Control Plane)**
- Runs on control plane nodes
- Watches Kubernetes API for changes
- Translates K8s objects into OVN Northbound DB entries
- Example: Pod created → ovnkube-master creates logical switch port in NB DB

**2. ovn-northd (Translator)**
- Runs inside ovnkube-master pod
- Translates Northbound DB (logical view) into Southbound DB (physical view)
- Does NOT directly touch OVS - it just updates the SB database

**3. ovnkube-node (Node Agent)**
- Runs on every node
- Contains ovn-controller
- Watches Southbound DB for changes
- Translates logical flows into actual OVS OpenFlow rules
- Manages local networking (veth pairs, IP addresses, etc.)

**4. Databases**
- **NB DB**: Stores logical network configuration (what we want)
- **SB DB**: Stores physical implementation (how to achieve it)
- Both are ovsdb databases (same technology as OVS configuration)

### Example Flow: Creating a Pod

Let's trace what happens when you create a pod:

1. **User**: `oc run nginx --image=nginx`
2. **Kubernetes API**: Creates Pod object
3. **ovnkube-master**: 
   - Sees new pod
   - Allocates IP address from subnet
   - Creates logical switch port in NB DB
   - Creates ACLs for default network policy
4. **ovn-northd**: 
   - Sees new logical switch port
   - Creates port binding in SB DB
   - Generates logical flows for this port
5. **ovnkube-node** (on the pod's node):
   - Sees port binding for local pod
   - Creates veth pair
   - Assigns IP address to pod
   - Connects veth to br-int
6. **ovn-controller** (inside ovnkube-node):
   - Sees logical flows in SB DB
   - Translates to OpenFlow rules
   - Installs flows in OVS (what you saw on Day 44!)

**Connection to Previous Weeks:**
- **Week 3 (veth pairs)**: Step 5 creates the veth pair you learned about
- **Day 43 (OVS)**: Step 5 adds the veth to br-int bridge
- **Day 44 (flows)**: Step 6 creates the flows you studied yesterday
- **Week 5 (Services)**: Similar process for Services, with load balancer entries

### Logical vs. Physical Networks

**Logical Network (Northbound DB):**
- Logical switch "cluster-network" for all pods
- Logical port "nginx-pod-123" with IP 10.128.0.5
- Logical router "cluster-router" for inter-subnet routing

**Physical Network (Southbound DB + OVS):**
- Logical switch maps to VNI (tunnel ID) 100
- Logical port maps to veth123 on node worker-1
- Logical router maps to flows in table 10

This abstraction allows OVN to:
- Move pods between nodes (update physical mapping, keep logical network)
- Implement multi-tenancy (separate logical networks on shared physical infrastructure)
- Apply policies consistently (logical ACLs → physical flows on all nodes)

---

## Hands-On Lab

### Prerequisites

- Completed Day 43 and 44 (OVS fundamentals and flows)
- Access to OpenShift cluster with admin permissions
- Understanding of Kubernetes basic objects (Pods, Services)

---

### Exercise 1: Explore OVN Components

**Objective**: Identify and inspect the OVN pods running in your cluster.

```bash
# Find OVN pods
oc get pods -n openshift-ovn-kubernetes

# Expected output: You should see:
# - ovnkube-master pods (on control plane nodes)
# - ovnkube-node pods (on all nodes)

# Get detailed info about ovnkube-master
oc describe pod -n openshift-ovn-kubernetes -l app=ovnkube-master | less

# Get detailed info about ovnkube-node
oc describe pod -n openshift-ovn-kubernetes -l app=ovnkube-node | less

# Check which nodes run ovnkube-master
oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o wide

# Check ovnkube-node distribution (should be on all nodes)
oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-node -o wide

# View ovnkube-master logs
MASTER_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o jsonpath='{.items[0].metadata.name}')
oc logs -n openshift-ovn-kubernetes $MASTER_POD | tail -50

# View ovnkube-node logs from a specific node
NODE_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-node -o jsonpath='{.items[0].metadata.name}')
oc logs -n openshift-ovn-kubernetes $NODE_POD | tail -50
```

**Understanding the Pods:**

**ovnkube-master containers:**
- `ovnkube-master`: Main controller watching K8s API
- `nbdb`: Northbound database server
- `sbdb`: Southbound database server
- `ovn-northd`: Translator between NB and SB databases

**ovnkube-node containers:**
- `ovnkube-node`: Node agent
- `ovn-controller`: Local controller translating SB DB to OVS flows

---

### Exercise 2: Query the Northbound Database

**Objective**: Explore the logical network view in the NB database.

```bash
# Exec into ovnkube-master to access NB DB
MASTER_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o jsonpath='{.items[0].metadata.name}')
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- ovn-nbctl show

# Show logical switches (like subnets)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- ovn-nbctl ls-list

# Show logical routers
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- ovn-nbctl lr-list

# Show logical switch ports (like pod interfaces)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- ovn-nbctl lsp-list <switch-name>

# Get detailed info about a specific logical switch
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- ovn-nbctl list logical_switch

# Show load balancers (Services)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- ovn-nbctl lb-list

# Show ACLs (NetworkPolicies)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- ovn-nbctl acl-list <switch-name>
```

**Sample Output Analysis:**

```
switch 2c7e9e7f-8b4f-4e0f-9c3f-1a2b3c4d5e6f (ovn-worker-1)
    port ovn-worker-1
        addresses: ["00:00:00:a1:b2:c3 10.128.0.1"]
    port nginx-pod-abc123_default
        addresses: ["00:00:00:a1:b2:c4 10.128.0.5"]
    port storage-pod-def456_default
        addresses: ["00:00:00:a1:b2:c5 10.128.0.6"]

router ovn_cluster_router
    port rtos-ovn-worker-1
        mac: "00:00:00:aa:bb:cc"
        networks: ["10.128.0.1/23"]
```

**What this tells us:**
- Logical switch "ovn-worker-1" represents the subnet for pods on worker-1
- Each pod has a logical switch port with its MAC and IP
- Router "ovn_cluster_router" connects different node subnets
- This is the "desired state" view

---

### Exercise 3: Correlate Pods with Logical Ports

**Objective**: Map Kubernetes pods to OVN logical switch ports.

```bash
# Get a list of pods
oc get pods -A -o wide | head -10

# Choose a specific pod
POD_NAME="nginx"  # Replace with actual pod name
POD_NAMESPACE="default"
POD_IP=$(oc get pod -n $POD_NAMESPACE $POD_NAME -o jsonpath='{.status.podIP}')
POD_NODE=$(oc get pod -n $POD_NAMESPACE $POD_NAME -o jsonpath='{.spec.nodeName}')

echo "Pod: $POD_NAME"
echo "IP: $POD_IP"
echo "Node: $POD_NODE"

# Find this pod in OVN Northbound DB
MASTER_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o jsonpath='{.items[0].metadata.name}')

# Search for the pod by IP
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl find logical_switch_port addresses="$POD_IP" | grep -E "(name|addresses)"

# Or search by name pattern
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl find logical_switch_port name~"$POD_NAME"

# Get full details of the logical port
LSP_NAME="<logical-switch-port-name-from-above>"
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl list logical_switch_port $LSP_NAME
```

**Key Fields in Logical Switch Port:**
- `name`: Usually format like `podname_namespace`
- `addresses`: MAC and IP assigned to pod
- `external_ids`: Links back to Kubernetes namespace/pod
- `port_security`: Security rules for this port
- `type`: Usually empty for pod ports, or "router" for router connections

---

### Exercise 4: Query the Southbound Database

**Objective**: See how logical networks map to physical implementation.

```bash
MASTER_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o jsonpath='{.items[0].metadata.name}')

# Show complete southbound configuration
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- ovn-sbctl show

# List chassis (physical nodes)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- ovn-sbctl chassis-list

# Show port bindings (which logical ports are on which chassis)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- ovn-sbctl list port_binding

# Find a specific pod's port binding
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- \
  ovn-sbctl find port_binding logical_port="<pod-logical-port-name>"

# Show datapath bindings (logical switches mapped to tunnel IDs)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- ovn-sbctl list datapath_binding

# Show logical flows (before they become OVS flows)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- ovn-sbctl lflow-list | head -50
```

**Sample Port Binding Output:**

```
_uuid               : 12345678-1234-1234-1234-123456789abc
chassis             : worker-1-chassis-uuid
datapath            : ovn-worker-1-datapath-uuid
logical_port        : nginx-pod-abc123_default
mac                 : ["00:00:00:a1:b2:c4 10.128.0.5"]
tunnel_key          : 5
```

**What this tells us:**
- This logical port is bound to "worker-1" chassis (physical node)
- It's on the "ovn-worker-1" datapath (logical switch)
- Tunnel key is 5 (used in VXLAN/Geneve for this port)
- This is the "implementation plan" view

---

### Exercise 5: Trace Logical Flows

**Objective**: Understand logical flows before they become OVS OpenFlow rules.

```bash
MASTER_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o jsonpath='{.items[0].metadata.name}')

# Show all logical flows (warning: long output)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- ovn-sbctl lflow-list > /tmp/logical-flows.txt

# View in less
less /tmp/logical-flows.txt

# Find flows for a specific datapath (logical switch)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- \
  ovn-sbctl lflow-list <datapath-name>

# Search for flows matching a specific IP
grep "10.128.0.5" /tmp/logical-flows.txt

# Search for flows in a specific table
grep "table=10" /tmp/logical-flows.txt
```

**Sample Logical Flow:**

```
table=10(ls_in_arp_rsp), priority=50, match=(arp.tpa == 10.128.0.5 && arp.op == 1), 
  action=(eth.dst = eth.src; eth.src = 00:00:00:a1:b2:c4; arp.op = 2; 
          arp.tha = arp.sha; arp.sha = 00:00:00:a1:b2:c4; 
          arp.tpa = arp.spa; arp.spa = 10.128.0.5; outport = inport; 
          flags.loopback = 1; output;)
```

**Breaking it down:**
- **table=10**: Logical table (different from OVS table numbers)
- **ls_in_arp_rsp**: Logical switch ingress ARP response stage
- **match**: If ARP request for 10.128.0.5
- **action**: Construct ARP reply and send back

**This logical flow becomes multiple OVS flows** when ovn-controller translates it!

---

### Exercise 6: Connect All the Pieces

**Objective**: Trace from Kubernetes pod to OVN to OVS flows.

```bash
# Step 1: Pick a pod
POD_NAME="nginx"
POD_NAMESPACE="default"
oc get pod -n $POD_NAMESPACE $POD_NAME -o wide

POD_IP=$(oc get pod -n $POD_NAMESPACE $POD_NAME -o jsonpath='{.status.podIP}')
POD_NODE=$(oc get pod -n $POD_NAMESPACE $POD_NAME -o jsonpath='{.spec.nodeName}')

# Step 2: Find in Northbound DB (logical view)
MASTER_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o jsonpath='{.items[0].metadata.name}')

echo "=== NORTHBOUND (Logical View) ==="
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl find logical_switch_port | grep -A10 "$POD_IP"

# Step 3: Find in Southbound DB (physical mapping)
echo "=== SOUTHBOUND (Physical Mapping) ==="
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- \
  ovn-sbctl find port_binding | grep -A10 "$POD_IP"

# Step 4: Find in OVS (actual flows) on the node
echo "=== OVS FLOWS (Actual Implementation) ==="
oc debug node/$POD_NODE -- chroot /host ovs-ofctl dump-flows br-int | grep "$POD_IP"

# Step 5: Find the veth pair (physical interface)
echo "=== VETH INTERFACE (Physical Connection) ==="
oc debug node/$POD_NODE -- chroot /host ip addr | grep -B2 "$POD_IP"
```

**Complete the Mapping:**

Create a document showing:
```
Kubernetes Layer:
  Pod: nginx in namespace default
  IP: 10.128.0.5
  Node: worker-1

OVN Northbound (Logical):
  Logical Switch: ovn-worker-1
  Logical Switch Port: nginx_default
  Address: 00:00:00:a1:b2:c4 10.128.0.5

OVN Southbound (Physical Mapping):
  Chassis: worker-1
  Port Binding: nginx_default
  Tunnel Key: 5
  Datapath: ovn-worker-1

OVS Layer:
  Bridge: br-int
  Veth: veth1234abcd
  OpenFlow Port: 7
  Flows: [list key flows with in_port=7 or nw_src=10.128.0.5]

Linux Layer:
  Network Namespace: <pod-netns-id>
  Interface: eth0 (inside pod) ↔ veth1234abcd (in host)
```

---

## Self-Check Questions

### Questions

1. **What is the primary difference between the Northbound and Southbound databases?**

2. **Which component watches the Kubernetes API and updates the NB database?**

3. **What does ovn-northd do?**

4. **How does ovn-controller on a node know what flows to install?**

5. **If you create a NetworkPolicy in Kubernetes, what happens in OVN?**

6. **What is a "chassis" in OVN terminology?**

7. **Why does OVN use two databases (NB and SB) instead of one?**

8. **How does this architecture enable pod mobility (moving pods between nodes)?**

---

### Answers

1. **Northbound vs Southbound databases:**
   - **Northbound (NB) DB**: Stores the **logical** network topology. Intent-based, "what we want." Contains logical switches, logical ports, logical routers, ACLs, load balancers. This is the API for network configuration - what the cluster administrator or controller wants to achieve.
   - **Southbound (SB) DB**: Stores the **physical** implementation details. Execution-based, "how to do it." Contains chassis info, port bindings (which logical port is on which physical node), datapath bindings (tunnel IDs), and logical flows (which will be translated to OVS flows). This is consumed by ovn-controllers on nodes.

2. **Component that watches K8s API:**
   - **ovnkube-master** watches the Kubernetes API server.
   - When it sees changes (Pod created/deleted, Service modified, NetworkPolicy applied), it translates these into OVN Northbound database entries.
   - Example: New pod → ovnkube-master creates logical_switch_port in NB DB with allocated IP.

3. **ovn-northd role:**
   - **ovn-northd** is the **translator** between NB and SB databases.
   - It watches the NB database (logical intent) and generates corresponding SB database entries (physical implementation).
   - It computes logical flows based on logical topology, ACLs, and load balancers.
   - It does NOT directly interact with OVS - it only updates the SB database.
   - Think of it as a compiler: NB DB (high-level language) → ovn-northd (compiler) → SB DB (low-level instructions).

4. **How ovn-controller knows what flows to install:**
   - **ovn-controller** (running inside ovnkube-node on each node) watches the **Southbound database**.
   - It filters for entries relevant to its chassis (node).
   - It reads logical flows from SB DB and translates them into OpenFlow rules.
   - It installs these OpenFlow rules into local OVS bridges using ovs-ofctl.
   - When SB DB changes, ovn-controller automatically updates OVS flows.

5. **NetworkPolicy in Kubernetes → OVN:**
   - User creates NetworkPolicy → Kubernetes API stores it
   - **ovnkube-master** sees new NetworkPolicy
   - Translates policy rules into **ACLs** (Access Control Lists) in NB DB
   - Attaches ACLs to relevant logical switches/ports
   - **ovn-northd** sees ACLs in NB DB
   - Generates logical flows in SB DB that implement allow/deny logic
   - **ovn-controller** on each node sees new logical flows
   - Translates to OVS flows with drop/allow actions
   - Result: Traffic is blocked/allowed according to policy at OVS layer

6. **"Chassis" in OVN:**
   - A **chassis** is an OVN term for a **physical or virtual host** running OVN.
   - In OpenShift, each node (control plane and worker) is a chassis.
   - Each chassis has a unique ID and is registered in the SB database.
   - Port bindings map logical ports to specific chassis.
   - Chassis information includes hostname, tunnel endpoint IP, and supported encapsulation types.

7. **Why two databases (NB and SB)?**
   - **Separation of concerns**: 
     - NB DB = "what" (intent, policy, desired state)
     - SB DB = "how" (implementation, physical bindings, flows)
   - **Scalability**: Different components can focus on different databases
   - **Security**: Management tools only need access to NB; nodes only need SB
   - **Abstraction**: Can change physical implementation without changing logical network
   - **Multi-tenancy**: Multiple logical networks can coexist on shared physical infrastructure
   - Similar to "desired state" vs "current state" in Kubernetes

8. **Pod mobility enabled by this architecture:**
   - **Logical network is stable**: Pod's logical switch port, IP, and identity remain constant in NB DB
   - **Physical binding is dynamic**: SB DB port_binding changes from chassis-A to chassis-B
   - **Process**:
     1. Pod deleted from node-1 → ovnkube-node unbinds port on chassis-1 → SB DB updated
     2. Pod created on node-2 → ovnkube-node binds same logical port to chassis-2 → SB DB updated
     3. ovn-controller on node-1 removes old flows
     4. ovn-controller on node-2 installs new flows
     5. Other nodes update tunnel destinations (flows now point to node-2 instead of node-1)
   - **Result**: Pod keeps same IP, same connectivity, seamless migration
   - Logical network abstraction makes physical movement transparent

---

## Today I Learned (TIL)

### Template

```
Date: _______________

# Day 45: OVN Architecture

## Key Concepts Mastered
- [ ] Understand OVN Northbound and Southbound databases
- [ ] Can navigate ovnkube-master and ovnkube-node pods
- [ ] Successfully queried NB and SB databases
- [ ] Correlated Kubernetes pod with OVN logical port
- [ ] Traced from K8s → NB DB → SB DB → OVS flows

## Important Commands Learned
1. ovn-nbctl show - ________________________________
2. ovn-sbctl show - ________________________________
3. ovn-nbctl find logical_switch_port - ________________________________

## Architecture Insights
The flow from creating a pod to actual networking:
1. ___________________________________________________________
2. ___________________________________________________________
3. ___________________________________________________________
4. ___________________________________________________________
5. ___________________________________________________________

## Real Pod Traced
Pod: _______________
Logical Port: _______________
Chassis: _______________
Tunnel Key: _______________
OVS Port: _______________

## Connection to Previous Days
- Day 43 (OVS bridges): ovnkube-node creates veth and adds to br-int
- Day 44 (OVS flows): ovn-controller generates the flows I examined
- This explains WHO creates WHAT I saw on Days 43-44!

## Questions/Confusions to Explore
1. _____________________________________________________________
2. _____________________________________________________________

## Tomorrow's Preview
Tomorrow I'll learn the 4 traffic flow patterns in detail and trace packets
through the complete path using everything learned this week!
```

---

## Commands Cheat Sheet

### OVN Pod Access

```bash
# === Find OVN Pods ===

# List all OVN pods
oc get pods -n openshift-ovn-kubernetes

# Get ovnkube-master pods
oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master

# Get ovnkube-node pods
oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-node

# Get specific pod name for scripting
MASTER_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o jsonpath='{.items[0].metadata.name}')
NODE_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-node -o jsonpath='{.items[0].metadata.name}')


# === Northbound Database Commands ===

# Show complete logical topology
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- ovn-nbctl show

# List logical switches
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- ovn-nbctl ls-list

# List ports on a logical switch
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- ovn-nbctl lsp-list <switch-name>

# List logical routers
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- ovn-nbctl lr-list

# List load balancers (Services)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- ovn-nbctl lb-list

# List ACLs on a switch (NetworkPolicies)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- ovn-nbctl acl-list <switch-name>

# Find logical switch port by criteria
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl find logical_switch_port addresses~"<ip-address>"

# Get full details of a logical switch port
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl list logical_switch_port <port-name>

# Get full details of a logical switch
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl list logical_switch <switch-name>

# Get load balancer details
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl list load_balancer


# === Southbound Database Commands ===

# Show complete physical topology
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- ovn-sbctl show

# List chassis (nodes)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- ovn-sbctl chassis-list

# List port bindings
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- ovn-sbctl list port_binding

# Find port binding by logical port
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- \
  ovn-sbctl find port_binding logical_port="<port-name>"

# List datapath bindings (logical switches to tunnel IDs)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- ovn-sbctl list datapath_binding

# Show logical flows (pre-OVS)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- ovn-sbctl lflow-list

# Show logical flows for specific datapath
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- \
  ovn-sbctl lflow-list <datapath-name>

# Get chassis details
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- \
  ovn-sbctl list chassis <chassis-name>


# === Useful Queries ===

# Find all pods on a specific node
NODE_NAME="worker-1"
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- \
  ovn-sbctl find port_binding chassis=$NODE_NAME

# Find OVN info for a pod IP
POD_IP="10.128.0.5"
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl find logical_switch_port | grep -A5 "$POD_IP"

# Get Service load balancer configuration
SERVICE_IP="172.30.0.10"
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl find load_balancer | grep -A10 "$SERVICE_IP"


# === Logs and Debugging ===

# View ovnkube-master logs
oc logs -n openshift-ovn-kubernetes $MASTER_POD -c ovnkube-master

# View ovn-northd logs
oc logs -n openshift-ovn-kubernetes $MASTER_POD -c ovn-northd

# View ovnkube-node logs
oc logs -n openshift-ovn-kubernetes $NODE_POD -c ovnkube-node

# View ovn-controller logs
oc logs -n openshift-ovn-kubernetes $NODE_POD -c ovn-controller

# Follow logs in real-time
oc logs -n openshift-ovn-kubernetes $MASTER_POD -c ovnkube-master -f
```

### Complete Pod Tracing Workflow

```bash
# Trace a pod through all layers

# 1. Kubernetes Layer
POD_NAME="nginx"
POD_NAMESPACE="default"
POD_IP=$(oc get pod -n $POD_NAMESPACE $POD_NAME -o jsonpath='{.status.podIP}')
POD_NODE=$(oc get pod -n $POD_NAMESPACE $POD_NAME -o jsonpath='{.spec.nodeName}')

# 2. OVN Northbound (Logical)
MASTER_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o jsonpath='{.items[0].metadata.name}')
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl find logical_switch_port | grep -A10 "$POD_IP"

# 3. OVN Southbound (Physical Mapping)
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c sbdb -- \
  ovn-sbctl find port_binding | grep -A10 "$POD_IP"

# 4. OVS Flows
oc debug node/$POD_NODE -- chroot /host ovs-ofctl dump-flows br-int | grep "$POD_IP"

# 5. Linux Interface
oc debug node/$POD_NODE -- chroot /host ip addr | grep -B2 "$POD_IP"
```

---

## What's Next

### Tomorrow: Day 46 - OVN Traffic Flows

You now understand the **architecture** (how OVN is structured). Tomorrow you'll learn the **traffic patterns** (how packets actually flow).

**Preview:**
- The 4 fundamental traffic patterns in OpenShift
- Pod-to-Pod on same node
- Pod-to-Pod across nodes (with tunneling)
- Pod-to-External (egress)
- External-to-Pod (ingress)
- Tracing each hop-by-hop using OVN and OVS tools

**Preparation:**
- Review the logical flows you saw in SB DB today
- Think about how a packet would traverse: veth → br-int → flows → tunnel → remote node
- This is where everything comes together!

### Week 7 Progress

- **Day 43**: OVS data plane structure ✓
- **Day 44**: OVS data plane logic (flows) ✓
- **Day 45**: OVN control plane architecture ✓
- **Day 46**: Complete traffic flow analysis (tomorrow)
- **Day 47-48**: Services built on this foundation
- **Day 49**: Real-world troubleshooting

You've climbed the ladder from low-level (OVS) to high-level (OVN). Tomorrow, you'll trace complete packet journeys using everything you've learned!

---

**Key Insight**: OVN is what makes OpenShift networking "just work." When you create a pod, you don't think about veth pairs, OVS bridges, flow rules, or tunnel IDs. OVN handles all of it automatically. But now you understand what's happening behind the scenes - and that knowledge is invaluable for troubleshooting!
