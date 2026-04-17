# Day 23: NMState — Declarative Node Network Config in OCP

**Date:** Tuesday, April 7, 2026  
**Phase:** 2 - Linux & Container Networking  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Explain what NMState is and why OpenShift uses it
- Write a NodeNetworkConfigurationPolicy (NNCP) to configure node networking
- Create a bonded interface using NMState YAML
- Verify the configuration using NodeNetworkState (NNS)
- Troubleshoot NMState configuration issues

---

## Plain English: What Is NMState?

Yesterday you manually configured a bond using `ip` commands.

But imagine you have 100 OpenShift nodes, and you need to configure bonding on all of them.

You could:
- SSH to each node and run commands (manual, error-prone)
- Write Ansible playbooks (better, but still requires running them)
- Use **NMState** (declare the desired config once, OpenShift applies it everywhere)

**NMState** is a Kubernetes-native way to manage node networking declaratively.

You write YAML that says "I want bond0 with eth0 and eth1 in active-backup mode."

OpenShift's NMState Operator:
- Reads your YAML
- Applies the configuration to all matching nodes
- Monitors and enforces the configuration
- Reports the actual state back to you

This is **GitOps for node networking** — you declare what you want, OpenShift makes it happen.

**Why does this matter for OCP?**

In OpenShift 4.x, you NEVER manually configure node networking by SSHing to nodes.

You use **NMState** to:
- Create bonds
- Configure VLANs
- Set static IPs
- Configure bridges

This is the production way to manage node networking.

---

## What Is NMState?

**NMState** is a library and Kubernetes operator that manages host networking in a declarative way.

**Key concepts:**

| Resource | Purpose |
|----------|---------|
| **NodeNetworkConfigurationPolicy (NNCP)** | The desired network configuration (what you want) |
| **NodeNetworkState (NNS)** | The actual network state on each node (what exists) |
| **NodeNetworkConfigurationEnactment (NNCE)** | The status of applying a policy to a specific node |

**Workflow:**

1. You create a **NodeNetworkConfigurationPolicy** (NNCP) with your desired config
2. NMState Operator reads the NNCP
3. Operator applies the config to all matching nodes
4. Operator creates a **NodeNetworkConfigurationEnactment** (NNCE) for each node showing success/failure
5. **NodeNetworkState** (NNS) resources show the current state of each node

---

## NMState YAML Structure

A typical NNCP looks like this:

```yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: bond0-policy
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
  desiredState:
    interfaces:
    - name: bond0
      type: bond
      state: up
      ipv4:
        enabled: true
        dhcp: true
      link-aggregation:
        mode: active-backup
        slaves:
        - eth0
        - eth1
```

**Field-by-field:**
- **nodeSelector:** Which nodes to apply this to
- **desiredState:** The network configuration you want
- **interfaces:** List of network interfaces to configure

---

## Hands-On Lab

**Note:** This lab requires an OpenShift cluster with the NMState Operator installed. If you do not have access to an OCP cluster, read through the lab conceptually and try it when you have cluster access.

### Part 1: Install the NMState Operator (10 minutes)

**Skip this if NMState is already installed.**

```bash
# Check if NMState is installed
oc get csv -n openshift-nmstate | grep nmstate

# If not installed, install it via OperatorHub
# (In the OpenShift web console: OperatorHub → search "nmstate" → Install)
# OR via CLI:
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-nmstate
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-nmstate
  namespace: openshift-nmstate
spec:
  targetNamespaces:
  - openshift-nmstate
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kubernetes-nmstate-operator
  namespace: openshift-nmstate
spec:
  channel: stable
  name: kubernetes-nmstate-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

Wait for the operator to be ready:

```bash
# Watch the operator pods
oc get pods -n openshift-nmstate -w
```

**Expected output:**

```
nmstate-operator-xxxxx   1/1   Running
nmstate-handler-xxxxx    1/1   Running (one per node)
nmstate-webhook-xxxxx    1/1   Running
```

---

### Part 2: View Current Node Network State (10 minutes)

```bash
# List all NodeNetworkState resources (one per node)
oc get nns

# View the network state of a specific node
oc get nns <node-name> -o yaml
```

**Expected output:**

You will see the current network configuration of each node in YAML format, including:
- Interfaces
- IP addresses
- Routes
- DNS

This is the **actual state** of the node's network.

---

### Part 3: Write a Simple NNCP to Configure a Bond (15 minutes)

Create a file called `bond-policy.yaml`:

```yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: bond0-policy
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
  desiredState:
    interfaces:
    - name: bond0
      type: bond
      state: up
      ipv4:
        enabled: true
        dhcp: true
      link-aggregation:
        mode: active-backup
        slaves:
        - ens4
        - ens5
```

**Important:** Replace `ens4` and `ens5` with the actual interface names on your worker nodes.

**What does this do?**

- Creates a bond interface called `bond0`
- Uses active-backup mode
- Adds `ens4` and `ens5` as slaves
- Uses DHCP for IPv4 addressing
- Applies to all worker nodes

---

### Part 4: Apply the NNCP (10 minutes)

```bash
# Apply the policy
oc apply -f bond-policy.yaml

# Verify it was created
oc get nncp
```

**Expected output:**

```
NAME            STATUS
bond0-policy    Pending
```

Wait a moment, then check again:

```bash
oc get nncp
```

**Expected output:**

```
NAME            STATUS
bond0-policy    Available
```

**Status meanings:**
- **Pending:** Being applied
- **Available:** Successfully applied
- **Degraded:** Failed on one or more nodes

---

### Part 5: Check NodeNetworkConfigurationEnactment (10 minutes)

```bash
# List enactments (shows status per node)
oc get nnce

# View details of a specific enactment
oc get nnce <node-name>.bond0-policy -o yaml
```

**Expected output:**

```yaml
status:
  conditions:
  - lastTransitionTime: "2026-04-07T10:00:00Z"
    message: Successfully applied
    reason: ConfigurationProgressed
    status: "True"
    type: Available
```

**What does this mean?**

The policy was successfully applied to this node.

If there was an error, you would see:

```yaml
status:
  conditions:
  - lastTransitionTime: "2026-04-07T10:00:00Z"
    message: "interface ens5 not found"
    reason: ConfigurationFailed
    status: "False"
    type: Available
```

---

### Part 6: Verify the Bond Was Created (15 minutes)

SSH to a worker node (or use `oc debug node`):

```bash
# Access a node shell
oc debug node/<node-name>

# Inside the debug pod:
chroot /host

# Check the bond
cat /proc/net/bonding/bond0

# Check IP address
ip addr show bond0

# Check slaves
ip link show | grep master
```

**Expected output:**

You should see bond0 with ens4 and ens5 as slaves.

---

### Part 7: Update the NNCP to Change Bonding Mode (15 minutes)

Let's change from active-backup to 802.3ad (LACP).

Edit `bond-policy.yaml`:

```yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: bond0-policy
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
  desiredState:
    interfaces:
    - name: bond0
      type: bond
      state: up
      ipv4:
        enabled: true
        dhcp: true
      link-aggregation:
        mode: 802.3ad   # Changed from active-backup
        slaves:
        - ens4
        - ens5
        options:
          miimon: "100"
```

Apply the update:

```bash
oc apply -f bond-policy.yaml
```

NMState will automatically update the bond on all nodes.

Check the status:

```bash
oc get nncp bond0-policy
oc get nnce
```

---

### Part 8: View NodeNetworkState After the Change (10 minutes)

```bash
# View updated state
oc get nns <node-name> -o yaml | grep -A 20 bond0
```

You should see the bond mode changed to 802.3ad.

---

### Part 9: Delete the NNCP (Cleanup) (5 minutes)

```bash
# Delete the policy
oc delete nncp bond0-policy
```

**What happens?**

NMState removes the bond from all nodes and restores the previous configuration.

Verify:

```bash
# Check enactments
oc get nnce

# SSH to a node and check
oc debug node/<node-name>
chroot /host
cat /proc/net/bonding/bond0   # Should not exist
```

---

### Part 10: Troubleshoot a Failed NNCP (10 minutes)

Let's intentionally create a broken NNCP to practice troubleshooting.

Create `broken-policy.yaml`:

```yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: broken-policy
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
  desiredState:
    interfaces:
    - name: bond0
      type: bond
      state: up
      link-aggregation:
        mode: active-backup
        slaves:
        - ens99   # This interface does not exist!
        - ens100
```

Apply it:

```bash
oc apply -f broken-policy.yaml
```

Check the status:

```bash
oc get nncp broken-policy
```

**Expected output:**

```
NAME            STATUS
broken-policy   Degraded
```

View the enactment to see the error:

```bash
oc get nnce -o yaml | grep -A 10 message
```

**Expected error:**

```
message: "Error applying configuration: interface ens99 not found"
```

**How to fix:**

1. Identify the problem (missing interface)
2. Edit the YAML to use correct interfaces
3. Reapply the NNCP

Delete the broken policy:

```bash
oc delete nncp broken-policy
```

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What is NMState?
2. What is the difference between NNCP, NNS, and NNCE?
3. How do you create a bond using NMState?
4. What happens when you delete a NNCP?
5. How do you troubleshoot a failed NNCP?

**Answers:**

1. A Kubernetes operator for declarative node network configuration
2. NNCP = desired config (policy), NNS = actual state (per node), NNCE = status of applying policy (per node)
3. Create a NodeNetworkConfigurationPolicy YAML with bond configuration and apply it
4. NMState removes the configuration from all nodes and restores previous state
5. Check `oc get nncp` for status, view NNCE resources for per-node errors

---

## Today I Learned (TIL) — Write This Down

In your notebook, write 5 bullet points:

- What did I learn today?
- What surprised me?
- What do I still not understand?

Example:

```
April 7, 2026 — Day 23: NMState

- NMState manages node networking declaratively in OpenShift
- NNCP defines the desired config, NNS shows actual state
- I can create bonds, VLANs, and bridges using YAML
- NMState automatically applies config to all matching nodes
- Never SSH to nodes to configure networking — use NMState instead
```

---

## Commands Cheat Sheet

**NMState CLI Commands:**

```bash
# List all policies
oc get nncp

# View a specific policy
oc get nncp <name> -o yaml

# List node network states
oc get nns

# View a node's network state
oc get nns <node-name> -o yaml

# List enactments (per-node status)
oc get nnce

# View a specific enactment
oc get nnce <node-name>.<policy-name> -o yaml

# Delete a policy
oc delete nncp <name>
```

**Example NNCP Templates:**

**Active-Backup Bond:**

```yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: bond-active-backup
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
  desiredState:
    interfaces:
    - name: bond0
      type: bond
      state: up
      ipv4:
        enabled: true
        dhcp: true
      link-aggregation:
        mode: active-backup
        slaves:
        - eth0
        - eth1
```

**LACP Bond:**

```yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: bond-lacp
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
  desiredState:
    interfaces:
    - name: bond0
      type: bond
      state: up
      ipv4:
        enabled: true
        address:
        - ip: 192.168.1.100
          prefix-length: 24
      link-aggregation:
        mode: 802.3ad
        slaves:
        - eth0
        - eth1
        options:
          miimon: "100"
```

---

## What's Next?

**Tomorrow (Day 24):** tcpdump Basics — capturing and filtering network traffic

**Why it matters:** You have been configuring networks. Now you will learn how to WATCH network traffic in real-time using tcpdump — the most important troubleshooting tool for network engineers.

---

**End of Day 23 Lab**

Excellent work. You now know how to manage node networking the OpenShift way. Tomorrow you start learning packet capture.
