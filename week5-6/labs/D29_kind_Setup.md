# Day 29: Setting Up kind for Local Kubernetes

## Learning Objectives
By the end of this lab, you will:
- Understand what kind (Kubernetes IN Docker) is and why it's useful
- Install kind on your local machine
- Create a multi-node Kubernetes cluster
- Verify cluster health and basic functionality
- Navigate between kind clusters and understand kubeconfig context

## Plain English Explanation

**What is kind?**

Think of kind as a "miniature Kubernetes factory" that runs entirely on your laptop. Instead of needing expensive cloud resources or multiple physical machines, kind creates a complete Kubernetes cluster using Docker containers as "fake" nodes.

**Why do we use kind?**

- **Cost**: Completely free, no cloud bills
- **Speed**: Spin up a cluster in under 2 minutes
- **Safety**: Experiment without fear of breaking production
- **Learning**: Perfect for understanding OpenShift Container Platform (OCP) networking concepts

**How does it work?**

Each "node" in your kind cluster is actually just a Docker container that runs all the Kubernetes components (kubelet, kube-proxy, etc.). When you create a 2-node cluster, kind starts 2 containers that talk to each other like real servers would.

**The Connection to OpenShift**

OpenShift runs on Kubernetes, so everything you learn about Kubernetes networking applies directly to OCP. The kubectl commands you use with kind work almost identically with `oc` in OpenShift.

## Hands-On Lab

### Exercise 1: Install kind

**Goal**: Get kind installed and verify it works.

```bash
# Download kind binary (Linux)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify installation
kind version

# Expected output:
# kind v0.20.0 go1.20.4 linux/amd64
```

**For macOS**:
```bash
brew install kind
```

**For Windows**:
```powershell
choco install kind
```

**What just happened?**
You downloaded a single binary that contains all the logic to create Kubernetes clusters using Docker.

### Exercise 2: Create Your First Cluster

**Goal**: Create a simple single-node cluster.

```bash
# Create a cluster named "learning"
kind create cluster --name learning

# This will:
# 1. Pull the kindest/node Docker image
# 2. Create a container running Kubernetes
# 3. Configure kubectl to talk to it

# Wait for output:
# Creating cluster "learning" ...
# ✓ Ensuring node image (kindest/node:v1.27.3) 🖼
# ✓ Preparing nodes 📦
# ✓ Writing configuration 📜
# ✓ Starting control-plane 🕹️
# ✓ Installing CNI 🔌
# ✓ Installing StorageClass 💾
# Set kubectl context to "kind-learning"
```

**Verify the cluster**:
```bash
# Check nodes
kubectl get nodes

# Expected output:
# NAME                     STATUS   ROLES           AGE   VERSION
# learning-control-plane   Ready    control-plane   1m    v1.27.3

# Check system pods
kubectl get pods -n kube-system

# You should see:
# - coredns pods (DNS)
# - etcd (database)
# - kube-apiserver
# - kube-controller-manager
# - kube-proxy
# - kindnet (CNI plugin)
```

### Exercise 3: Create a Multi-Node Cluster

**Goal**: Create a 2-node cluster to simulate a real environment.

First, delete the single-node cluster:
```bash
kind delete cluster --name learning
```

Create a configuration file:
```bash
cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
EOF
```

Create the cluster:
```bash
kind create cluster --name learning --config kind-config.yaml

# This creates:
# - 1 control-plane node (runs Kubernetes control components)
# - 1 worker node (runs your application pods)
```

Verify:
```bash
kubectl get nodes

# Expected output:
# NAME                     STATUS   ROLES           AGE   VERSION
# learning-control-plane   Ready    control-plane   2m    v1.27.3
# learning-worker          Ready    <none>          2m    v1.27.3
```

### Exercise 4: Explore Cluster Networking

**Goal**: Understand the network setup kind creates.

```bash
# See the Docker containers (these ARE your nodes)
docker ps

# Expected output shows 2 containers:
# CONTAINER ID   IMAGE                  NAMES
# abc123...      kindest/node:v1.27.3   learning-worker
# def456...      kindest/node:v1.27.3   learning-control-plane

# Check the Docker network kind created
docker network ls | grep kind

# Inspect the network
docker network inspect kind

# Look for the Subnet field - this is the network your nodes live on
# Typically: 172.18.0.0/16 or similar
```

**Get node IP addresses**:
```bash
kubectl get nodes -o wide

# Note the INTERNAL-IP column
# These IPs are from the Docker network
```

### Exercise 5: Deploy Pods and Verify Cross-Node Communication

**Goal**: Deploy pods and see them get scheduled on different nodes.

```bash
# Create a deployment with 2 replicas
kubectl create deployment nginx --image=nginx --replicas=2

# Watch the pods get created
kubectl get pods -o wide --watch

# Press Ctrl+C after both pods are Running

# Expected output:
# NAME                     READY   STATUS    NODE
# nginx-abc123-xyz         1/1     Running   learning-control-plane
# nginx-def456-uvw         1/1     Running   learning-worker
```

**Note**: Your pods should be on different nodes (though not guaranteed with just 2 replicas).

Check pod IPs:
```bash
kubectl get pods -o wide

# Note the IP column - these are pod IPs
# Typically from 10.244.0.0/16 range
```

Test connectivity between pods:
```bash
# Get pod names
POD1=$(kubectl get pod -l app=nginx -o jsonpath='{.items[0].metadata.name}')
POD2=$(kubectl get pod -l app=nginx -o jsonpath='{.items[1].metadata.name}')

# Get POD2's IP
POD2_IP=$(kubectl get pod $POD2 -o jsonpath='{.status.podIP}')

# From POD1, ping POD2
kubectl exec $POD1 -- ping -c 3 $POD2_IP

# Expected: successful pings even if pods are on different nodes
```

### Exercise 6: Explore the Kubeconfig

**Goal**: Understand how kubectl knows to talk to your kind cluster.

```bash
# View current context
kubectl config current-context

# Output: kind-learning

# View all contexts
kubectl config get-contexts

# See the full kubeconfig
kubectl config view

# Find these important pieces:
# - clusters: the API server URL
# - users: authentication credentials
# - contexts: which cluster + which user
```

**Where does kind store the cluster info?**
```bash
# kind clusters use localhost with a mapped port
kubectl cluster-info

# Output shows:
# Kubernetes control plane is running at https://127.0.0.1:xxxxx
```

That port is mapped to the control-plane container:
```bash
docker port learning-control-plane

# Shows: 6443/tcp -> 127.0.0.1:xxxxx
```

## Self-Check Questions

### Question 1
What is the fundamental difference between kind and a production Kubernetes cluster?

**Answer**: kind uses Docker containers to simulate nodes, whereas production clusters use real virtual machines or physical servers. Each kind "node" is just a container running on your laptop, making it lightweight and fast but not suitable for production workloads.

### Question 2
You run `kubectl get nodes` and see 2 nodes, but when you run `docker ps` you see 3 containers. What's the extra container?

**Answer**: This is common in some kind versions. The extra container is often a load balancer container that kind creates to provide a stable endpoint for the Kubernetes API server, especially in multi-node control-plane setups.

### Question 3
Your colleague creates a kind cluster named "dev" on their laptop. Can you access it from your laptop?

**Answer**: No. kind clusters are local to the machine they're created on. The API server binds to localhost (127.0.0.1) and is not accessible from other machines. Each developer needs to create their own kind cluster.

### Question 4
After creating a kind cluster, you notice pods have IPs like 10.244.1.5. Where does this IP range come from?

**Answer**: This is the pod CIDR (Classless Inter-Domain Routing) configured by the CNI (Container Network Interface) plugin. kind uses the kindnet CNI by default, which assigns pod IPs from the 10.244.0.0/16 range. Each node gets a subnet (like /24) from this range.

### Question 5
Why is kind useful for learning OpenShift networking?

**Answer**: OpenShift is built on Kubernetes, so the networking fundamentals are identical. Services, DNS, NetworkPolicies, and pod networking work the same way. Learning with kind gives you a free, fast environment to experiment with these concepts before applying them to OpenShift.

## Today I Learned (TIL)

Fill this out at the end of the day:

```
Date: _______________

What I learned today:
- kind stands for: _______________
- The command to create a cluster is: _______________
- kind nodes are actually: _______________
- The default pod CIDR in kind is: _______________

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
# Installation
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

# Cluster Management
kind create cluster --name <name>                    # Create single-node cluster
kind create cluster --name <name> --config <file>    # Create from config
kind delete cluster --name <name>                    # Delete cluster
kind get clusters                                    # List all clusters

# Basic Kubernetes Commands
kubectl get nodes                                    # List nodes
kubectl get nodes -o wide                            # List nodes with more details
kubectl get pods -n kube-system                      # List system pods
kubectl get pods -o wide                             # List pods with node and IP
kubectl cluster-info                                 # Show cluster info

# Context Management
kubectl config get-contexts                          # List all contexts
kubectl config current-context                       # Show current context
kubectl config use-context kind-<cluster-name>       # Switch context

# Debugging
docker ps                                            # See kind containers
docker network inspect kind                          # Inspect kind network
kubectl describe node <node-name>                    # Node details
```

## What's Next

Tomorrow (Day 30), you'll learn about the **4 fundamental rules of Kubernetes networking**:
1. All pods can communicate with each other without NAT
2. All nodes can communicate with all pods without NAT
3. The IP a pod sees itself as is the same IP others see it as
4. Pods are ephemeral, Services are stable

You'll deploy pods across your kind cluster and verify these rules in action. This is the foundation that makes Kubernetes (and OpenShift) networking magical.

**Preparation**: Keep your kind cluster running! We'll use it tomorrow.

---

**Pro Tip**: Create a habit of running `kubectl get nodes` and `kubectl get pods -A` whenever you start working. These two commands give you an instant health check of your cluster.
