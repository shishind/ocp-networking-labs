# Day 15: Network Namespaces — The Foundation of Container Networking

**Date:** Monday, March 30, 2026  
**Phase:** 2 - Linux & Container Networking  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Explain what network namespaces are and why containers use them
- Create and manage network namespaces using `ip netns`
- Execute commands inside a network namespace
- Understand how Kubernetes pods use network namespaces for isolation

---

## Plain English: What Is a Network Namespace?

Imagine you have 5 people living in the same house, but each person wants their own private phone line that others cannot see or use.

A **network namespace** is like giving each person their own invisible phone system. They all live in the same physical house (the Linux kernel), but each person has completely separate phone lines (network interfaces, routing tables, firewall rules).

This is EXACTLY how containers work.

When you create a Docker container or a Kubernetes pod, Linux creates a new network namespace. The container gets its own private network stack — its own IP addresses, its own routing table, its own iptables rules — completely isolated from the host and other containers.

**Why does this matter for OCP?**

Every pod in OpenShift runs in its own network namespace. When you debug networking, you need to "jump into" that namespace to see what the pod sees. Otherwise, you are looking at the host's network stack, not the pod's.

---

## What Is a Network Namespace?

A **network namespace** is a Linux kernel feature that creates an isolated copy of the network stack.

Each namespace has its own:
- Network interfaces (eth0, lo, etc.)
- IP addresses
- Routing tables
- iptables rules
- ARP tables
- Network statistics

When you create a new namespace, it starts EMPTY — no interfaces except `lo` (loopback), and even that is DOWN by default.

---

## Why Containers Use Network Namespaces

Without namespaces, all containers would share the host's network stack. That means:
- They would all see the same IP addresses
- Port 80 could only be used by one container
- One container could snoop on another's traffic

**Network namespaces solve this** by giving each container its own isolated network environment.

---

## Hands-On Lab

### Part 1: View Your Current Network Namespace (5 minutes)

On your Linux machine (RHEL, Fedora, or Ubuntu), run:

```bash
# View your current network interfaces
ip addr show

# View your routing table
ip route show

# View your iptables rules
sudo iptables -L -n
```

**Question:** How many network interfaces do you see?

You are currently in the **default (root) network namespace** — the host's main network stack.

---

### Part 2: Create a New Network Namespace (10 minutes)

```bash
# Create a new network namespace called "myns"
sudo ip netns add myns

# List all network namespaces
sudo ip netns list

# Expected output:
# myns
```

**What just happened?**

Linux created a brand new, isolated network stack for `myns`. It is completely separate from the host.

Now run this:

```bash
# Execute a command INSIDE the namespace
sudo ip netns exec myns ip addr show
```

**Question:** How many interfaces do you see now?

**Answer:** Only one — `lo` (loopback). And it is DOWN.

This proves the namespace is isolated. It does not see eth0, ens3, or any of the host's interfaces.

---

### Part 3: Bring Up the Loopback Interface (10 minutes)

Inside the namespace, the loopback interface is down by default. Let's fix that:

```bash
# Bring up loopback inside the namespace
sudo ip netns exec myns ip link set lo up

# Verify it is up
sudo ip netns exec myns ip addr show lo

# Test loopback connectivity
sudo ip netns exec myns ping -c 3 127.0.0.1
```

**Expected result:** Ping should work.

**Why?** Even though the namespace is isolated, it has its own loopback interface for internal communication.

---

### Part 4: Check the Routing Table Inside the Namespace (10 minutes)

```bash
# View the routing table inside the namespace
sudo ip netns exec myns ip route show
```

**Question:** What routes do you see?

**Answer:** Only one — the loopback route (127.0.0.0/8 dev lo). No default route, no eth0 routes.

This namespace is **completely isolated** from the outside world right now.

---

### Part 5: Compare Namespace vs Host Network Stack (15 minutes)

Run these commands side-by-side:

```bash
# Host network interfaces
ip addr show

# Namespace network interfaces
sudo ip netns exec myns ip addr show
```

```bash
# Host routing table
ip route show

# Namespace routing table
sudo ip netns exec myns ip route show
```

```bash
# Host iptables rules
sudo iptables -L -n

# Namespace iptables rules
sudo ip netns exec myns iptables -L -n
```

**Fill in the table:**

| Resource | Host | Namespace |
|----------|------|-----------|
| Number of interfaces | ? | ? |
| Default route exists? | ? | ? |
| iptables rules | ? | ? |

**Answers:**
- Host: Multiple interfaces, has default route, has iptables rules
- Namespace: Only `lo`, no default route, empty iptables (all ACCEPT)

---

### Part 6: Run a Process Inside the Namespace (10 minutes)

```bash
# Start a bash shell inside the namespace
sudo ip netns exec myns bash

# Inside the namespace, run:
ip addr show
ip route show
ping 8.8.8.8  # This will fail — no route to outside world

# Exit the namespace
exit
```

**What did you learn?**

When you run `ip netns exec myns bash`, you get a shell that sees ONLY the namespace's network stack. This is exactly how containers work.

---

### Part 7: Clean Up (5 minutes)

```bash
# Delete the namespace
sudo ip netns delete myns

# Verify it is gone
sudo ip netns list
```

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What is a network namespace?
2. Why do containers use network namespaces?
3. What network interfaces exist in a newly created namespace?
4. How do you run a command inside a namespace?
5. Can a process inside a namespace see the host's network interfaces?

**Answers:**

1. An isolated copy of the Linux network stack (interfaces, routes, iptables, etc.)
2. To isolate each container's network so they do not interfere with each other
3. Only `lo` (loopback), and it is down by default
4. `sudo ip netns exec <namespace-name> <command>`
5. No — it only sees interfaces inside its own namespace

---

## Today I Learned (TIL) — Write This Down

In your notebook, write 5 bullet points:

- What did I learn today?
- What surprised me?
- What do I still not understand?

Example:

```
March 30, 2026 — Day 15: Network Namespaces

- Network namespaces isolate the network stack for containers
- A new namespace starts with only a DOWN loopback interface
- ip netns exec <ns> <cmd> runs a command inside the namespace
- Each Kubernetes pod has its own network namespace
- This is how 100 pods can all listen on port 8080 without conflicts
```

---

## Commands Cheat Sheet

**Network Namespace Basics:**

```bash
# Create a namespace
sudo ip netns add <name>

# List all namespaces
sudo ip netns list

# Run a command inside a namespace
sudo ip netns exec <name> <command>

# Delete a namespace
sudo ip netns delete <name>

# Common commands to run inside a namespace:
sudo ip netns exec myns ip addr show
sudo ip netns exec myns ip route show
sudo ip netns exec myns iptables -L -n
sudo ip netns exec myns ping 127.0.0.1
```

---

## What's Next?

**Tomorrow (Day 16):** veth Pairs — how to connect network namespaces together

**Why it matters:** Namespaces are isolated by default. Tomorrow you will learn how to connect them using virtual Ethernet pairs — the same technology that connects containers to the host.

---

**End of Day 15 Lab**

Great work. You just learned the foundation of container networking. Tomorrow we connect namespaces together.
