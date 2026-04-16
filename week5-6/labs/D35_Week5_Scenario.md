# Day 35: Week 5 Scenario - "Service Returns Connection Refused"

## Learning Objectives
By the end of this lab, you will:
- Apply a systematic debugging methodology to Service connectivity issues
- Use multiple tools (kubectl, iptables, logs) to triangulate problems
- Diagnose issues at different layers (DNS, Service, Endpoints, Pods)
- Build confidence troubleshooting real-world Kubernetes networking problems

## Scenario Overview

**Your Role**: Platform Engineer at a startup

**The Problem**: 
Your frontend team reports that their app can't connect to the backend API. The error message is:
```
Error: connect ECONNREFUSED when trying to reach http://backend-api:8080
```

**What You Know**:
- The backend deployment is named `backend-api`
- It should be exposed as a Service named `backend-api` on port 8080
- The frontend is working fine otherwise
- This was working yesterday

**Your Mission**: Find and fix the problem using systematic debugging techniques.

## Setup: Create the Broken Environment

Let's create the scenario with intentional bugs.

```bash
# Create the backend deployment
kubectl create deployment backend-api --image=hashicorp/http-echo --replicas=3 -- -text="Backend API v1.0"

# Wait for pods to be ready
kubectl wait --for=condition=Ready pod -l app=backend-api --timeout=60s

# Verify pods are running
kubectl get pods -l app=backend-api

# Now create a Service with INTENTIONAL BUGS
# Bug 1: Wrong port
# Bug 2: Wrong selector
kubectl create service clusterip backend-api --tcp=8080:5678

# Override the selector with a typo
kubectl patch service backend-api --type='json' -p='[{"op": "replace", "path": "/spec/selector", "value":{"app":"backend-wrong"}}]'

# Create a frontend pod to test from
kubectl run frontend --image=nicolaka/netshoot --command -- sleep 3600

# Wait for it
kubectl wait --for=condition=Ready pod/frontend --timeout=60s
```

**Now test the broken connection**:
```bash
kubectl exec frontend -- curl -v --max-time 5 http://backend-api:8080

# Expected error:
# * Could not resolve host: backend-api (if DNS is broken)
# OR
# curl: (7) Failed to connect to backend-api port 8080: Connection refused
# OR  
# curl: (28) Connection timed out
```

Your job is to figure out WHY and FIX it!

## Debugging Methodology

Use this systematic approach:

### Step 1: Verify DNS Resolution

**Question**: Can the frontend pod resolve the Service name to an IP?

```bash
# Test DNS resolution
kubectl exec frontend -- nslookup backend-api

# Expected output (if DNS works):
# Server:         10.96.0.10
# Address:        10.96.0.10#53
#
# Name:   backend-api.default.svc.cluster.local
# Address: 10.96.XXX.XXX

# If this fails, the problem is DNS (CoreDNS issue)
# If this succeeds, DNS is fine - problem is elsewhere
```

**Record your findings**:
- Did DNS resolve? (Yes/No)
- What IP did it resolve to?

### Step 2: Check if the Service Exists

**Question**: Does the Service object exist and have a ClusterIP?

```bash
# List services
kubectl get service backend-api

# Expected output:
# NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
# backend-api   ClusterIP   10.96.XXX.XXX   <none>        8080/TCP   5m

# Get detailed info
kubectl describe service backend-api
```

**What to check**:
- Does the Service exist?
- Does it have a ClusterIP?
- What selector does it use? (This is KEY!)
- What are the Port and TargetPort values?

**Record your findings**:
- Service exists: (Yes/No)
- ClusterIP: _______________
- Selector: _______________
- Port: _____ TargetPort: _____

### Step 3: Check Endpoints

**Question**: Does the Service have backend pods?

```bash
# This is the MOST IMPORTANT debugging command
kubectl get endpoints backend-api

# Healthy output:
# NAME          ENDPOINTS                                      AGE
# backend-api   10.244.1.2:5678,10.244.1.3:5678,10.244.1.4:5678   5m

# PROBLEM output:
# NAME          ENDPOINTS   AGE
# backend-api   <none>      5m
```

**If Endpoints is <none>, you found the problem!**

The Service can't find any pods. Why?

```bash
# Check what the Service is looking for
kubectl get service backend-api -o jsonpath='{.spec.selector}'

# Output might be: {"app":"backend-wrong"}

# Check what labels the pods actually have
kubectl get pods -l app=backend-api --show-labels

# Output shows: app=backend-api

# MISMATCH! The Service is looking for "backend-wrong" but pods have "backend-api"
```

**Record your findings**:
- Endpoints count: _______________
- Service selector: _______________
- Pod labels: _______________
- Do they match? (Yes/No)

### Step 4: Fix the Selector

**Action**: Correct the Service selector.

```bash
# Fix the selector to match the pod labels
kubectl set selector service backend-api app=backend-api

# Verify the fix
kubectl get endpoints backend-api

# Now you should see:
# NAME          ENDPOINTS                                      AGE
# backend-api   10.244.1.2:5678,10.244.1.3:5678,10.244.1.4:5678   6m
```

**Test again**:
```bash
kubectl exec frontend -- curl -v --max-time 5 http://backend-api:8080

# You might STILL get an error!
# Why? Because we have a second bug...
```

### Step 5: Verify Port Configuration

**Question**: Are the Service port and pod port correct?

```bash
# Check the Service configuration
kubectl get service backend-api -o yaml | grep -A 5 ports

# Output:
# ports:
# - port: 8080          <- Service port (what clients connect to)
#   protocol: TCP
#   targetPort: 5678    <- Pod port (where traffic is sent)

# Now check what port the pods are actually listening on
kubectl get pods -l app=backend-api -o jsonpath='{.items[0].spec.containers[0].args}'

# Output: [-text=Backend API v1.0]

# The hashicorp/http-echo image listens on port 5678 by default
# So targetPort: 5678 is CORRECT

# But wait... let's test directly to a pod IP to be sure
POD_IP=$(kubectl get pod -l app=backend-api -o jsonpath='{.items[0].status.podIP}')

kubectl exec frontend -- curl -v --max-time 5 http://$POD_IP:5678

# This should work!
# Output: Backend API v1.0
```

**So the issue is**: Service port is 8080, targetPort is 5678 (correct), but something else is wrong...

Actually, the Service is correct now! Let's test again:

```bash
kubectl exec frontend -- curl -v http://backend-api:8080

# This should NOW work!
# Output: Backend API v1.0
```

**Success!** The problem was the selector mismatch.

### Step 6: Verify iptables Rules (Advanced)

**Question**: Did kube-proxy program the correct iptables rules?

```bash
# Get a node name
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

# Access the node (in kind, it's a Docker container)
docker exec -it $NODE_NAME bash

# Inside the node, get the Service ClusterIP
# (You noted this in Step 2)
SVC_IP=10.96.XXX.XXX  # Replace with your actual Service IP

# Search for iptables rules
iptables-save | grep $SVC_IP

# You should see:
# -A KUBE-SERVICES -d <SVC_IP>/32 -p tcp -m tcp --dport 8080 -j KUBE-SVC-XXXXX

# Check the Service chain
iptables-save | grep KUBE-SVC-XXXXX

# You should see DNAT rules to pod IPs

# Exit the node
exit
```

If iptables rules are missing, kube-proxy might not be running:
```bash
kubectl get pods -n kube-system -l k8s-app=kube-proxy
```

### Step 7: Check Pod Logs

**Question**: Are the backend pods actually healthy?

```bash
# Check if pods are ready
kubectl get pods -l app=backend-api

# All should be Running and 1/1 Ready

# Check logs for errors
kubectl logs -l app=backend-api --tail=20

# For http-echo, you should see:
# 2024/01/15 12:00:00 Server is listening on :5678

# If you see errors, that's your problem
```

### Step 8: Test End-to-End

**Action**: Verify everything works.

```bash
# DNS test
kubectl exec frontend -- nslookup backend-api
# Should resolve

# Direct Service access
kubectl exec frontend -- curl http://backend-api:8080
# Should return: Backend API v1.0

# Multiple requests (test load balancing)
for i in {1..5}; do
    kubectl exec frontend -- curl -s http://backend-api:8080
done

# All should succeed
```

## Practice Scenario: Introduce Your Own Bugs

Now that you've fixed the scenario, let's practice with different bugs.

### Bug Scenario A: Wrong TargetPort

```bash
# Break the Service by changing targetPort
kubectl patch service backend-api --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/targetPort", "value":9999}]'

# Test
kubectl exec frontend -- curl -v --max-time 5 http://backend-api:8080

# Expected: Connection refused or timeout

# Debug and fix
# Hint: Check pod logs, test direct pod IP access, check Service targetPort
```

**Fix**:
```bash
# Correct the targetPort
kubectl patch service backend-api --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/targetPort", "value":5678}]'
```

### Bug Scenario B: Pods Not Ready

```bash
# Create a deployment with a failing readiness probe
kubectl delete deployment backend-api

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend-api
  template:
    metadata:
      labels:
        app: backend-api
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo
        args: ["-text=Backend API v1.0"]
        ports:
        - containerPort: 5678
        readinessProbe:
          httpGet:
            path: /healthz
            port: 5678
          initialDelaySeconds: 3
          periodSeconds: 3
EOF

# Wait a moment
sleep 10

# Check pods
kubectl get pods -l app=backend-api

# They'll be Running but NOT Ready (0/1)

# Check Endpoints
kubectl get endpoints backend-api

# Should show:
# ENDPOINTS   AGE
# <none>      30s
# OR
# NotReadyAddresses shown in describe

# Test
kubectl exec frontend -- curl -v --max-time 5 http://backend-api:8080

# Expected: Connection timeout
```

**Fix**:
```bash
# Remove the readiness probe or fix the health endpoint
kubectl delete deployment backend-api
kubectl create deployment backend-api --image=hashicorp/http-echo --replicas=3 -- -text="Backend API v1.0"
```

### Bug Scenario C: Service Doesn't Exist

```bash
# Delete the Service
kubectl delete service backend-api

# Test
kubectl exec frontend -- curl -v --max-time 5 http://backend-api:8080

# Expected: Could not resolve host: backend-api

# Debug
kubectl exec frontend -- nslookup backend-api
# DNS fails

kubectl get service backend-api
# Error: service "backend-api" not found
```

**Fix**:
```bash
# Recreate the Service
kubectl expose deployment backend-api --port=8080 --target-port=5678
```

## Debugging Decision Tree

Use this flowchart for any Service connectivity issue:

```
START: Can't connect to Service
    ↓
1. Can you resolve the DNS name?
   → NO: Check CoreDNS (kubectl get pods -n kube-system -l k8s-app=kube-dns)
   → YES: Continue to step 2
    ↓
2. Does the Service exist?
   → NO: Create the Service (kubectl expose...)
   → YES: Continue to step 3
    ↓
3. Does the Service have Endpoints?
   → NO: Go to step 4
   → YES: Go to step 5
    ↓
4. Why no Endpoints?
   → Check Service selector (kubectl get svc <name> -o yaml)
   → Check pod labels (kubectl get pods --show-labels)
   → Check pod readiness (kubectl get pods)
   → Fix the mismatch
    ↓
5. Can you connect to pod IP directly?
   → NO: Pod is broken (check logs, describe pod)
   → YES: Continue to step 6
    ↓
6. Are the Service ports correct?
   → Check port vs targetPort
   → Verify pod is listening on targetPort
   → Fix port configuration
    ↓
7. Still broken?
   → Check iptables rules on node
   → Check kube-proxy is running
   → Check NetworkPolicy (Week 6 topic)
```

## Self-Check Questions

### Question 1
You run `kubectl get endpoints backend-api` and see `<none>`. What are the three most likely causes?

**Answer**:
1. **Selector mismatch**: Service selector doesn't match pod labels
2. **Pods not ready**: Pods exist but failing readiness probes
3. **No pods**: Deployment has 0 replicas or pods are still starting

Check with: `kubectl describe service`, `kubectl get pods`, `kubectl describe pod`

### Question 2
DNS resolves the Service name to a ClusterIP, but `curl` times out. Where's the problem?

**Answer**: The Service exists (so DNS works), but either:
- No Endpoints (no backend pods)
- Wrong targetPort (Service routing to wrong port on pods)
- Pods are broken (not actually listening on the port)

Check Endpoints first: `kubectl get endpoints`. If empty, fix the selector or pod readiness. If populated, test direct pod access and check ports.

### Question 3
You fix the Service selector, but existing connections still fail for 30 seconds. Why?

**Answer**: kube-proxy updates iptables rules, but existing connections may be cached or in-flight. The kubelet sync interval (default ~30s) means it takes time for changes to propagate. New connections should work immediately, but some clients may cache DNS responses or have connection pooling.

### Question 4
What's the fastest way to test if a pod is actually listening on the expected port?

**Answer**: 
```bash
# Get pod IP
POD_IP=$(kubectl get pod <name> -o jsonpath='{.status.podIP}')

# Test direct access from another pod
kubectl exec <test-pod> -- curl -v http://$POD_IP:<port>
```

This bypasses the Service entirely and tests the pod directly.

### Question 5
Your Service has 3 endpoints, but requests to the Service fail 33% of the time. What's likely wrong?

**Answer**: One of the three backend pods is unhealthy, but its readiness probe isn't failing (or doesn't exist). iptables still routes ~33% of requests to the broken pod, causing failures. Fix: Add/fix readiness probes, or check pod logs to find and fix the unhealthy pod.

## Today I Learned (TIL)

Fill this out at the end of the day:

```
Date: _______________

Bugs I diagnosed today:
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

Most useful debugging command:
_______________________________________________

Common mistake I'll avoid:
_______________________________________________

My debugging workflow:
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________
4. _______________________________________________

Biggest "aha" moment:
_______________________________________________
_______________________________________________

How this applies to production:
_______________________________________________
_______________________________________________
```

## Debugging Commands Cheat Sheet

```bash
# DNS Troubleshooting
kubectl exec <pod> -- nslookup <service-name>
kubectl exec <pod> -- cat /etc/resolv.conf
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Service Troubleshooting
kubectl get service <name>
kubectl describe service <name>
kubectl get service <name> -o yaml

# Endpoints Troubleshooting (MOST IMPORTANT)
kubectl get endpoints <service-name>
kubectl describe endpoints <service-name>

# Check selector mismatch
kubectl get service <name> -o jsonpath='{.spec.selector}'
kubectl get pods --show-labels
kubectl get pods -l <selector>

# Pod Troubleshooting
kubectl get pods -l <selector>
kubectl describe pod <name>
kubectl logs <pod-name>
kubectl exec <pod> -- <command>

# Test direct pod access
POD_IP=$(kubectl get pod <name> -o jsonpath='{.status.podIP}')
kubectl exec <test-pod> -- curl http://$POD_IP:<port>

# kube-proxy Troubleshooting
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl logs -n kube-system <kube-proxy-pod>

# iptables (inside node)
docker exec -it <node-name> bash
iptables-save | grep <service-ip>
```

## What's Next

Congratulations! You've completed **Week 5 - Kubernetes Networking Fundamentals**.

**This week you learned**:
- How to set up a local Kubernetes cluster with kind
- The 4 fundamental rules of Kubernetes networking
- How ClusterIP Services work at the iptables level
- How CoreDNS provides service discovery
- How Endpoints link Services to Pods
- How to expose Services externally with NodePort and Ingress
- A systematic approach to debugging Service connectivity issues

**Next week (Week 6)**, you'll dive deeper:
- NetworkPolicy: Control which pods can talk to each other
- CNI Deep Dive: What happens when a pod starts
- Advanced DNS troubleshooting
- kube-proxy IPVS mode
- Wireshark for packet analysis

**Preparation**: Keep your kind cluster running. Review your TIL notes from this week to solidify your understanding.

---

**Pro Tip**: In production, create runbooks based on this debugging methodology. When someone reports "Service X is down," your team can follow a checklist: DNS? Service exists? Endpoints? Pod health? This systematic approach saves hours of random guessing.
