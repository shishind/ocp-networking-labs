# Day 10: VLANs — Virtual LANs

**Date:** Wednesday, March 18, 2026  
**Phase:** 1 - Core Networking Fundamentals  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Understand what a VLAN is and why it exists
- Explain how VLANs separate network traffic
- Create a VLAN interface on Linux
- Understand why OpenShift uses VLANs
- Troubleshoot VLAN tagging issues

---

## Plain English: What Is a VLAN?

**VLAN (Virtual Local Area Network)** lets you split **one physical network** into **multiple virtual networks**.

Think of it like apartment buildings:

- **One building (physical network)** = one Ethernet switch
- **Multiple apartments (VLANs)** = separate networks inside the same building
- Each apartment has its own mailbox, its own door — they are isolated

**Why it matters:**

Without VLANs:
- All devices on a switch see all traffic
- Security risk: anyone can sniff packets
- Performance problem: broadcast storms

With VLANs:
- Devices on VLAN 10 cannot see traffic on VLAN 20
- More secure, better performance

**In OpenShift:**
- VLANs separate tenant traffic
- VLANs separate storage network from data network
- VLANs isolate different environments (dev, test, prod)

---

## How VLANs Work — Tagging

When a packet enters a VLAN-aware switch, the switch **adds a tag** to the packet:

```
Before VLAN tag:
  [Ethernet Header] [IP Packet]

After VLAN tag:
  [Ethernet Header] [VLAN Tag: ID 10] [IP Packet]
```

The **VLAN tag** is a 12-bit number (0-4095) that identifies which VLAN the packet belongs to.

**Flow:**

```
Computer on VLAN 10 → Switch adds tag "VLAN 10" → Packet travels → Switch removes tag → Destination computer
```

**Important:**

- The computer usually does NOT see the tag (the switch adds/removes it)
- Unless you configure a **trunk port** (more on that later)

---

## VLAN Types

| Type | Description | Example Use |
|------|-------------|-------------|
| **Access Port** | Untagged port for end devices | Your laptop plugs into an access port (VLAN 10) |
| **Trunk Port** | Tagged port for switches | Switch-to-switch link carries VLAN 10, 20, 30 |
| **Native VLAN** | Default VLAN for untagged traffic | Usually VLAN 1 |

**Access port:**
- Belongs to **one VLAN**
- Switch adds/removes VLAN tag automatically
- End device sees no tags

**Trunk port:**
- Carries **multiple VLANs**
- Tags are preserved
- Used between switches or between switch and router

---

## VLAN Numbering

| VLAN ID | Purpose |
|---------|---------|
| **0** | Reserved (priority tagging) |
| **1** | Default VLAN (native VLAN) |
| **2-1001** | Normal VLANs |
| **1002-1005** | Reserved for legacy protocols |
| **1006-4094** | Extended VLANs |
| **4095** | Reserved |

**Best practice:** Use 10, 20, 30, etc. for your VLANs (easier to remember).

---

## How to Create a VLAN on Linux

On Linux, you can create a VLAN interface on top of a physical interface.

**Example:**

```bash
sudo ip link add link eth0 name eth0.10 type vlan id 10
```

**What this does:**

- **Parent interface:** eth0 (physical NIC)
- **VLAN interface:** eth0.10 (virtual interface for VLAN 10)
- **VLAN ID:** 10

**Then bring it up:**

```bash
sudo ip link set eth0.10 up
```

**And assign an IP:**

```bash
sudo ip addr add 192.168.10.100/24 dev eth0.10
```

**Now you can send traffic on VLAN 10:**

```bash
ping -I eth0.10 192.168.10.1
```

---

## OpenShift and VLANs

In OpenShift, VLANs are commonly used for:

1. **Tenant isolation** — Different customers on different VLANs
2. **Network separation** — Separate storage network (iSCSI, NFS) from pod network
3. **Security zones** — DMZ, internal, management

**Example:**

- **VLAN 10:** Management network (API server, SSH)
- **VLAN 20:** Pod network (10.128.0.0/14)
- **VLAN 30:** Storage network (NFS, Ceph)

**OpenShift nodes** often have:
- `eth0` → Management network (VLAN 10)
- `eth0.20` → Pod network (VLAN 20)
- `eth0.30` → Storage network (VLAN 30)

---

## Hands-On Lab

### Part 1: View Current Network Interfaces (10 minutes)

Run this command:

```bash
ip link show
```

**Expected output:**

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP
3: br-ex: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP
```

**Your task:**

1. Identify your **physical interface** (e.g., eth0, ens3, enp0s3)
2. Check if you have any VLAN interfaces (they will have a `.` in the name, like `eth0.10`)
3. Note the **MTU** (Maximum Transmission Unit — usually 1500)

---

### Part 2: Create a VLAN Interface (15 minutes)

**Warning:** Only do this on a test machine, not on production!

**Step 1: Create VLAN interface**

```bash
sudo ip link add link eth0 name eth0.10 type vlan id 10
```

**Step 2: Verify it exists**

```bash
ip link show eth0.10
```

**Expected output:**

```
4: eth0.10@eth0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
```

**Notice:**

- Name: `eth0.10` (VLAN interface)
- Parent: `@eth0` (physical interface)
- State: `DOWN` (we haven't brought it up yet)

**Step 3: Bring it up**

```bash
sudo ip link set eth0.10 up
```

**Step 4: Assign an IP address**

```bash
sudo ip addr add 192.168.10.100/24 dev eth0.10
```

**Step 5: Verify**

```bash
ip addr show eth0.10
```

**Expected output:**

```
4: eth0.10@eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP
    inet 192.168.10.100/24 scope global eth0.10
```

**Your task:**

1. Create the VLAN interface
2. Bring it up
3. Assign an IP
4. Verify with `ip addr show`

---

### Part 3: Test VLAN Interface (10 minutes)

**Try to ping the gateway on VLAN 10:**

```bash
ping -I eth0.10 192.168.10.1
```

**Expected result:**

- **If you have a VLAN 10 gateway:** Ping succeeds
- **If you don't have a VLAN 10 network:** Ping fails (no route)

**This is normal.** You just created a VLAN interface, but there is no VLAN 10 network on your switch.

**Your task:**

1. Try to ping the gateway
2. Understand why it fails (no VLAN 10 network configured)

---

### Part 4: Delete the VLAN Interface (5 minutes)

**Important:** Always clean up test interfaces!

```bash
sudo ip link delete eth0.10
```

**Verify it's gone:**

```bash
ip link show eth0.10
```

**Expected output:**

```
Device "eth0.10" does not exist.
```

**Your task:**

1. Delete the VLAN interface
2. Verify it's gone

---

### Part 5: Understand VLAN Tagging with tcpdump (15 minutes)

Let's see VLAN tags in a packet capture.

**If you have access to a VLAN trunk port:**

```bash
sudo tcpdump -i eth0 -e -n 'vlan'
```

**What the flags mean:**
- `-i eth0` = Interface
- `-e` = Show Ethernet headers (includes VLAN tags)
- `-n` = No DNS lookup
- `'vlan'` = Filter for VLAN-tagged packets

**Expected output:**

```
12:34:56.789012 02:42:ac:11:00:02 > ff:ff:ff:ff:ff:ff, ethertype 802.1Q (0x8100), length 64: vlan 10, p 0, ethertype ARP, Request who-has 192.168.10.1 tell 192.168.10.100
```

**Your task:**

1. Run tcpdump and look for `vlan X` in the output
2. Identify the **VLAN ID** (e.g., `vlan 10`)
3. Notice the **ethertype 802.1Q** (this is the VLAN tagging protocol)

**If you don't see any VLAN traffic:**

That's normal. Your network might not use VLANs, or you are on an access port (untagged).

---

## VLAN Tagging Protocol — 802.1Q

The standard for VLAN tagging is **IEEE 802.1Q**.

**Packet structure:**

```
[Ethernet Header]
   ↓
[Destination MAC] [Source MAC] [802.1Q Tag] [EtherType] [Payload] [FCS]
                                    ↑
                             [VLAN ID: 10]
```

**802.1Q tag:**
- **TPID (Tag Protocol ID):** 0x8100 (indicates this is a VLAN-tagged frame)
- **PCP (Priority Code Point):** 3 bits (QoS priority)
- **DEI (Drop Eligible Indicator):** 1 bit (can this frame be dropped if congested?)
- **VID (VLAN ID):** 12 bits (0-4095)

**Total:** 4 bytes (32 bits)

---

## Troubleshooting VLANs

| Symptom | Cause | Fix |
|---------|-------|-----|
| Cannot reach gateway on VLAN | VLAN mismatch (you are on VLAN 10, gateway is on VLAN 20) | Check VLAN ID on interface and switch |
| Packet loss on VLAN | MTU mismatch (VLAN adds 4 bytes) | Increase MTU to 1504 on VLAN interfaces |
| No VLAN traffic | Access port instead of trunk | Configure switch port as trunk |
| Wrong VLAN ID | Misconfigured VLAN interface | Check `ip -d link show` for VLAN ID |

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What does VLAN stand for?
2. What is the purpose of a VLAN?
3. What is the difference between an access port and a trunk port?
4. What is the VLAN tagging protocol called?
5. What command creates a VLAN interface on Linux?
6. What is the VLAN ID range?

**Answers:**

1. Virtual Local Area Network
2. To separate one physical network into multiple virtual networks
3. Access port = one VLAN, untagged. Trunk port = multiple VLANs, tagged
4. IEEE 802.1Q
5. `ip link add link eth0 name eth0.10 type vlan id 10`
6. 0-4095 (but 1-4094 are usable)

---

## Today I Learned (TIL) — Write This Down

Example:

```
March 18, 2026 — Day 10: VLANs

- VLAN = Virtual LAN, splits one physical network into multiple virtual networks
- Access port = one VLAN, untagged. Trunk port = multiple VLANs, tagged
- VLAN tagging protocol = IEEE 802.1Q (adds 4-byte tag)
- VLAN ID range = 0-4095 (1-4094 usable)
- Create VLAN: ip link add link eth0 name eth0.10 type vlan id 10
- OpenShift uses VLANs for tenant isolation, storage networks, security zones
- tcpdump -e shows VLAN tags in packets
```

---

## Commands Cheat Sheet

```bash
# Show all network interfaces
ip link show

# Create VLAN interface
sudo ip link add link eth0 name eth0.10 type vlan id 10

# Bring VLAN interface up
sudo ip link set eth0.10 up

# Assign IP to VLAN interface
sudo ip addr add 192.168.10.100/24 dev eth0.10

# Show VLAN details
ip -d link show eth0.10

# Delete VLAN interface
sudo ip link delete eth0.10

# Capture VLAN-tagged packets
sudo tcpdump -i eth0 -e -n 'vlan'

# Show only VLAN 10 packets
sudo tcpdump -i eth0 -e -n 'vlan 10'

# Ping using specific interface
ping -I eth0.10 192.168.10.1
```

---

## What's Next?

**Tomorrow (Day 11):** chrony and NTP — Time Synchronization

**Practice tonight:**
- Create a test VLAN interface (eth0.99)
- Assign it an IP
- Delete it
- Run tcpdump and look for VLAN tags

---

**End of Day 10 Lab**

Good job. Tomorrow we learn about time synchronization — why it matters for distributed systems like OpenShift.
