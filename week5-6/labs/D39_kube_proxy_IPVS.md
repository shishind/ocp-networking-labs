# Day 39: kube-proxy IPVS Mode - Better Load Balancing

## Learning Objectives
By the end of this lab, you will:
- Understand the difference between iptables and IPVS modes in kube-proxy
- Check which mode your cluster is using
- View IPVS load balancing rules
- Understand when to use IPVS vs iptables
- Explore IPVS load balancing algorithms

## Plain English Explanation

**Remember kube-proxy from Day 31?**

kube-proxy is responsible for implementing Services. It watches Services and Endpoints, then programs network rules to make ClusterIPs work.

**Two Modes**:

1. **iptables mode** (default in most clusters)
   - Uses iptables rules for load balancing
   - We explored this in Day 31
   
2. **IPVS mode** (IP Virtual Server)
   - Uses IPVS (a Linux kernel feature) for load balancing
   - More efficient, more features

**Why IPVS Exists**

**The iptables problem**: As you add more Services and pods, iptables rules grow linearly:
- 100 Services with 10 pods each = thousands of iptables rules
- Every packet must traverse these rules sequentially
- Adding/removing rules is slow (entire chain must be replaced)

**IPVS advantages**:
- **Faster lookups**: Uses hash tables instead of sequential rule traversal
- **Better load balancing algorithms**: Round-robin, least-connection, weighted, etc.
- **Better scalability**: 10,000 Services? No problem.
- **Lower CPU usage**: Less processing per packet

**How IPVS Works**:

Instead of iptables DNAT chains, IPVS creates "virtual servers":

```
iptables mode:
ClusterIP:Port → iptables chain → DNAT to pod IP

IPVS mode:
ClusterIP:Port → IPVS virtual server → Load balance to real servers (pod IPs)
```

**Still uses some iptables**: IPVS mode still uses iptables for:
- Packet filtering (NodePort opening, masquerading)
- Traffic that doesn't match IPVS rules

**In OpenShift**: OpenShift 4.x supports both modes. IPVS is recommended for large clusters (hundreds of Services).

## Hands-On Lab

### Exercise 1: Check Current kube-proxy Mode

**Goal**: Determine if your cluster uses iptables or IPVS.

```bash
# Get kube-proxy config
kubectl get configmap -n kube-system kube-proxy -o yaml | grep mode

# Output (iptables mode):
# mode: ""  (empty = iptables is default)
# OR
# mode: "iptables"

# Output (IPVS mode):
# mode: "ipvs"

# Alternative: Check kube-proxy logs
KUBE_PROXY_POD=$(kubectl get pod -n kube-system -l k8s-app=kube-proxy -o jsonpath='{.items[0].metadata.name}')

kubectl logs -n kube-system $KUBE_PROXY_POD | head -20

# Look for lines like:
# "Using iptables Proxier"
# OR
# "Using ipvs Proxier"
```

**If you're in iptables mode**, we'll switch to IPVS in the next exercise.

### Exercise 2: Switch kube-proxy to IPVS Mode

**Goal**: Reconfigure kube-proxy to use IPVS.

**Check if IPVS modules are loaded on nodes**:
```bash
# Access a node
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
docker exec -it $NODE_NAME bash
```

**Inside the node**:
```bash
# Check if IPVS modules are loaded
lsmod | grep ip_vs

# If empty, load them
modprobe ip_vs
modprobe ip_vs_rr   # Round-robin
modprobe ip_vs_wrr  # Weighted round-robin
modprobe ip_vs_sh   # Source hash

# Verify
lsmod | grep ip_vs

# Exit the node
exit
```

**Now configure kube-proxy to use IPVS**:
```bash
# Edit the kube-proxy ConfigMap
kubectl edit configmap -n kube-system kube-proxy

# Find the "mode" field in the config data and change it:
# mode: "ipvs"

# Also add IPVS settings (if not present):
# ipvs:
#   scheduler: "rr"  # Round-robin

# Save and exit (:wq in vim)

# Delete kube-proxy pods to restart with new config
kubectl delete pods -n kube-system -l k8s-app=kube-proxy

# Wait for new pods to start
kubectl wait --for=condition=Ready pod -n kube-system -l k8s-app=kube-proxy --timeout=60s

# Verify they're using IPVS now
KUBE_PROXY_POD=$(kubectl get pod -n kube-system -l k8s-app=kube-proxy -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n kube-system $KUBE_PROXY_POD | grep -i ipvs

# Should see: "Using ipvs Proxier"
```

### Exercise 3: View IPVS Rules

**Goal**: See IPVS virtual servers and real servers.

First, install ipvsadm (IPVS admin tool):

```bash
# Access a node
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
docker exec -it $NODE_NAME bash
```

**Inside the node**:
```bash
# Install ipvsadm
apt-get update && apt-get install -y ipvsadm

# List all IPVS virtual servers
ipvsadm -ln

# Example output:
# IP Virtual Server version 1.2.1 (size=4096)
# Prot LocalAddress:Port Scheduler Flags
#   -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
# TCP  10.96.0.1:443 rr
#   -> 172.18.0.2:6443              Masq    1      0          0
# TCP  10.96.0.10:53 rr
#   -> 10.244.1.2:53                Masq    1      0          0
#   -> 10.244.2.3:53                Masq    1      0          0
# TCP  10.96.45.123:80 rr
#   -> 10.244.1.5:8080              Masq    1      0          0
#   -> 10.244.1.6:8080              Masq    1      0          0
#   -> 10.244.2.4:8080              Masq    1      0          0
```

**Decode the output**:
- `TCP 10.96.0.1:443`: Virtual server (Service ClusterIP:Port)
- `rr`: Scheduler (round-robin)
- `-> 172.18.0.2:6443`: Real server (backend pod IP:Port)
- `Masq`: SNAT (masquerade) mode
- `Weight`: Load balancing weight (higher = more traffic)
- `ActiveConn`: Current active connections
- `InActConn`: Inactive connections

### Exercise 4: Test IPVS Load Balancing

**Goal**: Verify IPVS distributes traffic evenly.

**Still inside the node**, keep a terminal watching IPVS stats:
```bash
# Watch IPVS stats in real-time
watch -n 1 'ipvsadm -ln --stats'

# This shows connection counts updating
```

**In another terminal, generate traffic**:
```bash
# Create a test service if you don't have one
kubectl create deployment web --image=nginx --replicas=3
kubectl expose deployment web --port=80 --name=web-service

# Create a client pod
kubectl run client --image=nicolaka/netshoot --command -- sleep 3600

# Generate requests
for i in $(seq 1 30); do
    kubectl exec client -- curl -s http://web-service >/dev/null
    echo "Request $i sent"
    sleep 0.5
done
```

**Back in the node terminal**, you'll see the connection counts increase on the real servers (pod IPs). With round-robin, they should increase roughly evenly.

**Stop the watch** (Ctrl+C) and continue.

### Exercise 5: Explore IPVS Scheduling Algorithms

**Goal**: Try different load balancing algorithms.

IPVS supports multiple schedulers:
- `rr`: Round-robin (default)
- `lc`: Least connection (send to server with fewest active connections)
- `wrr`: Weighted round-robin
- `sh`: Source hash (same client IP always goes to same server)

**Change the scheduler**:
```bash
# Exit the node first
exit

# Edit kube-proxy config
kubectl edit configmap -n kube-system kube-proxy

# Change the scheduler:
# ipvs:
#   scheduler: "lc"  # Least connection

# Save and restart kube-proxy
kubectl delete pods -n kube-system -l k8s-app=kube-proxy
kubectl wait --for=condition=Ready pod -n kube-system -l k8s-app=kube-proxy --timeout=60s
```

**Verify the change**:
```bash
# Access the node again
docker exec -it $NODE_NAME bash

# Check IPVS rules
ipvsadm -ln | head -20

# The "Scheduler" column should now show "lc" instead of "rr"
```

**Test least-connection**:

With least-connection, if one server is slow (has many active connections), new connections go to others.

```bash
# Simulate a slow backend pod
# (In a real scenario, one pod might be overloaded)

# From another terminal, make a long-running request
kubectl exec client -- curl -s --max-time 30 http://web-service &

# Immediately make more requests
for i in $(seq 1 10); do
    kubectl exec client -- curl -s http://web-service >/dev/null
done

# IPVS should route new requests to pods with fewer active connections
```

**Inside the node**, check active connections:
```bash
ipvsadm -ln --stats

# The pod handling the long request should have a higher ActiveConn count
```

### Exercise 6: Compare IPVS vs iptables Performance

**Goal**: Understand when IPVS matters.

**Create many Services** (to simulate a large cluster):
```bash
# Exit the node
exit

# Create 50 Services with 3 pods each
for i in $(seq 1 50); do
    kubectl create deployment test-$i --image=hashicorp/http-echo --replicas=3 -- -text="Service $i"
    kubectl expose deployment test-$i --port=5678 --name=service-$i
done

# This creates 50 Services * 3 pods = 150 endpoints
```

**IPVS mode** (current):
```bash
# Access the node
docker exec -it $NODE_NAME bash

# Count IPVS rules
ipvsadm -ln | grep "TCP\|UDP" | wc -l

# Should show ~50+ (one per Service)

# Check performance (this is instant)
time ipvsadm -ln >/dev/null

# Output: real 0m0.002s
```

**Compare with iptables**:
```bash
# Count iptables rules
iptables-save | grep KUBE-SVC | wc -l

# Much fewer now (IPVS mode doesn't use many iptables rules for Services)

# In iptables mode, you'd have hundreds or thousands of rules
```

**The difference**:
- **IPVS**: Scales to thousands of Services with minimal performance impact
- **iptables**: Every additional Service adds rules; lookup time increases linearly

**Clean up**:
```bash
# Exit the node
exit

# Delete test services
for i in $(seq 1 50); do
    kubectl delete deployment test-$i
    kubectl delete service service-$i
done
```

## Self-Check Questions

### Question 1
What are the main advantages of IPVS mode over iptables mode?

**Answer**:
1. **Better scalability**: Hash table lookups vs sequential rule traversal
2. **More load balancing algorithms**: Round-robin, least-connection, source hash, etc.
3. **Lower latency**: Faster packet processing, especially with many Services
4. **Lower CPU usage**: Less overhead per packet

### Question 2
Does switching to IPVS mode mean you don't use iptables at all?

**Answer**: No. IPVS mode still uses iptables for:
- Packet filtering (NodePort, masquerading)
- Traffic that doesn't match IPVS rules
- Some edge cases

IPVS handles the Service load balancing, but iptables is still involved in the data path.

### Question 3
When should you use IPVS mode instead of iptables mode?

**Answer**: Use IPVS when:
- You have hundreds or thousands of Services
- You need advanced load balancing (least-connection, weighted, etc.)
- You want better performance/lower CPU usage

Stick with iptables if:
- Your cluster is small (< 100 Services)
- You want the default, well-tested mode
- Your nodes don't support IPVS kernel modules

### Question 4
You see connection counts in `ipvsadm -ln --stats` but they're all zero. Why?

**Answer**: Two possibilities:
1. **No traffic**: No clients are actually using the Service right now
2. **Short-lived connections**: HTTP requests complete quickly; by the time you check, connections are closed (they move to InActConn)

Active connections are only shown while they're in progress. For HTTP, that's milliseconds.

### Question 5
What does the "Masq" in IPVS output mean?

**Answer**: "Masq" stands for masquerade (SNAT - Source NAT). It means when traffic is forwarded to the real server (pod), the source IP is changed to the node's IP. This ensures the response comes back through the same node, where IPVS can reverse the NAT.

## Today I Learned (TIL)

Fill this out at the end of the day:

```
Date: _______________

Key Concepts:
- IPVS stands for: _______________
- kube-proxy mode in my cluster: _______________
- IPVS scheduler I used: _______________
- IPVS advantages over iptables: _______________

Commands I used:
_______________________________________________

IPVS virtual servers I saw: _______________

Biggest "aha" moment:
_______________________________________________
_______________________________________________

Something I'm still confused about:
_______________________________________________
_______________________________________________

How this applies to production:
_______________________________________________
_______________________________________________
```

## Commands Cheat Sheet

```bash
# Check kube-proxy mode
kubectl get configmap -n kube-system kube-proxy -o yaml | grep mode
kubectl logs -n kube-system <kube-proxy-pod> | grep -i "proxier\|mode"

# Switch to IPVS mode
kubectl edit configmap -n kube-system kube-proxy
# Set: mode: "ipvs"
kubectl delete pods -n kube-system -l k8s-app=kube-proxy

# Inside node - IPVS modules
lsmod | grep ip_vs
modprobe ip_vs
modprobe ip_vs_rr

# Inside node - View IPVS rules
ipvsadm -ln                    # List virtual servers
ipvsadm -ln --stats            # Show connection stats
ipvsadm -ln --rate             # Show packet/byte rates
watch -n 1 'ipvsadm -ln'       # Watch in real-time

# Inside node - Install ipvsadm
apt-get update && apt-get install -y ipvsadm  # Debian/Ubuntu
yum install -y ipvsadm                        # RHEL/CentOS

# IPVS schedulers
# rr  - Round-robin
# lc  - Least connection
# wrr - Weighted round-robin
# sh  - Source hash

# iptables (for comparison)
iptables-save | grep KUBE-SVC
iptables-save | wc -l
```

## What's Next

Tomorrow (Day 40), you'll tackle a **full Service troubleshooting scenario**. You'll use everything you've learned:
- Check Endpoints
- Describe Services
- Test with exec and curl
- Check NetworkPolicies
- Use IPVS/iptables debugging

This is your chance to combine all your skills into a real-world debugging workflow!

**Preparation**: Review your notes from this week. Tomorrow's scenario will test your understanding of Services, Endpoints, DNS, and NetworkPolicies.

---

**Pro Tip**: In production clusters with 500+ Services, IPVS mode can reduce kube-proxy CPU usage by 50% or more. Monitor `kubectl top pods -n kube-system -l k8s-app=kube-proxy` before and after switching modes to see the difference.
