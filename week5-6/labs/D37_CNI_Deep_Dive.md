# Day 37: CNI Deep Dive - What Happens When a Pod Starts

## Learning Objectives
By the end of this lab, you will:
- Understand the Container Network Interface (CNI) specification
- Trace what happens when a pod starts and gets an IP
- Examine veth (virtual ethernet) pairs and how they connect pods to nodes
- Inspect CNI plugin configuration
- Troubleshoot pod networking issues at the CNI level

## Plain English Explanation

**What Is CNI?**

CNI (Container Network Interface) is a **specification** that defines how container runtimes (like containerd, CRI-O) should set up networking for containers.

Think of it like a plug-and-play standard:
- Kubernetes says: "I need networking for this pod"
- The CNI plugin (Calico, Cilium, Flannel, etc.) says: "I know how to do that"
- They communicate using a standard format defined by the CNI spec

**The Pod Startup Network Flow**:

When you create a pod, here's what happens behind the scenes:

1. **API Server** receives your `kubectl create pod` command
2. **Scheduler** chooses which node should run the pod
3. **kubelet** on that node sees the new pod assignment
4. **Container Runtime** (containerd) creates the container
5. **kubelet** calls the **CNI plugin** with: "Give this container networking"
6. **CNI plugin** does the magic:
   - Allocates an IP address
   - Creates a **veth pair** (virtual ethernet cable)
   - Connects one end to the pod, one end to the node
   - Sets up routing rules
   - Returns the IP address to kubelet
7. **Pod** starts with networking ready

**What Is a veth Pair?**

Think of a veth pair as a virtual ethernet cable with two ends:
- One end goes **inside the pod's network namespace** (the pod sees it as `eth0`)
- Other end stays on the **node** (named like `veth12345678`)
- Packets sent to one end come out the other end

```
[Pod namespace]           [Node]
    eth0 ←────────────→ vethXXXXXXXX
  10.244.1.5            (bridge or routing)
```

**IP Address Allocation**:

The CNI plugin manages a pool of IP addresses:
- Calico: Uses IPAM (IP Address Management) from a cluster-wide pool
- Each node gets a subnet (e.g., node1: 10.244.1.0/24, node2: 10.244.2.0/24)
- Pods on node1 get IPs from 10.244.1.0/24

**In OpenShift**: The same CNI concepts apply. OpenShift SDN and OVN-Kubernetes are both CNI plugins that implement this spec.

## Hands-On Lab

### Exercise 1: Examine CNI Plugin Configuration

**Goal**: Find and read the CNI configuration on a node.

```bash
# CNI configs are stored on each node at /etc/cni/net.d/
# In kind, nodes are Docker containers

# Get a node name
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

# Access the node
docker exec -it $NODE_NAME bash
```

**Inside the node**:
```bash
# List CNI configuration files
ls -la /etc/cni/net.d/

# Output (with Calico):
# 10-calico.conflist
# calico-kubeconfig

# Read the Calico config
cat /etc/cni/net.d/10-calico.conflist

# You'll see JSON like:
# {
#   "name": "k8s-pod-network",
#   "cniVersion": "0.3.1",
#   "plugins": [
#     {
#       "type": "calico",
#       "ipam": {
#         "type": "calico-ipam"
#       },
#       ...
#     }
#   ]
# }
```

**Key fields**:
- `name`: Network name
- `type`: CNI plugin binary to execute (calico, bridge, etc.)
- `ipam.type`: IP Address Management plugin
- `plugins`: Chain of CNI plugins to run

**Exit the node**:
```bash
exit
```

### Exercise 2: Watch CNI in Action - Create a Pod and Trace Network Setup

**Goal**: Create a pod and observe the veth pair creation.

**Terminal 1 - Watch network interfaces on node**:
```bash
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

# Watch network interfaces (this will stream changes)
docker exec -it $NODE_NAME bash -c 'watch -n 1 ip link show | grep veth | wc -l'

# Note the count of veth interfaces
```

**Terminal 2 - Create a pod**:
```bash
kubectl run test-cni --image=nginx

# Wait for it to be running
kubectl wait --for=condition=Ready pod/test-cni --timeout=60s
```

**Back to Terminal 1**:
You should see the veth count increase by 1!

**Stop the watch** (Ctrl+C) and investigate:

```bash
# Get the pod's IP
POD_IP=$(kubectl get pod test-cni -o jsonpath='{.status.podIP}')
echo "Pod IP: $POD_IP"

# Inside the node, find which veth corresponds to this pod
docker exec -it $NODE_NAME bash
```

**Inside the node**:
```bash
# List all veth interfaces
ip link show type veth

# Output shows pairs like:
# 12: veth12345678@if11: <BROADCAST,MULTICAST,UP,LOWER_UP>
# 14: veth87654321@if13: <BROADCAST,MULTICAST,UP,LOWER_UP>

# To find which veth belongs to our pod, we need to enter the pod's network namespace
# First, find the pod's container ID
CONTAINER_ID=$(crictl ps --name nginx -o json | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

echo "Container ID: $CONTAINER_ID"

# Get the container's PID
PID=$(crictl inspect $CONTAINER_ID | grep -m 1 '"pid"' | grep -o '[0-9]*')

echo "Container PID: $PID"

# Enter the pod's network namespace and check its eth0
nsenter -t $PID -n ip link show eth0

# Output:
# 11: eth0@if12: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1480
#           ^^^^^ this is the pair index

# The "if12" means "interface 12 on the other side"
# So eth0 (interface 11) is paired with veth (interface 12)

# Check interface 12 on the node
ip link show | grep -A 1 "^12:"

# Output:
# 12: veth12345678@if11: <BROADCAST,MULTICAST,UP,LOWER_UP>
```

**Perfect match!** The pod's eth0 (interface 11) is connected to the node's veth12345678 (interface 12).

### Exercise 3: Trace Packet Flow from Pod to Node

**Goal**: See how packets travel through the veth pair.

**Still inside the node**:
```bash
# Install tcpdump if not present
apt-get update && apt-get install -y tcpdump

# Capture traffic on the veth interface
# Replace vethXXXXXXXX with your actual veth name from Exercise 2
VETH_NAME=veth12345678  # Use your actual veth name

tcpdump -i $VETH_NAME -n icmp &
TCPDUMP_PID=$!

# Give it a moment to start
sleep 2
```

**In another terminal, ping from the pod**:
```bash
kubectl exec test-cni -- ping -c 3 8.8.8.8
```

**Back in the node terminal**:
```bash
# You'll see the ICMP packets on the veth interface!
# Output:
# 12:00:00.123456 IP 10.244.1.5 > 8.8.8.8: ICMP echo request
# 12:00:00.124567 IP 8.8.8.8 > 10.244.1.5: ICMP echo reply

# Stop tcpdump
kill $TCPDUMP_PID

# Exit the node
exit
```

**What you observed**: Packets leaving the pod's eth0 immediately appear on the node's veth interface. They're literally two ends of the same virtual cable!

### Exercise 4: Examine IP Address Allocation

**Goal**: Understand how the CNI plugin allocates IP addresses.

```bash
# Get all pod IPs and their nodes
kubectl get pods -A -o wide | grep -E "NAME|test-cni"

# Create a few more pods
kubectl run test-cni-2 --image=nginx
kubectl run test-cni-3 --image=nginx
kubectl run test-cni-4 --image=nginx

# Wait for them
kubectl wait --for=condition=Ready pod -l run --timeout=60s

# Check their IPs
kubectl get pods -o wide | grep test-cni

# Example output:
# test-cni     10.244.1.5    node1
# test-cni-2   10.244.2.3    node2
# test-cni-3   10.244.1.6    node1
# test-cni-4   10.244.2.4    node2
```

**Notice**: 
- Pods on node1 get IPs from 10.244.1.x
- Pods on node2 get IPs from 10.244.2.x
- Each node has its own subnet

**Check Calico's IPAM**:
```bash
# View Calico IP pool configuration
kubectl get ippools -o yaml

# If kubectl doesn't recognize 'ippools', install calicoctl:
# (This is Calico's CLI tool)

# For now, we can infer from pod IPs that each node has a /24 subnet
```

### Exercise 5: Simulate CNI Plugin Failure

**Goal**: See what happens when CNI can't set up networking.

```bash
# We'll create a pod on a node but "break" the CNI temporarily
# This is educational - don't do this in production!

# Access a node
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
docker exec -it $NODE_NAME bash
```

**Inside the node**:
```bash
# Backup the CNI config
cp /etc/cni/net.d/10-calico.conflist /tmp/10-calico.conflist.backup

# Break the CNI config (remove it)
mv /etc/cni/net.d/10-calico.conflist /tmp/

# Check - CNI config should be gone
ls /etc/cni/net.d/

# Exit the node
exit
```

**Now try to create a pod on this specific node**:
```bash
# We can't force a pod to a specific node easily without taints/tolerations
# So let's just create a pod and see what happens

kubectl run broken-cni --image=nginx

# Watch the pod
kubectl get pod broken-cni -w

# The pod will be stuck in ContainerCreating
# Press Ctrl+C after 30 seconds
```

**Check why it's stuck**:
```bash
kubectl describe pod broken-cni

# In the Events section:
# Failed to create pod sandbox: ... failed to find plugin "calico" in path [/opt/cni/bin]
# OR
# NetworkPlugin cni failed to set up pod network
```

**Fix it**:
```bash
# Restore the CNI config
docker exec -it $NODE_NAME bash -c 'mv /tmp/10-calico.conflist /etc/cni/net.d/'

# Wait a moment - kubelet will retry
sleep 10

# Check the pod again
kubectl get pod broken-cni

# Should be Running now!

# Clean up
kubectl delete pod broken-cni
```

### Exercise 6: Inspect CNI Plugin Logs

**Goal**: See CNI plugin activity in logs.

```bash
# Calico runs as a DaemonSet
kubectl get pods -n kube-system -l k8s-app=calico-node

# Get logs from one of the calico-node pods
CALICO_POD=$(kubectl get pod -n kube-system -l k8s-app=calico-node -o jsonpath='{.items[0].metadata.name}')

kubectl logs -n kube-system $CALICO_POD | tail -50

# Look for lines like:
# "Calico CNI executing"
# "Allocated IP address X.X.X.X"
# "Created veth pair"

# Create a new pod to generate fresh logs
kubectl run log-test --image=nginx &

# Tail the Calico logs in real-time
kubectl logs -n kube-system $CALICO_POD --follow

# You'll see CNI activity as the pod starts:
# "Assigning IP address 10.244.1.10"
# "Created veth pair"
# "Setting up routes"

# Press Ctrl+C to stop following

# Clean up
kubectl delete pod log-test
```

## Self-Check Questions

### Question 1
What's the difference between a CNI plugin and a CNI specification?

**Answer**: 
- **CNI specification**: A standard document that defines the API/contract between container runtimes and network plugins
- **CNI plugin**: An actual implementation (like Calico, Cilium, Flannel) that follows the spec

It's like the difference between USB specification (the standard) and a USB flash drive (the implementation).

### Question 2
A pod is stuck in ContainerCreating with "NetworkPlugin cni failed". What are the first three things you check?

**Answer**:
1. **CNI config exists**: Check `/etc/cni/net.d/` on the node
2. **CNI plugin pods running**: `kubectl get pods -n kube-system` (look for calico, cilium, etc.)
3. **CNI plugin logs**: `kubectl logs -n kube-system <cni-pod>` for errors

### Question 3
How can you tell which veth on the node corresponds to a specific pod?

**Answer**: 
1. Enter the pod's network namespace: `nsenter -t <pod-pid> -n ip link show`
2. Note the interface index on eth0 (e.g., `11: eth0@if12`)
3. The `@if12` means it's paired with interface 12 on the host
4. On the node: `ip link show | grep "^12:"` to find the veth name

### Question 4
What happens to the pod's IP address when the pod is deleted?

**Answer**: The IP is returned to the CNI plugin's IP pool and can be reused by another pod. IP addresses are ephemeral and tied to the pod's lifecycle. When the pod is deleted, the veth pair is destroyed and the IP is deallocated.

### Question 5
Can you have multiple CNI plugins in the same cluster?

**Answer**: Not really. Each node has one CNI plugin configured (though that plugin might be a "meta-plugin" that chains multiple plugins). However, you can use CNI chaining where one plugin calls another (e.g., Multus allows multiple networks per pod, but there's still one "primary" CNI).

## Today I Learned (TIL)

Fill this out at the end of the day:

```
Date: _______________

Key Concepts:
- CNI stands for: _______________
- veth pair connects: _______________
- CNI config location: _______________
- IP allocation is managed by: _______________

My pod today:
- Name: _______________
- IP: _______________
- veth on node: _______________

What I traced:
_______________________________________________

Biggest "aha" moment:
_______________________________________________
_______________________________________________

Something I'm still confused about:
_______________________________________________
_______________________________________________

How this applies to OpenShift:
_______________________________________________
_______________________________________________
```

## Commands Cheat Sheet

```bash
# Access kind node
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
docker exec -it $NODE_NAME bash

# Inside node - CNI config
ls /etc/cni/net.d/
cat /etc/cni/net.d/*.conflist

# Inside node - Network interfaces
ip link show
ip link show type veth
ip addr show

# Inside node - Find pod's veth pair
CONTAINER_ID=$(crictl ps --name <pod-name> -o json | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
PID=$(crictl inspect $CONTAINER_ID | grep -m 1 '"pid"' | grep -o '[0-9]*')
nsenter -t $PID -n ip link show

# CNI plugin logs
kubectl get pods -n kube-system -l k8s-app=calico-node
kubectl logs -n kube-system <calico-pod>

# IP address inspection
kubectl get pods -o wide
kubectl get ippools -o yaml  # Calico-specific

# Troubleshooting
kubectl describe pod <name>  # Check for CNI errors
kubectl get pods -n kube-system  # Check CNI plugin health
crictl ps  # Inside node - list containers
crictl inspect <container-id>  # Container details
```

## What's Next

Tomorrow (Day 38), you'll learn about **DNS Troubleshooting** in Kubernetes. You'll discover:
- Common DNS issues and how to fix them
- How to break DNS intentionally for testing
- Advanced CoreDNS debugging techniques
- How to test DNS resolution step-by-step

You've seen how pods get networking set up. Tomorrow you'll master DNS debugging!

**Preparation**: Keep your kind cluster running with the test pods for DNS exercises.

---

**Pro Tip**: When troubleshooting pod networking, always check the CNI plugin first. 90% of "pod can't get an IP" or "pod networking doesn't work" issues are because:
1. CNI plugin pods aren't running
2. CNI config is missing or malformed
3. IP pool is exhausted

Check `kubectl get pods -n kube-system` before diving deep!
