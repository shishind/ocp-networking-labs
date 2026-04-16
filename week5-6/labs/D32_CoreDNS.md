# Day 32: CoreDNS - Service Discovery Inside the Cluster

## Learning Objectives
By the end of this lab, you will:
- Understand how DNS works in Kubernetes clusters
- Query DNS records for Services from inside pods
- Interpret the /etc/resolv.conf file in a pod
- Troubleshoot DNS resolution issues
- Explain the role of CoreDNS in service discovery

## Plain English Explanation

**The DNS Problem in Kubernetes**

Yesterday you learned that Services give you stable IPs. But memorizing IPs is still painful:
- `curl http://10.96.45.123` - which service is this again?
- `curl http://10.96.87.234` - is this production or staging?

What you really want is to use **names**: `curl http://web-service`

**Enter: CoreDNS**

CoreDNS is the DNS server that runs inside your Kubernetes cluster. It automatically creates DNS records for every Service you create.

**How It Works**:

1. You create a Service named `web-service` in the `default` namespace
2. CoreDNS automatically creates a DNS A record: `web-service.default.svc.cluster.local` → Service ClusterIP
3. Pods can now use `web-service` (short name) or the full name to reach the Service

**The DNS Hierarchy**:

Full DNS name: `<service-name>.<namespace>.svc.cluster.local`

- `web-service` - the Service name
- `default` - the namespace
- `svc` - indicates it's a Service (not a pod)
- `cluster.local` - the cluster domain (configurable)

**Pod DNS Configuration**:

Every pod gets `/etc/resolv.conf` configured automatically:
```
nameserver 10.96.0.10          # CoreDNS Service IP
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

The `search` line means when you query `web-service`, it expands to:
1. `web-service.default.svc.cluster.local` (found! Use this)
2. (or tries other search domains if not found)

**In OpenShift**: CoreDNS works identically, providing the same DNS-based service discovery.

## Hands-On Lab

### Exercise 1: Query the Kubernetes API DNS Record

**Goal**: Verify CoreDNS is working by looking up the built-in kubernetes Service.

```bash
# Every cluster has a "kubernetes" Service for the API server
kubectl get service kubernetes

# Output:
# NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
# kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   1d
```

**Query it from a pod**:
```bash
# Use your test-pod or create one
kubectl run dnstest --image=nicolaka/netshoot --command -- sleep 3600

# Wait for it to be ready
kubectl wait --for=condition=Ready pod/dnstest --timeout=60s

# Perform an nslookup
kubectl exec dnstest -- nslookup kubernetes

# Expected output:
# Server:         10.96.0.10
# Address:        10.96.0.10#53
#
# Name:   kubernetes.default.svc.cluster.local
# Address: 10.96.0.1
```

**What happened**:
- You queried "kubernetes" (short name)
- CoreDNS (at 10.96.0.10) resolved it to the full name
- Returned the ClusterIP: 10.96.0.1

### Exercise 2: Examine Pod DNS Configuration

**Goal**: Understand how pods are configured to use CoreDNS.

```bash
# Check the resolv.conf file
kubectl exec dnstest -- cat /etc/resolv.conf

# Example output:
# nameserver 10.96.0.10
# search default.svc.cluster.local svc.cluster.local cluster.local
# options ndots:5
```

**Decode each line**:

**nameserver 10.96.0.10**:
This is the CoreDNS Service IP. Let's verify:
```bash
kubectl get service -n kube-system kube-dns

# Output:
# NAME       TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)         AGE
# kube-dns   ClusterIP   10.96.0.10    <none>        53/UDP,53/TCP   1d
```

Yes! The `kube-dns` Service (which routes to CoreDNS pods) is at 10.96.0.10.

**search default.svc.cluster.local ...**:
When you query "web-service", the resolver tries these in order:
1. `web-service.default.svc.cluster.local`
2. `web-service.svc.cluster.local`
3. `web-service.cluster.local`

**options ndots:5**:
If your query has fewer than 5 dots, use the search list. Otherwise, treat it as a FQDN (fully qualified domain name).

### Exercise 3: Query Your Service with Different DNS Names

**Goal**: Test short names, namespaced names, and FQDNs.

First, make sure you have the web-service from yesterday:
```bash
# If you don't have it, create it
kubectl create deployment web --image=nginx --replicas=2
kubectl expose deployment web --port=80 --name=web-service

# Verify
kubectl get service web-service
```

**Now test DNS resolution**:

**Short name (within same namespace)**:
```bash
kubectl exec dnstest -- nslookup web-service

# Should resolve to the ClusterIP
```

**Namespaced name**:
```bash
kubectl exec dnstest -- nslookup web-service.default

# Also works
```

**Fully qualified domain name (FQDN)**:
```bash
kubectl exec dnstest -- nslookup web-service.default.svc.cluster.local

# Most explicit, always works
```

**Verify with dig for more details**:
```bash
kubectl exec dnstest -- dig web-service +short

# Output: 10.96.45.123 (or whatever your Service IP is)

# Get full details
kubectl exec dnstest -- dig web-service

# Shows the full DNS query and response
```

### Exercise 4: Cross-Namespace DNS Queries

**Goal**: Query a Service in a different namespace.

```bash
# Create a new namespace
kubectl create namespace testing

# Create a Service in that namespace
kubectl create deployment db --image=postgres:13 --namespace=testing
kubectl expose deployment db --port=5432 --namespace=testing --name=database

# From your pod in the default namespace, try short name
kubectl exec dnstest -- nslookup database

# This will FAIL with "server can't find database: NXDOMAIN"
# Why? Because "database" expands to "database.default.svc..." (wrong namespace)

# Use the namespaced name
kubectl exec dnstest -- nslookup database.testing

# This works! Returns the ClusterIP

# Or use the FQDN
kubectl exec dnstest -- nslookup database.testing.svc.cluster.local

# Also works
```

**The lesson**: Short names only work within the same namespace. For cross-namespace queries, include the namespace.

### Exercise 5: Query DNS for Pod IPs (Headless Service)

**Goal**: Understand DNS for individual pods.

```bash
# Create a headless Service (ClusterIP: None)
kubectl create service clusterip web-headless --tcp=80:80 --clusterip=None

# Set the selector to match the web deployment
kubectl set selector service web-headless app=web

# Check the Service
kubectl get service web-headless

# Output:
# NAME           TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
# web-headless   ClusterIP   None         <none>        80/TCP    5s

# Query the DNS
kubectl exec dnstest -- nslookup web-headless

# Output shows multiple A records (one per pod):
# Name:   web-headless.default.svc.cluster.local
# Address: 10.244.1.2
# Name:   web-headless.default.svc.cluster.local
# Address: 10.244.0.5
```

**Headless Services don't get a ClusterIP**. DNS returns the pod IPs directly. This is useful for stateful applications (like databases) that need to talk to specific pods.

### Exercise 6: Explore the CoreDNS Pods

**Goal**: See where CoreDNS actually runs.

```bash
# CoreDNS runs in the kube-system namespace
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Output:
# NAME                       READY   STATUS    RESTARTS   AGE
# coredns-565d847f94-abc12   1/1     Running   0          1d
# coredns-565d847f94-def34   1/1     Running   0          1d
```

**Check the CoreDNS configuration**:
```bash
kubectl get configmap -n kube-system coredns -o yaml

# Look at the "Corefile" section
# This shows the CoreDNS configuration
```

**Check CoreDNS logs**:
```bash
# Pick one of the CoreDNS pods
COREDNS_POD=$(kubectl get pod -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].metadata.name}')

# View logs
kubectl logs -n kube-system $COREDNS_POD

# Make a DNS query from your test pod
kubectl exec dnstest -- nslookup web-service

# Check logs again - you'll see the query logged
kubectl logs -n kube-system $COREDNS_POD --tail=10
```

## Self-Check Questions

### Question 1
Your pod can't resolve service names. You run `kubectl exec mypod -- cat /etc/resolv.conf` and the nameserver line is missing. What's wrong?

**Answer**: The pod's DNS configuration is broken, likely due to a problem with the kubelet or pod spec. Every pod should automatically get /etc/resolv.conf with the kube-dns Service IP as the nameserver. Check the pod's dnsPolicy field (should be "ClusterFirst" by default) and ensure CoreDNS is running.

### Question 2
You have a Service called "api" in the "backend" namespace. What DNS name would you use from a pod in the "frontend" namespace to reach it?

**Answer**: Use `api.backend` or the full `api.backend.svc.cluster.local`. You cannot use just `api` because that would expand to `api.frontend.svc.cluster.local` (the wrong namespace).

### Question 3
Why does Kubernetes use "ndots:5" in resolv.conf?

**Answer**: With ndots:5, any query with fewer than 5 dots is treated as a short name and the search domains are tried first. This means `web-service` (0 dots) tries the search list before trying it as a FQDN. However, queries like `www.google.com` (2 dots) also try the search list first, which can cause extra DNS queries. This is a known inefficiency in Kubernetes DNS.

### Question 4
What's the difference between a regular Service and a headless Service (ClusterIP: None) in terms of DNS?

**Answer**: 
- Regular Service: DNS returns the single ClusterIP address
- Headless Service: DNS returns all pod IPs directly

Headless Services are used when you need to talk to specific pods (like StatefulSet pods) rather than load-balancing across all of them.

### Question 5
A developer reports that DNS lookups are slow. How would you investigate?

**Answer**: 
1. Check CoreDNS pod health: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
2. Check CoreDNS logs for errors: `kubectl logs -n kube-system <coredns-pod>`
3. Test from a pod: `kubectl exec <pod> -- time nslookup kubernetes`
4. Check if ndots is causing extra queries (it often is)
5. Look at CoreDNS resource usage - it might be CPU-throttled

### Question 6
Can pods use external DNS (like 8.8.8.8) to resolve internet domains?

**Answer**: Yes! CoreDNS forwards queries it can't answer (like www.google.com) to the upstream DNS servers configured on the nodes. This allows pods to resolve both cluster Services and external domains.

## Today I Learned (TIL)

Fill this out at the end of the day:

```
Date: _______________

Key DNS Concepts:
- CoreDNS Service IP in my cluster: _______________
- DNS name format: _______________
- The "ndots" setting means: _______________

Services I queried today:
1. _______________ resolved to _______________
2. _______________ resolved to _______________

Cross-namespace query I tested:
_______________________________________________

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
# DNS queries from pod
kubectl exec <pod> -- nslookup <service-name>
kubectl exec <pod> -- dig <service-name>
kubectl exec <pod> -- host <service-name>

# Check pod DNS configuration
kubectl exec <pod> -- cat /etc/resolv.conf

# CoreDNS management
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system <coredns-pod>
kubectl get service -n kube-system kube-dns

# CoreDNS configuration
kubectl get configmap -n kube-system coredns -o yaml

# Create headless Service
kubectl create service clusterip <name> --tcp=80:80 --clusterip=None

# Test DNS resolution
kubectl run dnstest --image=nicolaka/netshoot --rm -it -- /bin/bash
# Then inside the pod:
nslookup <service>
dig <service>
cat /etc/resolv.conf

# Query specific DNS record types
kubectl exec <pod> -- dig <service> A      # IPv4 address
kubectl exec <pod> -- dig <service> SRV    # Service record
kubectl exec <pod> -- dig <service> ANY    # All records
```

## What's Next

Tomorrow (Day 33), you'll learn about **Endpoints** - the glue between Services and pods. You'll discover:
- How Services know which pods to route traffic to
- What happens when a pod becomes unhealthy
- How to watch Endpoints update in real-time
- How to debug "Service has no endpoints" errors

You've learned that Services provide stable IPs and DNS names. Tomorrow you'll see how Kubernetes tracks which pods should receive that traffic.

**Preparation**: Keep your web-service and pods running for tomorrow's Endpoints exercises.

---

**Pro Tip**: When writing applications for Kubernetes, use DNS names (not IPs) for Service discovery. This makes your app portable across clusters and environments. For example, connect to `database.production.svc.cluster.local` instead of a hardcoded IP.
