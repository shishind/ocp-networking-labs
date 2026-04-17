# Day 38: DNS Troubleshooting in Kubernetes

## Learning Objectives
By the end of this lab, you will:
- Diagnose common DNS resolution failures in pods
- Test DNS step-by-step from pod to CoreDNS to upstream resolvers
- Fix misconfigured DNS settings
- Understand CoreDNS performance issues
- Build a systematic DNS debugging workflow

## Plain English Explanation

**Why DNS Breaks in Kubernetes**

DNS is the most common source of frustration in Kubernetes. Symptoms include:
- "Can't resolve service name"
- "nslookup works but curl doesn't"
- "DNS is slow - requests timeout"

**Common Root Causes**:

1. **CoreDNS pods are down/unhealthy**
   - Most obvious: if CoreDNS isn't running, no DNS works
   
2. **Pod's /etc/resolv.conf is wrong**
   - Missing nameserver
   - Wrong search domains
   - Corrupted by custom pod spec

3. **Service doesn't exist**
   - DNS can't resolve what doesn't exist
   - Typo in service name
   - Wrong namespace

4. **CoreDNS misconfigured**
   - Upstream DNS servers unreachable
   - Corefile syntax errors
   - Resource limits too low (CPU throttling)

5. **ndots causing slow queries**
   - Remember `ndots:5` from Day 32?
   - It causes extra DNS queries before trying FQDNs
   - Can make DNS seem slow

**The DNS Path**:

When a pod queries `backend.production.svc.cluster.local`:

```
Pod → /etc/resolv.conf → kube-dns Service (10.96.0.10)
                             ↓
                       CoreDNS pod(s)
                             ↓
        ┌────────────────────┴────────────────────┐
        ↓                                         ↓
    Cluster zone                           Upstream DNS
    (.cluster.local)                        (8.8.8.8, etc.)
        ↓                                         ↓
    Returns pod/service IP               Returns external IP
```

**In OpenShift**: DNS troubleshooting is identical. OpenShift uses CoreDNS (in 4.x) with the same configuration patterns.

## Hands-On Lab

### Exercise 1: Verify CoreDNS Health

**Goal**: Check that CoreDNS is running and healthy.

```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Expected output:
# NAME                       READY   STATUS    RESTARTS   AGE
# coredns-565d847f94-abc12   1/1     Running   0          2d
# coredns-565d847f94-def34   1/1     Running   0          2d

# If pods are not Running or not Ready, DNS won't work!

# Check CoreDNS Service
kubectl get service -n kube-system kube-dns

# Expected output:
# NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
# kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP   2d

# Check endpoints
kubectl get endpoints -n kube-system kube-dns

# Should show the CoreDNS pod IPs
# NAME       ENDPOINTS                           AGE
# kube-dns   10.244.1.2:53,10.244.2.3:53         2d
```

**If CoreDNS pods are down**:
```bash
kubectl describe pod -n kube-system <coredns-pod-name>

# Check for:
# - Image pull errors
# - Resource limits (OOMKilled)
# - Node affinity issues
```

### Exercise 2: Test DNS from a Pod - The Full Diagnostic

**Goal**: Systematically test DNS resolution.

```bash
# Create a test pod
kubectl run dns-debug --image=nicolaka/netshoot --command -- sleep 3600

# Wait for it
kubectl wait --for=condition=Ready pod/dns-debug --timeout=60s
```

**Test 1: Check /etc/resolv.conf**:
```bash
kubectl exec dns-debug -- cat /etc/resolv.conf

# Expected output:
# nameserver 10.96.0.10
# search default.svc.cluster.local svc.cluster.local cluster.local
# options ndots:5
```

**Verify each line**:
- `nameserver 10.96.0.10` should match the kube-dns Service IP
- `search` should include your namespace and cluster domain
- `options ndots:5` is normal (though causes extra queries)

**Test 2: Resolve the kubernetes Service**:
```bash
kubectl exec dns-debug -- nslookup kubernetes

# Expected output:
# Server:         10.96.0.10
# Address:        10.96.0.10#53
#
# Name:   kubernetes.default.svc.cluster.local
# Address: 10.96.0.1
```

**If this fails**:
- CoreDNS is likely down (check Step 1)
- Or network connectivity to CoreDNS is broken (check NetworkPolicies)

**Test 3: Resolve an external domain**:
```bash
kubectl exec dns-debug -- nslookup google.com

# Expected output:
# Server:         10.96.0.10
# Address:        10.96.0.10#53
#
# Non-authoritative answer:
# Name:   google.com
# Address: 142.250.XXX.XXX
```

**If internal DNS works but external doesn't**:
- CoreDNS can't reach upstream DNS servers
- Check the Corefile configuration

**Test 4: Measure DNS query time**:
```bash
kubectl exec dns-debug -- time nslookup kubernetes

# Output:
# real    0m0.015s   <- Should be < 100ms

kubectl exec dns-debug -- time nslookup www.google.com

# Output:
# real    0m0.050s   <- Might be slower due to upstream query
```

**If DNS is slow (> 1 second)**:
- CoreDNS might be CPU-throttled
- Too many CoreDNS queries (need more replicas)
- ndots causing extra queries

### Exercise 3: Break DNS and Fix It (Service Name Typo)

**Goal**: Simulate a common mistake - wrong service name.

```bash
# Create a service
kubectl create deployment web --image=nginx
kubectl expose deployment web --port=80 --name=web-service

# Test correct name
kubectl exec dns-debug -- nslookup web-service

# Works!

# Now try a typo
kubectl exec dns-debug -- nslookup web-servise  # Typo: "servise"

# Output:
# Server:         10.96.0.10
# Address:        10.96.0.10#53
#
# ** server can't find web-servise: NXDOMAIN
```

**NXDOMAIN = "No such domain"**

**How to diagnose**:
```bash
# Check what services actually exist
kubectl get services

# Output shows:
# web-service (not web-servise)

# Check if the service is in a different namespace
kubectl get services -A | grep web
```

**The fix**: Use the correct service name!

### Exercise 4: Break DNS with Wrong Namespace

**Goal**: Understand cross-namespace DNS queries.

```bash
# Create a service in a different namespace
kubectl create namespace production
kubectl create deployment api -n production --image=hashicorp/http-echo -- -text=API
kubectl expose deployment api -n production --port=5678

# From default namespace, try to resolve with short name
kubectl exec dns-debug -- nslookup api

# Output:
# ** server can't find api: NXDOMAIN

# Why? The search domains expand "api" to:
# - api.default.svc.cluster.local (not found - api is in production namespace)
# - api.svc.cluster.local (not found)
# - api.cluster.local (not found)
```

**The fix - use the namespaced name**:
```bash
kubectl exec dns-debug -- nslookup api.production

# Works! Returns the service IP

# Or use the FQDN
kubectl exec dns-debug -- nslookup api.production.svc.cluster.local

# Also works
```

### Exercise 5: Break DNS with Custom resolv.conf

**Goal**: See what happens when a pod overrides DNS settings.

```bash
# Create a pod with custom DNS config
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-dns
spec:
  containers:
  - name: test
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
  dnsConfig:
    nameservers:
    - 1.1.1.1  # Cloudflare DNS instead of kube-dns
EOF

# Wait for it
kubectl wait --for=condition=Ready pod/broken-dns --timeout=60s

# Check its resolv.conf
kubectl exec broken-dns -- cat /etc/resolv.conf

# Output:
# nameserver 1.1.1.1
# (No cluster search domains!)

# Try to resolve a cluster service
kubectl exec broken-dns -- nslookup web-service

# Output:
# ** server can't find web-service: NXDOMAIN

# Why? 1.1.1.1 doesn't know about cluster.local domains

# But external DNS works
kubectl exec broken-dns -- nslookup google.com

# Works!
```

**When would you do this?**
- Pods that only need external DNS (no cluster services)
- Custom DNS servers for specific apps
- Testing

**Clean up**:
```bash
kubectl delete pod broken-dns
```

### Exercise 6: Debug CoreDNS Performance Issues

**Goal**: Identify and fix slow DNS queries.

**Simulate load on CoreDNS**:
```bash
# Generate lots of DNS queries
kubectl exec dns-debug -- sh -c 'for i in $(seq 1 100); do nslookup kubernetes >/dev/null 2>&1; done'

# Check CoreDNS CPU usage
kubectl top pods -n kube-system -l k8s-app=kube-dns

# If CPU is high (close to limits), CoreDNS might be throttled

# Check CoreDNS resource limits
kubectl get deployment -n kube-system coredns -o yaml | grep -A 5 resources

# Example output:
# resources:
#   limits:
#     memory: 170Mi
#   requests:
#     cpu: 100m
#     memory: 70Mi
```

**If CoreDNS is CPU-throttled**:
```bash
# Increase CPU limits
kubectl set resources deployment -n kube-system coredns --limits=cpu=200m

# OR scale up replicas
kubectl scale deployment -n kube-system coredns --replicas=3

# Verify
kubectl get deployment -n kube-system coredns
```

**Check CoreDNS logs for errors**:
```bash
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=100

# Look for:
# - "i/o timeout" (can't reach upstream DNS)
# - "read udp: timeout" (network issues)
# - "NXDOMAIN" (frequent not-found queries)
```

### Exercise 7: The ndots Problem and How to Fix It

**Goal**: Understand why ndots causes extra DNS queries.

```bash
# Watch CoreDNS logs while making a query
kubectl logs -n kube-system -l k8s-app=kube-dns --follow &
LOGS_PID=$!

# Query an external domain
kubectl exec dns-debug -- nslookup www.google.com

# In the logs, you'll see MULTIPLE queries:
# [INFO] www.google.com.default.svc.cluster.local. A: NXDOMAIN
# [INFO] www.google.com.svc.cluster.local. A: NXDOMAIN
# [INFO] www.google.com.cluster.local. A: NXDOMAIN
# [INFO] www.google.com. A: answered with 142.250.XXX.XXX

# Stop following logs
kill $LOGS_PID
```

**Why?** With ndots:5, queries with fewer than 5 dots try the search domains first.

**The fix** (for pods that mostly query external domains):
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: low-ndots
spec:
  containers:
  - name: test
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
  dnsConfig:
    options:
    - name: ndots
      value: "1"
EOF

# Wait for it
kubectl wait --for=condition=Ready pod/low-ndots --timeout=60s

# Check resolv.conf
kubectl exec low-ndots -- cat /etc/resolv.conf

# Output:
# nameserver 10.96.0.10
# search default.svc.cluster.local svc.cluster.local cluster.local
# options ndots:1

# Now query external domain
kubectl logs -n kube-system -l k8s-app=kube-dns --follow &
LOGS_PID=$!

kubectl exec low-ndots -- nslookup www.google.com

# Only ONE query this time!
# [INFO] www.google.com. A: answered with 142.250.XXX.XXX

kill $LOGS_PID

# Clean up
kubectl delete pod low-ndots
```

## Self-Check Questions

### Question 1
A developer reports "nslookup web-service works, but curl http://web-service fails." What's likely wrong?

**Answer**: This isn't a DNS problem - DNS resolution is working (nslookup succeeded). The issue is likely:
1. The Service has no endpoints (no backend pods)
2. Wrong port in the curl command
3. Backend pods are unhealthy
4. NetworkPolicy blocking traffic

Check endpoints: `kubectl get endpoints web-service`

### Question 2
All DNS queries from pods fail with "server can't find X." What's the first thing you check?

**Answer**: Check if CoreDNS pods are running and healthy:
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

If they're not Running/Ready, DNS won't work cluster-wide.

### Question 3
You can resolve "kubernetes" but not "kubernetes.default.svc.cluster.local". What's wrong?

**Answer**: This is unusual because both should resolve to the same thing. Possible causes:
- The short name works because of search domains in /etc/resolv.conf
- The FQDN fails if there's a typo or if the Corefile is misconfigured
- Check: `kubectl exec <pod> -- cat /etc/resolv.conf` for search domains

### Question 4
DNS queries work but are very slow (2-3 seconds). What are three possible causes?

**Answer**:
1. **ndots causing extra queries**: Each query tries multiple search domains first
2. **CoreDNS CPU-throttled**: Check `kubectl top pods -n kube-system`
3. **Upstream DNS slow**: CoreDNS waiting for external DNS servers to respond

### Question 5
How do you query a service in a different namespace?

**Answer**: Use the namespaced name or FQDN:
- `service-name.namespace` (e.g., `api.production`)
- `service-name.namespace.svc.cluster.local` (FQDN)

Short names only work within the same namespace due to search domains.

## Today I Learned (TIL)

Fill this out at the end of the day:

```
Date: _______________

Key DNS Debugging Commands:
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

DNS issues I debugged:
_______________________________________________

CoreDNS Service IP in my cluster: _______________

Most common DNS mistake:
_______________________________________________

The ndots problem:
_______________________________________________

Biggest "aha" moment:
_______________________________________________
_______________________________________________

How this applies to production:
_______________________________________________
_______________________________________________
```

## Commands Cheat Sheet

```bash
# Check CoreDNS health
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get service -n kube-system kube-dns
kubectl get endpoints -n kube-system kube-dns

# CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --follow

# Test DNS from pod
kubectl exec <pod> -- cat /etc/resolv.conf
kubectl exec <pod> -- nslookup <domain>
kubectl exec <pod> -- dig <domain>
kubectl exec <pod> -- host <domain>

# Time DNS queries
kubectl exec <pod> -- time nslookup <domain>

# CoreDNS configuration
kubectl get configmap -n kube-system coredns -o yaml

# CoreDNS performance
kubectl top pods -n kube-system -l k8s-app=kube-dns
kubectl scale deployment -n kube-system coredns --replicas=<N>
kubectl set resources deployment -n kube-system coredns --limits=cpu=<value>

# Custom DNS config in pod
dnsConfig:
  nameservers:
    - 1.1.1.1
  searches:
    - custom.domain
  options:
    - name: ndots
      value: "1"

# Troubleshooting
kubectl describe pod <pod>  # Check DNS policy
kubectl get services  # List available services
kubectl get services -A | grep <name>  # Search all namespaces
```

## What's Next

Tomorrow (Day 39), you'll learn about **kube-proxy IPVS mode**. You'll discover:
- The difference between iptables and IPVS modes
- How to check which mode kube-proxy is using
- How to view IPVS rules with ipvsadm
- When to use IPVS vs iptables

You've mastered DNS troubleshooting. Tomorrow you'll dive into an alternative to iptables for Service implementation!

**Preparation**: Keep your kind cluster running. We'll switch kube-proxy to IPVS mode.

---

**Pro Tip**: Create a "DNS debug pod" with all troubleshooting tools (netshoot, dnsutils) and keep it running in your clusters. When DNS issues arise, you can immediately exec into it and start debugging. Much faster than creating a pod on-demand.
