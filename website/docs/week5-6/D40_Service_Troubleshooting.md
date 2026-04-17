# Day 40: Full Service Troubleshooting Scenario

## Learning Objectives
By the end of this lab, you will:
- Apply a complete troubleshooting methodology to Service connectivity issues
- Combine skills from the entire week (Services, DNS, Endpoints, NetworkPolicy)
- Build confidence debugging complex, multi-layer problems
- Create a personal troubleshooting playbook

## Scenario Overview

**Your Role**: Senior Platform Engineer at a fast-growing startup

**The Situation**: 
It's 2 PM on a Tuesday. Your Slack explodes with messages:
- Frontend team: "Can't connect to the API!"
- Backend team: "Our pods are running fine, check the network"
- Manager: "Customer-facing app is down, what's the ETA?"

**The Symptoms**:
- Frontend pods can't reach the backend API Service
- Error: `curl: (7) Failed to connect to api-service port 8080: Connection refused`
- This worked this morning
- No code changes were deployed

**Your Mission**: Find and fix the problem. Fast.

## Setup: Create the Broken Environment

Let's build a realistic scenario with multiple issues.

```bash
# Clean slate
kubectl delete namespace frontend backend 2>/dev/null || true

# Create namespaces
kubectl create namespace frontend
kubectl create namespace backend

# Deploy backend with a subtle issue
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
      version: v2  # Note: version label
  template:
    metadata:
      labels:
        app: api
        version: v2
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo
        args: ["-text=API v2.0"]
        ports:
        - containerPort: 5678
        readinessProbe:
          httpGet:
            path: /
            port: 5678
          initialDelaySeconds: 5
          periodSeconds: 3
EOF

# Create Service with WRONG selector (Bug #1)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: backend
spec:
  selector:
    app: api
    version: v1  # WRONG! Pods are labeled v2
  ports:
  - port: 8080
    targetPort: 5678
EOF

# Apply a NetworkPolicy that blocks access (Bug #2)
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: backend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# Deploy frontend
kubectl create deployment web -n frontend --image=nginx
kubectl label pods -n frontend -l app=web tier=frontend

# Wait for pods
kubectl wait --for=condition=Ready pod --all -n backend --timeout=60s
kubectl wait --for=condition=Ready pod --all -n frontend --timeout=60s

echo "Environment ready! The bugs are planted. Start debugging..."
```

## The Troubleshooting Process

### Phase 1: Gather Information

**Step 1: Reproduce the error**

```bash
# Get a frontend pod
FRONTEND_POD=$(kubectl get pod -n frontend -l app=web -o jsonpath='{.items[0].metadata.name}')

# Try to access the API
kubectl exec -n frontend $FRONTEND_POD -- curl -v --max-time 5 http://api-service.backend:8080

# Expected error:
# * Could not resolve host: api-service.backend
# OR
# curl: (28) Connection timed out
# OR
# curl: (7) Failed to connect
```

**Record your observation**: What exact error did you get?

**Step 2: Break down the problem**

The request flow is:
```
Frontend Pod → DNS → Service ClusterIP → Endpoints → Backend Pods
```

One of these links is broken. Let's test each one.

### Phase 2: Test DNS Resolution

**Question**: Can the frontend pod resolve the Service name?

```bash
kubectl exec -n frontend $FRONTEND_POD -- nslookup api-service.backend

# Expected output (if DNS works):
# Server:         10.96.0.10
# Address:        10.96.0.10#53
#
# Name:   api-service.backend.svc.cluster.local
# Address: 10.96.XXX.XXX
```

**If DNS fails**:
- Check CoreDNS: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
- Check Service exists: `kubectl get service -n backend api-service`
- Wrong namespace in query

**If DNS works**: Note the ClusterIP and continue to Phase 3.

### Phase 3: Check Service Configuration

**Question**: Does the Service exist and have the right configuration?

```bash
# Get Service details
kubectl describe service -n backend api-service

# Check these fields:
# - Selector: What labels is it looking for?
# - Port/TargetPort: Are they correct?
# - Endpoints: Are there any?

# Get the selector
kubectl get service -n backend api-service -o jsonpath='{.spec.selector}' | jq

# Output:
# {
#   "app": "api",
#   "version": "v1"   # This is the FIRST BUG!
# }
```

**Red flag**: The selector has `version: v1`.

**Step: Check pod labels**

```bash
# What labels do the backend pods actually have?
kubectl get pods -n backend --show-labels

# Output:
# NAME                   READY   STATUS    LABELS
# api-7d8f8c9d8f-abc12   1/1     Running   app=api,version=v2
# api-7d8f8c9d8f-def34   1/1     Running   app=api,version=v2
# api-7d8f8c9d8f-ghi56   1/1     Running   app=api,version=v2
```

**BUG FOUND #1**: Service selector says `version=v1`, but pods are labeled `version=v2`!

### Phase 4: Check Endpoints

**Question**: Does the Service have any backend pods?

```bash
kubectl get endpoints -n backend api-service

# Output:
# NAME          ENDPOINTS   AGE
# api-service   <none>      5m
```

**No endpoints!** This confirms the selector mismatch.

**Fix Bug #1**:
```bash
# Correct the Service selector
kubectl patch service -n backend api-service --type='json' -p='[{"op": "replace", "path": "/spec/selector/version", "value":"v2"}]'

# Verify the fix
kubectl get endpoints -n backend api-service

# Now you should see:
# NAME          ENDPOINTS                                      AGE
# api-service   10.244.1.5:5678,10.244.2.3:5678,10.244.2.4:5678   6m
```

**Test again**:
```bash
kubectl exec -n frontend $FRONTEND_POD -- curl -v --max-time 5 http://api-service.backend:8080

# You might STILL get a timeout!
# Why? Because of Bug #2 (NetworkPolicy)
```

### Phase 5: Test Direct Pod Access

**Question**: Can we bypass the Service and reach a pod directly?

```bash
# Get a backend pod IP
BACKEND_POD_IP=$(kubectl get pod -n backend -o jsonpath='{.items[0].status.podIP}')

echo "Backend pod IP: $BACKEND_POD_IP"

# Try to access it directly on the correct port (5678, not 8080)
kubectl exec -n frontend $FRONTEND_POD -- curl -v --max-time 5 http://$BACKEND_POD_IP:5678

# Expected: TIMEOUT
# This means the pod itself is reachable, but something is blocking the traffic
```

### Phase 6: Check NetworkPolicies

**Question**: Is there a NetworkPolicy blocking traffic?

```bash
# Check for NetworkPolicies in the backend namespace
kubectl get networkpolicy -n backend

# Output:
# NAME        POD-SELECTOR   AGE
# deny-all    <none>         10m

# Describe it
kubectl describe networkpolicy -n backend deny-all

# Output shows:
# Spec:
#   PodSelector:     <none> (Allowing the specific traffic to all pods in this namespace)
#   Allowing ingress traffic:
#     <none> (Selected pods are isolated for ingress connectivity)
#   Not affecting egress traffic
#   Policy Types: Ingress
```

**BUG FOUND #2**: A deny-all NetworkPolicy is blocking all ingress traffic!

**Fix Bug #2**:

We need to allow traffic from the frontend namespace:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: frontend
    ports:
    - protocol: TCP
      port: 5678
EOF

# Verify
kubectl get networkpolicy -n backend
```

### Phase 7: Test End-to-End

**Question**: Does it work now?

```bash
# Test via Service
kubectl exec -n frontend $FRONTEND_POD -- curl -v http://api-service.backend:8080

# Expected output:
# < HTTP/1.1 200 OK
# API v2.0

# Success!
```

### Phase 8: Verify and Document

**Verify all components**:

```bash
# Check Service
kubectl get service -n backend api-service
# Has ClusterIP, correct selector

# Check Endpoints
kubectl get endpoints -n backend api-service
# Has 3 pod IPs

# Check Pods
kubectl get pods -n backend
# All Running and Ready

# Check NetworkPolicies
kubectl get networkpolicy -n backend
# allow-frontend exists

# Test multiple requests (load balancing)
for i in $(seq 1 5); do
    kubectl exec -n frontend $FRONTEND_POD -- curl -s http://api-service.backend:8080
done

# All return: API v2.0
```

**Document the issues**:

Create an incident report:

```
INCIDENT REPORT
===============
Date: [Today's date]
Duration: 15 minutes (from detection to fix)
Impact: Frontend unable to reach backend API

ROOT CAUSES:
1. Service selector mismatch
   - Service selector: version=v1
   - Pod labels: version=v2
   - Result: Zero endpoints, all traffic dropped

2. Overly restrictive NetworkPolicy
   - deny-all policy with no allow rules
   - Result: Even after fixing selector, traffic was blocked

FIXES APPLIED:
1. Updated Service selector to version=v2
2. Added NetworkPolicy to allow frontend → backend traffic

PREVENTION:
- Add tests to verify Service selectors match pod labels
- Document NetworkPolicy changes in deployment docs
- Use label validation in CI/CD
```

## Practice Scenario: New Bugs

Now let's introduce different bugs and practice again.

### Scenario A: Wrong Port

```bash
# Reset environment
kubectl delete networkpolicy -n backend allow-frontend

# Create a new Service with wrong port
kubectl delete service -n backend api-service

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: backend
spec:
  selector:
    app: api
    version: v2
  ports:
  - port: 8080
    targetPort: 9999  # WRONG! Should be 5678
EOF

# Re-apply the allow NetworkPolicy
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: frontend
    ports:
    - protocol: TCP
      port: 5678
EOF

# Test
kubectl exec -n frontend $FRONTEND_POD -- curl -v --max-time 5 http://api-service.backend:8080

# Error: Connection refused or timeout
```

**Your turn**: Debug this!

**Hints**:
1. Check endpoints - are there any?
2. Try accessing a pod directly on port 5678
3. Check the Service targetPort
4. Compare with the pod's containerPort

**Solution**:
```bash
# The issue: targetPort is 9999, but pods listen on 5678
kubectl patch service -n backend api-service --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/targetPort", "value":5678}]'

# Test again - should work now
kubectl exec -n frontend $FRONTEND_POD -- curl http://api-service.backend:8080
```

### Scenario B: Pods Not Ready

```bash
# Create a deployment with a failing readiness probe
kubectl delete deployment -n backend api

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
      version: v2
  template:
    metadata:
      labels:
        app: api
        version: v2
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo
        args: ["-text=API v2.0"]
        ports:
        - containerPort: 5678
        readinessProbe:
          httpGet:
            path: /health  # WRONG! This endpoint doesn't exist
            port: 5678
          initialDelaySeconds: 3
          periodSeconds: 3
EOF

# Wait a moment
sleep 10

# Check pods
kubectl get pods -n backend

# They're Running but NOT Ready (0/1)

# Test
kubectl exec -n frontend $FRONTEND_POD -- curl -v --max-time 5 http://api-service.backend:8080

# Error: timeout
```

**Your turn**: Debug this!

**Hints**:
1. Check pod status
2. Check endpoints
3. Describe a pod to see why it's not ready

**Solution**:
```bash
# Check endpoints
kubectl get endpoints -n backend api-service
# Shows: <none> or NotReadyAddresses

# Check pod details
kubectl describe pod -n backend <pod-name>

# See: Readiness probe failed: HTTP probe failed with statuscode: 404

# Fix: Remove the bad readiness probe or fix the path
kubectl patch deployment -n backend api --type='json' -p='[{"op": "remove", "path": "/spec/template/spec/containers/0/readinessProbe"}]'

# Wait for pods to become ready
kubectl wait --for=condition=Ready pod -n backend -l app=api --timeout=60s

# Test again
kubectl exec -n frontend $FRONTEND_POD -- curl http://api-service.backend:8080
```

## The Ultimate Debugging Checklist

Use this for any Service connectivity issue:

```
[ ] Step 1: Reproduce the error
    - What exact error message?
    - From which pod/namespace?
    
[ ] Step 2: DNS Resolution
    - Can the client pod resolve the Service name?
    - Command: kubectl exec <pod> -- nslookup <service>
    - If fails: Check CoreDNS, Service existence
    
[ ] Step 3: Service Exists
    - Does the Service exist in the right namespace?
    - Command: kubectl get service -n <namespace> <name>
    - If not: Create it
    
[ ] Step 4: Service Configuration
    - Check selector: kubectl get service <name> -o yaml
    - Check ports: port, targetPort, nodePort (if applicable)
    
[ ] Step 5: Endpoints
    - Does the Service have endpoints?
    - Command: kubectl get endpoints <service>
    - If <none>: Check selector vs pod labels
    
[ ] Step 6: Pod Labels
    - Do pod labels match Service selector?
    - Command: kubectl get pods --show-labels
    - Command: kubectl get service <name> -o jsonpath='{.spec.selector}'
    
[ ] Step 7: Pod Readiness
    - Are the pods Ready?
    - Command: kubectl get pods
    - If not: Check readiness probes, describe pod
    
[ ] Step 8: Direct Pod Access
    - Can you reach a pod directly (bypass Service)?
    - Command: kubectl exec <client> -- curl <pod-ip>:<port>
    - If fails: NetworkPolicy or pod is broken
    
[ ] Step 9: NetworkPolicy
    - Are there NetworkPolicies blocking traffic?
    - Command: kubectl get networkpolicy -n <namespace>
    - Command: kubectl describe networkpolicy <name>
    
[ ] Step 10: kube-proxy
    - Is kube-proxy running?
    - Command: kubectl get pods -n kube-system -l k8s-app=kube-proxy
    - Check logs if suspicious
    
[ ] Step 11: iptables/IPVS Rules
    - Are Service rules programmed correctly?
    - Access node, run: iptables-save | grep <service-ip>
    - Or: ipvsadm -ln (if IPVS mode)
```

## Self-Check Questions

### Question 1
You fix the Service selector and endpoints appear, but traffic still doesn't work. What are the top 3 things to check next?

**Answer**:
1. **NetworkPolicy**: Is there a policy blocking ingress to the backend pods?
2. **Wrong port**: Is the Service targetPort correct? Does it match the pod's containerPort?
3. **Pod not actually listening**: Is the application inside the pod running and bound to the correct port?

### Question 2
Endpoints show NotReadyAddresses instead of Addresses. What does this mean and how do you fix it?

**Answer**: Pods exist but are not passing their readiness probes. Check:
- `kubectl describe pod <name>` for readiness probe failures
- Pod logs for application errors
- Fix the probe configuration or fix the application

### Question 3
The Service has endpoints and NetworkPolicy allows traffic, but you still get "connection refused." What's likely wrong?

**Answer**: The targetPort is probably wrong. The Service is routing traffic to a port where the pod isn't listening. Verify:
- Service targetPort: `kubectl get service <name> -o yaml`
- Pod containerPort: `kubectl get pod <name> -o yaml`
- Test direct pod access: `kubectl exec <client> -- curl <pod-ip>:<container-port>`

### Question 4
How can you tell if the problem is with the Service layer or the pod layer?

**Answer**: Test direct pod access (bypass the Service):
```bash
POD_IP=$(kubectl get pod <name> -o jsonpath='{.status.podIP}')
kubectl exec <client> -- curl http://$POD_IP:<port>
```

If this works, the problem is the Service (selector, ports, endpoints).
If this fails, the problem is the pod (NetworkPolicy, app not listening, pod broken).

### Question 5
You've fixed all the issues, but the error persists for 30 seconds, then starts working. Why?

**Answer**: Propagation delay:
- Endpoint updates take a few seconds
- kube-proxy syncs iptables/IPVS rules every ~30 seconds (default syncPeriod)
- Client DNS caching (negative responses cached for TTL)

New connections should work immediately, but cached data may cause temporary failures.

## Today I Learned (TIL)

Fill this out at the end of the day:

```
Date: _______________

Bugs I found and fixed:
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

Most useful debugging command:
_______________________________________________

My debugging process:
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

Common mistake I'll avoid:
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
# Full debugging workflow
kubectl exec <pod> -- nslookup <service>              # Test DNS
kubectl get service -n <namespace> <name>             # Check Service exists
kubectl describe service -n <namespace> <name>        # Service details
kubectl get endpoints -n <namespace> <name>           # Check endpoints
kubectl get pods --show-labels                        # Check pod labels
kubectl get service <name> -o jsonpath='{.spec.selector}'  # Get selector
kubectl get pods                                      # Check pod readiness
kubectl exec <client> -- curl <pod-ip>:<port>        # Direct pod access
kubectl get networkpolicy -n <namespace>              # Check policies
kubectl describe networkpolicy -n <namespace> <name>  # Policy details
kubectl logs <pod>                                    # Pod logs
kubectl describe pod <pod>                            # Pod events

# Quick fixes
kubectl patch service <name> --type='json' -p='...'   # Fix Service
kubectl set selector service <name> <label>=<value>   # Fix selector
kubectl label pods -l <old-label> <new-label>=<value> # Fix pod labels
```

## What's Next

Tomorrow (Day 41), you'll learn about **Wireshark for Kubernetes**. You'll discover:
- How to capture packets in Kubernetes environments
- How to read pcap files
- Useful Wireshark filters for Kubernetes traffic
- How to follow TCP streams to debug protocols

You've mastered logical troubleshooting. Tomorrow you'll add packet-level debugging to your toolkit!

**Preparation**: Download Wireshark on your laptop if you don't have it already.

---

**Pro Tip**: Create a "runbook" for your team based on today's checklist. When someone reports a Service issue, they can follow the steps systematically instead of guessing. This reduces MTTR (Mean Time To Resolution) dramatically.
