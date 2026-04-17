# Day 20: Docker Networking — Containers in Practice

**Date:** Saturday, April 4, 2026  
**Phase:** 2 - Linux & Container Networking  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Explain how Docker creates container networks
- Trace the complete packet path from container to host to internet
- Find and interpret iptables rules created by Docker
- Understand the docker0 bridge and veth pairs
- Map Docker networking to Kubernetes/OCP networking concepts

---

## Plain English: How Docker Networking Works

You have learned all the building blocks this week:
- Network namespaces (Day 15)
- veth pairs (Day 16)
- Linux bridges (Day 17)
- iptables NAT (Day 18)
- conntrack (Day 19)

**Docker networking combines ALL of these.**

When you run `docker run -p 8080:80 nginx`:

1. Docker creates a **network namespace** for the container
2. Docker creates a **veth pair** (one end in container, one on host)
3. Docker attaches the host end to the **docker0 bridge**
4. Docker creates **iptables NAT rules** for port forwarding
5. Docker sets up **masquerading** so the container can reach the internet
6. **conntrack** tracks all connections

Today you will see all of this in action and trace the entire packet path.

---

## Docker Networking Architecture

**Default Docker network (bridge mode):**

```
Internet
   |
   | (eth0 on host)
   |
[Host]
   |
   | (iptables NAT + MASQUERADE)
   |
[docker0 bridge] -- 172.17.0.1/16
   |
   +--- veth1234 (host side)
           |
           | (veth pair)
           |
        eth0 (container side) -- 172.17.0.2
        [Container Namespace]
```

**Key components:**
- **docker0:** Linux bridge (172.17.0.1)
- **veth pairs:** Connect containers to docker0
- **iptables:** NAT for port forwarding and internet access
- **Network namespace:** Isolates each container

---

## Hands-On Lab

### Part 1: Inspect the docker0 Bridge (5 minutes)

Before creating any containers, examine the default Docker bridge.

```bash
# Show the docker0 bridge
ip addr show docker0

# Show interfaces attached to docker0
ip link show master docker0
```

**Expected output:**

```
4: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN
    link/ether 02:42:XX:XX:XX:XX brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
```

**Key points:**
- docker0 is a Linux bridge
- It has IP 172.17.0.1
- State is DOWN (no containers attached yet)

---

### Part 2: Start a Container and Watch the Network Change (10 minutes)

```bash
# Start an nginx container with port forwarding
sudo docker run -d -p 8080:80 --name web1 nginx

# Check docker0 again
ip addr show docker0

# Check what is attached to docker0
ip link show master docker0
```

**Expected output:**

```
4: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP
```

Now docker0 is UP because a container is connected.

You should also see a veth interface attached to docker0:

```
6: veth1234abc@if5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master docker0 state UP
```

**What happened?**

Docker created a veth pair and attached one end to docker0.

---

### Part 3: Find the Container's Network Namespace (10 minutes)

```bash
# Get the container's PID
CONTAINER_PID=$(sudo docker inspect -f '{{.State.Pid}}' web1)
echo "Container PID: $CONTAINER_PID"

# List the container's network namespace
sudo ls -l /proc/$CONTAINER_PID/ns/net
```

**Expected output:**

```
lrwxrwxrwx. 1 root root 0 Apr  4 10:00 /proc/12345/ns/net -> net:[4026532456]
```

This shows the container's network namespace ID.

---

### Part 4: Enter the Container's Network Namespace (10 minutes)

```bash
# Use nsenter to enter the container's network namespace
sudo nsenter -t $CONTAINER_PID -n ip addr show
```

**Expected output:**

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN
5: eth0@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
```

**Key observations:**
- The container has its own `lo` and `eth0`
- eth0 has IP 172.17.0.2
- `eth0@if6` means it is paired with interface 6 on the host

Check the host's interface 6:

```bash
ip link show | grep "^6:"
```

You should see the veth interface that is attached to docker0.

---

### Part 5: Verify the veth Pair Connection (10 minutes)

Let's prove that the container's eth0 and the host's veth are paired.

```bash
# Get the container's eth0 interface number
CONTAINER_IF=$(sudo nsenter -t $CONTAINER_PID -n ip link show eth0 | head -1 | cut -d: -f1)
echo "Container eth0 is interface: $CONTAINER_IF"

# Get the host-side veth interface number
HOST_VETH=$(ip link show | grep "^$CONTAINER_IF:" | cut -d: -f2 | cut -d@ -f1 | xargs)
echo "Host veth is: $HOST_VETH"

# Verify it is attached to docker0
ip link show $HOST_VETH
```

**Expected output:**

The veth interface on the host should show `master docker0`.

**What does this prove?**

The container's eth0 is one end of a veth pair, and the other end is attached to the docker0 bridge on the host.

---

### Part 6: Trace the Packet Path (15 minutes)

Now let's trace a packet from the container to the internet.

**Step 1: Container's view**

```bash
# Check container's routing table
sudo nsenter -t $CONTAINER_PID -n ip route show
```

**Expected output:**

```
default via 172.17.0.1 dev eth0
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.2
```

**What does this mean?**
- For internet traffic, use default gateway 172.17.0.1 (docker0)
- For local 172.17.0.0/16 traffic, use eth0 directly

**Step 2: Ping from container to internet**

```bash
# Ping Google DNS from inside the container
sudo nsenter -t $CONTAINER_PID -n ping -c 2 8.8.8.8
```

**Step 3: Trace the path**

1. Container sends packet to 8.8.8.8
2. Container's routing table says "use default gateway 172.17.0.1"
3. Packet goes out eth0 (container side of veth)
4. Packet arrives at veth on host side
5. veth forwards packet to docker0 bridge
6. docker0 routes to host (because 8.8.8.8 is not local)
7. iptables MASQUERADE rewrites source IP from 172.17.0.2 to host's public IP
8. Packet leaves host via eth0
9. Reply comes back, iptables rewrites dest IP back to 172.17.0.2
10. Packet is routed to docker0, then to container's veth, then to container

---

### Part 7: Find the iptables MASQUERADE Rule (10 minutes)

```bash
# Show POSTROUTING chain in NAT table
sudo iptables -t nat -L POSTROUTING -n -v
```

**Expected output:**

```
Chain POSTROUTING (policy ACCEPT)
MASQUERADE  all  --  172.17.0.0/16  0.0.0.0/0
```

**What does this mean?**

Any packet from 172.17.0.0/16 (Docker containers) going to the internet gets MASQUERADED (source IP rewritten to host's IP).

This is how containers reach the internet.

---

### Part 8: Find the Port Forwarding Rule (10 minutes)

You started the container with `-p 8080:80`. Let's find the iptables rule.

```bash
# Show the DOCKER chain in NAT table
sudo iptables -t nat -L DOCKER -n -v
```

**Expected output:**

```
Chain DOCKER (2 references)
DNAT  tcp  --  0.0.0.0/0  0.0.0.0/0  tcp dpt:8080 to:172.17.0.2:80
```

**What does this mean?**

Any packet to port 8080 (on any interface) gets DNAT-ed to 172.17.0.2:80 (the container's IP and port).

---

### Part 9: Test Port Forwarding (10 minutes)

```bash
# Test from the host
curl localhost:8080
```

**Expected output:**

You should see the nginx welcome page.

**Trace the packet:**

1. curl sends request to 127.0.0.1:8080
2. iptables DNAT rule rewrites destination to 172.17.0.2:80
3. Packet is routed to docker0
4. docker0 forwards to veth connected to container
5. Container receives on eth0:80
6. nginx responds
7. iptables rewrites source IP back to 127.0.0.1:8080
8. curl receives response

---

### Part 10: View conntrack Entries (10 minutes)

```bash
# View connections related to the container
sudo conntrack -L | grep 172.17.0.2
```

**Expected output:**

You should see entries for:
- The curl connection (DNAT from 8080 to 172.17.0.2:80)
- Any connections the container made (MASQUERADE for internet traffic)

---

### Part 11: Compare to Kubernetes (10 minutes)

**Docker networking vs Kubernetes/OCP networking:**

| Component | Docker | Kubernetes/OCP |
|-----------|--------|----------------|
| **Bridge** | docker0 | OVS bridge (br-int, br-ex) |
| **veth pairs** | One per container | One per pod |
| **NAT for Services** | iptables DNAT | iptables/OVN DNAT |
| **Internet access** | iptables MASQUERADE | OVN NAT or iptables |
| **Network namespace** | One per container | One per pod |

**Key insight:**

Kubernetes networking is MORE complex (multiple bridges, overlay networks, CNI plugins), but the FUNDAMENTALS are the same:
- Namespaces for isolation
- veth pairs for connectivity
- Bridges for switching
- iptables for NAT
- conntrack for state

---

### Part 12: Clean Up (5 minutes)

```bash
# Stop and remove the container
sudo docker stop web1
sudo docker rm web1

# Verify docker0 is DOWN again
ip addr show docker0
```

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What is the docker0 bridge?
2. How does a container connect to docker0?
3. How does a container reach the internet?
4. How does port forwarding work in Docker?
5. What is the difference between Docker and Kubernetes networking?

**Answers:**

1. A Linux bridge at 172.17.0.1 that connects all containers
2. Via a veth pair (one end in container, one end attached to docker0)
3. docker0 routes to host, iptables MASQUERADE rewrites source IP
4. iptables DNAT rule rewrites host port to container IP:port
5. Same fundamentals, but Kubernetes uses overlay networks (OVN) and more complex routing

---

## Today I Learned (TIL) — Write This Down

In your notebook, write 5 bullet points:

- What did I learn today?
- What surprised me?
- What do I still not understand?

Example:

```
April 4, 2026 — Day 20: Docker Networking

- Docker combines namespaces, veth pairs, bridges, and iptables NAT
- docker0 is a Linux bridge at 172.17.0.1
- Each container has a veth pair connecting it to docker0
- iptables MASQUERADE allows containers to reach the internet
- Port forwarding uses iptables DNAT rules
```

---

## Commands Cheat Sheet

**Docker Networking Inspection:**

```bash
# Show docker0 bridge
ip addr show docker0

# Show interfaces attached to docker0
ip link show master docker0

# Get container PID
docker inspect -f '{{.State.Pid}}' <container-name>

# Enter container's network namespace
sudo nsenter -t <PID> -n <command>

# View container's interfaces
sudo nsenter -t <PID> -n ip addr show

# View container's routing table
sudo nsenter -t <PID> -n ip route show

# View Docker's iptables rules
sudo iptables -t nat -L DOCKER -n -v
sudo iptables -t nat -L POSTROUTING -n -v

# View conntrack entries for container
sudo conntrack -L | grep <container-ip>
```

**Complete Packet Trace:**

```bash
# 1. Start container
docker run -d -p 8080:80 --name web nginx

# 2. Get container IP
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web

# 3. Check iptables DNAT rule
sudo iptables -t nat -L DOCKER -n -v | grep 8080

# 4. Test port forwarding
curl localhost:8080

# 5. Check conntrack
sudo conntrack -L | grep <container-ip>
```

---

## What's Next?

**Tomorrow (Day 21):** Weekend Scenario — "Docker container cannot reach internet"

**Why it matters:** You will use everything you learned this week (namespaces, veth, bridges, iptables, conntrack) to debug a real networking problem.

---

**End of Day 20 Lab**

Excellent work. You now understand how Docker networking works under the hood. Tomorrow you debug a broken container.
