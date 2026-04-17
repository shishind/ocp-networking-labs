# Day 36: NetworkPolicy - Controlling Pod-to-Pod Traffic

## Learning Objectives
By the end of this lab, you will:
- Understand what NetworkPolicies are and why they're needed
- Implement a deny-all ingress policy
- Create allow rules for specific traffic
- Test and verify NetworkPolicy enforcement
- Troubleshoot NetworkPolicy-related connectivity issues

## Plain English Explanation

**The Problem: By Default, Everything Can Talk to Everything**

Remember the 4 rules of Kubernetes networking? Rule #1 says "All pods can communicate with all other pods without NAT." This is great for flexibility, but terrible for security.

**Example**:
- Your frontend pods can talk to database pods directly
- A compromised pod in the "dev" namespace can access production data
- There's no network-level isolation between applications

**The Solution: NetworkPolicy**

A **NetworkPolicy** is like a firewall rule for pods. It controls:
- **Ingress**: What traffic can come INTO a pod
- **Egress**: What traffic can go OUT of a pod

**Key Concept: Deny-by-Default**

NetworkPolicies work best with a "deny-all, then allow specific" approach:
1. Apply a policy that denies all traffic to pods
2. Create additional policies that allow only necessary traffic
3. All other traffic is blocked

**How It Works**:

```
Without NetworkPolicy:
Frontend → Database  ✓ Allowed
Random Pod → Database  ✓ Allowed (BAD!)

With NetworkPolicy:
Frontend → Database  ✓ Allowed (explicit rule)
Random Pod → Database  ✗ Denied (no matching rule)
```

**Label Selectors Are Key**

NetworkPolicies use label selectors to:
- Choose which pods the policy applies to (podSelector)
- Define which pods are allowed to connect (namespaceSelector, podSelector)

**CNI Plugin Requirement**

NetworkPolicies are implemented by the CNI plugin (Calico, Cilium, etc.). kind uses kindnet, which **does NOT support NetworkPolicies**. We'll need to install Calico.

**In OpenShift**: NetworkPolicies work out of the box with OpenShift SDN or OVN-Kubernetes. OpenShift also adds EgressNetworkPolicy for additional control.

## Hands-On Lab

### Exercise 1: Install Calico in kind (For NetworkPolicy Support)

**Goal**: Replace kindnet with Calico to enable NetworkPolicy enforcement.

```bash
# Check current CNI
kubectl get pods -n kube-system

# You'll see kindnet pods - these don't support NetworkPolicy

# Delete existing kind cluster and recreate without default CNI
kind delete cluster --name learning

# Create cluster config that disables default CNI
cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: 192.168.0.0/16
nodes:
- role: control-plane
- role: worker
EOF

# Create the cluster
kind create cluster --name learning --config kind-config.yaml

# Nodes will be NotReady (no CNI yet)
kubectl get nodes

# Install Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Wait for Calico to be ready
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=120s

# Check nodes - should now be Ready
kubectl get nodes

# Verify Calico pods
kubectl get pods -n kube-system -l k8s-app=calico-node
```

### Exercise 2: Deploy Test Applications

**Goal**: Create three different apps to test policies.

```bash
# Create namespaces
kubectl create namespace frontend
kubectl create namespace backend
kubectl create namespace database

# Deploy frontend
kubectl create deployment web -n frontend --image=nginx --replicas=2
kubectl label pods -n frontend -l app=web tier=frontend

# Deploy backend API
kubectl create deployment api -n backend --image=hashicorp/http-echo --replicas=2 -- -text="Backend API"
kubectl label pods -n backend -l app=api tier=backend

# Expose backend as a Service
kubectl expose deployment api -n backend --port=5678 --name=api-service

# Deploy database
kubectl create deployment db -n database --image=postgres:13-alpine --replicas=1
kubectl label pods -n database -l app=db tier=database
kubectl set env deployment/db -n database POSTGRES_PASSWORD=secret

# Expose database as a Service
kubectl expose deployment db -n database --port=5432 --name=db-service

# Wait for all pods to be ready
kubectl wait --for=condition=Ready pod --all -n frontend --timeout=60s
kubectl wait --for=condition=Ready pod --all -n backend --timeout=60s
kubectl wait --for=condition=Ready pod --all -n database --timeout=60s

# Verify all are running
kubectl get pods -A -o wide | grep -E 'frontend|backend|database'
```

### Exercise 3: Test Default Behavior (Everything Allowed)

**Goal**: Verify that without NetworkPolicies, all traffic is allowed.

```bash
# Get a frontend pod name
FRONTEND_POD=$(kubectl get pod -n frontend -o jsonpath='{.items[0].metadata.name}')

# Get the backend Service IP
BACKEND_SVC=$(kubectl get service -n backend api-service -o jsonpath='{.spec.clusterIP}')

# Get a database pod IP
DB_POD_IP=$(kubectl get pod -n database -o jsonpath='{.items[0].status.podIP}')

# Test frontend → backend (should work)
kubectl exec -n frontend $FRONTEND_POD -- curl -s --max-time 3 http://api-service.backend:5678
# Output: Backend API

# Test frontend → database (should work, but SHOULDN'T in real life!)
kubectl exec -n frontend $FRONTEND_POD -- nc -zv $DB_POD_IP 5432
# Output: Connection succeeded (THIS IS BAD - frontend shouldn't access DB directly)
```

**Without NetworkPolicies, frontend can access the database directly. This is a security risk!**

### Exercise 4: Apply Deny-All Ingress Policy to Database

**Goal**: Block all incoming traffic to database pods.

```bash
# Create a deny-all ingress policy for database namespace
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: database
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# Verify the policy
kubectl get networkpolicy -n database

# Test access - should now be blocked
kubectl exec -n frontend $FRONTEND_POD -- nc -zv -w 3 $DB_POD_IP 5432

# Output: Connection timed out (BLOCKED!)
```

**What just happened**:
- `podSelector: {}` means "apply to all pods in this namespace"
- `policyTypes: [Ingress]` means "control incoming traffic"
- No `ingress` rules defined = deny all ingress

**Even backend can't access the database now**:
```bash
BACKEND_POD=$(kubectl get pod -n backend -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n backend $BACKEND_POD -- nc -zv -w 3 $DB_POD_IP 5432
# Output: Connection timed out (BLOCKED!)
```

### Exercise 5: Allow Backend to Access Database

**Goal**: Create a policy that allows only backend pods to connect to the database.

```bash
# Create an allow rule for backend → database
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-db
  namespace: database
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: backend
      podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 5432
EOF

# Verify the policy
kubectl get networkpolicy -n database

# Test backend → database (should work now)
kubectl exec -n backend $BACKEND_POD -- nc -zv $DB_POD_IP 5432
# Output: Connection succeeded

# Test frontend → database (should still be blocked)
kubectl exec -n frontend $FRONTEND_POD -- nc -zv -w 3 $DB_POD_IP 5432
# Output: Connection timed out (STILL BLOCKED - good!)
```

**Decode the policy**:
- `podSelector: {tier: database}`: Apply to database pods
- `ingress[].from[]`: Allow traffic from...
  - `namespaceSelector`: Pods in the "backend" namespace
  - `podSelector`: That have label "tier=backend"
- `ports`: Only on port 5432/TCP

### Exercise 6: Apply Deny-All Egress Policy

**Goal**: Control outgoing traffic from frontend pods.

```bash
# Create a deny-all egress policy for frontend
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
  namespace: frontend
spec:
  podSelector: {}
  policyTypes:
  - Egress
EOF

# Test - frontend can't reach anything now
kubectl exec -n frontend $FRONTEND_POD -- curl -s --max-time 3 http://api-service.backend:5678
# Hangs and times out (even DNS fails!)

# Why? Because egress is blocked, including DNS queries!
```

**Allow DNS and backend access**:
```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-egress
  namespace: frontend
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Egress
  egress:
  # Allow DNS
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
  # Allow backend access
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: backend
    ports:
    - protocol: TCP
      port: 5678
EOF

# Test - should work now
kubectl exec -n frontend $FRONTEND_POD -- curl -s --max-time 3 http://api-service.backend:5678
# Output: Backend API
```

### Exercise 7: Debug NetworkPolicy Issues

**Goal**: Learn how to troubleshoot blocked traffic.

**Symptom**: Connection timeout when accessing a Service.

**Debugging steps**:

**Step 1: Check if NetworkPolicies exist**:
```bash
# List all NetworkPolicies
kubectl get networkpolicy -A

# Check specific namespace
kubectl get networkpolicy -n backend

# Get policy details
kubectl describe networkpolicy <name> -n <namespace>
```

**Step 2: Verify pod labels match policy selectors**:
```bash
# Check pod labels
kubectl get pods -n backend --show-labels

# Check policy selector
kubectl get networkpolicy -n backend <name> -o yaml | grep -A 5 podSelector
```

**Step 3: Test with a pod NOT affected by policies**:
```bash
# Create a test pod in a different namespace without NetworkPolicies
kubectl create namespace testing
kubectl run test -n testing --image=nicolaka/netshoot --command -- sleep 3600

# Test from this pod
kubectl exec -n testing test -- curl http://api-service.backend:5678

# If this works but your app doesn't, the problem is NetworkPolicy
```

**Step 4: Temporarily disable NetworkPolicy**:
```bash
# Delete the policy to test
kubectl delete networkpolicy <name> -n <namespace>

# Test again
# If it works now, the problem was the NetworkPolicy configuration
```

## Self-Check Questions

### Question 1
You apply a NetworkPolicy to a pod, but traffic is still flowing. What are possible reasons?

**Answer**:
1. **CNI doesn't support NetworkPolicy**: Check if your CNI (kindnet, flannel) supports it. Use Calico, Cilium, or Weave instead.
2. **Label mismatch**: The podSelector doesn't match the pod's labels
3. **No policyTypes**: If you don't specify `policyTypes`, the policy may not be enforced
4. **Multiple policies**: If multiple policies apply, they're additive (OR logic). Another policy might allow the traffic.

### Question 2
What's the difference between these two podSelector configurations?

A: `podSelector: {}`
B: `podSelector: {matchLabels: {app: web}}`

**Answer**:
- **A**: Applies to ALL pods in the namespace (empty selector matches everything)
- **B**: Applies only to pods with label `app=web`

### Question 3
Your app can't resolve DNS after applying an egress NetworkPolicy. Why?

**Answer**: The egress policy blocks ALL outbound traffic, including DNS queries. You must explicitly allow egress to kube-dns on port 53/UDP:

```yaml
egress:
- to:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: kube-system
    podSelector:
      matchLabels:
        k8s-app: kube-dns
  ports:
  - protocol: UDP
    port: 53
```

### Question 4
Can a single NetworkPolicy control both ingress and egress?

**Answer**: Yes! Include both in `policyTypes`:

```yaml
spec:
  policyTypes:
  - Ingress
  - Egress
  ingress:
    # ... ingress rules
  egress:
    # ... egress rules
```

### Question 5
In OpenShift, what's the difference between NetworkPolicy and EgressNetworkPolicy?

**Answer**: 
- **NetworkPolicy**: Standard Kubernetes API, controls pod-to-pod traffic using selectors
- **EgressNetworkPolicy**: OpenShift-specific, controls egress to external IPs/CIDR ranges (outside the cluster)

NetworkPolicy can't block traffic to external IPs by CIDR; EgressNetworkPolicy fills that gap.

## Today I Learned (TIL)

Fill this out at the end of the day:

```
Date: _______________

Key Concepts:
- NetworkPolicy controls: _______________
- Default behavior without policies: _______________
- Deny-all policy means: _______________

Policies I created:
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

Traffic I blocked successfully:
_______________________________________________

Most common mistake:
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
# NetworkPolicy Management
kubectl get networkpolicy -A
kubectl get networkpolicy -n <namespace>
kubectl describe networkpolicy <name> -n <namespace>
kubectl delete networkpolicy <name> -n <namespace>

# Create deny-all ingress policy
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# Create deny-all egress policy
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Egress
EOF

# Test connectivity
kubectl exec -n <namespace> <pod> -- curl -v --max-time 5 http://<target>
kubectl exec -n <namespace> <pod> -- nc -zv <ip> <port>

# Check pod labels
kubectl get pods -n <namespace> --show-labels

# Debugging
kubectl get pods -A -o wide
kubectl describe networkpolicy <name> -n <namespace>
kubectl logs -n kube-system -l k8s-app=calico-node
```

## What's Next

Tomorrow (Day 37), you'll learn about **CNI Deep Dive** - what happens when a pod starts. You'll discover:
- How the CNI plugin is invoked
- How veth pairs are created
- How IP addresses are allocated
- How to trace pod network setup

You've learned how to control traffic with NetworkPolicies. Tomorrow you'll see how the network plumbing actually gets set up!

**Preparation**: Keep your kind cluster with Calico running for tomorrow's exercises.

---

**Pro Tip**: In production, start with a deny-all policy on sensitive namespaces (database, secrets) and gradually add allow rules. It's easier to add allow rules later than to remove overly permissive access. Use labels strategically - they're the key to clean, maintainable NetworkPolicies.
