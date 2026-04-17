# Day 33: Endpoints - How Services Know Which Pods to Route To

## Learning Objectives
By the end of this lab, you will:
- Understand what Kubernetes Endpoints are and why they exist
- View and interpret Endpoint objects
- Watch Endpoints update when pods change
- Troubleshoot "Service has no endpoints" errors
- Explain the relationship between Services, Endpoints, and Pods

## Plain English Explanation

**The Missing Link: Services → Pods**

You've learned:
- **Services** provide stable IPs and DNS names
- **Pods** are ephemeral and get new IPs when they restart

But how does a Service know **which pods** to send traffic to? When you create a Service with selector `app=web`, Kubernetes needs to:
1. Find all pods with label `app=web`
2. Extract their IP addresses
3. Tell kube-proxy "these are the IPs to DNAT to"

**Enter: Endpoints**

An **Endpoint object** is the list of IP addresses backing a Service. It's automatically created and maintained by Kubernetes.

**The Flow**:
```
1. You create: Deployment with label app=web
2. Pods start:  pod-1 (10.244.1.2), pod-2 (10.244.1.3)
3. You create: Service with selector app=web
4. K8s creates: Endpoint object with [10.244.1.2:80, 10.244.1.3:80]
5. kube-proxy:  Programs iptables to DNAT to those IPs
```

**Why a Separate Object?**

Endpoints are separate from Services because:
- Services are **configuration** (what you want)
- Endpoints are **state** (what currently exists)
- Endpoints change frequently as pods come and go
- You can manually create Endpoints for external services (outside the cluster)

**The Endpoint Controller**

A component called the **Endpoint Controller** constantly watches:
- Services and their selectors
- Pods and their labels
- Pod readiness status

It updates Endpoint objects automatically when pods are added, removed, or become unhealthy.

**In OpenShift**: Endpoints work identically. OpenShift's routing layer relies on Endpoints to know which pods to route traffic to.

## Hands-On Lab

### Exercise 1: View Endpoints for a Service

**Goal**: See the Endpoint object backing a Service.

```bash
# Make sure you have a Service with backend pods
kubectl get service web-service

# If not, create it:
# kubectl create deployment web --image=nginx --replicas=3
# kubectl expose deployment web --port=80 --name=web-service

# View the Endpoints
kubectl get endpoints web-service

# Example output:
# NAME          ENDPOINTS                                      AGE
# web-service   10.244.0.5:80,10.244.1.2:80,10.244.1.3:80      5m
```

**Get detailed information**:
```bash
kubectl describe endpoints web-service

# Output shows:
# Name:         web-service
# Namespace:    default
# Labels:       app=web
# Annotations:  endpoints.kubernetes.io/last-change-trigger-time: ...
# Subsets:
#   Addresses:          10.244.0.5,10.244.1.2,10.244.1.3
#   NotReadyAddresses:  <none>
#   Ports:
#     Name     Port  Protocol
#     ----     ----  --------
#     <unset>  80    TCP
```

**Key fields**:
- **Addresses**: Ready pod IPs
- **NotReadyAddresses**: Pods that exist but aren't ready yet
- **Ports**: The port on each pod

### Exercise 2: Match Endpoints to Pods

**Goal**: Verify that Endpoint IPs match pod IPs.

```bash
# Get pod IPs
kubectl get pods -l app=web -o wide

# Example output:
# NAME                   READY   STATUS    IP            NODE
# web-7d8f8c9d8f-abc12   1/1     Running   10.244.1.2    learning-worker
# web-7d8f8c9d8f-def34   1/1     Running   10.244.0.5    learning-control-plane
# web-7d8f8c9d8f-ghi56   1/1     Running   10.244.1.3    learning-worker

# Get Endpoints
kubectl get endpoints web-service -o yaml

# Look at the "addresses" section:
# addresses:
# - ip: 10.244.0.5
#   nodeName: learning-control-plane
#   targetRef:
#     kind: Pod
#     name: web-7d8f8c9d8f-def34
#     namespace: default
# - ip: 10.244.1.2
#   ...
```

**Notice**: Each Endpoint address includes:
- The pod IP
- The node it's on
- A reference to the actual pod object

Perfect match!

### Exercise 3: Watch Endpoints Update When Pods Are Deleted

**Goal**: See real-time Endpoint updates.

Open **two terminal windows**.

**Terminal 1 - Watch Endpoints**:
```bash
kubectl get endpoints web-service --watch

# You'll see the current state, then it waits for changes
```

**Terminal 2 - Delete a pod**:
```bash
# Delete one of the backend pods
POD_TO_DELETE=$(kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.name}')
echo "Deleting: $POD_TO_DELETE"

kubectl delete pod $POD_TO_DELETE
```

**What you see in Terminal 1**:

Almost immediately, the Endpoints update:
```
web-service   10.244.0.5:80,10.244.1.2:80,10.244.1.3:80   5m   <- Initial state
web-service   10.244.0.5:80,10.244.1.3:80                  5m   <- Pod removed
web-service   10.244.0.5:80,10.244.1.3:80,10.244.1.4:80   5m   <- New pod added
```

The Deployment controller creates a replacement pod, and once it's ready, it appears in the Endpoints.

### Exercise 4: Simulate an Unhealthy Pod

**Goal**: See how unhealthy pods are removed from Endpoints.

```bash
# Create a deployment with a readiness probe
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-with-probe
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-probe
  template:
    metadata:
      labels:
        app: web-probe
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /healthy
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
EOF

# Create a Service
kubectl expose deployment web-with-probe --port=80 --name=web-probe-service

# Check pods - they'll be Running but NOT Ready (0/1)
kubectl get pods -l app=web-probe

# Output:
# NAME                              READY   STATUS    RESTARTS   AGE
# web-with-probe-7d8f8c9d8f-abc12   0/1     Running   0          10s
# web-with-probe-7d8f8c9d8f-def34   0/1     Running   0          10s

# Check Endpoints - should be empty or in NotReadyAddresses
kubectl get endpoints web-probe-service

# Output:
# NAME                ENDPOINTS   AGE
# web-probe-service   <none>      15s

# Or with describe:
kubectl describe endpoints web-probe-service

# Shows:
# Subsets:
#   Addresses:          <none>
#   NotReadyAddresses:  10.244.1.5,10.244.1.6
```

**The pods exist but aren't in the Endpoints because they're not ready!**

Now make them ready:
```bash
# Create the /healthy file in each pod
for POD in $(kubectl get pod -l app=web-probe -o name); do
    kubectl exec $POD -- sh -c 'mkdir -p /usr/share/nginx/html && echo OK > /usr/share/nginx/html/healthy'
done

# Wait a few seconds
sleep 5

# Check pods - now they're Ready
kubectl get pods -l app=web-probe

# Output:
# NAME                              READY   STATUS    RESTARTS   AGE
# web-with-probe-7d8f8c9d8f-abc12   1/1     Running   0          1m
# web-with-probe-7d8f8c9d8f-def34   1/1     Running   0          1m

# Check Endpoints - now they're populated
kubectl get endpoints web-probe-service

# Output:
# NAME                ENDPOINTS                     AGE
# web-probe-service   10.244.1.5:80,10.244.1.6:80   1m
```

**The lesson**: Only **ready** pods appear in Endpoints!

### Exercise 5: Debug "Service Has No Endpoints"

**Goal**: Systematically troubleshoot a common problem.

```bash
# Create a broken Service with a typo in the selector
kubectl create deployment broken-app --image=nginx --replicas=2

# The pods have label: app=broken-app
# But create a Service with the wrong selector:
kubectl create service clusterip broken-service --tcp=80:80
kubectl set selector service broken-service app=wrong-label

# Check the Service
kubectl get service broken-service

# Looks fine - has a ClusterIP

# Try to access it
kubectl run test --image=nicolaka/netshoot --rm -it --restart=Never -- curl -m 5 http://broken-service

# FAILS with timeout or connection refused

# Debug: Check Endpoints
kubectl get endpoints broken-service

# Output:
# NAME             ENDPOINTS   AGE
# broken-service   <none>      30s

# No endpoints! The Service can't find pods.
```

**Troubleshooting steps**:

**Step 1: Check the Service selector**:
```bash
kubectl describe service broken-service | grep Selector

# Output: Selector:   app=wrong-label
```

**Step 2: Check what labels the pods actually have**:
```bash
kubectl get pods -l app=broken-app --show-labels

# Output shows: app=broken-app
```

**Step 3: Fix the selector**:
```bash
kubectl set selector service broken-service app=broken-app

# Check Endpoints again
kubectl get endpoints broken-service

# Output:
# NAME             ENDPOINTS                     AGE
# broken-service   10.244.1.7:80,10.244.1.8:80   2m

# Now it works!
```

**Clean up**:
```bash
kubectl delete service broken-service
kubectl delete deployment broken-app
```

### Exercise 6: Manual Endpoints for External Services

**Goal**: Create a Service that points to an external IP (outside the cluster).

```bash
# Create a Service WITHOUT a selector (manual Endpoints)
kubectl create service clusterip external-db --tcp=5432:5432

# Remove the selector (if any)
kubectl patch service external-db -p '{"spec":{"selector":null}}'

# Check - no Endpoints are created automatically
kubectl get endpoints external-db

# Output:
# NAME          ENDPOINTS   AGE
# external-db   <none>      5s

# Manually create Endpoints pointing to an external IP
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Endpoints
metadata:
  name: external-db
  namespace: default
subsets:
- addresses:
  - ip: 192.168.1.100
  ports:
  - port: 5432
    protocol: TCP
EOF

# Check Endpoints
kubectl get endpoints external-db

# Output:
# NAME          ENDPOINTS            AGE
# external-db   192.168.1.100:5432   10s

# Now pods can use the Service name to reach the external database
kubectl run test --image=nicolaka/netshoot --rm -it --restart=Never -- nslookup external-db

# DNS resolves to the Service ClusterIP
# Traffic to that IP gets DNATed to 192.168.1.100:5432
```

**Use case**: Migrating from external databases to in-cluster databases. Apps keep using the same Service name.

## Self-Check Questions

### Question 1
You have a Service and 5 pods with matching labels, but only 3 pods appear in the Endpoints. Why?

**Answer**: The missing 2 pods are likely not ready. Check with `kubectl describe endpoints <service>` and look at the NotReadyAddresses field. Pods only appear in the Addresses list (and receive traffic) when their readiness probe passes.

### Question 2
You delete a pod. How long does it take for the Endpoints to update?

**Answer**: Nearly instantly (within 1-2 seconds). The Endpoint Controller watches for pod deletions and immediately removes the pod's IP from the Endpoints. kube-proxy then updates iptables rules within seconds. However, existing connections to the deleted pod may fail if the pod terminates before they complete.

### Question 3
Can you have an Endpoint without a Service?

**Answer**: Technically yes, you can create a standalone Endpoint object, but it's useless without a corresponding Service. The Service provides the ClusterIP and DNS name; the Endpoint provides the backend IPs. They work together.

### Question 4
What happens if you scale a deployment to 0 replicas?

**Answer**: The Endpoints object will have no addresses (Endpoints: `<none>`). Any attempt to access the Service will fail because there are no backend pods to route traffic to. The Service and Endpoints objects still exist, but they're effectively non-functional.

### Question 5
Why do some tutorials mention "EndpointSlices" instead of "Endpoints"?

**Answer**: EndpointSlices are a newer API (v1.21+) that replace Endpoints for better scalability. For Services with hundreds or thousands of pods, a single Endpoints object becomes huge. EndpointSlices split the data into smaller chunks. However, the concept is the same - tracking which IPs back a Service.

## Today I Learned (TIL)

Fill this out at the end of the day:

```
Date: _______________

Key Concepts:
- Endpoints are: _______________
- The component that manages Endpoints: _______________
- Ready vs NotReady addresses: _______________

Services I inspected today:
- Service: _______________ had ___ endpoints
- Deleted a pod from: _______________
- Observed endpoint update: _______________

Common debugging command:
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
# View Endpoints
kubectl get endpoints
kubectl get endpoints <service-name>
kubectl describe endpoints <service-name>

# Detailed Endpoint info
kubectl get endpoints <service-name> -o yaml

# Watch for changes
kubectl get endpoints <service-name> --watch

# Match Endpoints to Pods
kubectl get pods -l <label-selector> -o wide
kubectl get endpoints <service-name> -o wide

# Check Service selector
kubectl describe service <name> | grep Selector
kubectl get service <name> -o jsonpath='{.spec.selector}'

# Fix Service selector
kubectl set selector service <name> <new-label>=<value>

# Debug "no endpoints"
# 1. Check selector
kubectl get service <name> -o yaml | grep -A 5 selector

# 2. Check pod labels
kubectl get pods --show-labels

# 3. Check pod readiness
kubectl get pods
kubectl describe pod <name>

# Manual Endpoints
kubectl create service clusterip <name> --tcp=<port>:<port>
kubectl patch service <name> -p '{"spec":{"selector":null}}'
# Then create Endpoints object manually

# EndpointSlices (newer API)
kubectl get endpointslices
```

## What's Next

Tomorrow (Day 34), you'll learn about **NodePort and Ingress** - exposing services externally. You'll discover:
- How NodePort lets you access Services from outside the cluster
- The difference between ClusterIP, NodePort, and LoadBalancer
- How to deploy an Ingress controller
- The role of Ingress in HTTP/HTTPS routing

So far you've learned about internal cluster networking. Tomorrow you'll open the door to external traffic!

**Preparation**: Your kind cluster should be running. We'll expose services to your laptop's network.

---

**Pro Tip**: When debugging Service issues, always check Endpoints first with `kubectl get endpoints <service>`. If Endpoints are empty:
1. Check the Service selector
2. Check pod labels
3. Check pod readiness
This solves 90% of Service problems!
