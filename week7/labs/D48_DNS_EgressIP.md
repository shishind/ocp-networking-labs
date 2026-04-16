# Day 48: DNS and EgressIP

**Week 7, Day 48: Phase 4 - OpenShift Networking Deep Dive**

---

## Learning Objectives

By the end of this lab, you will be able to:

1. Understand the DNS Operator and CoreDNS in OpenShift
2. Configure and troubleshoot cluster DNS resolution
3. Assign and manage EgressIP addresses for pods
4. Create and enforce EgressNetworkPolicies
5. Verify egress source IP addresses for external traffic
6. Troubleshoot DNS and egress connectivity issues

---

## Plain English Explanation

### DNS in OpenShift

**The Problem DNS Solves:**

Imagine you're in a pod and want to talk to another service. You could use the service's IP address (like 172.30.123.45), but:
- Service IPs can change
- IPs are hard to remember
- Different environments have different IPs

**DNS provides names instead of numbers:**
- `frontend-service` instead of `172.30.123.45`
- `database.production.svc.cluster.local` instead of `172.30.98.12`
- `api.example.com` for external services

**How OpenShift DNS Works:**

```
Pod wants to connect to "database"
    ↓
Check /etc/resolv.conf → DNS server is 172.30.0.10
    ↓
Query DNS server (CoreDNS pod): "What IP is 'database'?"
    ↓
CoreDNS checks:
  1. Is it a Service in this namespace? → 172.30.123.45
  2. Is it a Service in another namespace?
  3. Is it an external domain? → Forward to upstream DNS
    ↓
Returns IP address
    ↓
Pod connects to 172.30.123.45
```

**Key Components:**

1. **CoreDNS**: The DNS server running in pods
2. **DNS Operator**: Manages CoreDNS configuration
3. **Service Discovery**: Automatic DNS records for all Services
4. **Search Domains**: Allow short names like "database" instead of full "database.namespace.svc.cluster.local"

**DNS Naming Convention:**

```
<service-name>.<namespace>.svc.cluster.local
```

Examples:
- `nginx.default.svc.cluster.local` - nginx service in default namespace
- `database.production.svc.cluster.local` - database in production
- `api-server.openshift-apiserver.svc.cluster.local` - OpenShift API server

**Connection to Previous Weeks:**
- **Week 5 (Services)**: DNS provides names for Services
- **Day 46 (Traffic Flows)**: DNS resolution happens before packet routing
- **Day 47 (Routes)**: External DNS points to router, internal DNS to Services

### EgressIP

**The Problem EgressIP Solves:**

From Day 46, you learned that when pods access external services, NAT changes the source IP to the node's IP. But which node? It depends on which node the pod is running on.

**Problems:**
- External firewalls need to allow traffic from ALL node IPs
- Source IP changes if pod moves to different node
- Can't track which traffic came from which application
- Compliance requirements may need stable source IPs

**EgressIP Solution:**

Assign a **specific IP address** to traffic from certain pods, regardless of which node they're on.

```
WITHOUT EgressIP:
  Pod on node1 (node IP: 192.168.1.10) → External sees 192.168.1.10
  Pod moves to node2 (node IP: 192.168.1.11) → External sees 192.168.1.11
  Problem: Source IP changed!

WITH EgressIP:
  Pod on node1 → Egress IP: 192.168.1.100 → External sees 192.168.1.100
  Pod moves to node2 → Egress IP: 192.168.1.100 → External sees 192.168.1.100
  Success: Source IP stable!
```

**How It Works:**

1. Configure EgressIP on node(s): Add secondary IP to node
2. Create EgressIP resource: Specify which pods and which IP
3. OVN configures flows: Route matching traffic through the EgressIP
4. External traffic: Source NAT uses EgressIP instead of node IP

**Use Cases:**
- External service allowlist requires specific IPs
- Compliance/audit requirements to track traffic by application
- Legacy systems that authenticate by source IP
- Per-customer egress IPs in multi-tenant environments

### EgressNetworkPolicy

**The Problem It Solves:**

By default, pods can reach ANY external IP. Security best practice: restrict outbound access.

**Without EgressNetworkPolicy:**
- Pod can connect to any internet site
- Compromised pod can exfiltrate data
- Hard to enforce security boundaries

**With EgressNetworkPolicy:**
- Define allowed/denied external destinations by IP/CIDR
- "Database pods can only reach 10.0.0.0/8, deny everything else"
- "App pods can reach api.example.com, deny all other external access"

**Example Policy:**

```yaml
apiVersion: network.openshift.io/v1
kind: EgressNetworkPolicy
metadata:
  name: database-egress
  namespace: production
spec:
  egress:
  - type: Allow
    to:
      cidrSelector: 10.0.0.0/8  # Internal network
  - type: Allow
    to:
      cidrSelector: 192.168.1.50/32  # Specific database server
  - type: Deny
    to:
      cidrSelector: 0.0.0.0/0  # Deny everything else
```

**Connection to NetworkPolicy (Week 6):**
- **NetworkPolicy**: Controls pod-to-pod traffic (east-west)
- **EgressNetworkPolicy**: Controls pod-to-external traffic (north-south)
- Often used together for defense-in-depth

---

## Hands-On Lab

### Prerequisites

- Completed Days 43-47
- Cluster admin access (for DNS Operator and EgressIP)
- At least one pod for testing

---

### Exercise 1: Explore DNS Configuration

**Objective**: Understand how DNS is configured in pods and the cluster.

```bash
# Check DNS Operator status
oc get clusteroperator dns

# View DNS Operator configuration
oc get dns.operator/default -o yaml

# Find CoreDNS pods
oc get pods -n openshift-dns

# View CoreDNS configuration
oc get configmap -n openshift-dns dns-default -o yaml

# Check a pod's DNS configuration
POD_NAME=$(oc get pods -n default -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$POD_NAME" ]; then
  oc run test-dns --image=registry.access.redhat.com/ubi9/ubi-minimal:latest -- sleep 3600
  POD_NAME="test-dns"
fi

# View /etc/resolv.conf in pod
oc exec -n default $POD_NAME -- cat /etc/resolv.conf

# Expected output shows:
# - nameserver: ClusterIP of DNS service (typically 172.30.0.10)
# - search domains: default.svc.cluster.local svc.cluster.local cluster.local

# Check DNS Service
oc get svc -n openshift-dns dns-default

DNS_SERVICE_IP=$(oc get svc -n openshift-dns dns-default -o jsonpath='{.spec.clusterIP}')
echo "DNS Service IP: $DNS_SERVICE_IP"
```

**Key Observations:**
- Every pod's /etc/resolv.conf points to the DNS Service
- Search domains allow short names (e.g., "nginx" expands to "nginx.default.svc.cluster.local")
- DNS Service is a ClusterIP service backed by CoreDNS pods

---

### Exercise 2: Test DNS Resolution

**Objective**: Verify DNS works for service discovery and external domains.

```bash
# Create a test service if needed
oc create deployment nginx -n default --image=nginxinc/nginx-unprivileged:latest || echo "Already exists"
oc expose deployment nginx -n default --port=8080 || echo "Already exists"

# Test DNS resolution from a pod
POD_NAME=$(oc get pods -n default -o jsonpath='{.items[0].metadata.name}')

# 1. Test short name (same namespace)
oc exec -n default $POD_NAME -- nslookup nginx

# 2. Test FQDN
oc exec -n default $POD_NAME -- nslookup nginx.default.svc.cluster.local

# 3. Test cross-namespace
oc exec -n default $POD_NAME -- nslookup kubernetes.default.svc.cluster.local

# 4. Test external domain
oc exec -n default $POD_NAME -- nslookup google.com

# 5. Use dig for detailed info
oc exec -n default $POD_NAME -- dig nginx.default.svc.cluster.local

# 6. Test SRV records (for service discovery)
oc exec -n default $POD_NAME -- dig SRV _http._tcp.nginx.default.svc.cluster.local

# 7. Check what DNS server is being used
oc exec -n default $POD_NAME -- nslookup kubernetes | grep Server
```

**Expected Results:**

```bash
# Short name resolves to service ClusterIP
nslookup nginx
Server:    172.30.0.10
Address 1: 172.30.0.10 dns-default.openshift-dns.svc.cluster.local
Name:      nginx
Address 1: 172.30.123.45 nginx.default.svc.cluster.local

# External domain works
nslookup google.com
Server:    172.30.0.10
Address 1: 172.30.0.10 dns-default.openshift-dns.svc.cluster.local
Name:      google.com
Address 1: 142.250.185.46
```

---

### Exercise 3: Customize DNS Configuration

**Objective**: Modify DNS settings for specific use cases.

```bash
# View current DNS Operator config
oc get dns.operator/default -o yaml > /tmp/dns-operator.yaml

# Add custom upstream DNS servers
cat <<EOF | oc apply -f -
apiVersion: operator.openshift.io/v1
kind: DNS
metadata:
  name: default
spec:
  servers:
  - name: custom-dns
    zones:
    - example.com
    forwardPlugin:
      upstreams:
      - 1.1.1.1
      - 8.8.8.8
EOF

# Wait for DNS pods to reload
sleep 10
oc rollout status daemonset/dns-default -n openshift-dns

# Verify custom configuration
oc get dns.operator/default -o yaml | grep -A10 servers

# Test custom upstream
oc exec -n default $POD_NAME -- nslookup www.example.com

# Add custom hosts (like /etc/hosts)
# This modifies the CoreDNS Corefile
oc edit configmap dns-default -n openshift-dns
# Add to Corefile:
# hosts {
#   192.168.1.100 custom.internal.example.com
#   fallthrough
# }

# Reload CoreDNS
oc rollout restart daemonset/dns-default -n openshift-dns

# Revert changes
oc apply -f /tmp/dns-operator.yaml
```

---

### Exercise 4: Configure EgressIP

**Objective**: Assign a static egress IP to pods.

```bash
# Prerequisites:
# - Additional IP available on your network
# - Node with capacity for EgressIP

# Step 1: Label a node for EgressIP
NODE_NAME=$(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[0].metadata.name}')
oc label node $NODE_NAME k8s.ovn.org/egress-assignable=""

# Verify label
oc get node $NODE_NAME --show-labels | grep egress

# Step 2: Create EgressIP object
# Note: Replace 192.168.1.200 with an IP available on your network
cat <<EOF | oc apply -f -
apiVersion: k8s.ovn.org/v1
kind: EgressIP
metadata:
  name: database-egress
spec:
  egressIPs:
  - 192.168.1.200
  namespaceSelector:
    matchLabels:
      env: production
  podSelector:
    matchLabels:
      app: database
EOF

# Step 3: Label namespace
oc create namespace production || echo "Namespace exists"
oc label namespace production env=production

# Step 4: Create test pod
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: database-app
  namespace: production
  labels:
    app: database
spec:
  containers:
  - name: app
    image: registry.access.redhat.com/ubi9/ubi-minimal:latest
    command: ["sleep", "3600"]
EOF

# Wait for pod
oc wait --for=condition=Ready pod/database-app -n production --timeout=60s

# Step 5: Verify EgressIP status
oc get egressip database-egress

# Check which node got the EgressIP assigned
oc get egressip database-egress -o yaml | grep -A5 status

# Step 6: Test egress traffic
# From the pod, check what external services see as source IP
oc exec -n production database-app -- curl -s ifconfig.me

# Expected: Should show 192.168.1.200 (the EgressIP)

# Compare with a pod without EgressIP
oc run test-no-egress -n default --image=registry.access.redhat.com/ubi9/ubi-minimal:latest -- sleep 3600
oc exec -n default test-no-egress -- curl -s ifconfig.me
# Expected: Shows node IP, not EgressIP

# Step 7: Verify on the node
oc debug node/$NODE_NAME
chroot /host

# Check if EgressIP is assigned to an interface
ip addr show | grep 192.168.1.200

# Check iptables rules for EgressIP
iptables -t nat -L -n -v | grep 192.168.1.200

# Check OVS flows
ovs-ofctl dump-flows br-int | grep 192.168.1.200

exit
exit
```

**Understanding EgressIP Assignment:**

```
1. OVN controller sees EgressIP object
2. Selects node labeled with k8s.ovn.org/egress-assignable
3. Assigns EgressIP to node (adds as secondary IP)
4. Updates OVN flows: traffic from matching pods → SNAT to EgressIP
5. External traffic appears to come from EgressIP
```

---

### Exercise 5: Create EgressNetworkPolicy

**Objective**: Restrict which external destinations pods can reach.

```bash
# Create test namespace
oc create namespace egress-policy-test || echo "Exists"

# Create test pod
oc run test-app -n egress-policy-test \
  --image=registry.access.redhat.com/ubi9/ubi-minimal:latest \
  -- sleep 3600

# Before policy: Test connectivity
echo "=== Before Policy ==="
oc exec -n egress-policy-test test-app -- curl -s -m 5 -o /dev/null -w "%{http_code}\n" http://google.com
oc exec -n egress-policy-test test-app -- curl -s -m 5 -o /dev/null -w "%{http_code}\n" http://redhat.com

# Create EgressNetworkPolicy
cat <<EOF | oc apply -f -
apiVersion: network.openshift.io/v1
kind: EgressNetworkPolicy
metadata:
  name: restrictive-egress
  namespace: egress-policy-test
spec:
  egress:
  # Allow DNS
  - type: Allow
    to:
      cidrSelector: 172.30.0.10/32
  # Allow specific external IP (example: 8.8.8.8 - Google DNS)
  - type: Allow
    to:
      cidrSelector: 8.8.8.8/32
  # Allow internal network
  - type: Allow
    to:
      cidrSelector: 10.0.0.0/8
  # Deny everything else
  - type: Deny
    to:
      cidrSelector: 0.0.0.0/0
EOF

# Wait for policy to apply
sleep 5

# After policy: Test connectivity
echo "=== After Policy ==="

# Should work: 8.8.8.8 allowed
oc exec -n egress-policy-test test-app -- ping -c 2 8.8.8.8

# Should fail: google.com IP not explicitly allowed
oc exec -n egress-policy-test test-app -- curl -s -m 5 -o /dev/null -w "%{http_code}\n" http://google.com || echo "Blocked as expected"

# Check policy status
oc get egressnetworkpolicy -n egress-policy-test

# View policy details
oc describe egressnetworkpolicy -n egress-policy-test restrictive-egress

# Clean up
oc delete egressnetworkpolicy -n egress-policy-test restrictive-egress
```

**Policy Evaluation Order:**

Rules are evaluated in order. First match wins.

```yaml
egress:
- type: Allow
  to:
    cidrSelector: 8.8.8.8/32     # Specific allow
- type: Deny
  to:
    cidrSelector: 8.8.0.0/16     # Broader deny (but 8.8.8.8 already matched Allow)
- type: Allow
  to:
    cidrSelector: 0.0.0.0/0      # Would allow everything, but previous rules matched first
```

---

### Exercise 6: Troubleshoot DNS Issues

**Objective**: Diagnose and fix common DNS problems.

```bash
# Scenario 1: Pod can't resolve service names

# Check DNS Service is running
oc get pods -n openshift-dns
oc get svc -n openshift-dns dns-default

# Check DNS endpoints (CoreDNS pods)
oc get endpoints -n openshift-dns dns-default

# If no endpoints, DNS pods might be down
oc describe pods -n openshift-dns

# Check pod's resolv.conf
oc exec -n default $POD_NAME -- cat /etc/resolv.conf

# Test DNS directly
DNS_SERVICE_IP=$(oc get svc -n openshift-dns dns-default -o jsonpath='{.spec.clusterIP}')
oc exec -n default $POD_NAME -- nslookup kubernetes $DNS_SERVICE_IP

# Check CoreDNS logs
COREDNS_POD=$(oc get pods -n openshift-dns -o jsonpath='{.items[0].metadata.name}')
oc logs -n openshift-dns $COREDNS_POD | tail -50

# Scenario 2: External DNS not resolving

# Check upstream DNS configuration
oc get dns.operator/default -o yaml | grep -A10 upstreams

# Test from CoreDNS pod directly
oc exec -n openshift-dns $COREDNS_POD -- nslookup google.com

# If CoreDNS can resolve but pod can't, check pod's resolv.conf
oc exec -n default $POD_NAME -- cat /etc/resolv.conf

# Scenario 3: Slow DNS resolution

# Check CoreDNS resource usage
oc top pods -n openshift-dns

# Check for DNS query errors in logs
oc logs -n openshift-dns $COREDNS_POD | grep -i error

# Increase CoreDNS replicas if needed (for high load)
oc get dns.operator/default -o yaml | grep -A5 nodePlacement

# Scenario 4: Custom DNS not working

# Verify DNS Operator applied configuration
oc get configmap -n openshift-dns dns-default -o yaml

# Check Corefile has your custom config
oc exec -n openshift-dns $COREDNS_POD -- cat /etc/coredns/Corefile

# If changes not applied, check DNS Operator logs
oc logs -n openshift-dns-operator deployment/dns-operator
```

---

### Exercise 7: Verify Complete DNS and Egress Flow

**Objective**: Trace a complete outbound connection using DNS resolution and egress.

```bash
# Create test environment
oc create namespace dns-egress-test || echo "Exists"
oc label namespace dns-egress-test env=testing

# Deploy test app
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-app
  namespace: dns-egress-test
  labels:
    app: test
spec:
  containers:
  - name: app
    image: registry.access.redhat.com/ubi9/ubi-minimal:latest
    command: ["sh", "-c", "microdnf install -y nmap-ncat && sleep 3600"]
EOF

oc wait --for=condition=Ready pod/test-app -n dns-egress-test --timeout=120s

# Trace the complete flow:

echo "=== Step 1: DNS Resolution ==="
oc exec -n dns-egress-test test-app -- nslookup google.com

echo "=== Step 2: Check routing to resolved IP ==="
GOOGLE_IP=$(oc exec -n dns-egress-test test-app -- nslookup google.com | grep "Address:" | tail -1 | awk '{print $2}')
echo "Resolved IP: $GOOGLE_IP"
oc exec -n dns-egress-test test-app -- ip route get $GOOGLE_IP

echo "=== Step 3: Check egress IP (if configured) ==="
oc get egressip -A

echo "=== Step 4: Verify actual source IP seen externally ==="
oc exec -n dns-egress-test test-app -- curl -s ifconfig.me
# This shows the actual source IP external services see

echo "=== Step 5: Check DNS in OVN ==="
MASTER_POD=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-master -o jsonpath='{.items[0].metadata.name}')
DNS_SERVICE_IP=$(oc get svc -n openshift-dns dns-default -o jsonpath='{.spec.clusterIP}')
oc exec -n openshift-ovn-kubernetes $MASTER_POD -c nbdb -- \
  ovn-nbctl find load_balancer | grep -A5 $DNS_SERVICE_IP

echo "=== Step 6: Trace on node ==="
POD_IP=$(oc get pod -n dns-egress-test test-app -o jsonpath='{.status.podIP}')
NODE=$(oc get pod -n dns-egress-test test-app -o jsonpath='{.spec.nodeName}')

oc debug node/$NODE -- chroot /host bash -c "
  echo 'Pod IP: $POD_IP'
  echo 'DNS queries from pod:'
  timeout 5 tcpdump -i any -n 'host $POD_IP and port 53' -c 5 &
  sleep 2
"

# From another terminal, trigger DNS query:
# oc exec -n dns-egress-test test-app -- nslookup yahoo.com
```

**Complete Flow Visualization:**

```
1. Application calls: connect("api.example.com", 443)
2. Resolver reads /etc/resolv.conf → DNS server: 172.30.0.10
3. DNS query: "What is api.example.com?" → CoreDNS pod
4. CoreDNS forwards to upstream → Gets IP: 203.0.113.50
5. Application connects to 203.0.113.50:443
6. Routing table: Use default route → gateway
7. OVN flows: Match egress traffic
8. EgressIP (if configured): SNAT to egress IP
9. Else: SNAT to node IP (standard NAT)
10. Packet exits cluster to 203.0.113.50
```

---

## Self-Check Questions

### Questions

1. **What is the role of CoreDNS in OpenShift?**

2. **Explain the DNS search domains in /etc/resolv.conf and why they exist.**

3. **How does EgressIP differ from the normal NAT behavior for pod egress traffic?**

4. **What is the difference between NetworkPolicy and EgressNetworkPolicy?**

5. **If a pod can't resolve internal service names but can resolve external domains, what's likely wrong?**

6. **How does OVN implement EgressIP at the flow level?**

7. **Why might you want multiple EgressIPs in a single EgressIP object?**

8. **What happens if two EgressNetworkPolicy rules match the same destination?**

---

### Answers

1. **CoreDNS role:**
   - **DNS server** for the entire cluster. Runs as pods in openshift-dns namespace.
   - **Service discovery**: Automatically creates DNS records for all Services (e.g., nginx.default.svc.cluster.local → Service ClusterIP).
   - **Forwards external queries** to upstream DNS servers (configured by DNS Operator).
   - **Plugins**: Supports custom configurations (hosts file, caching, metrics, etc.).
   - **High availability**: Multiple CoreDNS pods for redundancy.
   - Every pod's /etc/resolv.conf points to CoreDNS Service IP.

2. **DNS search domains:**
   - `/etc/resolv.conf` contains: `search default.svc.cluster.local svc.cluster.local cluster.local`
   - **Purpose**: Allow using short names instead of fully qualified domain names.
   - **Example in default namespace**:
     - Type "nginx" → searches "nginx.default.svc.cluster.local" first → FOUND
     - Type "database" → searches all domains until found
   - **Benefit**: Simpler references in code, environment variables, etc.
   - **Namespace-aware**: Search includes current namespace first, then global.
   - **External domains**: If all searches fail, queries as-is (for google.com, etc.).

3. **EgressIP vs normal NAT:**
   - **Normal NAT**: Source IP becomes the node's IP. Varies by which node the pod is on. Changes if pod moves/restarts on different node.
   - **EgressIP**: Source IP is a specific IP defined in EgressIP object. Consistent regardless of which node the pod is on. OVN manages the IP and routing.
   - **Assignment**: EgressIP is assigned to a node by OVN, node gets it as a secondary IP.
   - **Use case**: External firewalls can allowlist single EgressIP instead of all node IPs. Stable source IP for audit/compliance.

4. **NetworkPolicy vs EgressNetworkPolicy:**
   - **NetworkPolicy** (standard Kubernetes):
     - Controls **pod-to-pod** traffic (cluster internal)
     - Both ingress (incoming to pod) and egress (outgoing from pod)
     - Layer 3-4: IP addresses, ports, protocols
     - Example: "Allow port 3306 to database pods only from app pods"
   - **EgressNetworkPolicy** (OpenShift-specific):
     - Controls **pod-to-external** traffic only
     - Egress only (outbound from cluster)
     - CIDR-based: Allow/deny by destination IP range
     - Example: "Deny all internet access except 8.8.8.8"
   - **Complementary**: Often use both together (NetworkPolicy for internal, EgressNetworkPolicy for external).

5. **Can resolve external but not internal:**
   - **Likely cause**: Search domains not configured properly in /etc/resolv.conf.
   - **Check**: `oc exec pod -- cat /etc/resolv.conf` should show search domains.
   - **Alternative cause**: Using FQDN incorrectly (typo in service name).
   - **Another possibility**: DNS working, but short name doesn't expand correctly.
   - **Test**: Try full FQDN: `nslookup nginx.default.svc.cluster.local` vs `nslookup nginx`
   - **Fix**: Usually indicates pod DNS configuration issue or DNS Operator misconfiguration.

6. **OVN implements EgressIP with flows:**
   - **Flow matching**: Match packets from pods selected by EgressIP (by pod IP or metadata).
   - **SNAT action**: Instead of SNATing to node IP, SNAT to EgressIP.
   - **Example flow**: `nw_src=10.128.0.5 actions=ct(commit,nat(src=192.168.1.200)),output:br-ex`
   - **Connection tracking**: Uses conntrack to maintain SNAT state.
   - **Node assignment**: OVN assigns EgressIP to specific node as secondary IP, updates flows to use it.
   - **High availability**: If assigned node fails, OVN can reassign EgressIP to another node.

7. **Multiple EgressIPs in one object:**
   - **High availability**: If one EgressIP/node fails, traffic uses another.
   - **Load distribution**: Spread traffic across multiple IPs to avoid bottlenecks.
   - **IP pool management**: Provide multiple IPs for the same set of pods.
   - **Example**:
     ```yaml
     spec:
       egressIPs:
       - 192.168.1.200
       - 192.168.1.201
       - 192.168.1.202
     ```
   - **Assignment**: OVN assigns each to a different node (if possible) for distribution.
   - **Selection**: OVN chooses which IP to use per connection (typically round-robin or based on node).

8. **Multiple matching EgressNetworkPolicy rules:**
   - **First match wins**: Rules evaluated in order from top to bottom.
   - **Evaluation stops** at first matching rule.
   - **Example**:
     ```yaml
     - type: Allow
       to:
         cidrSelector: 8.8.8.8/32   # Matches, allows 8.8.8.8
     - type: Deny
       to:
         cidrSelector: 8.8.0.0/16   # Would match, but previous rule already matched
     ```
   - **Result**: 8.8.8.8 is allowed (first rule), even though second rule would deny.
   - **Order matters**: Put more specific rules first, general rules last.
   - **Best practice**: End with explicit `Deny 0.0.0.0/0` to deny by default.

---

## Today I Learned (TIL)

### Template

```
Date: _______________

# Day 48: DNS and EgressIP

## Key Concepts Mastered
- [ ] Understand CoreDNS and DNS Operator
- [ ] Tested DNS resolution for services and external domains
- [ ] Configured EgressIP for stable egress source IPs
- [ ] Created EgressNetworkPolicy to restrict external access
- [ ] Troubleshot DNS issues

## DNS Configuration
DNS Service IP: ______________
Search domains: ______________________________________________
Upstream DNS: ________________________________________________

## EgressIP Configured
EgressIP: ______________
Namespace selector: __________________________________________
Pod selector: ________________________________________________
Assigned node: ______________

## EgressNetworkPolicy Rules
Allowed destinations: ________________________________________
Denied destinations: _________________________________________
Effect observed: _____________________________________________

## Troubleshooting Scenario
Problem: _____________________________________________________
Diagnosis steps: _____________________________________________
Solution: ____________________________________________________

## Connection to Week 7
- Day 46: Learned egress traffic flow (pod → NAT → external)
- Day 48: Learned to control egress (EgressIP, EgressNetworkPolicy)
- DNS enables service discovery for all the networking we've learned

## Questions/Areas to Review
1. _____________________________________________________________
2. _____________________________________________________________

## Tomorrow's Preview
Tomorrow is the Week 7 scenario day - a complex troubleshooting challenge
that uses EVERYTHING from this week!
```

---

## Commands Cheat Sheet

### DNS Commands

```bash
# === DNS Operator ===

# Check DNS Operator status
oc get clusteroperator dns

# View DNS Operator configuration
oc get dns.operator/default -o yaml

# Edit DNS configuration
oc edit dns.operator/default


# === CoreDNS Pods ===

# List CoreDNS pods
oc get pods -n openshift-dns

# View CoreDNS logs
oc logs -n openshift-dns <coredns-pod>

# Get CoreDNS configuration
oc get configmap -n openshift-dns dns-default -o yaml

# View Corefile
COREDNS_POD=$(oc get pods -n openshift-dns -o jsonpath='{.items[0].metadata.name}')
oc exec -n openshift-dns $COREDNS_POD -- cat /etc/coredns/Corefile


# === DNS Service ===

# Get DNS Service
oc get svc -n openshift-dns dns-default

# Get DNS Service IP
DNS_IP=$(oc get svc -n openshift-dns dns-default -o jsonpath='{.spec.clusterIP}')

# Check DNS endpoints
oc get endpoints -n openshift-dns dns-default


# === Testing DNS from Pods ===

# Check pod's resolv.conf
oc exec <pod> -- cat /etc/resolv.conf

# Test service resolution (short name)
oc exec <pod> -- nslookup <service-name>

# Test service resolution (FQDN)
oc exec <pod> -- nslookup <service>.<namespace>.svc.cluster.local

# Test external domain
oc exec <pod> -- nslookup google.com

# Detailed DNS query with dig
oc exec <pod> -- dig <domain>

# Query specific DNS server
oc exec <pod> -- nslookup <domain> <dns-server-ip>

# SRV records
oc exec <pod> -- dig SRV _http._tcp.<service>.<namespace>.svc.cluster.local


# === EgressIP ===

# List EgressIPs
oc get egressip -A

# Create EgressIP
cat <<EOF | oc apply -f -
apiVersion: k8s.ovn.org/v1
kind: EgressIP
metadata:
  name: <name>
spec:
  egressIPs:
  - <ip-address>
  namespaceSelector:
    matchLabels:
      <key>: <value>
  podSelector:
    matchLabels:
      <key>: <value>
EOF

# View EgressIP status
oc get egressip <name> -o yaml

# Label node for EgressIP assignment
oc label node <node-name> k8s.ovn.org/egress-assignable=""

# Remove EgressIP label from node
oc label node <node-name> k8s.ovn.org/egress-assignable-

# Check which node has EgressIP assigned
oc get egressip <name> -o jsonpath='{.status.items[0].node}'

# Delete EgressIP
oc delete egressip <name>


# === EgressNetworkPolicy ===

# List EgressNetworkPolicies
oc get egressnetworkpolicy -A

# Create EgressNetworkPolicy
cat <<EOF | oc apply -f -
apiVersion: network.openshift.io/v1
kind: EgressNetworkPolicy
metadata:
  name: <name>
  namespace: <namespace>
spec:
  egress:
  - type: Allow
    to:
      cidrSelector: <cidr>
  - type: Deny
    to:
      cidrSelector: 0.0.0.0/0
EOF

# View policy
oc describe egressnetworkpolicy -n <namespace> <name>

# Delete policy
oc delete egressnetworkpolicy -n <namespace> <name>


# === Verification ===

# Check egress source IP from pod
oc exec <pod> -- curl -s ifconfig.me

# Alternative egress IP check
oc exec <pod> -- curl -s https://api.ipify.org

# Trace DNS query traffic
oc debug node/<node> -- chroot /host tcpdump -i any -n 'port 53' -c 10

# Check EgressIP on node
oc debug node/<node> -- chroot /host ip addr show | grep <egress-ip>
```

### Troubleshooting DNS

```bash
# Complete DNS troubleshooting workflow

echo "=== DNS Service Health ==="
oc get pods -n openshift-dns
oc get svc -n openshift-dns dns-default
oc get endpoints -n openshift-dns dns-default

echo "=== DNS Operator Status ==="
oc get clusteroperator dns

echo "=== Test from Pod ==="
POD=<test-pod>
oc exec $POD -- cat /etc/resolv.conf
oc exec $POD -- nslookup kubernetes
oc exec $POD -- nslookup google.com

echo "=== CoreDNS Logs ==="
COREDNS_POD=$(oc get pods -n openshift-dns -o jsonpath='{.items[0].metadata.name}')
oc logs -n openshift-dns $COREDNS_POD --tail=20

echo "=== Test CoreDNS Directly ==="
DNS_IP=$(oc get svc -n openshift-dns dns-default -o jsonpath='{.spec.clusterIP}')
oc exec $POD -- nslookup google.com $DNS_IP
```

---

## What's Next

### Tomorrow: Day 49 - Week 7 Scenario

Tomorrow is your final challenge for Week 7:

**Scenario**: "Pods on different nodes cannot communicate"

You'll use the complete troubleshooting framework:
- **Kubernetes layer**: Pods, Services, NetworkPolicies
- **OVN layer**: Northbound/Southbound DBs, logical networks
- **OVS layer**: Bridges, flows, tunnels
- **Linux layer**: veth pairs, routing, iptables
- **DNS**: Service discovery
- **Egress**: External connectivity

**Skills Applied:**
- Days 43-44: OVS inspection
- Day 45: OVN architecture
- Day 46: Traffic flow tracing
- Day 47: Routes (if applicable)
- Day 48: DNS and egress

This scenario will tie together EVERYTHING you've learned this week!

### Week 7 Complete Learning Path

- **Day 43**: OVS Fundamentals ✓
- **Day 44**: OVS Flow Tables ✓
- **Day 45**: OVN Architecture ✓
- **Day 46**: OVN Traffic Flows ✓
- **Day 47**: Routes and HAProxy ✓
- **Day 48**: DNS and EgressIP ✓
- **Day 49**: Week 7 Scenario (tomorrow)

You now have complete knowledge of the OpenShift networking stack from the physical layer (veth, OVS) through the control plane (OVN) to the application layer (Routes, DNS). Tomorrow, you'll prove it!

---

**Key Takeaway**: DNS and egress control are the "finishing touches" on the networking stack. DNS makes the network usable (names instead of IPs), while EgressIP and EgressNetworkPolicy provide security and compliance. Combined with everything from Days 43-47, you now understand the complete OpenShift networking picture!
