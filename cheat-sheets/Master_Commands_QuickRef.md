# Master Commands Quick Reference
**Essential Commands Across All Phases**

---

## 🔍 First Steps - What's Wrong?

```bash
# Pod issues
oc get pods -o wide
oc describe pod <pod-name>
oc logs <pod-name>

# Service issues
oc get svc
oc get endpoints <service-name>

# Network issues
oc get networkpolicy
oc get routes
```

---

## 📡 Network Connectivity Testing

### Basic Tests
```bash
# Test pod-to-pod
oc exec <pod> -- ping -c 2 <other-pod-ip>

# Test pod-to-service
oc exec <pod> -- curl http://<service-name>

# Test pod-to-internet
oc exec <pod> -- curl -v https://google.com

# Test DNS
oc exec <pod> -- nslookup <service-name>
oc exec <pod> -- nslookup kubernetes.default
```

### Debug Pod
```bash
# Quick debug pod
oc run -it --rm debug --image=busybox --restart=Never -- sh

# With full network tools
oc run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash

# Debug on specific node
oc debug node/<node-name>
```

---

## 🌐 DNS Troubleshooting

### Quick DNS Checks
```bash
# Check DNS resolution
oc exec <pod> -- nslookup <service-name>
oc exec <pod> -- cat /etc/resolv.conf

# Check CoreDNS
oc get pods -n openshift-dns
oc logs -n openshift-dns -l dns.operator.openshift.io/daemonset-dns=default

# Restart CoreDNS
oc delete pod -n openshift-dns -l dns.operator.openshift.io/daemonset-dns=default
```

### DNS Query Patterns
```bash
# Same namespace
nslookup servicename

# Different namespace
nslookup servicename.namespace

# Full FQDN
nslookup servicename.namespace.svc.cluster.local
```

---

## 🔌 Service & Endpoint Debugging

```bash
# Check service and endpoints together
oc get svc <service-name> && oc get ep <service-name>

# Verify selector matches pods
oc get svc <service-name> -o yaml | grep -A 3 selector
oc get pods --show-labels

# Get service ClusterIP
oc get svc <service-name> -o jsonpath='{.spec.clusterIP}'

# Get endpoint IPs
oc get ep <service-name> -o jsonpath='{.subsets[*].addresses[*].ip}'
```

**Common Issues:**
- No endpoints → Labels don't match
- Endpoints exist but service fails → Check pod readiness

---

## 🚪 Route Troubleshooting

```bash
# Check route
oc get route <route-name>
oc describe route <route-name>

# Get route hostname
oc get route <route-name> -o jsonpath='{.spec.host}'

# Test route
ROUTE=$(oc get route <route-name> -o jsonpath='{.spec.host}')
curl -v http://$ROUTE

# Check router pods
oc get pods -n openshift-ingress
oc logs -n openshift-ingress router-default-xxxxx | grep <route-name>
```

---

## 🔐 NetworkPolicy Quick Check

```bash
# List policies
oc get networkpolicy

# Describe policy
oc describe networkpolicy <policy-name>

# Check if policy applies to pod
oc get pods --show-labels
oc get networkpolicy <policy-name> -o yaml | grep -A 5 podSelector

# Test before/after policy
oc exec <pod-a> -- curl http://<pod-b-ip>
oc apply -f policy.yaml
oc exec <pod-a> -- curl --max-time 5 http://<pod-b-ip>
```

---

## 🌉 OVS/OVN Quick Commands

### On Node (via debug)
```bash
# Enter node
oc debug node/<node-name>
chroot /host

# Check OVS
ovs-vsctl show
ovs-ofctl dump-flows br-int | head -20

# Check interfaces
ip link show
ip addr show
```

### From Master Pod
```bash
# Check OVN logical topology
oc exec -n openshift-ovn-kubernetes ovnkube-master-xxxxx -c northd -- ovn-nbctl show

# List logical switches
oc exec -n openshift-ovn-kubernetes ovnkube-master-xxxxx -c northd -- ovn-nbctl ls-list

# Check load balancers (services)
oc exec -n openshift-ovn-kubernetes ovnkube-master-xxxxx -c northd -- ovn-nbctl lb-list
```

---

## 📤 EgressIP Quick Commands

```bash
# Check EgressIP
oc get egressip
oc describe egressip <egressip-name>

# Verify node labels
oc get nodes -l k8s.ovn.org/egress-assignable

# Test from pod
oc exec <pod> -- curl ifconfig.me

# Check assignment
oc get egressip -o jsonpath='{.items[*].status}'
```

---

## 📦 Container/Namespace Basics

### Network Namespaces
```bash
# Create and use namespace
ip netns add myns
ip netns exec myns bash

# List namespaces
ip netns list

# Execute in namespace
ip netns exec myns ip addr
```

### veth Pairs
```bash
# Create pair
ip link add veth0 type veth peer name veth1

# Move to namespace
ip link set veth1 netns myns

# Configure
ip addr add 10.0.0.1/24 dev veth0
ip link set veth0 up
```

### Docker Quick
```bash
# Get container IP
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container>

# Enter container namespace
PID=$(docker inspect -f '{{.State.Pid}}' <container>)
nsenter -t $PID -n bash
```

---

## 📊 Packet Capture

### tcpdump Essentials
```bash
# Capture on interface
tcpdump -i eth0 -nn

# Specific port
tcpdump -i eth0 port 80 -nn

# Specific host
tcpdump -i eth0 host 10.0.0.5 -nn

# Save to file
tcpdump -i eth0 -w capture.pcap

# Read file
tcpdump -r capture.pcap
```

### In Kubernetes/OpenShift
```bash
# Capture in pod
oc exec <pod> -- tcpdump -i any -nn port 80

# Capture on node
oc debug node/<node>
chroot /host
tcpdump -i any -nn host <pod-ip>
```

---

## 🔥 iptables Quick Reference

```bash
# View rules
iptables -L -v -n
iptables -t nat -L -v -n

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Simple NAT (masquerade)
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Port forward
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 192.168.1.10:80

# Allow connection
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
```

---

## 🛤️ Routing Quick Commands

```bash
# Show routes
ip route show
ip route get 8.8.8.8

# Add default gateway
ip route add default via 192.168.1.1

# Add specific route
ip route add 10.0.0.0/8 via 192.168.1.254

# Check ARP
ip neigh show
```

---

## 🔧 systemd & Services

```bash
# Service status
systemctl status <service>

# Start/stop/restart
systemctl start <service>
systemctl restart <service>

# Enable/disable
systemctl enable <service>

# View logs
journalctl -u <service>
journalctl -u <service> -f
journalctl -u <service> --since "10 min ago"
```

---

## 🔎 Common Troubleshooting Workflows

### Service Not Accessible

1. **Check service exists**
   ```bash
   oc get svc <service-name>
   ```

2. **Check endpoints**
   ```bash
   oc get ep <service-name>
   ```

3. **If no endpoints - check labels**
   ```bash
   oc get svc <service-name> -o yaml | grep -A 3 selector
   oc get pods --show-labels
   ```

4. **If endpoints exist - check pods**
   ```bash
   oc get pods
   oc describe pod <pod-name>
   ```

5. **Test connectivity**
   ```bash
   oc run -it --rm test --image=busybox --restart=Never -- wget -qO- http://<service-name>
   ```

### Route Returns 503

1. **Check route**
   ```bash
   oc get route <route-name>
   ```

2. **Check service endpoints**
   ```bash
   oc get ep <service-name>
   ```

3. **Check pods are ready**
   ```bash
   oc get pods
   ```

4. **Check router logs**
   ```bash
   oc logs -n openshift-ingress router-default-xxxxx | grep <route-name>
   ```

### DNS Not Working

1. **Check CoreDNS pods**
   ```bash
   oc get pods -n openshift-dns
   ```

2. **Test basic resolution**
   ```bash
   oc exec <pod> -- nslookup kubernetes.default
   ```

3. **Check DNS config in pod**
   ```bash
   oc exec <pod> -- cat /etc/resolv.conf
   ```

4. **Check CoreDNS logs**
   ```bash
   oc logs -n openshift-dns -l dns.operator.openshift.io/daemonset-dns=default
   ```

### Pod Cannot Reach Internet

1. **Test by IP first (eliminate DNS)**
   ```bash
   oc exec <pod> -- ping -c 2 8.8.8.8
   ```

2. **Check default route in pod**
   ```bash
   oc exec <pod> -- ip route
   ```

3. **Check EgressFirewall**
   ```bash
   oc get egressfirewall
   ```

4. **Check node networking**
   ```bash
   oc debug node/<node>
   chroot /host
   ip route
   iptables -t nat -L -v -n
   ```

---

## 📝 Quick IP/Port Reference

### Reserved IPs
- `10.0.0.0/8` - Private Class A
- `172.16.0.0/12` - Private Class B
- `192.168.0.0/16` - Private Class C
- `127.0.0.0/8` - Loopback
- `169.254.0.0/16` - Link-local

### Common Ports
| Port | Service |
|------|---------|
| 22 | SSH |
| 53 | DNS |
| 80 | HTTP |
| 443 | HTTPS |
| 6443 | Kubernetes API |
| 8080 | HTTP Alt |
| 3306 | MySQL |
| 5432 | PostgreSQL |

### OpenShift Defaults
- **Pod CIDR**: Usually `10.128.0.0/14`
- **Service CIDR**: Usually `172.30.0.0/16`
- **API Server**: Port `6443`
- **Router HTTP**: Port `80`
- **Router HTTPS**: Port `443`

---

## 🚀 One-Liner Utilities

```bash
# Get all pod IPs
oc get pods -o wide | awk '{print $1, $6}'

# Get all service ClusterIPs
oc get svc -o custom-columns=NAME:.metadata.name,CLUSTER-IP:.spec.clusterIP

# Check which pods are not Ready
oc get pods --field-selector=status.phase!=Running

# Find pods on specific node
oc get pods -o wide --all-namespaces | grep <node-name>

# Get pod CPU/Memory usage
oc adm top pods

# Get node CPU/Memory usage
oc adm top nodes

# Watch pod status
watch -n 2 'oc get pods'

# Get events sorted by time
oc get events --sort-by='.lastTimestamp'

# Quick pod shell
oc exec -it <pod-name> -- /bin/bash

# Copy file from pod
oc cp <pod-name>:/path/to/file ./local-file

# Port forward to pod
oc port-forward <pod-name> 8080:80
```

---

## 🎯 Essential oc/kubectl Commands

```bash
# Get resources
oc get pods
oc get svc
oc get routes
oc get nodes

# All namespaces
oc get pods -A
oc get svc -A

# Wide output
oc get pods -o wide

# YAML/JSON output
oc get pod <name> -o yaml
oc get pod <name> -o json

# Describe (detailed info)
oc describe pod <name>
oc describe svc <name>

# Logs
oc logs <pod-name>
oc logs <pod-name> -f
oc logs <pod-name> --previous

# Execute command
oc exec <pod> -- <command>
oc exec -it <pod> -- bash

# Delete
oc delete pod <name>
oc delete svc <name>

# Apply YAML
oc apply -f file.yaml

# Create from command
oc create deployment nginx --image=nginx
oc expose deployment nginx --port=80
```

---

## 💡 Pro Tips

### Quick Service Test
```bash
# One command to test service
oc run -it --rm test --image=busybox --restart=Never -- wget -qO- http://servicename
```

### Quick Route Test
```bash
# Get and test in one go
curl -v http://$(oc get route <route-name> -o jsonpath='{.spec.host}')
```

### Quick Endpoint Check
```bash
# See if service has backends
oc get svc,ep | grep <service-name>
```

### Monitor Real-time
```bash
# Watch multiple resources
watch -n 1 'oc get pods,svc,ep'
```

### Get Shell with Network Tools
```bash
# Always available debug pod
oc run netdebug --image=nicolaka/netshoot --command -- sleep infinity
oc exec -it netdebug -- bash
# When done: oc delete pod netdebug
```

---

## 🔗 Quick Links to Full Cheat Sheets

- **Phase 1**: Core Networking (IP, DNS, routing, iptables)
- **Phase 2**: Linux Containers (namespaces, veth, bridge, Docker)
- **Phase 3**: Kubernetes (Services, DNS, NetworkPolicy, CNI)
- **Phase 4**: OpenShift (OVS, OVN, Routes, EgressIP)

---

## 📞 When Things Break

**First 5 Commands:**
```bash
1. oc get pods -o wide
2. oc get svc
3. oc get ep <service-name>
4. oc describe pod <pod-name>
5. oc logs <pod-name>
```

**If DNS:**
```bash
oc get pods -n openshift-dns
oc exec <pod> -- nslookup kubernetes.default
```

**If Network:**
```bash
oc get networkpolicy
oc get pods -n openshift-ovn-kubernetes
```

**If Route:**
```bash
oc get routes
oc get pods -n openshift-ingress
oc logs -n openshift-ingress router-default-xxxxx
```

---

**Remember:** Start simple, eliminate variables, test one thing at a time.
