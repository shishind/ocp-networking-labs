# Day 34: NodePort and Ingress - External Access to Services

## Learning Objectives
By the end of this lab, you will:
- Understand the three Service types: ClusterIP, NodePort, and LoadBalancer
- Create a NodePort Service and access it from outside the cluster
- Deploy an Ingress controller (nginx)
- Create Ingress rules for HTTP routing
- Explain the relationship between Services and Ingress

## Plain English Explanation

**The Problem: ClusterIP Is Internal Only**

So far, you've worked with ClusterIP Services. They're great for pod-to-pod communication **inside** the cluster, but they're invisible to the outside world. Your laptop can't reach a ClusterIP.

**Solution 1: NodePort**

A NodePort Service opens a **port on every node** in the cluster and forwards traffic from that port to the Service.

**How it works**:
1. You create a NodePort Service on port 30080 (example)
2. Kubernetes opens port 30080 on **every node**
3. Traffic to `<any-node-ip>:30080` gets forwarded to the Service
4. The Service load-balances to backend pods (using ClusterIP + iptables)

**Example**:
```
Your laptop:       curl http://192.168.1.10:30080
                          ↓
Node IP:           192.168.1.10:30080
                          ↓
iptables:          DNAT to ClusterIP 10.96.5.10:80
                          ↓
Service:           Load-balance to pod IPs
                          ↓
Pods:              10.244.1.5:8080, 10.244.2.3:8080
```

**Port Range**: NodePorts use ports 30000-32767 by default.

**Solution 2: LoadBalancer**

A LoadBalancer Service creates an external load balancer (in cloud providers like AWS, GCP, Azure). The load balancer gets a public IP and forwards traffic to the NodePorts.

**In kind**: LoadBalancer doesn't work (no cloud provider), but you can use MetalLB for testing.

**Solution 3: Ingress**

NodePort works but has issues:
- You need to remember weird ports (30080, 31234, etc.)
- Wastes ports (each Service needs its own NodePort)
- No HTTP-level routing (can't route based on hostname or path)

**Ingress** solves this by providing **HTTP/HTTPS routing** to multiple Services through a single entry point.

**How Ingress works**:
1. You deploy an **Ingress Controller** (like nginx, Traefik, HAProxy)
2. The Ingress Controller runs as a pod and watches for Ingress resources
3. You create **Ingress** objects that define routing rules
4. The controller configures itself to route traffic based on those rules

**Example**:
```
Your laptop:       curl http://myapp.example.com/api
                          ↓
Ingress Controller: Check Host header and path
                          ↓
Route to:          api-service:80
                          ↓
Service:           Load-balance to pods
```

**In OpenShift**: OpenShift has a built-in Ingress controller called the Router, which works similarly but uses Routes instead of Ingress objects (though it supports Ingress too).

## Hands-On Lab

### Exercise 1: Create a NodePort Service

**Goal**: Expose a Service externally using NodePort.

```bash
# Create a deployment
kubectl create deployment web-nodeport --image=nginx --replicas=2

# Expose it as a NodePort Service
kubectl expose deployment web-nodeport --type=NodePort --port=80 --name=web-nodeport-svc

# Check the Service
kubectl get service web-nodeport-svc

# Example output:
# NAME               TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# web-nodeport-svc   NodePort   10.96.100.50    <none>        80:31234/TCP   5s
#                                                              ^^^^^^^^^^^
#                                                              NodePort is 31234
```

**Decode the PORT(S) column**:
- `80`: The Service port (ClusterIP port)
- `31234`: The NodePort (randomly assigned from 30000-32767)

**View details**:
```bash
kubectl describe service web-nodeport-svc

# Look for:
# Type:                     NodePort
# IP:                       10.96.100.50
# Port:                     <unset>  80/TCP
# TargetPort:               80/TCP
# NodePort:                 <unset>  31234/TCP
# Endpoints:                10.244.1.10:80,10.244.1.11:80
```

### Exercise 2: Access the NodePort from Outside the Cluster

**Goal**: Access the Service from your laptop.

In kind, nodes are Docker containers, so we need to map the port.

**Get the node IP**:
```bash
# kind uses localhost with port mapping
# First, find which port kind mapped for the NodePort

# Get node info
kubectl get nodes -o wide

# In kind, you access via localhost
# But first we need to recreate the cluster with port mapping
```

**For kind, we need to pre-configure port mappings**. Let's do that:

```bash
# Delete the current cluster
kind delete cluster --name learning

# Create a config that maps ports
cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
- role: worker
EOF

# Create the cluster
kind create cluster --name learning --config kind-config.yaml

# Now recreate the deployment and Service with a specific NodePort
kubectl create deployment web-nodeport --image=nginx --replicas=2

kubectl expose deployment web-nodeport --type=NodePort --port=80 --name=web-nodeport-svc

# Patch the Service to use port 30080
kubectl patch service web-nodeport-svc --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/nodePort", "value":30080}]'

# Verify
kubectl get service web-nodeport-svc

# Now access from your laptop
curl http://localhost:30080

# You should see the nginx welcome page!
```

**What just happened**:
1. Your laptop sent a request to `localhost:30080`
2. Docker forwarded it to the kind node container's port 30080
3. iptables on the node routed it to the Service ClusterIP
4. The Service load-balanced to a backend pod
5. The response came back the same way

### Exercise 3: Deploy an Ingress Controller (nginx-ingress)

**Goal**: Install an Ingress controller in the cluster.

```bash
# Apply the official nginx-ingress manifest for kind
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# This creates:
# - Namespace: ingress-nginx
# - ServiceAccount, RBAC roles
# - Deployment: ingress-nginx-controller
# - Service: ingress-nginx-controller (type: NodePort)

# Wait for the controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Check the controller pod
kubectl get pods -n ingress-nginx

# Example output:
# NAME                                        READY   STATUS    RESTARTS   AGE
# ingress-nginx-controller-7d8f8c9d8f-abc12   1/1     Running   0          1m

# Check the Service
kubectl get service -n ingress-nginx ingress-nginx-controller

# Output:
# NAME                       TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)
# ingress-nginx-controller   NodePort   10.96.200.100   <none>        80:XXXXX/TCP,443:XXXXX/TCP
```

The Ingress controller is now ready to route traffic!

### Exercise 4: Create an Ingress Resource

**Goal**: Define HTTP routing rules using an Ingress object.

```bash
# Create a deployment and Service for your app
kubectl create deployment app1 --image=hashicorp/http-echo --replicas=2 -- -text="App 1"
kubectl expose deployment app1 --port=5678 --name=app1-service

# Create another app
kubectl create deployment app2 --image=hashicorp/http-echo --replicas=2 -- -text="App 2"
kubectl expose deployment app2 --port=5678 --name=app2-service

# Create an Ingress resource
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: app1.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1-service
            port:
              number: 5678
  - host: app2.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2-service
            port:
              number: 5678
EOF

# Check the Ingress
kubectl get ingress demo-ingress

# Output:
# NAME           CLASS   HOSTS                   ADDRESS       PORTS   AGE
# demo-ingress   nginx   app1.local,app2.local   172.18.0.2    80      10s
```

### Exercise 5: Access Apps Through Ingress

**Goal**: Route traffic based on HTTP Host header.

```bash
# In kind, the Ingress controller is accessible via localhost:80 and localhost:443
# (if you configured port mappings)

# For kind, let's use port-forward to access the Ingress controller
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80 &

# Give it a second to start
sleep 2

# Test app1
curl -H "Host: app1.local" http://localhost:8080

# Output: App 1

# Test app2
curl -H "Host: app2.local" http://localhost:8080

# Output: App 2

# Same IP and port, different apps based on Host header!

# Kill the port-forward
pkill -f "port-forward"
```

**What happened**:
1. Your curl sent a request with `Host: app1.local`
2. The Ingress controller received it
3. It matched the Host header against Ingress rules
4. Found the rule for `app1.local` → route to `app1-service`
5. Made a request to the app1-service ClusterIP
6. Service routed to an app1 pod

**Path-based routing**:

You can also route based on URL paths:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-based-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /v1
        pathType: Prefix
        backend:
          service:
            name: app1-service
            port:
              number: 5678
      - path: /v2
        pathType: Prefix
        backend:
          service:
            name: app2-service
            port:
              number: 5678
EOF

# Test it
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80 &
sleep 2

curl -H "Host: myapp.local" http://localhost:8080/v1
# Output: App 1

curl -H "Host: myapp.local" http://localhost:8080/v2
# Output: App 2

pkill -f "port-forward"
```

### Exercise 6: Debug Ingress Issues

**Goal**: Troubleshoot common Ingress problems.

**Check Ingress status**:
```bash
kubectl describe ingress demo-ingress

# Look for:
# - Events (errors during creation)
# - Rules (are they correct?)
# - Backend status
```

**Check Ingress controller logs**:
```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Look for:
# - "Configuration changes detected, backend reload required"
# - Any error messages
# - HTTP requests (if logging is enabled)
```

**Common issues**:

**1. Ingress has no ADDRESS**:
```bash
kubectl get ingress

# If ADDRESS is empty after 1-2 minutes, check:
kubectl get pods -n ingress-nginx  # Is the controller running?
kubectl describe ingress <name>    # Any events?
```

**2. 404 Not Found**:
- The Ingress controller is working, but can't find a matching rule
- Check Host header: `curl -v -H "Host: app1.local" ...`
- Check Ingress rules: `kubectl get ingress -o yaml`

**3. 503 Service Temporarily Unavailable**:
- The rule matched, but the backend Service has no endpoints
- Check endpoints: `kubectl get endpoints <service-name>`

**4. Connection Refused**:
- The Ingress controller itself isn't accessible
- Check controller Service: `kubectl get service -n ingress-nginx`
- Check controller pods: `kubectl get pods -n ingress-nginx`

## Self-Check Questions

### Question 1
What's the difference between a NodePort Service and an Ingress?

**Answer**: 
- **NodePort**: Exposes a Service on a specific port (30000-32767) on every node. Works for any TCP/UDP protocol. Each Service needs its own port.
- **Ingress**: HTTP/HTTPS-only routing through a single entry point. Can route multiple Services based on hostnames and paths. Cleaner for web applications.

### Question 2
You create a NodePort on port 31000. Can you access it on ALL nodes, or just the node where the pod is running?

**Answer**: You can access it on **all nodes**. Kubernetes configures iptables on every node to forward traffic from the NodePort to the Service ClusterIP, which then load-balances to pods regardless of which node they're on. This is why it's called NodePort - the port is opened on every node.

### Question 3
Your Ingress works for app1.local but not app2.local. Where would you start debugging?

**Answer**: 
1. Check the Ingress rules: `kubectl get ingress <name> -o yaml` - is there a rule for app2.local?
2. Check the backend Service: `kubectl get service app2-service` - does it exist?
3. Check endpoints: `kubectl get endpoints app2-service` - are there backend pods?
4. Check Ingress controller logs: `kubectl logs -n ingress-nginx <controller-pod>`

### Question 4
Can you have multiple Ingress controllers in the same cluster?

**Answer**: Yes! You can have nginx-ingress, Traefik, HAProxy, etc., all in the same cluster. Use the `ingressClassName` field in the Ingress resource to specify which controller should handle it. This is useful for different teams or different types of traffic.

### Question 5
In OpenShift, what's the difference between an Ingress and a Route?

**Answer**: Routes are OpenShift's original ingress solution (predating Kubernetes Ingress). They're similar but have OpenShift-specific features like edge/passthrough/reencrypt TLS termination. OpenShift 4.x supports both Routes and standard Kubernetes Ingress objects. The OpenShift Router (Ingress controller) handles both.

## Today I Learned (TIL)

Fill this out at the end of the day:

```
Date: _______________

Service Types:
- ClusterIP: _______________
- NodePort: _______________
- LoadBalancer: _______________

NodePort I created:
- Service: _______________
- NodePort number: _______________
- Accessed via: _______________

Ingress rules I created:
- Host: _______________ → Service: _______________
- Host: _______________ → Service: _______________

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
# NodePort Services
kubectl expose deployment <name> --type=NodePort --port=<port>
kubectl patch service <name> --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/nodePort", "value":<port>}]'

# View Service details
kubectl get service <name>
kubectl describe service <name>

# Ingress Controller (nginx)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl get pods -n ingress-nginx
kubectl get service -n ingress-nginx

# Ingress Resources
kubectl get ingress
kubectl describe ingress <name>
kubectl get ingress <name> -o yaml

# Create Ingress
kubectl create ingress <name> --rule="host/path=service:port"

# Debug Ingress
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
kubectl describe ingress <name>
kubectl get endpoints <service-name>

# Port forwarding (for testing)
kubectl port-forward service/<name> <local-port>:<service-port>
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80

# Test with Host header
curl -H "Host: example.com" http://localhost:8080
```

## What's Next

Tomorrow (Day 35), you have a **weekend scenario**: "Service returns 'connection refused'". You'll use everything you've learned this week to debug a realistic problem:
- Check Endpoints
- Inspect iptables rules
- Analyze pod logs
- Verify NetworkPolicy (preview of next week)

This is your chance to put it all together!

**Preparation**: Review the debugging commands from this week. Tomorrow's scenario will test your understanding of Services, DNS, and Endpoints.

---

**Pro Tip**: For production, use an Ingress controller with TLS termination and certificate management (like cert-manager). Never expose NodePorts directly to the internet - use a LoadBalancer or Ingress with proper security controls.
