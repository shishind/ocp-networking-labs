# Phase 4: OpenShift Networking Command Reference
**Week 7 Labs | OVS, OVN, Routes, EgressIP**

---

## OVS (Open vSwitch) Commands

### Basic OVS Operations

**View bridges:**
```bash
# List all bridges
ovs-vsctl show

# List bridge names only
ovs-vsctl list-br

# Show bridge details
ovs-vsctl list bridge br-int

# Show bridge ports
ovs-vsctl list-ports br-int
```

**View ports:**
```bash
# List all ports
ovs-vsctl list-ports br-int

# Show port details
ovs-vsctl list interface veth1234

# Show all interfaces
ovs-vsctl list interface

# Get interface statistics
ovs-vsctl get interface veth1234 statistics
```

**Database operations:**
```bash
# Show entire database
ovs-vsctl show

# List tables
ovsdb-client list-tables

# Dump specific table
ovs-vsctl list Port
ovs-vsctl list Interface
ovs-vsctl list Bridge

# Get specific column
ovs-vsctl get Port veth1234 tag
ovs-vsctl get Interface veth1234 ofport
```

### OVS Flow Tables

**View flows:**
```bash
# Dump all flows
ovs-ofctl dump-flows br-int

# Dump flows for specific table
ovs-ofctl dump-flows br-int table=0

# Show flows with statistics
ovs-ofctl dump-flows br-int --names

# Watch flows (with stats)
watch -n 1 'ovs-ofctl dump-flows br-int'

# Count flows
ovs-ofctl dump-flows br-int | wc -l
```

**Flow filtering:**
```bash
# Filter by table
ovs-ofctl dump-flows br-int table=0

# Filter by port
ovs-ofctl dump-flows br-int in_port=1

# Filter by IP
ovs-ofctl dump-flows br-int | grep "nw_src=10.128.0.5"

# Filter by action
ovs-ofctl dump-flows br-int | grep "output"
```

**Flow management:**
```bash
# Add flow
ovs-ofctl add-flow br-int "table=0,priority=100,in_port=1,actions=output:2"

# Delete flows
ovs-ofctl del-flows br-int

# Delete specific flow
ovs-ofctl del-flows br-int "table=0,in_port=1"

# Modify flow
ovs-ofctl mod-flows br-int "table=0,priority=100,in_port=1,actions=drop"
```

**Port management:**
```bash
# Show port numbers
ovs-ofctl show br-int

# Get port number for interface
ovs-vsctl get Interface veth1234 ofport

# Show port stats
ovs-ofctl dump-ports br-int

# Show port description
ovs-ofctl dump-ports-desc br-int
```

### OVS Packet Tracing

```bash
# Trace packet through bridge
ovs-appctl ofproto/trace br-int in_port=1,tcp,nw_src=10.128.0.5,nw_dst=10.128.0.6,tp_src=12345,tp_dst=80

# Trace with minimal output
ovs-appctl ofproto/trace br-int in_port=1,ip,nw_dst=10.128.0.6 --minimal

# Trace specific packet
ovs-appctl ofproto/trace br-int 'in_port=1,dl_src=aa:bb:cc:dd:ee:ff,dl_dst=11:22:33:44:55:66,nw_src=10.0.0.1,nw_dst=10.0.0.2'
```

### OVS Monitoring

```bash
# Show OVS version
ovs-vsctl --version
ovs-ofctl --version

# Show database contents
ovsdb-client dump

# Show coverage (internal stats)
ovs-appctl coverage/show

# Show memory usage
ovs-appctl memory/show

# List available commands
ovs-appctl list-commands
```

---

## OVN (Open Virtual Network) Commands

### OVN Northbound Database (ovn-nbctl)

**Logical switches:**
```bash
# List logical switches
ovn-nbctl ls-list
ovn-nbctl list Logical_Switch

# Show logical switch details
ovn-nbctl ls-get <switch-uuid>
ovn-nbctl show <switch-uuid>

# List logical switch ports
ovn-nbctl lsp-list <switch-name>

# Show logical switch port details
ovn-nbctl lsp-get-type <port-name>
ovn-nbctl list Logical_Switch_Port <port-name>
```

**Logical routers:**
```bash
# List logical routers
ovn-nbctl lr-list
ovn-nbctl list Logical_Router

# Show logical router details
ovn-nbctl lr-get <router-name>

# List logical router ports
ovn-nbctl lrp-list <router-name>

# Show router routes
ovn-nbctl lr-route-list <router-name>
```

**ACLs (Access Control Lists):**
```bash
# List ACLs
ovn-nbctl acl-list <switch-name>

# Show ACL details
ovn-nbctl list ACL

# Add ACL (example)
ovn-nbctl acl-add <switch> to-lport 1000 "ip4.src == 10.128.0.0/24" allow

# Delete ACL
ovn-nbctl acl-del <switch> to-lport 1000 "ip4.src == 10.128.0.0/24"
```

**Load balancers:**
```bash
# List load balancers
ovn-nbctl lb-list
ovn-nbctl list Load_Balancer

# Show load balancer details
ovn-nbctl lb-get <lb-uuid>
```

**General northbound database:**
```bash
# Show entire northbound database
ovn-nbctl show

# List all tables
ovn-nbctl list <table-name>

# Examples:
ovn-nbctl list Logical_Switch
ovn-nbctl list Logical_Router
ovn-nbctl list ACL
ovn-nbctl list Load_Balancer
```

### OVN Southbound Database (ovn-sbctl)

**Chassis (nodes):**
```bash
# List chassis
ovn-sbctl chassis-list
ovn-sbctl list Chassis

# Show chassis details
ovn-sbctl show <chassis-name>
```

**Port bindings:**
```bash
# List port bindings
ovn-sbctl list Port_Binding

# Show port binding details
ovn-sbctl show

# Find port binding for specific port
ovn-sbctl find Port_Binding logical_port=<port-name>
```

**Datapath bindings:**
```bash
# List datapath bindings
ovn-sbctl list Datapath_Binding

# Show datapath details
ovn-sbctl show
```

**Flows:**
```bash
# Show logical flows
ovn-sbctl lflow-list
ovn-sbctl list Logical_Flow

# Show flows for specific datapath
ovn-sbctl lflow-list <datapath-uuid>

# Show multicast groups
ovn-sbctl list Multicast_Group
```

**General southbound database:**
```bash
# Show entire southbound database
ovn-sbctl show

# List specific table
ovn-sbctl list <table-name>

# Examples:
ovn-sbctl list Chassis
ovn-sbctl list Port_Binding
ovn-sbctl list Datapath_Binding
ovn-sbctl list Logical_Flow
```

### OVN Trace

```bash
# Trace packet through logical network
ovn-trace <datapath> 'inport=="<port>" && eth.src==<mac> && ip4.src==<ip> && ip4.dst==<ip>'

# Example: Trace TCP packet
ovn-trace --minimal <switch-name> 'inport=="pod1" && eth.src==aa:bb:cc:dd:ee:ff && ip4.src==10.128.0.5 && ip4.dst==10.128.0.6 && tcp.dst==80'

# Trace with detailed output
ovn-trace --detailed <switch-name> '<packet-spec>'

# Trace through router
ovn-trace <router-name> 'inport=="<port>" && ip4.src==<ip> && ip4.dst==<ip>'
```

### OVN on OpenShift

**Access OVN databases (on control plane):**
```bash
# Access northbound database
oc exec -n openshift-ovn-kubernetes ovnkube-master-xxxxx -c northd -- ovn-nbctl show

# Access southbound database
oc exec -n openshift-ovn-kubernetes ovnkube-master-xxxxx -c northd -- ovn-sbctl show

# List logical switches
oc exec -n openshift-ovn-kubernetes ovnkube-master-xxxxx -c northd -- ovn-nbctl ls-list

# List logical routers
oc exec -n openshift-ovn-kubernetes ovnkube-master-xxxxx -c northd -- ovn-nbctl lr-list
```

**Access OVN on node:**
```bash
# Debug into node
oc debug node/<node-name>

# In debug shell:
chroot /host

# Check OVS
ovs-vsctl show
ovs-ofctl dump-flows br-int

# Check OVN
ovn-sbctl show
```

---

## The 4 Traffic Flows in OpenShift

### 1. Pod-to-Pod Traffic (Same Node)

**Verification commands:**
```bash
# Check OVS flows for local delivery
ovs-ofctl dump-flows br-int | grep "nw_dst=<pod-ip>"

# Trace packet
ovs-appctl ofproto/trace br-int in_port=<port>,ip,nw_src=<src-ip>,nw_dst=<dst-ip>

# Check OVN logical flows
ovn-sbctl lflow-list | grep <pod-ip>
```

**Flow path:**
```
Pod1 → veth → br-int (OVS) → veth → Pod2
```

### 2. Pod-to-Pod Traffic (Different Nodes)

**Verification commands:**
```bash
# Check tunnel ports
ovs-vsctl show | grep -A 5 geneve

# Check tunnel flows
ovs-ofctl dump-flows br-int | grep tun_id

# Verify Geneve tunnels
ip -d link show | grep geneve

# Check routing between nodes
ip route | grep ovn
```

**Flow path:**
```
Pod1 → veth → br-int → Geneve tunnel → Remote Node → br-int → veth → Pod2
```

### 3. Pod-to-Service (ClusterIP)

**Verification commands:**
```bash
# Check load balancer in OVN
ovn-nbctl lb-list
ovn-nbctl list Load_Balancer

# Check service endpoints
oc get endpoints <service-name>

# Check OVN ACLs
ovn-nbctl acl-list <switch-name>

# Trace service traffic
ovn-trace <switch-name> 'inport=="<port>" && ip4.dst==<cluster-ip> && tcp.dst==<port>'
```

**Flow path:**
```
Pod → br-int → OVN Load Balancer (DNAT) → Backend Pod
```

### 4. External-to-Pod (Route/Ingress)

**Verification commands:**
```bash
# Check routes
oc get routes

# Check router pods
oc get pods -n openshift-ingress

# Check HAProxy config
oc exec -n openshift-ingress router-default-xxxxx -- cat /var/lib/haproxy/conf/haproxy.config

# Check route details
oc describe route <route-name>

# Test route
curl -v http://<route-hostname>
```

**Flow path:**
```
External → HAProxy (router pod) → Service → Backend Pod
```

---

## OpenShift Routes

### Route Management

**Create routes:**
```bash
# Expose service as route
oc expose service <service-name>

# Create route with custom hostname
oc expose service <service-name> --hostname=app.example.com

# Create secure route (edge termination)
oc create route edge --service=<service-name>

# Create secure route (passthrough)
oc create route passthrough --service=<service-name>

# Create secure route (re-encrypt)
oc create route reencrypt --service=<service-name>

# Create route with path
oc expose service <service-name> --path=/api
```

**View routes:**
```bash
# List routes
oc get routes

# Get route details
oc describe route <route-name>

# Get route YAML
oc get route <route-name> -o yaml

# Get route hostname
oc get route <route-name> -o jsonpath='{.spec.host}'

# Show all routes across all projects
oc get routes -A
```

**Test routes:**
```bash
# Get route hostname
ROUTE=$(oc get route <route-name> -o jsonpath='{.spec.host}')

# Test HTTP route
curl -v http://$ROUTE

# Test HTTPS route
curl -v https://$ROUTE

# Test with specific path
curl -v http://$ROUTE/api

# Test with host header
curl -v -H "Host: $ROUTE" http://<router-ip>
```

### Route Types

| Type | TLS Termination | Use Case |
|------|----------------|----------|
| Edge | At router | Most common, router handles TLS |
| Passthrough | At pod | End-to-end encryption, router just forwards |
| Re-encrypt | At router & pod | Re-encrypt traffic to backend |

### HAProxy (Router) Debugging

**Check router pods:**
```bash
# Get router pods
oc get pods -n openshift-ingress

# Check router logs
oc logs -n openshift-ingress router-default-xxxxx

# Follow router logs
oc logs -n openshift-ingress router-default-xxxxx -f

# Get specific request logs
oc logs -n openshift-ingress router-default-xxxxx | grep "GET /api"
```

**Inspect HAProxy configuration:**
```bash
# View HAProxy config
oc exec -n openshift-ingress router-default-xxxxx -- cat /var/lib/haproxy/conf/haproxy.config

# Check for specific route
oc exec -n openshift-ingress router-default-xxxxx -- cat /var/lib/haproxy/conf/haproxy.config | grep <route-name>

# View backend servers
oc exec -n openshift-ingress router-default-xxxxx -- cat /var/lib/haproxy/conf/haproxy.config | grep "server "

# Check HAProxy stats
oc exec -n openshift-ingress router-default-xxxxx -- cat /var/lib/haproxy/conf/haproxy.config | grep stats
```

**HAProxy statistics:**
```bash
# Access stats page (if enabled)
# Usually at: http://<router-ip>:1936/

# Check connection stats
oc exec -n openshift-ingress router-default-xxxxx -- ss -s

# Check open connections
oc exec -n openshift-ingress router-default-xxxxx -- ss -tn
```

**Test route from router pod:**
```bash
# Execute in router pod
oc exec -n openshift-ingress router-default-xxxxx -- curl -v http://<service-name>.<namespace>.svc.cluster.local

# Test with specific Host header
oc exec -n openshift-ingress router-default-xxxxx -- curl -v -H "Host: <route-hostname>" http://localhost:80
```

---

## DNS Operator

### DNS Operator Management

```bash
# Get DNS operator
oc get clusteroperator dns

# Check DNS operator status
oc describe clusteroperator dns

# Get DNS pods
oc get pods -n openshift-dns

# Check CoreDNS pods
oc get pods -n openshift-dns -l dns.operator.openshift.io/daemonset-dns=default

# View DNS operator logs
oc logs -n openshift-dns-operator deployment/dns-operator
```

### CoreDNS Configuration

```bash
# Get DNS configuration
oc get dns.operator cluster -o yaml

# Check CoreDNS ConfigMap
oc get configmap -n openshift-dns dns-default -o yaml

# View Corefile
oc exec -n openshift-dns dns-default-xxxxx -- cat /etc/coredns/Corefile

# Check DNS service
oc get svc -n openshift-dns dns-default
```

### DNS Troubleshooting

```bash
# Test DNS from pod
oc exec <pod-name> -- nslookup kubernetes.default

# Test specific service
oc exec <pod-name> -- nslookup <service-name>.<namespace>.svc.cluster.local

# Test external DNS
oc exec <pod-name> -- nslookup google.com

# Check pod DNS config
oc exec <pod-name> -- cat /etc/resolv.conf

# View DNS logs
oc logs -n openshift-dns dns-default-xxxxx

# Follow DNS query logs
oc logs -n openshift-dns dns-default-xxxxx -f | grep query
```

**Custom DNS configuration:**
```bash
# Add custom DNS server
oc edit dns.operator cluster

# Add in spec:
spec:
  servers:
  - name: custom
    zones:
    - example.com
    forwardPlugin:
      upstreams:
      - 1.1.1.1
```

---

## EgressIP

### EgressIP Configuration

**View EgressIPs:**
```bash
# Get EgressIP objects
oc get egressip

# Describe EgressIP
oc describe egressip <egressip-name>

# Get EgressIP YAML
oc get egressip <egressip-name> -o yaml

# Check EgressIP status
oc get egressip -o jsonpath='{.items[*].status}'
```

**Create EgressIP:**
```yaml
apiVersion: k8s.ovn.org/v1
kind: EgressIP
metadata:
  name: project-a-egress
spec:
  egressIPs:
  - 192.168.10.100
  namespaceSelector:
    matchLabels:
      egress: allowed
  podSelector:
    matchLabels:
      app: web
```

```bash
# Apply EgressIP
oc apply -f egressip.yaml

# Label namespace to use EgressIP
oc label namespace <namespace> egress=allowed

# Label pods to use EgressIP
oc label pod <pod-name> app=web
```

**Verify EgressIP:**
```bash
# Check which node has the EgressIP
oc get egressip -o jsonpath='{.items[*].status.items[*].node}'

# Check EgressIP status
oc get egressip <egressip-name> -o jsonpath='{.status}'

# Test from pod
oc exec <pod-name> -- curl ifconfig.me

# Should return the EgressIP address
```

**Configure nodes for EgressIP:**
```bash
# Label nodes that can host EgressIP
oc label node <node-name> k8s.ovn.org/egress-assignable=""

# Remove label
oc label node <node-name> k8s.ovn.org/egress-assignable-

# Check which nodes can host EgressIP
oc get nodes -l k8s.ovn.org/egress-assignable
```

### EgressIP Troubleshooting

```bash
# 1. Check EgressIP object
oc get egressip <egressip-name> -o yaml

# 2. Verify node labels
oc get nodes -l k8s.ovn.org/egress-assignable

# 3. Check namespace labels
oc get namespace <namespace> --show-labels

# 4. Check pod labels
oc get pods --show-labels

# 5. Check EgressIP assignment
oc get egressip -o jsonpath='{.items[*].status}'

# 6. Check OVN configuration
oc exec -n openshift-ovn-kubernetes ovnkube-master-xxxxx -c northd -- ovn-nbctl lr-route-list

# 7. Test from pod
oc exec <pod-name> -- curl ifconfig.me

# 8. Check logs
oc logs -n openshift-ovn-kubernetes ovnkube-node-xxxxx -c ovnkube-node
```

---

## EgressNetworkPolicy (Legacy)

### EgressNetworkPolicy Management

**Note:** EgressNetworkPolicy is deprecated. Use EgressFirewall instead.

**View EgressNetworkPolicy:**
```bash
# Get EgressNetworkPolicy
oc get egressnetworkpolicy -n <namespace>

# Describe
oc describe egressnetworkpolicy -n <namespace>
```

**Create EgressNetworkPolicy:**
```yaml
apiVersion: network.openshift.io/v1
kind: EgressNetworkPolicy
metadata:
  name: default
  namespace: myproject
spec:
  egress:
  - type: Allow
    to:
      cidrSelector: 1.2.3.0/24
  - type: Deny
    to:
      cidrSelector: 0.0.0.0/0
```

---

## EgressFirewall (Preferred)

### EgressFirewall Configuration

**View EgressFirewall:**
```bash
# Get EgressFirewall
oc get egressfirewall -n <namespace>

# Describe
oc describe egressfirewall -n <namespace>

# Get YAML
oc get egressfirewall -n <namespace> -o yaml
```

**Create EgressFirewall:**
```yaml
apiVersion: k8s.ovn.org/v1
kind: EgressFirewall
metadata:
  name: default
  namespace: myproject
spec:
  egress:
  - type: Allow
    to:
      cidrSelector: 1.2.3.0/24
  - type: Allow
    to:
      dnsName: www.example.com
  - type: Deny
    to:
      cidrSelector: 0.0.0.0/0
```

```bash
# Apply EgressFirewall
oc apply -f egressfirewall.yaml

# Test from pod
oc exec <pod-name> -- curl http://1.2.3.4   # Should succeed
oc exec <pod-name> -- curl http://8.8.8.8   # Should fail
```

---

## NetworkPolicy (OpenShift)

### NetworkPolicy Management

```bash
# List NetworkPolicies
oc get networkpolicy
oc get netpol

# Describe NetworkPolicy
oc describe networkpolicy <policy-name>

# Get YAML
oc get networkpolicy <policy-name> -o yaml

# Delete NetworkPolicy
oc delete networkpolicy <policy-name>
```

### Common NetworkPolicy Examples

**Deny all ingress:**
```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

**Allow from same namespace:**
```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: allow-same-namespace
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
```

**Allow from specific namespace:**
```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: allow-from-namespace
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
```

**Allow from OpenShift Ingress:**
```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: allow-from-openshift-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          network.openshift.io/policy-group: ingress
```

---

## Troubleshooting Workflows

### Route Not Working

```bash
# 1. Check route exists
oc get route <route-name>

# 2. Check route hostname
oc get route <route-name> -o jsonpath='{.spec.host}'

# 3. Check service exists
oc get svc <service-name>

# 4. Check service endpoints
oc get endpoints <service-name>

# 5. Test DNS resolution
nslookup <route-hostname>

# 6. Check router pods
oc get pods -n openshift-ingress

# 7. Check router logs
oc logs -n openshift-ingress router-default-xxxxx | grep <route-name>

# 8. Test from router pod
oc exec -n openshift-ingress router-default-xxxxx -- curl -v http://<service-name>.<namespace>.svc

# 9. Check HAProxy config
oc exec -n openshift-ingress router-default-xxxxx -- cat /var/lib/haproxy/conf/haproxy.config | grep <route-name>
```

### Pod-to-Pod Connectivity Issues

```bash
# 1. Check OVN pods are running
oc get pods -n openshift-ovn-kubernetes

# 2. Check OVN logs
oc logs -n openshift-ovn-kubernetes ovnkube-node-xxxxx -c ovnkube-node

# 3. Check OVS on node
oc debug node/<node-name>
chroot /host
ovs-vsctl show
ovs-ofctl dump-flows br-int

# 4. Check NetworkPolicy
oc get networkpolicy

# 5. Test connectivity
oc exec <pod-name> -- ping <other-pod-ip>

# 6. Check OVN logical topology
oc exec -n openshift-ovn-kubernetes ovnkube-master-xxxxx -c northd -- ovn-nbctl show
```

### EgressIP Not Working

```bash
# See "EgressIP Troubleshooting" section above
```

---

## Quick Reference

### Get Cluster Network Config
```bash
oc get network.config cluster -o yaml
```

### Check OVN Health
```bash
oc get pods -n openshift-ovn-kubernetes
oc get clusteroperator network
```

### Test Route from Outside
```bash
curl -v -H "Host: <route-hostname>" http://<router-lb-ip>
```

### Get Pod IP and Node
```bash
oc get pods -o wide
```

### Quick OVS Flow Check
```bash
oc debug node/<node> -- chroot /host ovs-ofctl dump-flows br-int | head -20
```

### Check Service from Pod
```bash
oc exec <pod> -- curl -v http://<service-name>:<port>
```

---

## Performance Monitoring

### OVN Performance

```bash
# Check OVN CPU/Memory
oc adm top pods -n openshift-ovn-kubernetes

# Check flow table size
oc debug node/<node> -- chroot /host ovs-ofctl dump-flows br-int | wc -l

# Check OVS statistics
oc debug node/<node> -- chroot /host ovs-vsctl get bridge br-int statistics
```

### Router Performance

```bash
# Check router resource usage
oc adm top pods -n openshift-ingress

# Check active connections
oc exec -n openshift-ingress router-default-xxxxx -- ss -s

# Monitor router logs for slow requests
oc logs -n openshift-ingress router-default-xxxxx | grep -E "backend.*[0-9]{4}ms"
```

---

## Important Locations

### Configuration Files (on nodes)

```
/etc/cni/net.d/                    # CNI configuration
/var/lib/cni/                      # CNI state
/var/run/openvswitch/              # OVS runtime
/etc/openvswitch/                  # OVS configuration
/var/log/openvswitch/              # OVS logs
```

### OpenShift Namespaces

```
openshift-ovn-kubernetes           # OVN pods
openshift-dns                      # DNS pods
openshift-ingress                  # Router pods
openshift-dns-operator             # DNS operator
openshift-network-operator         # Network operator
openshift-sdn (if using SDN)       # SDN pods (legacy)
```

---

## Common Issues & Solutions

| Issue | Check | Solution |
|-------|-------|----------|
| Route returns 503 | Check endpoints | Verify pods are ready, service selector matches |
| Route returns 404 | Check HAProxy config | Verify route path, backend configuration |
| Pod cannot reach external | Check EgressFirewall | Add allow rule or check node routing |
| EgressIP not assigned | Check node labels | Label node with egress-assignable |
| DNS not resolving | Check DNS pods | Verify CoreDNS pods running, check logs |
| Pod-to-pod timeout | Check OVN/OVS | Verify OVN pods, check flow tables, NetworkPolicy |
| Service ClusterIP timeout | Check endpoints | Verify OVN load balancer, check pod status |
