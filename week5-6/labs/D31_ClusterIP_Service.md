# Day 31: ClusterIP Services - The iptables Deep Dive

## Learning Objectives
By the end of this lab, you will:
- Understand what a Kubernetes Service is and why it exists
- Create a ClusterIP Service and observe its virtual IP
- Trace the iptables rules that make Services work
- Explain the role of kube-proxy in Service implementation
- Debug Service connectivity issues using iptables

## Plain English Explanation

**The Problem Services Solve**

Yesterday you learned that pod IPs are ephemeral - they change every time a pod restarts. Imagine you have:
- 3 frontend pods that need to talk to backend pods
- Backend pods restart frequently (updates, crashes, scaling)
- Frontend pods would need to constantly update the backend IPs they connect to

This is unsustainable. You need a **stable endpoint** that doesn't change even when pods come and go.

**Enter: The Service**

A Kubernetes Service is like a load balancer that sits in front of a group of pods. It has:
- A **stable IP address** (ClusterIP) that never changes
- A **stable DNS name** (like `backend.default.svc.cluster.local`)
- A **label selector** that identifies which pods to route traffic to

**How ClusterIP Works Under the Hood**

Here's the magic: The ClusterIP doesn't actually exist on any network interface. It's a **virtual IP** (VIP) that only exists in iptables rules.

**The Flow**:
1. Your pod sends a packet to the Service IP (e.g., 10.96.0.10:80)
2. Before the packet leaves the pod, iptables intercepts it
3. iptables performs DNAT (Destination NAT) to change the destination from 10.96.0.10:80 to a real pod IP like 10.244.1.5:8080
4. The packet gets routed to the pod
5. The response comes back and iptables does reverse NAT

**Who Creates These iptables Rules?**

The `kube-proxy` component runs on every node. It watches the API server for Service and Endpoint changes and programs iptables rules accordingly.

**In OpenShift**: The exact same mechanism applies. OpenShift uses kube-proxy (or sometimes IPVS mode) to implement Services.

## Hands-On Lab

### Exercise 1: Deploy an Application and Expose It

**Goal**: Create a deployment and a Service, then observe the ClusterIP.

```bash
# Create a deployment with 3 nginx pods
kubectl create deployment web --image=nginx --replicas=3

# Wait for pods to be ready
kubectl wait --for=condition=Ready pod -l app=web --timeout=60s

# Check the pods and their IPs
kubectl get pods -l app=web -o wide

# Example output:
# NAME                   READY   STATUS    IP            NODE
# web-7d8f8c9d8f-abc12   1/1     Running   10.244.1.2    learning-worker
# web-7d8f8c9d8f-def34   1/1     Running   10.244.0.5    learning-control-plane
# web-7d8f8c9d8f-ghi56   1/1     Running   10.244.1.3    learning-worker
```

**Note these pod IPs - they're ephemeral and will change on restart.**

Now create a Service:
```bash
# Expose the deployment as a ClusterIP Service
kubectl expose deployment web --port=80 --target-port=80 --name=web-service

# Check the Service
kubectl get service web-service

# Example output:
# NAME          TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
# web-service   ClusterIP   10.96.45.123   <none>        80/TCP    5s
```

**What to notice**:
- `CLUSTER-IP`: This is the stable virtual IP
- `TYPE: ClusterIP`: Only accessible from within the cluster
- `PORT(S): 80/TCP`: The Service listens on port 80

### Exercise 2: Test the Service from a Pod

**Goal**: Verify the Service IP works and routes to backend pods.

```bash
# Create a test pod if you don't have one
kubectl run test-pod --image=nicolaka/netshoot --command -- sleep 3600

# Get the Service IP
SVC_IP=$(kubectl get service web-service -o jsonpath='{.spec.clusterIP}')
echo "Service IP: $SVC_IP"

# Test connectivity from the test pod
kubectl exec test-pod -- curl -s http://$SVC_IP

# You should see the nginx welcome page HTML
```

**Test multiple times to see load balancing**:
```bash
# The Service distributes traffic across all backend pods
for i in {1..6}; do
    echo "Request $i:"
    kubectl exec test-pod -- curl -s http://$SVC_IP | grep -i "welcome"
done
```

Each request might hit a different backend pod (though you can't easily tell with default nginx).

### Exercise 3: Find the iptables DNAT Rules

**Goal**: Discover the iptables magic that makes Services work.

This is where it gets interesting. Let's look inside a node.

```bash
# Pick a node (in kind, these are containers)
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Examining node: $NODE_NAME"

# Access the node
docker exec -it $NODE_NAME bash
```

**Inside the node**, run these commands:

```bash
# Get the Service IP (you noted it earlier, or run this)
# For this example, let's say it's 10.96.45.123

# Search for iptables rules mentioning this IP
iptables-save | grep 10.96.45.123

# You'll see output like:
# -A KUBE-SERVICES -d 10.96.45.123/32 -p tcp -m tcp --dport 80 -j KUBE-SVC-XXXXX
```

**Decode this rule**:
- `-A KUBE-SERVICES`: Append to the KUBE-SERVICES chain
- `-d 10.96.45.123/32`: Destination is the Service IP
- `-p tcp -m tcp --dport 80`: Protocol TCP, destination port 80
- `-j KUBE-SVC-XXXXX`: Jump to another chain (specific to this Service)

**Now look at that Service-specific chain**:
```bash
# Replace XXXXX with the actual chain name from above
iptables-save | grep KUBE-SVC-XXXXX

# You'll see rules like:
# -A KUBE-SVC-XXXXX -m statistic --mode random --probability 0.33 -j KUBE-SEP-AAAA
# -A KUBE-SVC-XXXXX -m statistic --mode random --probability 0.50 -j KUBE-SEP-BBBB
# -A KUBE-SVC-XXXXX -j KUBE-SEP-CCCC
```

**What this means**:
- 33% chance: Jump to KUBE-SEP-AAAA
- 50% of remaining (33%): Jump to KUBE-SEP-BBBB  
- Remaining (33%): Jump to KUBE-SEP-CCCC

This is **probabilistic load balancing**!

**Now look at the endpoint chains** (SEP = Service Endpoint):
```bash
iptables-save | grep KUBE-SEP-AAAA

# You'll see:
# -A KUBE-SEP-AAAA -p tcp -m tcp -j DNAT --to-destination 10.244.1.2:80
```

**This is the DNAT rule!** It changes the destination from the Service IP to a real pod IP.

Exit the node:
```bash
exit
```

### Exercise 4: Visualize the Complete Chain

**Goal**: Understand the full iptables traversal for a Service request.

Let's trace what happens when you `curl http://10.96.45.123:80`:

```bash
# Get the Service details
kubectl get service web-service -o yaml

# Get the endpoints (pod IPs backing this Service)
kubectl get endpoints web-service

# Example output:
# NAME          ENDPOINTS                                      AGE
# web-service   10.244.0.5:80,10.244.1.2:80,10.244.1.3:80      5m
```

**The packet journey**:

1. **Packet created**: `SRC=10.244.0.10 DST=10.96.45.123:80`
2. **iptables PREROUTING**: Packet hits the NAT table
3. **KUBE-SERVICES chain**: Matches the Service IP rule
4. **KUBE-SVC-XXX chain**: Probabilistically selects an endpoint
5. **KUBE-SEP-AAA chain**: DNATs to pod IP: `DST=10.244.1.2:80`
6. **Routing**: Packet routed to the pod
7. **Response**: Pod replies to SRC IP (your original pod)
8. **Reverse NAT**: iptables changes SRC from 10.244.1.2 back to 10.96.45.123

From the client pod's perspective, it talked to the Service IP the whole time!

### Exercise 5: Watch iptables Rules Update When Pods Change

**Goal**: See kube-proxy update iptables in real-time.

Open two terminal windows.

**Terminal 1 - Watch endpoints**:
```bash
kubectl get endpoints web-service --watch
```

**Terminal 2 - Delete a pod**:
```bash
# Delete one of the backend pods
POD_TO_DELETE=$(kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD_TO_DELETE
```

**What you'll see in Terminal 1**:
The endpoints list updates immediately when the pod is deleted, and again when the replacement pod becomes ready.

**Check iptables again**:
```bash
# Access the node again
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
docker exec -it $NODE_NAME bash

# Inside the node, get the Service IP
SVC_IP=10.96.45.123  # Your actual Service IP

# Count the DNAT rules
iptables-save | grep DNAT | grep $SVC_IP -A 3

# You should see 3 rules (for 3 pods)
exit
```

kube-proxy keeps iptables synchronized with the current set of healthy pods!

### Exercise 6: Test Service Without Endpoints

**Goal**: See what happens when no pods match a Service.

```bash
# Create a Service with a selector that matches nothing
kubectl create service clusterip fake-service --tcp=80:80

# Set a selector that matches no pods
kubectl set selector service fake-service app=nonexistent

# Check the Service
kubectl get service fake-service

# Check endpoints
kubectl get endpoints fake-service

# Output:
# NAME           ENDPOINTS   AGE
# fake-service   <none>      10s
```

**Try to access it**:
```bash
FAKE_IP=$(kubectl get service fake-service -o jsonpath='{.spec.clusterIP}')

kubectl exec test-pod -- curl -v --max-time 5 http://$FAKE_IP

# You'll get a connection timeout or "No route to host"
```

**Why?** iptables has rules for the Service IP, but they don't DNAT to any pod because there are no endpoints. The packet gets dropped.

Clean up:
```bash
kubectl delete service fake-service
```

## Self-Check Questions

### Question 1
You run `ip addr` on a node and don't see the ClusterIP address anywhere. Is the Service broken?

**Answer**: No, the Service is fine. ClusterIP addresses are virtual IPs that exist only in iptables rules, not on any network interface. You won't find them with `ip addr` or `ifconfig`. This is by design - kube-proxy creates iptables rules to intercept traffic destined for the ClusterIP and DNAT it to pod IPs.

### Question 2
A Service has 3 backend pods. How does iptables decide which pod gets the traffic?

**Answer**: iptables uses probabilistic load balancing with the `--mode random --probability` match. For 3 pods, the rules typically look like: 33% chance for pod1, 50% of remaining for pod2 (33% total), and 100% of remaining for pod3 (33% total). This gives roughly equal distribution over many requests.

### Question 3
What happens if you send traffic to a ClusterIP from outside the cluster?

**Answer**: It won't work. The ClusterIP only exists in the iptables rules on cluster nodes. External hosts don't have these rules, so they can't route to the virtual IP. For external access, you need NodePort, LoadBalancer, or Ingress.

### Question 4
You create a Service at 10.96.5.10. Pods can reach it from node1 but not node2. What's wrong?

**Answer**: kube-proxy is likely not running on node2, or it's misconfigured. kube-proxy is a DaemonSet that must run on every node to program iptables. Check with `kubectl get pods -n kube-system -l k8s-app=kube-proxy` and ensure a pod is running on node2.

### Question 5
Why does kube-proxy use iptables instead of a real load balancer daemon?

**Answer**: iptables is kernel-level packet processing - extremely fast with minimal overhead. A userspace load balancer would need to receive every packet, process it, and forward it, which is slower. iptables processes packets in the kernel without context switching. However, IPVS mode (which we'll see in Week 6) is even more efficient for clusters with many Services.

## Today I Learned (TIL)

Fill this out at the end of the day:

```
Date: _______________

Key Concepts:
- A ClusterIP is a: _______________
- kube-proxy runs on: _______________
- The iptables chain for Services is: _______________
- DNAT stands for: _______________

My Service today:
- Name: _______________
- ClusterIP: _______________
- Number of backend pods: _______________

iptables chain I found:
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
# Create a Service
kubectl expose deployment <name> --port=<port> --target-port=<target>
kubectl create service clusterip <name> --tcp=<port>:<target-port>

# View Services
kubectl get services
kubectl get svc
kubectl describe service <name>

# View Endpoints
kubectl get endpoints
kubectl get endpoints <service-name>

# Get ClusterIP
kubectl get service <name> -o jsonpath='{.spec.clusterIP}'

# Test Service from pod
kubectl exec <pod> -- curl http://<service-ip>:<port>

# iptables debugging (inside node)
iptables-save | grep <service-ip>
iptables-save | grep KUBE-SERVICES
iptables-save | grep KUBE-SVC
iptables-save | grep DNAT

# Check kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl logs -n kube-system <kube-proxy-pod>

# Delete Service
kubectl delete service <name>
```

## What's Next

Tomorrow (Day 32), you'll learn about **CoreDNS and service discovery**. You'll discover:
- How pods can use DNS names instead of IPs
- What `web-service.default.svc.cluster.local` means
- How to troubleshoot DNS resolution inside pods
- The role of CoreDNS in Kubernetes

Instead of `curl http://10.96.45.123`, you'll be able to use `curl http://web-service`. Much better!

**Preparation**: Keep your `web-service` and test-pod running for tomorrow's DNS exercises.

---

**Pro Tip**: When debugging Service issues, always check three things in order:
1. **Endpoints**: `kubectl get endpoints <service>` - Are there any pods?
2. **iptables**: Jump into a node and check for DNAT rules
3. **kube-proxy**: Is it running? Check its logs for errors
