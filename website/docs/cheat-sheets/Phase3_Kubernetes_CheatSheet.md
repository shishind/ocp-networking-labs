# Phase 3: Kubernetes Networking Command Reference
**Week 5-6 Labs | K8s Services, DNS, NetworkPolicy, CNI**

---

## kubectl/oc Basic Commands

### Cluster & Context

```bash
# View cluster info
kubectl cluster-info
oc cluster-info

# Get current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Switch context
kubectl config use-context <context-name>

# View kubeconfig
kubectl config view

# Get cluster nodes
kubectl get nodes
kubectl get nodes -o wide
```

### Resource Operations

```bash
# Get resources
kubectl get pods
kubectl get pods -o wide
kubectl get pods -A              # All namespaces
kubectl get pods -n namespace    # Specific namespace
kubectl get pods --show-labels
kubectl get pods -l app=nginx    # Label selector

# Describe resources (detailed info)
kubectl describe pod podname
kubectl describe svc servicename

# Get YAML/JSON output
kubectl get pod podname -o yaml
kubectl get pod podname -o json

# Watch resources
kubectl get pods -w
kubectl get pods -w -n namespace
```

### Working with Namespaces

```bash
# List namespaces
kubectl get namespaces
kubectl get ns

# Create namespace
kubectl create namespace myns

# Set default namespace for context
kubectl config set-context --current --namespace=myns

# Delete namespace
kubectl delete namespace myns
```

---

## Services & Endpoints

### Service Management

**View services:**
```bash
# List services
kubectl get svc
kubectl get services
kubectl get svc -A
kubectl get svc -o wide

# Describe service
kubectl describe svc servicename

# Get service YAML
kubectl get svc servicename -o yaml

# Get service endpoints
kubectl get endpoints servicename
kubectl get ep servicename
```

**Create services:**
```bash
# Create ClusterIP service (default)
kubectl create service clusterip myservice --tcp=80:8080

# Expose deployment as service
kubectl expose deployment myapp --port=80 --target-port=8080

# Create NodePort service
kubectl create service nodeport myservice --tcp=80:8080 --node-port=30080

# Create LoadBalancer service
kubectl create service loadbalancer myservice --tcp=80:8080

# Create service from YAML
kubectl apply -f service.yaml
```

**Service types:**
```yaml
# ClusterIP - Internal only
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080

# NodePort - Exposes on node IP:port
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080

# LoadBalancer - Cloud load balancer
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
```

### Endpoint Debugging

```bash
# Get endpoints
kubectl get endpoints
kubectl get ep

# Describe endpoints
kubectl describe endpoints servicename

# Get endpoint IPs
kubectl get endpoints servicename -o jsonpath='{.subsets[*].addresses[*].ip}'

# Check if endpoints are populated
kubectl get ep servicename -o yaml

# Common issue: No endpoints
# Check: Pod labels match service selector
kubectl get pod podname --show-labels
kubectl get svc servicename -o jsonpath='{.spec.selector}'
```

### Service Troubleshooting Workflow

**When service is not working:**

```bash
# 1. Check service exists
kubectl get svc servicename

# 2. Check endpoints are populated
kubectl get ep servicename

# 3. If no endpoints, check pod selector
kubectl get svc servicename -o yaml | grep -A 5 selector
kubectl get pods --show-labels

# 4. Check pod readiness
kubectl get pods
kubectl describe pod podname

# 5. Check service port configuration
kubectl get svc servicename -o yaml | grep -A 10 ports

# 6. Test from within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Inside pod:
wget -qO- http://servicename
nslookup servicename

# 7. Check kube-proxy
kubectl get pods -n kube-system | grep kube-proxy
kubectl logs -n kube-system kube-proxy-xxxxx

# 8. Check iptables/IPVS rules (on node)
sudo iptables-save | grep servicename
sudo ipvsadm -Ln
```

---

## DNS in Kubernetes

### DNS Query Commands

**From within a pod:**
```bash
# Test DNS resolution
kubectl exec -it podname -- nslookup kubernetes.default

# Query service in same namespace
kubectl exec -it podname -- nslookup servicename

# Query service in different namespace
kubectl exec -it podname -- nslookup servicename.namespace

# Query full FQDN
kubectl exec -it podname -- nslookup servicename.namespace.svc.cluster.local

# Use dig for more details
kubectl exec -it podname -- dig servicename

# Check DNS server being used
kubectl exec -it podname -- cat /etc/resolv.conf
```

### DNS Naming Convention

| DNS Name | Resolves To |
|----------|-------------|
| `servicename` | Service in same namespace |
| `servicename.namespace` | Service in specific namespace |
| `servicename.namespace.svc` | Service (explicit) |
| `servicename.namespace.svc.cluster.local` | Fully qualified domain name |
| `pod-ip.namespace.pod.cluster.local` | Specific pod (IP with dashes) |

**Examples:**
```bash
# Service: myapp in namespace: prod
myapp                                    # From within prod namespace
myapp.prod                              # From any namespace
myapp.prod.svc.cluster.local           # FQDN

# Pod with IP 10.244.1.5 in namespace: prod
10-244-1-5.prod.pod.cluster.local
```

### CoreDNS Troubleshooting

```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get pods -n kube-system | grep coredns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system coredns-xxxxx

# Follow CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns -f

# Check CoreDNS ConfigMap
kubectl get configmap -n kube-system coredns -o yaml
kubectl describe configmap -n kube-system coredns

# Check CoreDNS service
kubectl get svc -n kube-system kube-dns
kubectl describe svc -n kube-system kube-dns

# Test DNS from debug pod
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# In pod:
nslookup kubernetes.default
nslookup kube-dns.kube-system
cat /etc/resolv.conf
```

### DNS Troubleshooting Workflow

**When DNS is broken:**

```bash
# 1. Check pod DNS configuration
kubectl exec podname -- cat /etc/resolv.conf

# 2. Check CoreDNS pods are running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 3. Check CoreDNS service
kubectl get svc -n kube-system kube-dns

# 4. Check CoreDNS endpoints
kubectl get ep -n kube-system kube-dns

# 5. Test basic DNS
kubectl exec podname -- nslookup kubernetes.default

# 6. Check CoreDNS logs for errors
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50

# 7. Verify CoreDNS ConfigMap
kubectl get cm -n kube-system coredns -o yaml

# 8. Test external DNS
kubectl exec podname -- nslookup google.com

# 9. Restart CoreDNS if needed
kubectl rollout restart -n kube-system deployment/coredns
```

---

## NetworkPolicy

### View NetworkPolicies

```bash
# List network policies
kubectl get networkpolicy
kubectl get netpol
kubectl get networkpolicies -A

# Describe network policy
kubectl describe networkpolicy policyname

# Get YAML
kubectl get networkpolicy policyname -o yaml
```

### NetworkPolicy Examples

**Deny all ingress:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

**Allow from specific namespace:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-namespace
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: allowed-namespace
```

**Allow specific port:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-port-80
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  ingress:
  - ports:
    - protocol: TCP
      port: 80
```

**Allow from specific pods:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

### NetworkPolicy Testing

```bash
# Create test pods
kubectl run frontend --image=busybox --labels=app=frontend -- sleep 3600
kubectl run backend --image=nginx --labels=app=backend

# Test connectivity before policy
kubectl exec frontend -- wget -qO- http://backend

# Apply network policy
kubectl apply -f networkpolicy.yaml

# Test connectivity after policy
kubectl exec frontend -- wget -qO- http://backend --timeout=5

# Check which policies apply to a pod
kubectl get networkpolicy
kubectl describe pod podname | grep -i label
kubectl get networkpolicy -o yaml | grep -A 5 podSelector
```

---

## CNI (Container Network Interface)

### View CNI Configuration

```bash
# Check CNI config directory (on node)
ls /etc/cni/net.d/

# View CNI config
cat /etc/cni/net.d/10-calico.conflist
cat /etc/cni/net.d/10-flannel.conflist

# Check CNI binary directory
ls /opt/cni/bin/
```

### CNI Plugin Pods

**Calico:**
```bash
# Get Calico pods
kubectl get pods -n kube-system -l k8s-app=calico-node

# Check Calico logs
kubectl logs -n kube-system -l k8s-app=calico-node

# Calico node status
kubectl exec -n kube-system calico-node-xxxxx -- calicoctl node status

# View Calico IP pools
kubectl get ippool -A
```

**Flannel:**
```bash
# Get Flannel pods
kubectl get pods -n kube-system -l app=flannel

# Check Flannel logs
kubectl logs -n kube-system -l app=flannel
```

**Weave:**
```bash
# Get Weave pods
kubectl get pods -n kube-system -l name=weave-net

# Check Weave status
kubectl exec -n kube-system weave-net-xxxxx -c weave -- /home/weave/weave --local status
```

### Pod Networking Debugging

```bash
# Get pod IP
kubectl get pod podname -o jsonpath='{.status.podIP}'

# Get pod network details
kubectl get pod podname -o jsonpath='{.metadata.annotations}'

# Check pod network namespace (on node)
# First, find the container ID
CONTAINER_ID=$(kubectl get pod podname -o jsonpath='{.status.containerStatuses[0].containerID}' | sed 's/.*:\/\///')

# Find container process
PID=$(docker inspect -f '{{.State.Pid}}' $CONTAINER_ID)

# Check network namespace
nsenter -t $PID -n ip addr
nsenter -t $PID -n ip route
```

---

## kube-proxy & IPVS

### kube-proxy Management

```bash
# Get kube-proxy pods
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# Check kube-proxy mode
kubectl logs -n kube-system kube-proxy-xxxxx | grep "Using"

# View kube-proxy config
kubectl get configmap -n kube-system kube-proxy -o yaml

# Check kube-proxy logs
kubectl logs -n kube-system kube-proxy-xxxxx
kubectl logs -n kube-system kube-proxy-xxxxx --tail=100
```

### IPVS Mode

**View IPVS rules (on node):**
```bash
# List all virtual services
ipvsadm -Ln

# Show with stats
ipvsadm -Ln --stats

# Show with rate
ipvsadm -Ln --rate

# Show specific service
ipvsadm -Ln | grep -A 5 "10.96.0.1:443"

# Clear all rules (dangerous!)
ipvsadm -C
```

### iptables Mode

**View iptables rules (on node):**
```bash
# Show all kube-proxy chains
iptables-save | grep KUBE

# Show service NAT rules
iptables -t nat -L KUBE-SERVICES -n -v

# Show service endpoints
iptables -t nat -L KUBE-SVC-XXXXX -n -v

# Show all Kubernetes rules
iptables-save | grep -E "KUBE|kubernetes"

# Count rules
iptables-save | grep KUBE | wc -l
```

### Service Proxy Debugging

```bash
# 1. Check kube-proxy is running
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# 2. Check mode (iptables or ipvs)
kubectl logs -n kube-system kube-proxy-xxxxx | grep mode

# 3. For iptables mode (on node)
sudo iptables-save | grep <service-name>

# 4. For IPVS mode (on node)
sudo ipvsadm -Ln | grep <cluster-ip>

# 5. Check kube-proxy logs for errors
kubectl logs -n kube-system kube-proxy-xxxxx --tail=50 | grep -i error

# 6. Restart kube-proxy if needed
kubectl delete pod -n kube-system kube-proxy-xxxxx
```

---

## Pod Network Debugging

### Create Debug Pod

```bash
# BusyBox
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# Alpine with network tools
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
# Inside pod:
apk add curl bind-tools tcpdump

# Ubuntu with network tools
kubectl run -it --rm debug --image=ubuntu --restart=Never -- bash
# Inside pod:
apt update && apt install -y curl dnsutils iputils-ping netcat

# nicolaka/netshoot (comprehensive tools)
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash
```

### Test Pod Connectivity

```bash
# Test pod-to-pod (by IP)
kubectl exec podname -- ping -c 2 10.244.1.5

# Test pod-to-service (by name)
kubectl exec podname -- curl -v http://servicename

# Test pod-to-service (by ClusterIP)
kubectl exec podname -- curl -v http://10.96.0.10

# Test DNS
kubectl exec podname -- nslookup servicename
kubectl exec podname -- nslookup kubernetes.default

# Test external connectivity
kubectl exec podname -- ping -c 2 8.8.8.8
kubectl exec podname -- curl -v https://google.com

# Check routing in pod
kubectl exec podname -- ip route

# Check network interfaces in pod
kubectl exec podname -- ip addr
```

### Packet Capture in Pod

```bash
# Using tcpdump in running pod
kubectl exec podname -- tcpdump -i any -nn port 80

# Using debug container (ephemeral container)
kubectl debug -it podname --image=nicolaka/netshoot --target=podname
# Inside debug container:
tcpdump -i any -nn

# Capture to file and download
kubectl exec podname -- tcpdump -i any -w /tmp/capture.pcap -c 100
kubectl cp podname:/tmp/capture.pcap ./capture.pcap
```

---

## Ingress & Load Balancing

### Ingress Resources

```bash
# List ingress resources
kubectl get ingress
kubectl get ing

# Describe ingress
kubectl describe ingress ingressname

# Get ingress YAML
kubectl get ingress ingressname -o yaml

# Check ingress controller pods
kubectl get pods -n ingress-nginx
kubectl get pods -A | grep ingress
```

### NodePort Services

```bash
# Get NodePort services
kubectl get svc -o wide | grep NodePort

# Get node IP
kubectl get nodes -o wide

# Test NodePort access
# Access: http://<node-ip>:<node-port>

# Get node port number
kubectl get svc servicename -o jsonpath='{.spec.ports[0].nodePort}'
```

---

## Troubleshooting Workflows

### Service Not Accessible from Pod

```bash
# 1. Verify service exists
kubectl get svc servicename

# 2. Get service ClusterIP
kubectl get svc servicename -o jsonpath='{.spec.clusterIP}'

# 3. Check endpoints
kubectl get ep servicename

# 4. If no endpoints, check selector
kubectl get svc servicename -o yaml | grep -A 3 selector
kubectl get pods --show-labels

# 5. Verify pod is ready
kubectl get pods -l app=<label>
kubectl describe pod podname

# 6. Test DNS resolution
kubectl exec testpod -- nslookup servicename

# 7. Test connectivity by IP
kubectl exec testpod -- curl http://<cluster-ip>:<port>

# 8. Check NetworkPolicy
kubectl get networkpolicy
kubectl describe networkpolicy policyname

# 9. Check kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl logs -n kube-system kube-proxy-xxxxx
```

### Pod Cannot Reach Internet

```bash
# 1. Test pod can ping gateway
kubectl exec podname -- ip route
kubectl exec podname -- ping -c 2 <gateway-ip>

# 2. Test pod can reach external IP
kubectl exec podname -- ping -c 2 8.8.8.8

# 3. Test DNS
kubectl exec podname -- nslookup google.com

# 4. Check node networking (on node)
sudo ip route
sudo iptables -t nat -L POSTROUTING -n -v

# 5. Check CNI logs
kubectl logs -n kube-system -l k8s-app=calico-node
kubectl logs -n kube-system -l app=flannel

# 6. Verify pod has default route
kubectl exec podname -- ip route | grep default
```

### DNS Not Working

```bash
# See "DNS Troubleshooting Workflow" section above
```

---

## Performance & Monitoring

### Network Statistics

```bash
# Pod network I/O
kubectl top pods
kubectl top pods --containers

# Node network stats (on node)
ip -s link show

# Connection tracking
kubectl exec podname -- cat /proc/net/nf_conntrack | wc -l
```

### Service Mesh (if installed)

**Istio:**
```bash
# Get Istio pods
kubectl get pods -n istio-system

# Check sidecar injection
kubectl get pod podname -o jsonpath='{.spec.containers[*].name}'

# Istio proxy logs
kubectl logs podname -c istio-proxy
```

**Linkerd:**
```bash
# Get Linkerd pods
kubectl get pods -n linkerd

# Check if pod is meshed
kubectl get pod podname -o jsonpath='{.metadata.annotations.linkerd\.io/inject}'

# Linkerd proxy logs
kubectl logs podname -c linkerd-proxy
```

---

## Quick Reference

### Test Service from Another Pod
```bash
kubectl run -it --rm test --image=busybox --restart=Never -- wget -qO- http://servicename
```

### Get All Service ClusterIPs
```bash
kubectl get svc -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,CLUSTER-IP:.spec.clusterIP
```

### Check Pod DNS Config
```bash
kubectl exec podname -- cat /etc/resolv.conf
```

### Quick Endpoint Check
```bash
kubectl get svc servicename -o yaml | grep -A 3 selector && kubectl get ep servicename
```

### Watch Service Updates
```bash
kubectl get svc -w
```

### Get Pod IPs
```bash
kubectl get pods -o wide | awk '{print $1, $6}'
```

### Test Port Connectivity
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- nc -zv servicename 80
```

---

## Common Issues & Solutions

| Issue | Check | Solution |
|-------|-------|----------|
| Service has no endpoints | `kubectl get ep servicename` | Fix pod selector or ensure pods are ready |
| DNS not resolving | `kubectl get pods -n kube-system -l k8s-app=kube-dns` | Check CoreDNS pods, restart if needed |
| NetworkPolicy blocking | `kubectl get netpol` | Review and adjust policy rules |
| kube-proxy not working | `kubectl logs -n kube-system kube-proxy-xxx` | Check logs, verify mode (iptables/IPVS) |
| Pod cannot reach internet | Test DNS, check NAT rules | Verify CNI, check node routing/NAT |
| Wrong service port | `kubectl get svc servicename -o yaml` | Verify port/targetPort configuration |
