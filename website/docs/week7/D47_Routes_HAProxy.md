# Day 47: Routes and HAProxy

**Week 7, Day 47: Phase 4 - OpenShift Networking Deep Dive**

---

## Learning Objectives

By the end of this lab, you will be able to:

1. Understand OpenShift Routes and how they differ from Kubernetes Ingress
2. Create and configure edge, passthrough, and re-encrypt route types
3. Inspect HAProxy router configuration and routing decisions
4. Test TLS termination at different layers
5. Troubleshoot route connectivity issues
6. Correlate routes with the underlying OVN/OVS infrastructure

---

## Plain English Explanation

### What Are Routes?

You've spent the last four days learning how packets flow at the network level (IP, TCP, tunnels, NAT). Today we're moving up the stack to the **application level** - specifically, how HTTP and HTTPS traffic gets routed to the right pod.

**The Problem Routes Solve:**

Imagine you have:
- App A running in pods 10.128.0.5, 10.128.0.6
- App B running in pods 10.128.1.7, 10.128.1.8
- External users who want to access: app-a.company.com and app-b.company.com

How do you:
1. Get external traffic into the cluster?
2. Route requests for app-a.company.com to App A pods?
3. Route requests for app-b.company.com to App B pods?
4. Handle TLS/SSL termination?
5. Load balance across multiple pods?

**Routes (and the HAProxy router) solve this!**

### Routes vs Services

**Service (Week 5):**
- Layer 4 (TCP/UDP) load balancing
- Internal to cluster (or via NodePort/LoadBalancer)
- Works with IP addresses and port numbers
- Example: "Any traffic to 172.30.0.10:8080 goes to one of these pods"

**Route:**
- Layer 7 (HTTP/HTTPS) routing
- External access via hostname
- Works with domain names and URL paths
- Example: "Requests for app-a.company.com go to Service app-a, which routes to pods"
- Built on top of Services!

**The Stack:**
```
External User
    ↓
DNS: app-a.company.com → Router Pod IP
    ↓
HAProxy Router Pod (examines HTTP Host header)
    ↓
Service app-a (load balances)
    ↓
App Pods (10.128.0.5, 10.128.0.6)
```

### HAProxy Router

**HAProxy** is a high-performance load balancer and reverse proxy. In OpenShift, router pods run HAProxy to handle all incoming HTTP/HTTPS traffic.

**Router Pods:**
- Run in the `openshift-ingress` namespace
- Usually deployed as a DaemonSet on specific nodes (often infra nodes)
- Watch for Route objects in the Kubernetes API
- Automatically reconfigure HAProxy when Routes change
- Handle TLS termination and certificate management

**How It Works:**
1. You create a Route: `oc expose service app-a --hostname=app-a.company.com`
2. Router pod sees the new Route
3. Router updates HAProxy configuration
4. HAProxy now forwards requests for `app-a.company.com` to Service `app-a`
5. Service load balances to pods (using kube-proxy or OVN load balancer)

### The Three Route Types

**1. Edge Route (Most Common)**
```
User → [HTTPS] → Router (TLS termination) → [HTTP] → Pod
```
- TLS terminates at the router
- Router decrypts traffic, inspects it, forwards plain HTTP to pods
- Pod doesn't need TLS certificates
- Router can inspect/modify HTTP traffic (headers, paths, etc.)

**2. Passthrough Route**
```
User → [HTTPS] → Router (just TCP proxy) → [HTTPS] → Pod
```
- TLS terminates at the pod
- Router just forwards encrypted TCP traffic (can't inspect content)
- Pod needs TLS certificates
- More secure (end-to-end encryption) but less flexible

**3. Re-encrypt Route**
```
User → [HTTPS] → Router (TLS termination + re-encryption) → [HTTPS] → Pod
```
- TLS terminates at router, then re-encrypts before sending to pod
- Router can inspect traffic AND maintain encryption to pod
- Both router and pod need certificates
- Best of both worlds, but more complex

**Connection to Previous Learning:**

**Week 5 (Services):**
- Routes build on Services
- Route → Service → Pods
- Service provides the load balancing backend

**Day 46 (Traffic Flows Pattern 4: External-to-Pod):**
- Yesterday you learned network-level ingress
- Today you're learning application-level routing on top of that
- Router pods receive traffic via NodePort or HostNetwork
- Then use Services to reach actual pods

---

## Hands-On Lab

### Prerequisites

- Access to OpenShift cluster with route creation permissions
- Understanding of Services (Week 5)
- Basic knowledge of TLS/SSL certificates

---

### Exercise 1: Explore the Router Infrastructure

**Objective**: Understand the existing router deployment in your cluster.

```bash
# Find router pods
oc get pods -n openshift-ingress

# Get detailed info about router deployment
oc get deployment -n openshift-ingress

# Check which nodes run router pods
oc get pods -n openshift-ingress -o wide

# Describe a router pod
ROUTER_POD=$(oc get pods -n openshift-ingress -l app=router -o jsonpath='{.items[0].metadata.name}')
oc describe pod -n openshift-ingress $ROUTER_POD

# Check router service (how external traffic reaches routers)
oc get svc -n openshift-ingress

# Check IngressController configuration
oc get ingresscontroller -n openshift-ingress-operator default -o yaml

# View router logs
oc logs -n openshift-ingress $ROUTER_POD | tail -50
```

**Key Questions to Answer:**
- How many router pods are running?
- What nodes are they on?
- How do they receive external traffic (NodePort, HostNetwork, LoadBalancer)?
- What ports are they listening on?

**Expected Findings:**
- Router pods use HostNetwork (listen directly on node's IP)
- They listen on ports 80 (HTTP) and 443 (HTTPS)
- Usually run on designated infrastructure or worker nodes

---

### Exercise 2: Create and Test an Edge Route

**Objective**: Deploy an application and expose it with an edge route.

```bash
# Create a test namespace
oc create namespace route-test

# Deploy a simple application
oc create deployment nginx -n route-test --image=nginxinc/nginx-unprivileged:latest --port=8080

# Wait for deployment
oc rollout status deployment/nginx -n route-test

# Verify pod is running
oc get pods -n route-test

# Create a service
oc expose deployment nginx -n route-test --port=8080 --target-port=8080

# Verify service
oc get svc -n route-test nginx

# Create an edge route (TLS termination at router)
oc create route edge nginx-edge -n route-test \
  --service=nginx \
  --hostname=nginx-edge.apps.<cluster-domain>

# If you don't know cluster domain, let OpenShift generate it:
oc expose service nginx -n route-test --name=nginx-edge

# Get route details
oc get route -n route-test nginx-edge

ROUTE_HOST=$(oc get route -n route-test nginx-edge -o jsonpath='{.spec.host}')
echo "Route hostname: $ROUTE_HOST"

# Test the route
curl -I http://$ROUTE_HOST
curl -I https://$ROUTE_HOST

# Test with verbose TLS info
curl -v https://$ROUTE_HOST 2>&1 | grep -E "(SSL|TLS|Server certificate)"

# Check route configuration
oc describe route -n route-test nginx-edge

# Check what certificate is being used
oc get route -n route-test nginx-edge -o yaml | grep -A5 tls
```

**Understanding the Output:**

```yaml
# Route YAML snippet
spec:
  host: nginx-edge.apps.cluster.example.com
  to:
    kind: Service
    name: nginx
  port:
    targetPort: 8080
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
```

**Key Fields:**
- `host`: The hostname for accessing this route
- `to`: The Service to route traffic to
- `tls.termination: edge`: TLS terminates at router
- `insecureEdgeTerminationPolicy: Redirect`: HTTP redirects to HTTPS

---

### Exercise 3: Create and Test a Passthrough Route

**Objective**: Create a route where TLS terminates at the pod, not the router.

```bash
# Deploy an application that handles TLS itself
# Using a simple TLS-enabled echo server
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tls-app
  namespace: route-test
  labels:
    app: tls-app
spec:
  containers:
  - name: tls-server
    image: registry.access.redhat.com/ubi9/ubi-minimal:latest
    command: ["/bin/sh"]
    args:
    - -c
    - |
      # Generate self-signed cert
      openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout /tmp/server.key -out /tmp/server.crt \
        -days 365 -subj "/CN=tls-app"
      # Start simple HTTPS server (using Python for demo)
      python3 -c "
      import http.server, ssl
      server_address = ('0.0.0.0', 8443)
      httpd = http.server.HTTPServer(server_address, http.server.SimpleHTTPRequestHandler)
      httpd.socket = ssl.wrap_socket(httpd.socket,
                                     server_side=True,
                                     certfile='/tmp/server.crt',
                                     keyfile='/tmp/server.key',
                                     ssl_version=ssl.PROTOCOL_TLS)
      print('Serving on https://0.0.0.0:8443')
      httpd.serve_forever()
      "
    ports:
    - containerPort: 8443
      protocol: TCP
EOF

# Wait for pod
oc wait --for=condition=Ready pod/tls-app -n route-test --timeout=60s

# Create service
oc expose pod tls-app -n route-test --port=8443 --target-port=8443

# Create passthrough route
oc create route passthrough tls-app-passthrough -n route-test \
  --service=tls-app \
  --port=8443

# Get route hostname
PASSTHROUGH_HOST=$(oc get route -n route-test tls-app-passthrough -o jsonpath='{.spec.host}')
echo "Passthrough route: $PASSTHROUGH_HOST"

# Test (use -k to ignore self-signed cert)
curl -k -v https://$PASSTHROUGH_HOST 2>&1 | grep -E "(SSL|TLS|certificate|CN=)"

# Compare: With edge route, you'd see router's certificate
# With passthrough, you see the pod's certificate (CN=tls-app)

# Inspect route configuration
oc get route -n route-test tls-app-passthrough -o yaml
```

**Key Difference from Edge:**

```yaml
tls:
  termination: passthrough
  # No insecureEdgeTerminationPolicy - passthrough is HTTPS only
```

**Verification:**
- Certificate seen by curl should be the pod's certificate (CN=tls-app)
- Router is NOT decrypting traffic, just forwarding TCP stream

---

### Exercise 4: Create a Re-encrypt Route

**Objective**: Create a route with TLS termination at router and re-encryption to pod.

```bash
# For re-encrypt, we need:
# 1. Certificate for the route (router uses this)
# 2. Certificate for the pod (pod uses this)
# 3. CA certificate (router validates pod's cert)

# We'll use the tls-app pod from Exercise 3

# Get the pod's certificate (to use as destination CA)
oc exec -n route-test tls-app -- cat /tmp/server.crt > /tmp/pod-ca.crt

# Create re-encrypt route
oc create route reencrypt tls-app-reencrypt -n route-test \
  --service=tls-app \
  --port=8443 \
  --dest-ca-cert=/tmp/pod-ca.crt

# Get route hostname
REENCRYPT_HOST=$(oc get route -n route-test tls-app-reencrypt -o jsonpath='{.spec.host}')
echo "Re-encrypt route: $REENCRYPT_HOST"

# Test
curl -k https://$REENCRYPT_HOST

# Inspect route configuration
oc get route -n route-test tls-app-reencrypt -o yaml | grep -A10 tls

# View the complete TLS configuration
oc get route -n route-test tls-app-reencrypt -o jsonpath='{.spec.tls}' | jq
```

**Re-encrypt Route Configuration:**

```yaml
tls:
  termination: reencrypt
  destinationCACertificate: |
    -----BEGIN CERTIFICATE-----
    [Pod's CA certificate]
    -----END CERTIFICATE-----
  insecureEdgeTerminationPolicy: Redirect
```

**The Flow:**
1. User connects to router with TLS (router's certificate)
2. Router decrypts, inspects HTTP
3. Router re-encrypts using pod's certificate
4. Pod receives encrypted traffic, decrypts with its own key

---

### Exercise 5: Inspect HAProxy Configuration

**Objective**: Look inside the router pod to see how HAProxy is configured.

```bash
# Access router pod
ROUTER_POD=$(oc get pods -n openshift-ingress -l app=router -o jsonpath='{.items[0].metadata.name}')

# View HAProxy configuration
oc exec -n openshift-ingress $ROUTER_POD -- cat /var/lib/haproxy/conf/haproxy.config | less

# Find configuration for your route
oc exec -n openshift-ingress $ROUTER_POD -- \
  grep -A20 "nginx-edge" /var/lib/haproxy/conf/haproxy.config

# Check HAProxy stats
oc exec -n openshift-ingress $ROUTER_POD -- \
  cat /var/lib/haproxy/conf/haproxy.config | grep "stats socket"

# Access HAProxy stats (if enabled)
# Usually available at https://<router>:1936/stats

# Check active backends
oc exec -n openshift-ingress $ROUTER_POD -- \
  grep "backend be_" /var/lib/haproxy/conf/haproxy.config | head -20

# Search for specific route backend
ROUTE_HOST=$(oc get route -n route-test nginx-edge -o jsonpath='{.spec.host}')
oc exec -n openshift-ingress $ROUTER_POD -- \
  grep -B5 -A10 "$ROUTE_HOST" /var/lib/haproxy/conf/haproxy.config
```

**Sample HAProxy Configuration:**

```
# Frontend for HTTPS
frontend fe_sni
  bind :443
  tcp-request inspect-delay 5s
  tcp-request content accept if { req_ssl_hello_type 1 }
  
  # Use SNI to route to correct backend
  use_backend be_secure:route-test:nginx-edge if { req_ssl_sni -i nginx-edge.apps.cluster.com }

# Backend for edge route
backend be_secure:route-test:nginx-edge
  mode http
  balance leastconn
  
  # Route configuration
  server pod:10.128.0.5:8080 10.128.0.5:8080 check inter 5s
  server pod:10.128.0.6:8080 10.128.0.6:8080 check inter 5s
```

**Key Observations:**
- Each Route creates a backend in HAProxy
- SNI (Server Name Indication) used to route HTTPS requests
- Backend lists all pod IPs from the Service endpoints
- Health checks configured for each backend server

---

### Exercise 6: Test and Troubleshoot Route Issues

**Objective**: Practice diagnosing common route problems.

```bash
# Scenario 1: Route created but not working

# Check if route exists
oc get route -n route-test nginx-edge

# Check route status and conditions
oc describe route -n route-test nginx-edge

# Verify service exists and has endpoints
oc get svc -n route-test nginx
oc get endpoints -n route-test nginx

# Check router pod logs for errors
ROUTER_POD=$(oc get pods -n openshift-ingress -l app=router -o jsonpath='{.items[0].metadata.name}')
oc logs -n openshift-ingress $ROUTER_POD | grep -i error

# Verify HAProxy loaded the route
oc exec -n openshift-ingress $ROUTER_POD -- \
  grep "nginx-edge" /var/lib/haproxy/conf/haproxy.config

# Test from within cluster
oc run test-curl --image=curlimages/curl:latest --rm -it --restart=Never -- \
  curl -I http://nginx.route-test.svc.cluster.local:8080

# Scenario 2: TLS certificate issues

# Check certificate in route
oc get route -n route-test nginx-edge -o yaml | grep -A20 tls

# Test certificate from external client
ROUTE_HOST=$(oc get route -n route-test nginx-edge -o jsonpath='{.spec.host}')
openssl s_client -connect $ROUTE_HOST:443 -servername $ROUTE_HOST </dev/null 2>/dev/null | \
  openssl x509 -noout -text | grep -E "(Subject:|Issuer:|DNS:)"

# Scenario 3: Service endpoints not updating

# Force service endpoint refresh
oc delete pod -n route-test -l app=nginx

# Watch endpoints
oc get endpoints -n route-test nginx -w

# Check HAProxy backend updated
sleep 10
oc exec -n openshift-ingress $ROUTER_POD -- \
  grep -A10 "nginx-edge" /var/lib/haproxy/conf/haproxy.config | grep "server pod"

# Scenario 4: Route hostname conflicts

# Create conflicting route
oc create route edge nginx-conflict -n route-test \
  --service=nginx \
  --hostname=$ROUTE_HOST || echo "Expected to fail - hostname already used"

# Check route admission status
oc get route -n route-test -o json | jq '.items[] | {name: .metadata.name, host: .spec.host, admitted: .status.ingress[0].conditions}'
```

**Troubleshooting Checklist:**

```bash
# Complete route troubleshooting workflow

ROUTE_NAME="nginx-edge"
NAMESPACE="route-test"

echo "=== 1. Route Configuration ==="
oc get route -n $NAMESPACE $ROUTE_NAME
oc describe route -n $NAMESPACE $ROUTE_NAME

echo "=== 2. Service and Endpoints ==="
SERVICE=$(oc get route -n $NAMESPACE $ROUTE_NAME -o jsonpath='{.spec.to.name}')
oc get svc -n $NAMESPACE $SERVICE
oc get endpoints -n $NAMESPACE $SERVICE

echo "=== 3. Pods ==="
oc get pods -n $NAMESPACE -l app=nginx

echo "=== 4. Router Pod ==="
oc get pods -n openshift-ingress

echo "=== 5. HAProxy Configuration ==="
ROUTER_POD=$(oc get pods -n openshift-ingress -l app=router -o jsonpath='{.items[0].metadata.name}')
oc exec -n openshift-ingress $ROUTER_POD -- \
  grep -c "$ROUTE_NAME" /var/lib/haproxy/conf/haproxy.config
echo "Route found in HAProxy config"

echo "=== 6. Connectivity Test ==="
ROUTE_HOST=$(oc get route -n $NAMESPACE $ROUTE_NAME -o jsonpath='{.spec.host}')
curl -I -s http://$ROUTE_HOST | head -1
```

---

### Exercise 7: Connect Routes to OVN/OVS Infrastructure

**Objective**: Trace how route traffic flows through the network stack you learned earlier this week.

```bash
# Find which node a router pod is on
ROUTER_POD=$(oc get pods -n openshift-ingress -l app=router -o jsonpath='{.items[0].metadata.name}')
ROUTER_NODE=$(oc get pod -n openshift-ingress $ROUTER_POD -o jsonpath='{.spec.nodeName}')
ROUTER_POD_IP=$(oc get pod -n openshift-ingress $ROUTER_POD -o jsonpath='{.status.podIP}')

echo "Router pod: $ROUTER_POD"
echo "Node: $ROUTER_NODE"
echo "Pod IP: $ROUTER_POD_IP"

# Router typically uses host network, check
oc get pod -n openshift-ingress $ROUTER_POD -o jsonpath='{.spec.hostNetwork}'

# If host network, router listens on node's IP
NODE_IP=$(oc get node $ROUTER_NODE -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
echo "Node IP (router listening here): $NODE_IP"

# Test external → router → service → pod flow
ROUTE_HOST=$(oc get route -n route-test nginx-edge -o jsonpath='{.spec.host}')
APP_SVC_IP=$(oc get svc -n route-test nginx -o jsonpath='{.spec.clusterIP}')
APP_POD_IP=$(oc get pod -n route-test -l app=nginx -o jsonpath='{.items[0].status.podIP}')

echo "=== Traffic Flow ==="
echo "1. External request to: $ROUTE_HOST (DNS resolves to $NODE_IP)"
echo "2. Router pod receives on: $NODE_IP:443"
echo "3. Router forwards to service: $APP_SVC_IP:8080"
echo "4. Service load balances to pod: $APP_POD_IP:8080"

# Trace this on the node (combining Day 43-46 knowledge!)
oc debug node/$ROUTER_NODE
chroot /host

# If router uses host network, check listening ports on node
ss -tlnp | grep ":443"
ss -tlnp | grep ":80"

# Check connection when accessing route
# (In another terminal, run: curl https://$ROUTE_HOST)
conntrack -L | grep $APP_POD_IP

# Check OVS flows for app pod traffic
APP_POD_IP="<pod-ip-from-above>"
VETH=$(ip addr | grep $APP_POD_IP -B2 | grep -o "veth[^:@]*" | head -1)
OFPORT=$(ovs-vsctl get interface $VETH ofport)
ovs-ofctl dump-flows br-int | grep "output:$OFPORT"

exit
exit

# The complete path:
# External → Node IP:443 → HAProxy (router pod) → Service IP → OVN/OVS → Pod
```

**Understanding the Integration:**

```
Layer 7 (Application):
  HAProxy reads HTTP Host header: nginx-edge.apps.cluster.com
  Routes to Service: nginx in namespace route-test

Layer 4 (Transport):
  Service IP: 172.30.123.45:8080
  Load balances to pod IPs: 10.128.0.5:8080

Layer 3-4 (Network - from Day 46):
  OVN/OVS flows route to pod
  If pod on same node: direct via br-int
  If pod on different node: tunnel via Geneve

Layer 2 (Data Link - from Day 43):
  veth pair delivers to pod network namespace
```

---

## Self-Check Questions

### Questions

1. **What is the primary difference between an OpenShift Route and a Kubernetes Ingress?**

2. **Explain the difference between edge, passthrough, and re-encrypt routes in terms of where TLS terminates.**

3. **Why does the router pod need access to the Service, not directly to pod IPs?**

4. **How does HAProxy determine which backend to use for an incoming HTTPS request?**

5. **If a Route is created but curl returns "503 Service Unavailable", what are the most likely causes?**

6. **What is the advantage of passthrough routes over edge routes? What is the disadvantage?**

7. **How do Routes integrate with the OVN/OVS networking you learned earlier this week?**

---

### Answers

1. **Route vs Ingress:**
   - **OpenShift Route**: Native OpenShift resource. Predates Kubernetes Ingress. Automatically implemented by HAProxy router pods. Simpler to use for basic cases. Supports edge/passthrough/re-encrypt TLS. Automatic certificate generation possible.
   - **Kubernetes Ingress**: Standard Kubernetes resource. Requires an Ingress Controller to be installed. More portable across Kubernetes distributions. OpenShift supports Ingress via the ingress-to-route conversion.
   - **In OpenShift**: Routes are first-class, Ingress is converted to Routes internally. Most users prefer Routes for OpenShift-specific features.

2. **TLS termination in three route types:**
   - **Edge**: TLS terminates at the **router**. Router decrypts, forwards plain HTTP to pod. Pod doesn't handle TLS. User↔Router: encrypted, Router↔Pod: plain HTTP.
   - **Passthrough**: TLS terminates at the **pod**. Router just forwards encrypted TCP stream without decryption. Pod handles TLS. User↔Pod: encrypted end-to-end (router is transparent TCP proxy).
   - **Re-encrypt**: TLS terminates at **router**, then router re-encrypts to **pod**. Two separate TLS sessions: User↔Router and Router↔Pod. Router can inspect HTTP but pod receives encrypted traffic.

3. **Why router uses Service, not pod IPs:**
   - **Dynamic endpoints**: Pod IPs change when pods restart/scale. Service provides stable abstraction.
   - **Load balancing**: Service handles distribution across multiple pods (via kube-proxy or OVN).
   - **Health checking**: Service only includes healthy pods in endpoints.
   - **Decoupling**: Router doesn't need to track individual pods, just watches Services.
   - **Consistency**: Same load balancing mechanism as cluster-internal traffic.

4. **HAProxy backend selection:**
   - **For HTTP**: Examines the `Host` header in the HTTP request. Matches against route hostnames configured in HAProxy backends.
   - **For HTTPS**: Uses SNI (Server Name Indication) from TLS ClientHello. SNI contains the hostname the client is trying to reach.
   - **Matching**: `use_backend be_secure:namespace:routename if { req_ssl_sni -i hostname.com }`
   - **Default**: If no match, uses default backend or returns 404/503.

5. **503 Service Unavailable causes:**
   - **No healthy endpoints**: Service exists but has zero pod endpoints. Check: `oc get endpoints -n namespace servicename`
   - **Pods not ready**: Pods exist but failing readiness probes. Check: `oc get pods -n namespace`
   - **Service selector mismatch**: Service selector doesn't match pod labels. Check: `oc describe svc` vs `oc get pods --show-labels`
   - **Wrong service port**: Route targeting a port that doesn't exist on Service. Check: `oc describe route` vs `oc describe svc`
   - **HAProxy can't reach pods**: Network issues between router and pods. Check OVN/OVS (Days 43-46).
   - **Diagnosis**: `oc describe route` shows admission status; `oc get endpoints` shows if backends exist.

6. **Passthrough advantages and disadvantages:**
   - **Advantages**:
     - End-to-end encryption (router never sees plain text)
     - More secure for sensitive data
     - Pod controls TLS configuration and certificates
     - Compliance requirements may mandate end-to-end TLS
   - **Disadvantages**:
     - Router can't inspect HTTP headers (can't do header-based routing)
     - Can't modify requests/responses (no HTTP-level features)
     - Each pod needs TLS certificates (more complex certificate management)
     - Can't use HTTP/2 or protocol upgrades at router level
     - Harder to troubleshoot (can't see plaintext traffic)

7. **Routes integration with OVN/OVS:**
   - **Router pods are pods** like any other - they have IPs, veth pairs, connect to br-int (Day 43).
   - **Router typically uses host network**: Bypasses pod networking, listens directly on node IP.
   - **Traffic flow to backend pods**:
     1. External traffic arrives at router (node IP, port 443)
     2. HAProxy determines target Service IP
     3. Traffic to Service IP uses standard OVN/OVS path (Day 46, Pattern 4)
     4. OVN load balancer or kube-proxy DNAT to pod IP
     5. OVS flows route to pod (same-node or tunnel to other node)
   - **Router → Pod is internal traffic**, uses all the OVN/OVS infrastructure from Days 43-46.
   - **Routes add Layer 7 on top** of the Layer 3-4 networking you already learned.

---

## Today I Learned (TIL)

### Template

```
Date: _______________

# Day 47: Routes and HAProxy

## Key Concepts Mastered
- [ ] Understand difference between Routes and Ingress
- [ ] Can create edge, passthrough, and re-encrypt routes
- [ ] Inspected HAProxy configuration
- [ ] Tested TLS termination at different layers
- [ ] Connected routes to OVN/OVS infrastructure

## Three Route Types
1. Edge: ___________________________________________________
2. Passthrough: _____________________________________________
3. Re-encrypt: ______________________________________________

## Routes I Created
Route Name: ______________  Type: ______________  Hostname: ______________
Route Name: ______________  Type: ______________  Hostname: ______________
Route Name: ______________  Type: ______________  Hostname: ______________

## HAProxy Insights
What I found in HAProxy config:
_________________________________________________________________

## Troubleshooting Scenario
Problem: __________________________________________________________
How I diagnosed: __________________________________________________
Solution: _________________________________________________________

## Connection to Week 7
- Days 43-46: Network-level packet flow (IP, TCP, OVN/OVS)
- Day 47: Application-level routing (HTTP/HTTPS, HAProxy, Routes)
- Routes use Services, which use OVN/OVS - complete stack!

## Questions/Areas to Review
1. _____________________________________________________________
2. _____________________________________________________________

## Tomorrow's Preview
Tomorrow I'll learn about DNS in OpenShift and EgressIP/EgressNetworkPolicy
for controlling outbound traffic.
```

---

## Commands Cheat Sheet

### Route Management

```bash
# === Creating Routes ===

# Create edge route (TLS at router)
oc create route edge <route-name> \
  --service=<service-name> \
  --hostname=<hostname>

# Create passthrough route (TLS at pod)
oc create route passthrough <route-name> \
  --service=<service-name> \
  --hostname=<hostname>

# Create re-encrypt route (TLS at router and pod)
oc create route reencrypt <route-name> \
  --service=<service-name> \
  --hostname=<hostname> \
  --dest-ca-cert=<path-to-pod-ca-cert>

# Simple expose (creates edge route)
oc expose service <service-name>

# With specific hostname
oc expose service <service-name> --hostname=<hostname>


# === Viewing Routes ===

# List all routes
oc get routes -A

# Get route details
oc get route <route-name> -n <namespace>

# Describe route (shows status and conditions)
oc describe route <route-name> -n <namespace>

# Get route YAML
oc get route <route-name> -n <namespace> -o yaml

# Get route hostname
oc get route <route-name> -n <namespace> -o jsonpath='{.spec.host}'

# Check route admission status
oc get route <route-name> -n <namespace> -o jsonpath='{.status.ingress[0].conditions}'


# === Testing Routes ===

# HTTP test
ROUTE_HOST=$(oc get route <route-name> -n <namespace> -o jsonpath='{.spec.host}')
curl -I http://$ROUTE_HOST

# HTTPS test
curl -I https://$ROUTE_HOST

# HTTPS with certificate details
curl -v https://$ROUTE_HOST 2>&1 | grep -E "(SSL|certificate)"

# Test with specific SNI
openssl s_client -connect $ROUTE_HOST:443 -servername $ROUTE_HOST

# Check certificate details
openssl s_client -connect $ROUTE_HOST:443 -servername $ROUTE_HOST </dev/null 2>/dev/null | \
  openssl x509 -noout -text


# === Router Inspection ===

# List router pods
oc get pods -n openshift-ingress

# Get router pod
ROUTER_POD=$(oc get pods -n openshift-ingress -l app=router -o jsonpath='{.items[0].metadata.name}')

# View HAProxy configuration
oc exec -n openshift-ingress $ROUTER_POD -- cat /var/lib/haproxy/conf/haproxy.config

# Search for specific route in config
oc exec -n openshift-ingress $ROUTER_POD -- \
  grep -A20 "<route-name>" /var/lib/haproxy/conf/haproxy.config

# View router logs
oc logs -n openshift-ingress $ROUTER_POD

# Follow router logs
oc logs -n openshift-ingress $ROUTER_POD -f

# View IngressController config
oc get ingresscontroller -n openshift-ingress-operator default -o yaml


# === Troubleshooting ===

# Check if service has endpoints
SERVICE=$(oc get route <route-name> -n <namespace> -o jsonpath='{.spec.to.name}')
oc get endpoints -n <namespace> $SERVICE

# Check pod status
oc get pods -n <namespace>

# Verify route in HAProxy
ROUTE_HOST=$(oc get route <route-name> -n <namespace> -o jsonpath='{.spec.host}')
oc exec -n openshift-ingress $ROUTER_POD -- \
  grep "$ROUTE_HOST" /var/lib/haproxy/conf/haproxy.config

# Test from within cluster
oc run test-curl --image=curlimages/curl:latest --rm -it --restart=Never -- \
  curl -I http://<service-name>.<namespace>.svc.cluster.local:<port>


# === Certificates ===

# Create custom certificate route
oc create route edge <route-name> \
  --service=<service-name> \
  --cert=<path-to-cert> \
  --key=<path-to-key> \
  --ca-cert=<path-to-ca> \
  --hostname=<hostname>

# View certificate in route
oc get route <route-name> -n <namespace> -o jsonpath='{.spec.tls.certificate}'

# Extract and view certificate
oc get route <route-name> -n <namespace> -o jsonpath='{.spec.tls.certificate}' | \
  openssl x509 -noout -text
```

### Route Troubleshooting Workflow

```bash
# Complete troubleshooting script

ROUTE_NAME="<route-name>"
NAMESPACE="<namespace>"

echo "=== Route Status ==="
oc get route -n $NAMESPACE $ROUTE_NAME
oc describe route -n $NAMESPACE $ROUTE_NAME | grep -A10 "Conditions:"

echo "=== Service and Endpoints ==="
SERVICE=$(oc get route -n $NAMESPACE $ROUTE_NAME -o jsonpath='{.spec.to.name}')
oc get svc -n $NAMESPACE $SERVICE
oc get endpoints -n $NAMESPACE $SERVICE

ENDPOINT_COUNT=$(oc get endpoints -n $NAMESPACE $SERVICE -o jsonpath='{.subsets[0].addresses}' | jq '. | length')
echo "Endpoint count: $ENDPOINT_COUNT"

if [ "$ENDPOINT_COUNT" -eq "0" ]; then
  echo "ERROR: No endpoints! Check pods."
  oc get pods -n $NAMESPACE
fi

echo "=== HAProxy Configuration ==="
ROUTER_POD=$(oc get pods -n openshift-ingress -l app=router -o jsonpath='{.items[0].metadata.name}')
ROUTE_HOST=$(oc get route -n $NAMESPACE $ROUTE_NAME -o jsonpath='{.spec.host}')

if oc exec -n openshift-ingress $ROUTER_POD -- grep -q "$ROUTE_HOST" /var/lib/haproxy/conf/haproxy.config; then
  echo "✓ Route found in HAProxy config"
else
  echo "✗ Route NOT in HAProxy config - check router logs"
fi

echo "=== Connectivity Test ==="
curl -I -s -o /dev/null -w "%{http_code}" http://$ROUTE_HOST
```

---

## What's Next

### Tomorrow: Day 48 - DNS and EgressIP

You've learned ingress (traffic coming into the cluster). Tomorrow you'll learn:

**DNS:**
- DNS Operator in OpenShift
- CoreDNS configuration
- Service discovery via DNS
- Custom DNS configurations

**Egress Control:**
- EgressIP: Assigning specific source IPs for egress traffic
- EgressNetworkPolicy: Controlling which external destinations pods can reach
- Egress router pods for legacy application requirements

**Connection:**
- Day 46: You learned pod-to-external traffic flow (Pattern 3)
- Day 48: You'll learn how to control and customize that egress traffic

### Week 7 Progress

- **Day 43**: OVS structure ✓
- **Day 44**: OVS flows ✓
- **Day 45**: OVN architecture ✓
- **Day 46**: Traffic flow patterns ✓
- **Day 47**: Routes and HAProxy ✓
- **Day 48**: DNS and Egress (tomorrow)
- **Day 49**: Real-world troubleshooting scenario

Almost there! Tomorrow completes your knowledge of all OpenShift networking components. Day 49 will test everything with a complex troubleshooting scenario.

---

**Key Takeaway**: Routes are the application-layer routing that sits on top of all the network-layer infrastructure you learned this week. HAProxy provides intelligent HTTP/HTTPS routing, while OVN/OVS handles the packet-level forwarding. Understanding both layers makes you a complete OpenShift networking expert!
