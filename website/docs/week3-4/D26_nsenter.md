# Day 26: nsenter — Entering a Pod's Network Namespace

**Date:** Friday, April 10, 2026  
**Phase:** 2 - Linux & Container Networking  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Explain what nsenter is and why it is critical for container debugging
- Find a container's or pod's PID
- Enter a container's network namespace using nsenter
- Run network commands inside a namespace without entering the container
- Apply nsenter to troubleshoot OCP networking issues

---

## Plain English: What Is nsenter?

Imagine you need to debug a broken container, but:
- The container image has no tools (no ping, no curl, no ip command)
- You cannot install packages inside the container
- You cannot rebuild the image just to add debugging tools

**How do you debug the network?**

**nsenter** (namespace enter) lets you "jump into" the container's network namespace from the host and run commands AS IF you were inside the container.

It is like having a secret backdoor to the container's network, without needing to be inside the container.

**Why does this matter for OCP?**

Many production containers are **minimal images** (e.g., distroless, alpine) with no debugging tools.

When you need to troubleshoot, you use nsenter to:
- Run `ip addr` to see the container's interfaces
- Run `ip route` to see the container's routing table
- Run `ping` to test connectivity
- Run `tcpdump` to capture packets

All WITHOUT needing tools inside the container.

---

## What Is nsenter?

**nsenter** is a Linux utility that runs a command in a different namespace.

Linux namespaces isolate:
- Network stack (network namespace)
- Process IDs (PID namespace)
- Mount points (mount namespace)
- IPC (IPC namespace)
- UTS (hostname namespace)
- User IDs (user namespace)

**nsenter can enter any of these namespaces.**

For networking, we care about the **network namespace**.

---

## nsenter Syntax

```bash
nsenter [options] [command]
```

**Common options:**

| Option | Namespace | Description |
|--------|-----------|-------------|
| `-t <PID>` | N/A | Target process ID |
| `-n` | Network | Enter network namespace |
| `-m` | Mount | Enter mount namespace |
| `-p` | PID | Enter PID namespace |
| `-i` | IPC | Enter IPC namespace |
| `-u` | UTS | Enter UTS namespace (hostname) |
| `-a` | ALL | Enter all namespaces |

**Example:**

```bash
# Enter network namespace of PID 1234 and run ip addr
sudo nsenter -t 1234 -n ip addr
```

---

## How to Find a Container's PID

**For Docker containers:**

```bash
docker inspect -f '{{.State.Pid}}' <container-name>
```

**For Kubernetes pods (on the node):**

```bash
# Method 1: crictl (CRI-O)
crictl inspect <container-id> | grep pid

# Method 2: Find the pause container's PID
ps aux | grep pause | grep <pod-name>
```

---

## Hands-On Lab

### Part 1: Start a Test Container (5 minutes)

```bash
# Start an nginx container
sudo docker run -d --name test-container nginx
```

Verify it is running:

```bash
sudo docker ps | grep test-container
```

---

### Part 2: Find the Container's PID (5 minutes)

```bash
# Get the PID
CONTAINER_PID=$(sudo docker inspect -f '{{.State.Pid}}' test-container)
echo "Container PID: $CONTAINER_PID"
```

**Expected output:**

```
Container PID: 12345
```

---

### Part 3: Enter the Container's Network Namespace (10 minutes)

```bash
# Use nsenter to run ip addr inside the container's network namespace
sudo nsenter -t $CONTAINER_PID -n ip addr show
```

**Expected output:**

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
5: eth0@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
```

**Compare to the host:**

```bash
# Host's interfaces
ip addr show
```

**Question:** Do you see the container's eth0 on the host?

**Answer:** No — the container's eth0 is only visible inside its network namespace.

---

### Part 4: Check the Container's Routing Table (10 minutes)

```bash
# View the container's routing table
sudo nsenter -t $CONTAINER_PID -n ip route show
```

**Expected output:**

```
default via 172.17.0.1 dev eth0
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.2
```

**Compare to the host:**

```bash
# Host's routing table
ip route show
```

Completely different — the container has its own isolated routing table.

---

### Part 5: Test Connectivity from Inside the Namespace (10 minutes)

```bash
# Ping from inside the container's namespace
sudo nsenter -t $CONTAINER_PID -n ping -c 3 8.8.8.8
```

**Expected output:**

```
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=117 time=10.2 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=117 time=10.5 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=117 time=10.3 ms
```

**What just happened?**

You ran `ping` from the HOST, but the ping packet originated from the CONTAINER's network namespace (using the container's IP 172.17.0.2).

---

### Part 6: Run tcpdump Inside the Namespace (15 minutes)

```bash
# Capture packets inside the container's namespace
sudo nsenter -t $CONTAINER_PID -n tcpdump -i eth0 -n -c 10
```

In another terminal, make a request to the container:

```bash
# Get container IP
CONTAINER_IP=$(sudo docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' test-container)

# Make a request
curl http://$CONTAINER_IP
```

**Expected output in tcpdump:**

You will see the HTTP request and response on the container's eth0 interface.

**Why is this useful?**

If the container image does not have tcpdump, you can still capture packets from the host using nsenter.

---

### Part 7: Compare nsenter vs docker exec (10 minutes)

**Using docker exec:**

```bash
# Run a command INSIDE the container
sudo docker exec test-container ip addr show
```

**Using nsenter:**

```bash
# Run a command in the container's namespace (from the host)
sudo nsenter -t $CONTAINER_PID -n ip addr show
```

**What is the difference?**

- `docker exec` runs the command INSIDE the container (requires the command to exist in the container image)
- `nsenter` runs the command from the HOST but in the container's namespace (uses the host's binaries)

**Use nsenter when:**
- The container does not have debugging tools
- You need to use tools from the host (tcpdump, ip, etc.)

---

### Part 8: Enter Multiple Namespaces at Once (10 minutes)

You can enter multiple namespaces simultaneously.

```bash
# Enter network AND mount namespaces
sudo nsenter -t $CONTAINER_PID -n -m bash
```

**Inside the namespace shell:**

```bash
# Check network interfaces
ip addr show

# Check mounted filesystems
df -h

# Check hostname
hostname

# Exit
exit
```

**Why enter multiple namespaces?**

Sometimes you need to see the container's filesystem AND network at the same time.

---

### Part 9: Troubleshoot a Container Without Network Tools (15 minutes)

Let's simulate a minimal container with NO network tools.

```bash
# Start a minimal container (busybox)
sudo docker run -d --name minimal-container busybox sleep 3600

# Try to run ip addr inside it
sudo docker exec minimal-container ip addr
```

**Expected error:**

```
exec: "ip": executable file not found in $PATH
```

The container does not have the `ip` command.

**Solution: Use nsenter**

```bash
# Get the PID
MINIMAL_PID=$(sudo docker inspect -f '{{.State.Pid}}' minimal-container)

# Use nsenter to run ip addr
sudo nsenter -t $MINIMAL_PID -n ip addr show
```

**Expected output:**

You will see the container's interfaces, even though the container does not have the `ip` command.

---

### Part 10: Clean Up (5 minutes)

```bash
# Stop and remove containers
sudo docker stop test-container minimal-container
sudo docker rm test-container minimal-container
```

---

## Real-World OCP Troubleshooting Scenario

**Problem:** "A pod cannot reach the internet, but the pod has no debugging tools."

**Troubleshooting steps using nsenter:**

1. **SSH to the node** where the pod is running
2. **Find the pod's pause container PID:**
   ```bash
   crictl ps | grep <pod-name>
   crictl inspect <container-id> | grep pid
   ```
3. **Enter the pod's network namespace:**
   ```bash
   sudo nsenter -t <PID> -n bash
   ```
4. **Run network commands:**
   ```bash
   ip addr show       # Check interfaces
   ip route show      # Check routing
   ping 8.8.8.8       # Test connectivity
   curl http://...    # Test HTTP
   tcpdump -i eth0    # Capture packets
   ```
5. **Diagnose the issue** using the output

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What is nsenter?
2. How do you find a container's PID?
3. What does the `-n` flag mean in nsenter?
4. What is the difference between nsenter and docker exec?
5. When should you use nsenter instead of docker exec?

**Answers:**

1. A tool to enter Linux namespaces and run commands inside them
2. `docker inspect -f '{{.State.Pid}}' <container-name>`
3. Enter the network namespace
4. nsenter runs commands from the host in the container's namespace; docker exec runs commands inside the container
5. When the container does not have debugging tools installed

---

## Today I Learned (TIL) — Write This Down

In your notebook, write 5 bullet points:

- What did I learn today?
- What surprised me?
- What do I still not understand?

Example:

```
April 10, 2026 — Day 26: nsenter

- nsenter lets me run commands inside a container's namespace from the host
- I can debug containers without needing tools inside the container
- docker inspect shows the container's PID
- nsenter -t <PID> -n enters the network namespace
- This is critical for debugging minimal/distroless containers in OCP
```

---

## Commands Cheat Sheet

**nsenter Basics:**

```bash
# Enter network namespace and run a command
sudo nsenter -t <PID> -n <command>

# Enter network namespace and start a shell
sudo nsenter -t <PID> -n bash

# Enter all namespaces
sudo nsenter -t <PID> -a <command>

# Common commands to run inside a namespace:
sudo nsenter -t <PID> -n ip addr show
sudo nsenter -t <PID> -n ip route show
sudo nsenter -t <PID> -n ping 8.8.8.8
sudo nsenter -t <PID> -n tcpdump -i eth0
sudo nsenter -t <PID> -n ss -tunlp
```

**Finding Container PIDs:**

```bash
# Docker
docker inspect -f '{{.State.Pid}}' <container-name>

# Kubernetes (on node, using CRI-O)
crictl inspect <container-id> | grep pid

# Kubernetes (on node, using containerd)
ctr task ls
```

**Complete Example:**

```bash
# Start a container
docker run -d --name web nginx

# Get its PID
CONTAINER_PID=$(docker inspect -f '{{.State.Pid}}' web)

# Check its network interfaces
sudo nsenter -t $CONTAINER_PID -n ip addr show

# Check its routing table
sudo nsenter -t $CONTAINER_PID -n ip route show

# Ping from inside its namespace
sudo nsenter -t $CONTAINER_PID -n ping -c 3 8.8.8.8

# Capture packets on its interface
sudo nsenter -t $CONTAINER_PID -n tcpdump -i eth0 -c 10
```

---

## What's Next?

**Tomorrow (Day 27):** Container Network Trace — complete packet path from container to internet

**Why it matters:** You have learned all the tools (namespaces, veth, bridges, iptables, tcpdump, nsenter). Tomorrow you will put it all together and trace a packet's complete journey from a container to the internet and back.

---

**End of Day 26 Lab**

Great work. You now know how to debug containers using nsenter. Tomorrow we trace the complete packet path.
