# Week 5-6: Phase 3 - Kubernetes Networking

This directory contains hands-on labs for **Phase 3: Kubernetes Networking** of the OCP Networking Mastery Plan. These labs cover foundational and advanced Kubernetes networking concepts that directly apply to OpenShift Container Platform.

## Overview

**Duration**: 2 weeks (14 days)  
**Level**: Intermediate to Advanced  
**Prerequisites**: Completion of Phases 1-2 (Core Networking, Linux & Container Networking)

## Learning Path

### Week 5: Kubernetes Networking Fundamentals (Days 29-35)

| Day | Lab | Topics Covered | Duration |
|-----|-----|----------------|----------|
| 29 | [kind Setup](D29_kind_Setup.md) | Set up kind cluster for local K8s | 1 hour |
| 30 | [K8s 4 Rules](D30_K8s_4_Rules.md) | K8s networking model - 4 rules, pod IPs | 1.5 hours |
| 31 | [ClusterIP Service](D31_ClusterIP_Service.md) | How ClusterIP works at iptables level | 2 hours |
| 32 | [CoreDNS](D32_CoreDNS.md) | DNS inside the cluster | 1.5 hours |
| 33 | [Endpoints](D33_Endpoints.md) | How Services know which pods to route to | 1.5 hours |
| 34 | [NodePort & Ingress](D34_NodePort_Ingress.md) | External access to Services | 2 hours |
| 35 | [Week 5 Scenario](D35_Week5_Scenario.md) | Weekend scenario: Service troubleshooting | 2 hours |

**Week 5 Total**: ~11.5 hours

### Week 6: Advanced Kubernetes Networking (Days 36-42)

| Day | Lab | Topics Covered | Duration |
|-----|-----|----------------|----------|
| 36 | [NetworkPolicy](D36_NetworkPolicy.md) | Deny-all then allow specific traffic | 2 hours |
| 37 | [CNI Deep Dive](D37_CNI_Deep_Dive.md) | What happens when a pod starts | 2 hours |
| 38 | [DNS Troubleshooting](D38_DNS_Troubleshooting.md) | K8s DNS troubleshooting | 1.5 hours |
| 39 | [kube-proxy IPVS](D39_kube_proxy_IPVS.md) | How Services are programmed | 1.5 hours |
| 40 | [Service Troubleshooting](D40_Service_Troubleshooting.md) | Full scenario: Pod cannot reach Service | 2.5 hours |
| 41 | [Wireshark Intro](D41_Wireshark_Intro.md) | Opening and reading pcap files | 2 hours |
| 42 | [Week 6 Scenario](D42_Week6_Scenario.md) | Weekend review: Explain ClusterIP without notes | 2 hours |

**Week 6 Total**: ~13.5 hours  
**Phase 3 Total**: ~25 hours

## Key Concepts Covered

### Kubernetes Networking Model
- The 4 fundamental rules of K8s networking
- Pod-to-pod communication without NAT
- Flat network model
- Pod IP allocation and CIDR ranges

### Services
- ClusterIP Services and virtual IPs
- Service discovery via DNS
- Endpoints and endpoint slices
- Service types: ClusterIP, NodePort, LoadBalancer
- kube-proxy implementation (iptables vs IPVS)

### DNS
- CoreDNS architecture and configuration
- DNS resolution flow
- Service DNS records
- Troubleshooting DNS issues
- The ndots problem

### External Access
- NodePort Services
- Ingress controllers (nginx-ingress)
- Ingress resources and routing rules
- Host-based and path-based routing

### Network Security
- NetworkPolicy basics
- Deny-all policies
- Ingress and egress rules
- Label selectors and namespaces
- CNI plugin enforcement

### CNI and Pod Networking
- Container Network Interface (CNI) specification
- CNI plugin architecture (Calico, Cilium, etc.)
- veth pairs and network namespaces
- IP address management (IPAM)
- Pod network setup flow

### Troubleshooting Tools
- kubectl debugging commands
- iptables/IPVS rule inspection
- tcpdump for packet capture
- Wireshark for packet analysis
- DNS debugging with dig/nslookup

## Lab Structure

Each lab follows a consistent format:

1. **Learning Objectives** - What you'll master by the end
2. **Plain English Explanation** - Concepts explained simply
3. **Hands-On Lab** - 5-6 practical exercises
4. **Self-Check Questions** - Test your understanding
5. **Today I Learned (TIL)** - Reflection template
6. **Commands Cheat Sheet** - Quick reference
7. **What's Next** - Preview of tomorrow's topic

## Prerequisites

### Required Tools
- Docker or Podman
- kubectl (v1.27+)
- kind (Kubernetes in Docker)
- Wireshark (for packet analysis labs)
- Basic text editor (vim, nano, or VS Code)

### Required Knowledge
- Completion of Week 1-4 labs (or equivalent knowledge)
- Basic Linux networking (IP, routing, DNS)
- Container concepts (namespaces, cgroups)
- Basic iptables understanding

### System Requirements
- 8GB RAM minimum (16GB recommended)
- 20GB free disk space
- Linux, macOS, or Windows with WSL2
- Internet connection for downloading images

## Getting Started

### 1. Install kind

**Linux**:
```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

**macOS**:
```bash
brew install kind
```

**Windows**:
```powershell
choco install kind
```

### 2. Verify Installation

```bash
kind version
kubectl version --client
docker --version
```

### 3. Start with Day 29

Begin with [D29_kind_Setup.md](D29_kind_Setup.md) to create your learning cluster.

## Tips for Success

### Time Management
- Each lab has an estimated duration - budget accordingly
- Weekend scenarios (Days 35 and 42) are review/practice days
- Don't rush - understanding is more important than speed

### Hands-On Practice
- Type every command yourself (don't copy-paste blindly)
- Experiment beyond the exercises
- Break things intentionally to learn troubleshooting

### Note-Taking
- Fill out the TIL (Today I Learned) section in each lab
- Keep a personal networking journal
- Document your "aha!" moments

### Lab Environment
- Keep your kind cluster running between labs when possible
- Take snapshots/notes of working configurations
- Clean up resources between major sections

### When You Get Stuck
1. Re-read the Plain English Explanation section
2. Check the Self-Check Questions and Answers
3. Review previous labs for foundational concepts
4. Use the Commands Cheat Sheet for quick reference
5. Search Kubernetes documentation
6. Ask in community forums (Kubernetes Slack, Reddit r/kubernetes)

## Common Issues and Solutions

### kind Cluster Won't Start
```bash
# Check Docker is running
docker ps

# Delete and recreate cluster
kind delete cluster --name learning
kind create cluster --name learning
```

### Pods Stuck in Pending
```bash
# Check node status
kubectl get nodes

# Check pod details
kubectl describe pod <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### DNS Not Working
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check kube-dns Service
kubectl get service -n kube-system kube-dns

# Test from a pod
kubectl run test --image=busybox --rm -it -- nslookup kubernetes
```

### NetworkPolicy Not Working
```bash
# Check if CNI supports NetworkPolicy
kubectl get pods -n kube-system

# kind's default CNI (kindnet) doesn't support NetworkPolicy
# Install Calico (see D36_NetworkPolicy.md)
```

## Mapping to OpenShift

These Kubernetes networking concepts directly apply to OpenShift:

| Kubernetes Concept | OpenShift Equivalent | Differences |
|-------------------|---------------------|-------------|
| ClusterIP Service | ClusterIP Service | Identical |
| Ingress | Route (+ Ingress) | OpenShift Routes predate K8s Ingress |
| NetworkPolicy | NetworkPolicy | OpenShift adds EgressNetworkPolicy |
| CoreDNS | CoreDNS | OpenShift 4.x uses CoreDNS |
| CNI (Calico/Cilium) | OpenShift SDN / OVN-K8s | OpenShift-specific CNI plugins |
| kubectl | oc | oc is a superset of kubectl |

## Assessment

After completing Week 5-6, you should be able to:

- [ ] Explain the 4 rules of Kubernetes networking
- [ ] Create and debug ClusterIP Services
- [ ] Troubleshoot DNS resolution issues
- [ ] Implement NetworkPolicies for pod isolation
- [ ] Understand how kube-proxy implements Services
- [ ] Trace packet flow through iptables/IPVS rules
- [ ] Use tcpdump and Wireshark for network debugging
- [ ] Debug complex multi-layer networking issues
- [ ] Explain the complete lifecycle of a network request

## Next Steps

After completing Phase 3:

1. **Week 7**: OpenShift Networking Deep Dive
   - OpenShift SDN vs OVN-Kubernetes
   - Routes and OpenShift Router
   - EgressIP and EgressNetworkPolicy
   - OpenShift-specific troubleshooting

2. **Week 8**: tcpdump & Wireshark Mastery
   - Advanced packet capture techniques
   - Protocol analysis
   - TLS/SSL troubleshooting
   - Performance analysis

## Resources

### Official Documentation
- [Kubernetes Networking](https://kubernetes.io/docs/concepts/services-networking/)
- [CoreDNS](https://coredns.io/manual/toc/)
- [kind Documentation](https://kind.sigs.k8s.io/)
- [Calico Documentation](https://docs.projectcalico.org/)

### Recommended Reading
- "Kubernetes Networking Demystified" (Cloud Native Computing Foundation)
- "Container Networking" by Michael Hausenblas
- [Kubernetes Networking Deep Dive](https://www.youtube.com/watch?v=0Omvgd7Hg1I) (KubeCon talk)

### Tools Documentation
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Wireshark User Guide](https://www.wireshark.org/docs/wsug_html_chunked/)
- [tcpdump Manual](https://www.tcpdump.org/manpages/tcpdump.1.html)

## Contributing

Found an issue or have a suggestion? Please:
1. Check existing issues in the repository
2. Create a detailed issue report
3. Submit a pull request with improvements

## License

These labs are part of the OCP Networking Mastery Plan and are provided for educational purposes.

---

**Ready to begin?** Start with [Day 29: kind Setup](D29_kind_Setup.md)

**Questions?** Review the [Main README](../../README.md) for overall program structure.

**Good luck with your Kubernetes networking journey!**
