# Day 22: Linux Bonding — High Availability for Node Networks

**Date:** Monday, April 6, 2026  
**Phase:** 2 - Linux & Container Networking  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Explain what NIC bonding is and why it is used
- Understand different bonding modes (active-backup, LACP, etc.)
- Create a bonded interface on Linux
- Test failover when a bonded interface goes down
- Apply bonding concepts to OpenShift node networking

---

## Plain English: What Is NIC Bonding?

Imagine you are driving to an important meeting, and you take a single road.

If that road has an accident, you are stuck. No alternative.

**NIC bonding** is like having TWO roads to the same destination. If one road is blocked, you automatically take the other road without even thinking about it.

In networking:
- You have two (or more) physical network cards (NICs)
- They are "bonded" together to act as ONE logical interface
- If one NIC fails, traffic automatically switches to the other NIC
- Applications do not notice anything — the bond interface keeps the same IP address

**Why does this matter for OCP?**

OpenShift nodes are critical infrastructure. If a node's NIC fails, pods lose connectivity and the cluster is degraded.

**Best practice:** OCP nodes should use bonded interfaces for:
- High availability (failover)
- Increased bandwidth (some bonding modes)
- Load balancing (some bonding modes)

In production OCP clusters, you will see bonds like `bond0` or `team0` configured via NMState.

---

## What Is NIC Bonding?

**NIC bonding (or teaming)** is a Linux kernel feature that combines multiple physical network interfaces into a single logical interface.

Benefits:
- **Redundancy:** If one NIC fails, the other takes over
- **Bandwidth aggregation:** Some modes combine bandwidth (e.g., 2x 1Gbps = 2Gbps)
- **Load balancing:** Distribute traffic across multiple NICs

**Bonding vs Teaming:**
- **Bonding:** Older, kernel-level implementation
- **Teaming:** Newer, userspace implementation with more features
- Both achieve the same goal
- OpenShift uses NMState to configure both

---

## Bonding Modes

Linux bonding supports several modes:

| Mode | Name | Description | Use Case |
|------|------|-------------|----------|
| **0** | **balance-rr** | Round-robin (load balance) | Lab/testing, requires switch support |
| **1** | **active-backup** | One NIC active, others standby | Most common, works with any switch |
| **2** | **balance-xor** | XOR hash for load balancing | Requires switch configuration |
| **3** | **broadcast** | Send on all NICs | Redundancy (rare use case) |
| **4** | **802.3ad (LACP)** | Dynamic link aggregation | Requires switch LACP support |
| **5** | **balance-tlb** | Adaptive transmit load balancing | No switch config needed |
| **6** | **balance-alb** | Adaptive load balancing (tx+rx) | No switch config needed |

**Most common in production:**
- **Mode 1 (active-backup):** Simplest, works with any switch
- **Mode 4 (802.3ad/LACP):** Best performance, requires switch configuration

Today you will use **mode 1 (active-backup)** because it works on any system.

---

## Hands-On Lab

### Part 1: Check Current Network Interfaces (5 minutes)

```bash
# List all network interfaces
ip link show

# Show IP addresses
ip addr show
```

**Question:** How many physical network interfaces do you have?

**Note:** You need at least TWO interfaces to create a bond. If you only have one, you can still follow along conceptually, but you cannot test failover.

For this lab, we will assume you have:
- `eth0` or `ens3` (primary interface)
- `eth1` or `ens4` (secondary interface)

**Adjust the commands to match your interface names.**

---

### Part 2: Load the Bonding Kernel Module (5 minutes)

```bash
# Load the bonding module
sudo modprobe bonding

# Verify it loaded
lsmod | grep bonding
```

**Expected output:**

```
bonding               165888  0
```

This shows the bonding kernel module is loaded.

---

### Part 3: Create a Bond Interface (10 minutes)

**Warning:** This will temporarily disrupt your network. Only do this in a lab environment or if you have console access.

```bash
# Create a bond interface in active-backup mode
sudo ip link add bond0 type bond mode active-backup

# Verify it was created
ip link show bond0
```

**Expected output:**

```
5: bond0: <BROADCAST,MULTICAST,MASTER> mtu 1500 qdisc noop state DOWN mode DEFAULT
    link/ether XX:XX:XX:XX:XX:XX brd ff:ff:ff:ff:ff:ff
```

**What does MASTER mean?**

The bond is the "master" interface. Slave interfaces (eth0, eth1) will be added to it.

---

### Part 4: Add Slave Interfaces to the Bond (15 minutes)

**Important:** This will take your interfaces offline temporarily. Make sure you have console access.

```bash
# Bring down the interfaces first
sudo ip link set eth0 down
sudo ip link set eth1 down

# Add eth0 as a slave to bond0
sudo ip link set eth0 master bond0

# Add eth1 as a slave to bond0
sudo ip link set eth1 master bond0

# Bring up the bond and slaves
sudo ip link set bond0 up
sudo ip link set eth0 up
sudo ip link set eth1 up
```

**Verify the bond:**

```bash
# Show bond details
cat /proc/net/bonding/bond0
```

**Expected output:**

```
Ethernet Channel Bonding Driver: v3.7.1

Bonding Mode: fault-tolerance (active-backup)
Primary Slave: None
Currently Active Slave: eth0
MII Status: up
MII Polling Interval (ms): 100
Up Delay (ms): 0
Down Delay (ms): 0

Slave Interface: eth0
MII Status: up
Speed: 1000 Mbps
Duplex: full
Link Failure Count: 0
Permanent HW addr: XX:XX:XX:XX:XX:XX

Slave Interface: eth1
MII Status: up
Speed: 1000 Mbps
Duplex: full
Link Failure Count: 0
Permanent HW addr: YY:YY:YY:YY:YY:YY
```

**Key fields:**
- **Bonding Mode:** active-backup
- **Currently Active Slave:** eth0 (this is the active interface)
- **Slave interfaces:** eth0 and eth1 are both UP

---

### Part 5: Assign an IP Address to the Bond (10 minutes)

```bash
# Assign an IP to bond0 (use an IP from your subnet)
sudo ip addr add 192.168.1.100/24 dev bond0

# Add a default route via bond0
sudo ip route add default via 192.168.1.1 dev bond0

# Verify
ip addr show bond0
ip route show
```

**Note:** Replace `192.168.1.100/24` and `192.168.1.1` with appropriate values for your network.

---

### Part 6: Test Connectivity (10 minutes)

```bash
# Test connectivity
ping -c 3 8.8.8.8
```

**Expected result:** Ping should succeed.

**What is happening?**

Traffic is going out via bond0, which is using eth0 (the active slave).

---

### Part 7: Simulate NIC Failure (Failover Test) (15 minutes)

Now let's simulate a failure of eth0 and watch the bond fail over to eth1.

```bash
# In one terminal, continuously ping to watch for interruptions
ping 8.8.8.8
```

In another terminal:

```bash
# Bring down eth0 (simulate cable unplug or NIC failure)
sudo ip link set eth0 down

# Check the bond status
cat /proc/net/bonding/bond0 | grep "Currently Active Slave"
```

**Expected output:**

```
Currently Active Slave: eth1
```

**What happened?**

The bond detected that eth0 went down and automatically switched to eth1. Traffic continued without interruption (maybe 1-2 dropped pings during failover).

Check your ping terminal — you should see:

```
64 bytes from 8.8.8.8: icmp_seq=10 ttl=117 time=10.2 ms
64 bytes from 8.8.8.8: icmp_seq=11 ttl=117 time=10.5 ms
(maybe 1-2 lost packets here during failover)
64 bytes from 8.8.8.8: icmp_seq=14 ttl=117 time=10.3 ms
64 bytes from 8.8.8.8: icmp_seq=15 ttl=117 time=10.4 ms
```

**This is high availability in action.**

---

### Part 8: Restore the Failed Interface (10 minutes)

```bash
# Bring eth0 back up
sudo ip link set eth0 up

# Check bond status again
cat /proc/net/bonding/bond0
```

**Question:** Which interface is active now?

**Answer:** Still eth1 (in active-backup mode, the bond does not fail back automatically unless configured to do so).

You can force it back:

```bash
# Force failback to eth0 (optional)
echo "eth0" | sudo tee /sys/class/net/bond0/bonding/active_slave
```

---

### Part 9: View Bond Statistics (10 minutes)

```bash
# View bond statistics
cat /proc/net/bonding/bond0

# View individual interface statistics
ip -s link show eth0
ip -s link show eth1
```

**Look for:**
- Link Failure Count (how many times each interface went down)
- RX/TX bytes (traffic counters)

---

### Part 10: Clean Up (5 minutes)

**Warning:** This will disrupt your network.

```bash
# Remove slaves from bond
sudo ip link set eth0 nomaster
sudo ip link set eth1 nomaster

# Delete the bond
sudo ip link delete bond0

# Reconfigure your original network (example):
sudo ip addr add <original-ip> dev eth0
sudo ip route add default via <gateway>
```

**Note:** In a real environment, you would use NetworkManager or NMState to persist bonding configuration across reboots.

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What is NIC bonding?
2. What is the difference between active-backup and LACP bonding modes?
3. What command creates a bond interface?
4. How do you check which slave is currently active?
5. Why do OCP nodes use bonding?

**Answers:**

1. Combining multiple NICs into one logical interface for redundancy and/or performance
2. active-backup: one NIC active at a time (simple, works with any switch); LACP: multiple NICs active simultaneously (requires switch LACP support)
3. `sudo ip link add bond0 type bond mode <mode>`
4. `cat /proc/net/bonding/bond0 | grep "Currently Active Slave"`
5. For high availability — if a NIC fails, the node stays connected

---

## Today I Learned (TIL) — Write This Down

In your notebook, write 5 bullet points:

- What did I learn today?
- What surprised me?
- What do I still not understand?

Example:

```
April 6, 2026 — Day 22: Linux Bonding

- NIC bonding combines multiple interfaces for redundancy
- active-backup mode is the simplest (one active, others standby)
- Failover happens automatically (1-2 second interruption)
- /proc/net/bonding/bond0 shows bond status and active slave
- OCP nodes should use bonding in production for HA
```

---

## Commands Cheat Sheet

**Linux Bonding Commands:**

```bash
# Load bonding module
sudo modprobe bonding

# Create bond interface
sudo ip link add bond0 type bond mode <mode>

# Bonding modes:
# mode 0 = balance-rr
# mode 1 = active-backup (most common)
# mode 4 = 802.3ad (LACP)

# Add slave to bond
sudo ip link set <interface> master bond0

# Remove slave from bond
sudo ip link set <interface> nomaster

# View bond status
cat /proc/net/bonding/bond0

# Check active slave
cat /proc/net/bonding/bond0 | grep "Currently Active Slave"

# Force failover to specific slave
echo "<interface>" | sudo tee /sys/class/net/bond0/bonding/active_slave

# Delete bond
sudo ip link delete bond0
```

**Complete Example:**

```bash
# Create active-backup bond
sudo ip link add bond0 type bond mode active-backup

# Add slaves
sudo ip link set eth0 master bond0
sudo ip link set eth1 master bond0

# Bring up
sudo ip link set bond0 up
sudo ip link set eth0 up
sudo ip link set eth1 up

# Assign IP
sudo ip addr add 192.168.1.100/24 dev bond0

# Test failover
sudo ip link set eth0 down   # Watch traffic switch to eth1
sudo ip link set eth0 up     # Restore eth0
```

---

## What's Next?

**Tomorrow (Day 23):** NMState — declarative node network configuration in OCP

**Why it matters:** You just learned bonding manually. Tomorrow you will learn how OpenShift manages node networking declaratively using NMState YAML — the production way to configure bonding.

---

**End of Day 22 Lab**

Great work. You now understand bonding for high availability. Tomorrow you will see how OCP automates this.
