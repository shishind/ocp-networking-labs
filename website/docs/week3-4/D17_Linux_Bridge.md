# Day 17: Linux Bridge — Connecting Multiple Namespaces

**Date:** Wednesday, April 1, 2026  
**Phase:** 2 - Linux & Container Networking  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Explain what a Linux bridge is and how it works
- Create a bridge and attach multiple veth interfaces to it
- Connect three or more network namespaces using a bridge
- Verify full connectivity between all namespaces
- Understand how Docker and Kubernetes use bridges for container networking

---

## Plain English: What Is a Linux Bridge?

Imagine you have 10 computers in an office, and you want them all to talk to each other.

You could connect each computer to every other computer with individual cables (messy!), OR you could buy a **network switch** and connect all 10 computers to the switch. The switch forwards traffic between them.

A **Linux bridge** is a virtual network switch inside the Linux kernel.

Just like a physical switch:
- It has multiple ports
- When a packet arrives on one port, the bridge forwards it to the correct port
- It learns MAC addresses to know which device is on which port
- It operates at Layer 2 (Data Link layer)

**Why does this matter for OCP?**

Docker uses a bridge called `docker0` to connect all containers on a host.

OpenShift uses **Open vSwitch (OVS)** bridges to connect all pods on a node. When you see `br-ex` or `br-int` on an OCP node, those are OVS bridges doing the same job.

Today you will build this from scratch using Linux bridges.

---

## What Is a Linux Bridge?

A **Linux bridge** is a virtual Layer 2 switch implemented in software.

Key characteristics:
- Creates a broadcast domain (like a physical switch)
- Forwards traffic based on MAC addresses
- Can have an IP address itself (acting as a gateway)
- Can have multiple interfaces attached to it

Think of it as a **virtual Ethernet switch**.

---

## How Docker Uses Bridges

When you install Docker, it creates a bridge called `docker0`:

1. Docker creates the `docker0` bridge on the host
2. For each container, Docker creates a veth pair
3. One end of the veth goes inside the container (`eth0`)
4. The other end gets attached to the `docker0` bridge
5. All containers can now talk to each other via the bridge

This is exactly what you are going to build today.

---

## Hands-On Lab

### Part 1: Create a Linux Bridge (5 minutes)

```bash
# Create a bridge called "br0"
sudo ip link add br0 type bridge

# Verify it was created
ip link show br0

# Bring up the bridge
sudo ip link set br0 up
```

**Expected output:**

```
5: br0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN
    link/ether XX:XX:XX:XX:XX:XX brd ff:ff:ff:ff:ff:ff
```

**What just happened?**

You created a virtual switch. Right now it has no ports, so it does nothing.

---

### Part 2: Create Three Network Namespaces (5 minutes)

```bash
# Create three namespaces
sudo ip netns add red
sudo ip netns add green
sudo ip netns add blue

# Verify they exist
sudo ip netns list
```

**Question:** Can these namespaces talk to each other right now?

**Answer:** No — they are isolated, and the bridge has no connections yet.

---

### Part 3: Create veth Pairs for Each Namespace (10 minutes)

We need to connect each namespace to the bridge using veth pairs.

```bash
# Create veth pair for red namespace
sudo ip link add veth-red type veth peer name br-red

# Create veth pair for green namespace
sudo ip link add veth-green type veth peer name br-green

# Create veth pair for blue namespace
sudo ip link add veth-blue type veth peer name br-blue
```

Verify they were created:

```bash
ip link show | grep veth
```

**Expected output:**

You should see 6 interfaces (3 pairs).

**Naming convention:**
- `veth-red` will go inside the red namespace
- `br-red` will attach to the bridge
- Same pattern for green and blue

---

### Part 4: Attach Bridge-Side veth Ends to the Bridge (10 minutes)

```bash
# Attach br-red to the bridge
sudo ip link set br-red master br0
sudo ip link set br-red up

# Attach br-green to the bridge
sudo ip link set br-green master br0
sudo ip link set br-green up

# Attach br-blue to the bridge
sudo ip link set br-blue master br0
sudo ip link set br-blue up
```

Verify the attachments:

```bash
# Show which interfaces are attached to the bridge
ip link show master br0
```

**Expected output:**

You should see `br-red`, `br-green`, and `br-blue` all attached to `br0`.

**What does this mean?**

The bridge now has three ports. Any traffic sent to these ports will be forwarded by the bridge.

---

### Part 5: Move Namespace-Side veth Ends Into Namespaces (10 minutes)

```bash
# Move veth-red into red namespace
sudo ip link set veth-red netns red

# Move veth-green into green namespace
sudo ip link set veth-green netns green

# Move veth-blue into blue namespace
sudo ip link set veth-blue netns blue
```

Verify they moved:

```bash
# Check red namespace
sudo ip netns exec red ip link show

# Check green namespace
sudo ip netns exec green ip link show

# Check blue namespace
sudo ip netns exec blue ip link show
```

Each namespace should now have `lo` and its respective `veth` interface.

---

### Part 6: Assign IP Addresses and Bring Up Interfaces (15 minutes)

```bash
# Configure red namespace
sudo ip netns exec red ip addr add 10.0.0.1/24 dev veth-red
sudo ip netns exec red ip link set veth-red up
sudo ip netns exec red ip link set lo up

# Configure green namespace
sudo ip netns exec green ip addr add 10.0.0.2/24 dev veth-green
sudo ip netns exec green ip link set veth-green up
sudo ip netns exec green ip link set lo up

# Configure blue namespace
sudo ip netns exec blue ip addr add 10.0.0.3/24 dev veth-blue
sudo ip netns exec blue ip link set veth-blue up
sudo ip netns exec blue ip link set lo up
```

Verify the configuration:

```bash
# Check red
sudo ip netns exec red ip addr show

# Check green
sudo ip netns exec green ip addr show

# Check blue
sudo ip netns exec blue ip addr show
```

**Fill in the table:**

| Namespace | Interface | IP Address | State |
|-----------|-----------|------------|-------|
| red | veth-red | ? | ? |
| green | veth-green | ? | ? |
| blue | veth-blue | ? | ? |

**Answers:**
- red: 10.0.0.1/24, UP
- green: 10.0.0.2/24, UP
- blue: 10.0.0.3/24, UP

---

### Part 7: Test Full Connectivity (15 minutes)

Now test that all namespaces can reach each other:

```bash
# From red, ping green and blue
sudo ip netns exec red ping -c 2 10.0.0.2
sudo ip netns exec red ping -c 2 10.0.0.3

# From green, ping red and blue
sudo ip netns exec green ping -c 2 10.0.0.1
sudo ip netns exec green ping -c 2 10.0.0.3

# From blue, ping red and green
sudo ip netns exec blue ping -c 2 10.0.0.1
sudo ip netns exec blue ping -c 2 10.0.0.2
```

**Expected result:** All pings should succeed.

**Question:** How does this work?

**Answer:**

1. When red pings green (10.0.0.2):
   - Packet leaves red's `veth-red` interface
   - Exits the paired `br-red` interface on the host
   - Enters the `br0` bridge
   - Bridge forwards it to `br-green` (based on MAC address)
   - Packet enters green's `veth-green` interface
   - Green receives the packet

The bridge is acting like a switch, forwarding traffic between all connected namespaces.

---

### Part 8: View the Bridge's MAC Address Table (10 minutes)

Bridges learn which MAC addresses are on which ports.

```bash
# Show the bridge's MAC address table
bridge fdb show br br0
```

**Expected output:**

You will see entries showing which MAC addresses are reachable via which interface.

This is exactly how a physical switch works — it learns MAC addresses by watching traffic.

---

### Part 9: Add an IP to the Bridge Itself (Optional - 10 minutes)

The bridge can also have an IP address, acting as a gateway for the namespaces.

```bash
# Assign IP to the bridge
sudo ip addr add 10.0.0.254/24 dev br0

# Verify
ip addr show br0

# Ping the bridge from red namespace
sudo ip netns exec red ping -c 3 10.0.0.254
```

**Expected result:** The ping should succeed.

**Why does this work?**

The bridge is now part of the 10.0.0.0/24 network. The namespaces can reach it just like they reach each other.

In Docker, the `docker0` bridge has an IP (usually 172.17.0.1), and containers use it as their default gateway.

---

### Part 10: Clean Up (5 minutes)

```bash
# Delete all namespaces
sudo ip netns delete red
sudo ip netns delete green
sudo ip netns delete blue

# Delete the bridge
sudo ip link delete br0

# Verify everything is gone
sudo ip netns list
ip link show | grep br0
```

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What is a Linux bridge?
2. What OSI layer does a bridge operate at?
3. How does a bridge know which port to forward traffic to?
4. How does Docker use bridges?
5. Can a bridge have an IP address?

**Answers:**

1. A virtual Layer 2 switch in the Linux kernel
2. Layer 2 (Data Link)
3. It learns MAC addresses by watching traffic (builds a MAC address table)
4. Docker creates a `docker0` bridge and connects all containers to it via veth pairs
5. Yes — and it can act as a gateway for connected interfaces

---

## Today I Learned (TIL) — Write This Down

In your notebook, write 5 bullet points:

- What did I learn today?
- What surprised me?
- What do I still not understand?

Example:

```
April 1, 2026 — Day 17: Linux Bridge

- A Linux bridge is a virtual Layer 2 switch
- Multiple namespaces can connect to one bridge via veth pairs
- The bridge learns MAC addresses just like a physical switch
- Docker uses docker0 bridge to connect all containers
- OpenShift uses OVS bridges (br-ex, br-int) for the same purpose
```

---

## Commands Cheat Sheet

**Linux Bridge Management:**

```bash
# Create a bridge
sudo ip link add <bridge-name> type bridge

# Bring up the bridge
sudo ip link set <bridge-name> up

# Attach an interface to a bridge
sudo ip link set <interface> master <bridge-name>

# Show interfaces attached to a bridge
ip link show master <bridge-name>

# Show bridge MAC address table
bridge fdb show br <bridge-name>

# Assign IP to bridge
sudo ip addr add <IP>/<mask> dev <bridge-name>

# Delete a bridge
sudo ip link delete <bridge-name>
```

**Complete Example (3 Namespaces + Bridge):**

```bash
# Create bridge
sudo ip link add br0 type bridge
sudo ip link set br0 up

# Create namespaces
sudo ip netns add ns1
sudo ip netns add ns2
sudo ip netns add ns3

# Create veth pairs
sudo ip link add veth1 type veth peer name br-veth1
sudo ip link add veth2 type veth peer name br-veth2
sudo ip link add veth3 type veth peer name br-veth3

# Attach bridge-side to bridge
sudo ip link set br-veth1 master br0 && sudo ip link set br-veth1 up
sudo ip link set br-veth2 master br0 && sudo ip link set br-veth2 up
sudo ip link set br-veth3 master br0 && sudo ip link set br-veth3 up

# Move namespace-side into namespaces
sudo ip link set veth1 netns ns1
sudo ip link set veth2 netns ns2
sudo ip link set veth3 netns ns3

# Configure IPs
sudo ip netns exec ns1 ip addr add 192.168.1.1/24 dev veth1
sudo ip netns exec ns2 ip addr add 192.168.1.2/24 dev veth2
sudo ip netns exec ns3 ip addr add 192.168.1.3/24 dev veth3

# Bring up interfaces
sudo ip netns exec ns1 ip link set veth1 up && sudo ip netns exec ns1 ip link set lo up
sudo ip netns exec ns2 ip link set veth2 up && sudo ip netns exec ns2 ip link set lo up
sudo ip netns exec ns3 ip link set veth3 up && sudo ip netns exec ns3 ip link set lo up

# Test
sudo ip netns exec ns1 ping -c 2 192.168.1.2
```

---

## What's Next?

**Tomorrow (Day 18):** iptables NAT — how Kubernetes Services really work

**Why it matters:** Now you know how containers connect to each other. Tomorrow you will learn how iptables rewrites packets to make Services work — the secret behind ClusterIP and NodePort.

---

**End of Day 17 Lab**

Great work. You just built the foundation of Docker networking from scratch. Tomorrow we add NAT to the mix.
