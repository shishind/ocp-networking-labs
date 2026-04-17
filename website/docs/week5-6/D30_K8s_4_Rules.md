# Day 30: The 4 Rules of Kubernetes Networking

## Learning Objectives
By the end of this lab, you will:
- Understand the 4 fundamental rules that govern Kubernetes networking
- Deploy pods and verify pod-to-pod communication without NAT
- Observe how pods receive routable IP addresses
- Test cross-node pod communication
- Explain why these rules matter for OpenShift networking

## Plain English Explanation

**The 4 Sacred Rules of Kubernetes Networking**

Kubernetes networking might seem complex, but it's built on 4 simple rules. Every CNI (Container Network Interface) plugin must follow these rules, whether you're using Calico, Cilium, Flannel, or OpenShift SDN.

**Rule 1: All pods can communicate with all other pods without NAT**

Imagine every pod has a phone number (IP address). Any pod can call any other pod directly without going through a switchboard that changes the number. This is different from traditional Docker networking where containers hide behind NAT.

**Example**: Pod A (10.244.1.5) can ping Pod B (10.244.2.8) directly. Pod B sees the source IP as 10.244.1.5, not some translated address.

**Rule 2: All nodes can communicate with all pods without NAT**

The physical/virtual machines (nodes) running Kubernetes can talk directly to any pod. The node doesn't need to translate addresses - it just routes packets to the pod's real IP.

**Example**: If you SSH into a worker node and ping a pod at 10.244.2.8, it works directly.

**Rule 3: The IP a pod sees itself as is the same IP that other pods see it as**

When a pod checks its own IP address (like running `hostname -i`), that's the same IP address other pods use to reach it. There's no hidden translation.

**Example**: If Pod A runs `hostname -i` and gets 10.244.1.5, then Pod B reaches Pod A by connecting to 10.244.1.5. No surprises.

**Rule 4: Pods are ephemeral, their IPs change**

This isn't an official "rule" but a critical reality. Pods come and go. When a pod restarts, it gets a new IP address. This is why we need Services (which we'll learn about tomorrow).

**Why These Rules Matter**

These rules create a "flat network" where every pod is a first-class citizen with a routable IP. This makes debugging easier (no NAT to trace through), simplifies service discovery, and makes Kubernetes networking predictable.

**In OpenShift**: These same rules apply. OpenShift's SDN (Software Defined Network) or OVN-Kubernetes both implement these rules.

## Hands-On Lab

### Exercise 1: Deploy Two Pods and Observe Their IPs

**Goal**: Create pods and see that they get unique, routable IPs.

```bash
# Make sure your kind cluster is running
kubectl get nodes

# Create a simple pod
kubectl run pod-a --image=nicolaka/netshoot --command -- sleep 3600

# Create a second pod
kubectl run pod-b --image=nicolaka/netshoot --command -- sleep 3600

# Wait for both to be running
kubectl get pods --watch

# Press Ctrl+C once both show STATUS: Running
```

**Check their IP addresses**:
```bash
kubectl get pods -o wide

# Output shows:
# NAME    READY   STATUS    IP            NODE
# pod-a   1/1     Running   10.244.1.2    learning-worker
# pod-b   1/1     Running   10.244.0.5    learning-control-plane
```

**What to notice**:
- Each pod has a unique IP from the pod CIDR (10.244.0.0/16)
- Pods might be on different nodes
- The IPs are different from node IPs

### Exercise 2: Verify Rule 3 - Pod Sees Its Own Real IP

**Goal**: Confirm a pod sees itself with the same IP others see.

```bash
# Get pod-a's IP as Kubernetes sees it
POD_A_IP=$(kubectl get pod pod-a -o jsonpath='{.status.podIP}')
echo "Kubernetes says pod-a IP is: $POD_A_IP"

# Ask pod-a what IP it thinks it has
kubectl exec pod-a -- hostname -i

# Also check with ip addr
kubectl exec pod-a -- ip addr show eth0

# Look for the "inet" line - it should match $POD_A_IP
```

**Expected result**: All three methods show the same IP address. There's no NAT hiding the "real" IP.

### Exercise 3: Verify Rule 1 - Pod-to-Pod Communication Without NAT

**Goal**: Prove pods can talk directly to each other.

```bash
# Get pod-b's IP
POD_B_IP=$(kubectl get pod pod-b -o jsonpath='{.status.podIP}')

# From pod-a, ping pod-b using its pod IP
kubectl exec pod-a -- ping -c 3 $POD_B_IP

# Expected output:
# PING 10.244.0.5 (10.244.0.5) 56(84) bytes of data.
# 64 bytes from 10.244.0.5: icmp_seq=1 ttl=62 time=0.234 ms
# ...
# 3 packets transmitted, 3 received, 0% packet loss
```

**Now verify NO NAT occurred**:
```bash
# From pod-a, make an HTTP request to pod-b
# First, start a simple HTTP server in pod-b
kubectl exec pod-b -- sh -c 'echo "Hello from pod-b" > /tmp/index.html && cd /tmp && python3 -m http.server 8080 &'

# Give it a second to start
sleep 2

# From pod-a, fetch the page
kubectl exec pod-a -- curl -s http://$POD_B_IP:8080/index.html

# Output: Hello from pod-b
```

**Check what IP pod-b sees the request coming from**:
```bash
# The Python HTTP server logs show the source IP
kubectl exec pod-b -- sh -c 'sleep 1'  # Give logs time to buffer

# On pod-a, get its IP
POD_A_IP=$(kubectl get pod pod-a -o jsonpath='{.status.podIP}')
echo "pod-a IP is: $POD_A_IP"

# The logs in pod-b would show requests from $POD_A_IP (not a NATed address)
```

### Exercise 4: Verify Rule 2 - Node-to-Pod Communication

**Goal**: Show that nodes can reach pods directly.

```bash
# Get the node where pod-a is running
POD_A_NODE=$(kubectl get pod pod-a -o jsonpath='{.spec.nodeName}')
POD_A_IP=$(kubectl get pod pod-a -o jsonpath='{.status.podIP}')

echo "pod-a is on node: $POD_A_NODE"
echo "pod-a IP is: $POD_A_IP"

# Access that node (it's a Docker container in kind)
docker exec -it $POD_A_NODE bash

# From inside the node, ping the pod
ping -c 3 $POD_A_IP

# Also try from the OTHER node
POD_B_NODE=$(kubectl get pod pod-b -o jsonpath='{.spec.nodeName}')
docker exec -it $POD_B_NODE ping -c 3 $POD_A_IP

# Exit the node
exit
```

**Expected result**: Both pings succeed. Nodes have direct routing to pods, even pods on other nodes.

### Exercise 5: Trace a Packet Between Pods

**Goal**: See the network path a packet takes between pods.

```bash
# From pod-a, trace the route to pod-b
POD_B_IP=$(kubectl get pod pod-b -o jsonpath='{.status.podIP}')

kubectl exec pod-a -- traceroute -n $POD_B_IP

# Example output:
# traceroute to 10.244.0.5 (10.244.0.5), 30 hops max, 46 byte packets
#  1  10.244.1.1  0.123 ms  0.089 ms  0.067 ms    <- Gateway on pod-a's node
#  2  10.244.0.5  0.234 ms  0.198 ms  0.176 ms    <- pod-b directly
```

**What happened**:
1. Packet left pod-a through its virtual ethernet (veth) interface
2. Hit the node's bridge/gateway (10.244.1.1)
3. Node routed it to pod-b's node
4. Arrived at pod-b

**No NAT involved!** The source IP stayed as pod-a's IP the entire time.

### Exercise 6: Demonstrate Pod Ephemerality (Rule 4)

**Goal**: Show that pod IPs change when pods restart.

```bash
# Record pod-a's current IP
POD_A_IP_BEFORE=$(kubectl get pod pod-a -o jsonpath='{.status.podIP}')
echo "Before deletion: $POD_A_IP_BEFORE"

# Delete pod-a
kubectl delete pod pod-a

# Recreate it
kubectl run pod-a --image=nicolaka/netshoot --command -- sleep 3600

# Wait for it to be running
kubectl wait --for=condition=Ready pod/pod-a --timeout=60s

# Check the new IP
POD_A_IP_AFTER=$(kubectl get pod pod-a -o jsonpath='{.status.podIP}')
echo "After recreation: $POD_A_IP_AFTER"

# Compare
if [ "$POD_A_IP_BEFORE" != "$POD_A_IP_AFTER" ]; then
    echo "IP CHANGED! This is why we need Services."
else
    echo "By chance, it got the same IP, but this is NOT guaranteed."
fi
```

**The lesson**: Never hardcode pod IPs. Always use Services (Day 31) or DNS (Day 32).

## Self-Check Questions

### Question 1
You have Pod A (IP: 10.244.1.5) on node1 and Pod B (IP: 10.244.2.8) on node2. Pod A pings Pod B. What source IP does Pod B see in the ICMP packet?

**Answer**: Pod B sees 10.244.1.5 (Pod A's real IP). Kubernetes networking uses no NAT between pods, so the source IP is preserved. This is Rule 1 in action.

### Question 2
Why is the "no NAT" rule important for debugging?

**Answer**: Without NAT, logs and packet captures show the real source of traffic. If Pod A calls Pod B and causes an error, Pod B's logs will show the request came from Pod A's actual IP. With NAT, you'd see a translated address and have to work backwards to find the real source.

### Question 3
Your application in Pod A crashes when it starts. You check the logs and see it tried to bind to IP address 192.168.1.5, but the pod's IP is 10.244.1.8. What's wrong?

**Answer**: The application is misconfigured. It's trying to bind to a hardcoded IP instead of binding to 0.0.0.0 (all interfaces) or its actual pod IP. Applications in Kubernetes should bind to 0.0.0.0 to accept traffic on whatever IP the pod receives.

### Question 4
Can you rely on a pod's IP address staying the same across a restart?

**Answer**: No. Pod IPs are ephemeral. When a pod restarts (due to a crash, update, or reschedule), it will almost certainly get a new IP address. This is why Kubernetes has Services - to provide stable endpoints that don't change even when pods come and go.

### Question 5
In OpenShift, do these 4 rules still apply?

**Answer**: Yes, absolutely. OpenShift's networking (whether using OpenShift SDN or OVN-Kubernetes) must comply with these same rules. The CNI plugin might be different, but the fundamental networking model is identical to upstream Kubernetes.

## Today I Learned (TIL)

Fill this out at the end of the day:

```
Date: _______________

The 4 Rules of Kubernetes Networking:
1. _____________________________________________
2. _____________________________________________
3. _____________________________________________
4. _____________________________________________

Pod IPs in my cluster today came from this range: _______________

When I pinged from pod-a to pod-b:
- pod-a IP: _______________
- pod-b IP: _______________
- Result: _______________

Biggest "aha" moment:
_______________________________________________
_______________________________________________

Something I'm still confused about:
_______________________________________________
_______________________________________________

How this applies to my work:
_______________________________________________
_______________________________________________
```

## Commands Cheat Sheet

```bash
# Create test pods
kubectl run <pod-name> --image=nicolaka/netshoot --command -- sleep 3600

# Get pod IPs
kubectl get pods -o wide
kubectl get pod <pod-name> -o jsonpath='{.status.podIP}'

# Test connectivity
kubectl exec <pod-a> -- ping -c 3 <pod-b-ip>
kubectl exec <pod-a> -- curl http://<pod-b-ip>:8080

# Check pod's view of its own IP
kubectl exec <pod-name> -- hostname -i
kubectl exec <pod-name> -- ip addr show eth0

# Trace route between pods
kubectl exec <pod-a> -- traceroute -n <pod-b-ip>

# Access node (in kind)
docker exec -it <node-name> bash

# From inside node, ping pod
ping -c 3 <pod-ip>

# Watch pods
kubectl get pods --watch
kubectl get pods -o wide --watch

# Pod troubleshooting
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

## What's Next

Tomorrow (Day 31), you'll learn about **ClusterIP Services**. You'll discover:
- How Services provide stable IPs for groups of pods
- What happens at the iptables level when you create a Service
- How kube-proxy programs NAT rules to distribute traffic
- Why Services are the solution to ephemeral pod IPs

Today you learned that pods can talk to each other directly. Tomorrow you'll learn how to give those pods a stable name and IP that survives pod restarts.

**Preparation**: Keep your kind cluster and the two test pods (pod-a and pod-b) running for tomorrow's exercises.

---

**Pro Tip**: The netshoot image we've been using contains dozens of networking tools (ping, curl, dig, traceroute, tcpdump, etc.). It's perfect for debugging Kubernetes networking. In production, you'd use similar troubleshooting containers when your app containers have minimal tooling.
