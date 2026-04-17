# Day 16: veth Pairs — Connecting Network Namespaces

**Date:** Tuesday, March 31, 2026  
**Phase:** 2 - Linux & Container Networking  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Explain what a veth pair is and how it works
- Create a veth pair to connect two network namespaces
- Assign IP addresses to veth interfaces
- Test connectivity between namespaces using ping
- Understand how containers connect to the host network

---

## Plain English: What Is a veth Pair?

Imagine you have two rooms with soundproof walls. People inside cannot talk to each other.

A **veth pair** is like drilling a hole through the wall and installing a tube with a speaker on each end. When someone talks into one end, the other person hears it on the other end.

A veth pair is a **virtual Ethernet cable** with two ends:
- One end goes in namespace A
- One end goes in namespace B
- Whatever you send into one end comes out the other end

This is EXACTLY how Docker connects a container to the host network:
- One end of the veth pair is inside the container (usually called `eth0`)
- The other end is on the host (usually called `veth1234abcd`)
- Traffic flows between them like a physical cable

**Why does this matter for OCP?**

Every pod in OpenShift has a veth pair:
- One end inside the pod's namespace (`eth0` inside the pod)
- One end on the host, connected to the OVS bridge

When you run `ip link` on an OCP node, you will see dozens of `veth` interfaces — one for each pod on that node.

---

## What Is a veth Pair?

A **veth pair** is a pair of virtual network interfaces that act like a cross-over cable.

Key characteristics:
- Always created in pairs (you cannot create just one)
- What goes into one end comes out the other end
- They can be in different network namespaces
- They act like real network interfaces (can have IP addresses, MAC addresses, etc.)

Think of it as a **virtual patch cable**.

---

## How Containers Use veth Pairs

When Docker or Kubernetes creates a container:

1. Creates a new network namespace for the container
2. Creates a veth pair
3. Moves one end into the container's namespace (renames it to `eth0`)
4. Keeps the other end on the host (usually named `vethXXXXXX`)
5. Connects the host end to a bridge (docker0 or OVS bridge)

This is how containers get network connectivity.

---

## Hands-On Lab

### Part 1: Create Two Network Namespaces (5 minutes)

```bash
# Create two namespaces
sudo ip netns add red
sudo ip netns add blue

# Verify they exist
sudo ip netns list

# Expected output:
# blue
# red
```

**Question:** Can these namespaces talk to each other right now?

**Answer:** No — they are completely isolated.

---

### Part 2: Create a veth Pair (10 minutes)

```bash
# Create a veth pair with two ends: veth-red and veth-blue
sudo ip link add veth-red type veth peer name veth-blue

# Verify it was created (both ends are on the host for now)
ip link show | grep veth
```

**Expected output:**

```
6: veth-blue@veth-red: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN
7: veth-red@veth-blue: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN
```

**What does this mean?**

- Both ends are currently in the host's namespace
- They are linked (notice `veth-blue@veth-red` — the `@` shows they are paired)
- They are both DOWN

---

### Part 3: Move Each End Into a Namespace (10 minutes)

```bash
# Move veth-red into the "red" namespace
sudo ip link set veth-red netns red

# Move veth-blue into the "blue" namespace
sudo ip link set veth-blue netns blue

# Check the host's interfaces — veth pair should be gone
ip link show | grep veth
```

**Expected result:** No output — the veth interfaces are no longer visible on the host.

Now check inside the namespaces:

```bash
# Check red namespace
sudo ip netns exec red ip link show

# Check blue namespace
sudo ip netns exec blue ip link show
```

**Expected output:**

Each namespace should now see its own veth interface.

---

### Part 4: Assign IP Addresses and Bring Up Interfaces (15 minutes)

```bash
# Configure the red namespace
sudo ip netns exec red ip addr add 10.0.0.1/24 dev veth-red
sudo ip netns exec red ip link set veth-red up
sudo ip netns exec red ip link set lo up

# Configure the blue namespace
sudo ip netns exec blue ip addr add 10.0.0.2/24 dev veth-blue
sudo ip netns exec blue ip link set veth-blue up
sudo ip netns exec blue ip link set lo up
```

Verify the configuration:

```bash
# Check red namespace
sudo ip netns exec red ip addr show

# Check blue namespace
sudo ip netns exec blue ip addr show
```

**Fill in the table:**

| Namespace | Interface | IP Address | State |
|-----------|-----------|------------|-------|
| red | veth-red | ? | ? |
| blue | veth-blue | ? | ? |

**Answers:**
- red: veth-red, 10.0.0.1/24, UP
- blue: veth-blue, 10.0.0.2/24, UP

---

### Part 5: Test Connectivity Between Namespaces (10 minutes)

```bash
# From red namespace, ping blue namespace
sudo ip netns exec red ping -c 3 10.0.0.2
```

**Expected output:**

```
PING 10.0.0.2 (10.0.0.2) 56(84) bytes of data.
64 bytes from 10.0.0.2: icmp_seq=1 ttl=64 time=0.045 ms
64 bytes from 10.0.0.2: icmp_seq=2 ttl=64 time=0.042 ms
64 bytes from 10.0.0.2: icmp_seq=3 ttl=64 time=0.038 ms
```

Success! The namespaces can now talk to each other.

Now try the reverse:

```bash
# From blue namespace, ping red namespace
sudo ip netns exec blue ping -c 3 10.0.0.1
```

**Question:** Why does this work?

**Answer:** The veth pair acts like a virtual cable connecting the two namespaces. Packets sent into one end come out the other end.

---

### Part 6: Trace the Packet Path (15 minutes)

Let's understand exactly how the ping packet travels:

1. **In red namespace:** Ping sends packet to 10.0.0.2
2. **Routing decision:** Red's routing table says "10.0.0.0/24 is directly connected via veth-red"
3. **Packet enters veth-red** in the red namespace
4. **Packet exits veth-blue** in the blue namespace (because they are paired)
5. **Blue namespace receives the packet** on veth-blue
6. **Blue responds** by sending ICMP echo reply back through veth-blue
7. **Packet exits veth-red** in the red namespace
8. **Red receives the reply**

Verify the routing tables:

```bash
# Red's routing table
sudo ip netns exec red ip route show

# Blue's routing table
sudo ip netns exec blue ip route show
```

**Expected output:**

```
# Red:
10.0.0.0/24 dev veth-red proto kernel scope link src 10.0.0.1

# Blue:
10.0.0.0/24 dev veth-blue proto kernel scope link src 10.0.0.2
```

This shows that both namespaces know how to reach the 10.0.0.0/24 network via their veth interface.

---

### Part 7: View ARP Tables (10 minutes)

When red pings blue, it needs to know blue's MAC address.

```bash
# Check red's ARP table
sudo ip netns exec red ip neigh show

# Check blue's ARP table
sudo ip netns exec blue ip neigh show
```

**Expected output:**

```
# Red:
10.0.0.2 dev veth-red lladdr <MAC-address> REACHABLE

# Blue:
10.0.0.1 dev veth-blue lladdr <MAC-address> REACHABLE
```

This shows that Layer 2 (ARP) is working correctly.

---

### Part 8: Clean Up (5 minutes)

```bash
# Delete both namespaces (this also deletes the veth pair)
sudo ip netns delete red
sudo ip netns delete blue

# Verify they are gone
sudo ip netns list
```

**Note:** When you delete a namespace, all interfaces inside it are automatically deleted. This includes the veth pair.

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What is a veth pair?
2. How many ends does a veth pair have?
3. Can you create a veth interface without a pair?
4. What happens when you send a packet into one end of a veth pair?
5. How does Docker connect a container to the host network?

**Answers:**

1. A pair of virtual network interfaces that act like a virtual Ethernet cable
2. Two ends (always created in pairs)
3. No — veth interfaces must be created in pairs
4. It comes out the other end of the pair
5. Creates a veth pair — one end in the container's namespace (eth0), one end on the host (vethXXX)

---

## Today I Learned (TIL) — Write This Down

In your notebook, write 5 bullet points:

- What did I learn today?
- What surprised me?
- What do I still not understand?

Example:

```
March 31, 2026 — Day 16: veth Pairs

- veth pairs are virtual Ethernet cables with two ends
- One end can be in one namespace, the other end in another namespace
- This is how containers get network connectivity
- When I see vethXXXXX on an OCP node, that's the host end of a pod's network
- ARP works inside namespaces just like on real networks
```

---

## Commands Cheat Sheet

**veth Pair Management:**

```bash
# Create a veth pair
sudo ip link add <name1> type veth peer name <name2>

# Move one end into a namespace
sudo ip link set <name1> netns <namespace>

# Assign IP address to veth interface
sudo ip netns exec <ns> ip addr add <IP>/<mask> dev <interface>

# Bring up the interface
sudo ip netns exec <ns> ip link set <interface> up

# Test connectivity
sudo ip netns exec <ns> ping <IP>

# Delete namespaces (this also deletes veth pairs inside them)
sudo ip netns delete <namespace>
```

**Complete Example:**

```bash
# Create namespaces
sudo ip netns add ns1
sudo ip netns add ns2

# Create veth pair
sudo ip link add veth1 type veth peer name veth2

# Move into namespaces
sudo ip link set veth1 netns ns1
sudo ip link set veth2 netns ns2

# Configure IPs
sudo ip netns exec ns1 ip addr add 192.168.1.1/24 dev veth1
sudo ip netns exec ns2 ip addr add 192.168.1.2/24 dev veth2

# Bring up interfaces
sudo ip netns exec ns1 ip link set veth1 up
sudo ip netns exec ns2 ip link set veth2 up
sudo ip netns exec ns1 ip link set lo up
sudo ip netns exec ns2 ip link set lo up

# Test
sudo ip netns exec ns1 ping -c 3 192.168.1.2
```

---

## What's Next?

**Tomorrow (Day 17):** Linux Bridge — connecting multiple namespaces together

**Why it matters:** A veth pair can only connect TWO namespaces. Tomorrow you will learn how to connect MANY namespaces using a Linux bridge — exactly how Docker and Kubernetes do it.

---

**End of Day 16 Lab**

Excellent work. You just learned how containers connect to the network. Tomorrow we scale this up to multiple containers.
