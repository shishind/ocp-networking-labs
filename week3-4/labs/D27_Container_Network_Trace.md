# Day 27: Container Network Trace — Complete Packet Path

**Date:** Saturday, April 11, 2026  
**Phase:** 2 - Linux & Container Networking  
**Time:** 2 hours (comprehensive hands-on lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Trace a packet's complete journey from container to internet and back
- Use tcpdump at multiple points along the path
- Understand how each component (veth, bridge, iptables, routing) affects the packet
- Apply this knowledge to troubleshoot real OCP networking issues
- Explain the packet flow to colleagues in plain English

---

## Plain English: The Complete Picture

This week you learned the building blocks:
- Network namespaces (Day 15)
- veth pairs (Day 16)
- Linux bridges (Day 17)
- iptables NAT (Day 18)
- conntrack (Day 19)
- Docker networking (Day 20)
- tcpdump (Days 24-25)
- nsenter (Day 26)

**Today you put it ALL together.**

You will start a container, send a ping to 8.8.8.8, and watch the packet at EVERY step:

1. **Inside the container** (container's eth0)
2. **On the veth pair** (host side)
3. **On the bridge** (docker0)
4. **After NAT** (host's eth0)
5. **Back again** (reply path)

This is the **most important lab of Week 3-4** because it synthesizes everything.

---

## The Packet Path (Visual)

```
[Container]
    | eth0 (172.17.0.2)
    | Packet: src=172.17.0.2, dst=8.8.8.8
    |
    v
[veth pair]
    | veth1234 (host side)
    |
    v
[docker0 bridge]
    | (172.17.0.1)
    | Routing decision: send to host's routing table
    |
    v
[iptables NAT]
    | POSTROUTING chain
    | MASQUERADE: rewrite src from 172.17.0.2 to host's public IP
    | conntrack: remember the translation
    |
    v
[Host eth0]
    | Packet: src=<host-public-ip>, dst=8.8.8.8
    |
    v
[Internet]
    | Packet reaches 8.8.8.8
    |
    v
[Reply comes back]
    | Packet: src=8.8.8.8, dst=<host-public-ip>
    |
    v
[Host eth0]
    |
    v
[iptables NAT + conntrack]
    | conntrack: "I remember this connection, rewrite dst to 172.17.0.2"
    |
    v
[docker0 bridge]
    | Forward to veth1234
    |
    v
[veth pair]
    |
    v
[Container eth0]
    | Packet: src=8.8.8.8, dst=172.17.0.2
    | Container receives ICMP reply
```

**Your job today:** Prove every step of this path using tcpdump.

---

## Hands-On Lab

### Part 1: Setup — Start a Container (5 minutes)

```bash
# Start an nginx container
sudo docker run -d --name trace-test nginx

# Get container IP
CONTAINER_IP=$(sudo docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' trace-test)
echo "Container IP: $CONTAINER_IP"

# Get container PID
CONTAINER_PID=$(sudo docker inspect -f '{{.State.Pid}}' trace-test)
echo "Container PID: $CONTAINER_PID"

# Find the veth interface on the host
CONTAINER_IF=$(sudo nsenter -t $CONTAINER_PID -n ip link show eth0 | head -1 | awk '{print $1}' | tr -d ':')
HOST_VETH=$(ip link show | grep "^$CONTAINER_IF:" | awk '{print $2}' | cut -d@ -f1)
echo "Host veth interface: $HOST_VETH"
```

---

### Part 2: Capture Point 1 — Inside the Container (10 minutes)

Open **Terminal 1** and run:

```bash
# Capture packets on the container's eth0 (inside the namespace)
sudo nsenter -t $CONTAINER_PID -n tcpdump -i eth0 -n icmp
```

**What you will see:** ICMP packets as they leave and enter the container.

---

### Part 3: Capture Point 2 — On the Host's veth Interface (10 minutes)

Open **Terminal 2** and run:

```bash
# Capture packets on the host side of the veth pair
sudo tcpdump -i $HOST_VETH -n icmp
```

**What you will see:** Same packets as Terminal 1, but seen from the host side of the veth.

---

### Part 4: Capture Point 3 — On the docker0 Bridge (10 minutes)

Open **Terminal 3** and run:

```bash
# Capture packets on the docker0 bridge
sudo tcpdump -i docker0 -n icmp
```

**What you will see:** Packets after they cross the bridge.

---

### Part 5: Capture Point 4 — On the Host's Physical Interface (10 minutes)

Open **Terminal 4** and run:

```bash
# Capture packets on the host's main interface (replace eth0 with your interface)
sudo tcpdump -i eth0 -n icmp
```

**What you will see:** Packets AFTER NAT — the source IP will be the host's IP, NOT the container's IP.

---

### Part 6: Send the Ping (5 minutes)

Now, with all 4 tcpdump sessions running, send a ping from the container:

Open **Terminal 5** and run:

```bash
# Ping from inside the container
sudo nsenter -t $CONTAINER_PID -n ping -c 1 8.8.8.8
```

---

### Part 7: Analyze the Output (20 minutes)

Go through each terminal and analyze what you see.

**Terminal 1 (Container's eth0):**

```
11:00:00.123456 IP 172.17.0.2 > 8.8.8.8: ICMP echo request, id 1, seq 1, length 64
11:00:00.145678 IP 8.8.8.8 > 172.17.0.2: ICMP echo reply, id 1, seq 1, length 64
```

**Observations:**
- Source: 172.17.0.2 (container's IP)
- Destination: 8.8.8.8
- Both request and reply are visible

---

**Terminal 2 (Host's veth):**

```
11:00:00.123457 IP 172.17.0.2 > 8.8.8.8: ICMP echo request, id 1, seq 1, length 64
11:00:00.145677 IP 8.8.8.8 > 172.17.0.2: ICMP echo reply, id 1, seq 1, length 64
```

**Observations:**
- Identical to Terminal 1
- This proves the veth pair is working
- Timestamp is microseconds later (packet traveled through the veth)

---

**Terminal 3 (docker0 bridge):**

```
11:00:00.123458 IP 172.17.0.2 > 8.8.8.8: ICMP echo request, id 1, seq 1, length 64
11:00:00.145676 IP 8.8.8.8 > 172.17.0.2: ICMP echo reply, id 1, seq 1, length 64
```

**Observations:**
- Still shows container IP (172.17.0.2)
- NAT has NOT happened yet
- Bridge is just forwarding at Layer 2

---

**Terminal 4 (Host's eth0):**

```
11:00:00.123460 IP <host-public-ip> > 8.8.8.8: ICMP echo request, id 1, seq 1, length 64
11:00:00.145675 IP 8.8.8.8 > <host-public-ip>: ICMP echo reply, id 1, seq 1, length 64
```

**Observations:**
- Source IP changed from 172.17.0.2 to host's public IP
- This is MASQUERADE in action (iptables NAT)
- Destination IP is still 8.8.8.8

---

### Part 8: Verify NAT Translation with conntrack (10 minutes)

While the ping is running (or right after), check conntrack:

```bash
# View the conntrack entry for this ping
sudo conntrack -L | grep 8.8.8.8
```

**Expected output:**

```
icmp     1 29 src=172.17.0.2 dst=8.8.8.8 type=8 code=0 id=1 src=8.8.8.8 dst=<host-public-ip> type=0 code=0 id=1
```

**What does this mean?**

- **Original direction:** src=172.17.0.2, dst=8.8.8.8
- **Reply direction:** src=8.8.8.8, dst=host-public-ip (then conntrack rewrites to 172.17.0.2)

conntrack remembers the NAT translation so the reply gets sent back to the container.

---

### Part 9: Trace the Return Path (15 minutes)

Let's focus on the reply packet.

Look at Terminal 4 (host's eth0) again:

```
IP 8.8.8.8 > <host-public-ip>: ICMP echo reply
```

This packet arrives at the host with destination = host's public IP.

**What happens next?**

1. **iptables checks conntrack:** "Do I have a NAT entry for this packet?"
2. **conntrack says:** "Yes, this is a reply to the ping from 172.17.0.2"
3. **iptables rewrites:** dst = host-public-ip → dst = 172.17.0.2
4. **Routing table:** "172.17.0.2 is on docker0"
5. **docker0 forwards** to the veth connected to the container
6. **veth pair** sends it into the container's eth0
7. **Container receives** the reply

You can see steps 5-7 in Terminals 3, 2, and 1.

---

### Part 10: Test with HTTP Instead of ICMP (20 minutes)

Let's trace an HTTP request to see TCP in action.

**Stop all tcpdump sessions (Ctrl+C in each terminal).**

Restart them with TCP filter:

**Terminal 1:**
```bash
sudo nsenter -t $CONTAINER_PID -n tcpdump -i eth0 -n tcp port 80
```

**Terminal 2:**
```bash
sudo tcpdump -i $HOST_VETH -n tcp port 80
```

**Terminal 3:**
```bash
sudo tcpdump -i docker0 -n tcp port 80
```

**Terminal 4:**
```bash
sudo tcpdump -i eth0 -n tcp port 80
```

**Terminal 5 (make an HTTP request from the container):**
```bash
sudo nsenter -t $CONTAINER_PID -n curl -s http://neverssl.com > /dev/null
```

**Analyze the output:**

**Terminal 1 (Container's eth0):**
```
[S]      172.17.0.2 > neverssl.com:80       (SYN)
[S.]     neverssl.com:80 > 172.17.0.2       (SYN-ACK)
[.]      172.17.0.2 > neverssl.com:80       (ACK)
[P.]     172.17.0.2 > neverssl.com:80       (HTTP GET)
[.]      neverssl.com:80 > 172.17.0.2       (ACK)
[P.]     neverssl.com:80 > 172.17.0.2       (HTTP Response)
[F.]     172.17.0.2 > neverssl.com:80       (FIN)
```

You will see the **complete TCP handshake and data transfer** inside the container.

**Terminal 4 (Host's eth0):**

Same flow, but with NAT:
```
[S]      <host-ip> > neverssl.com:80        (SYN, src NATed)
```

---

### Part 11: Intentionally Break the Path (20 minutes)

Let's break different parts of the path to see what happens.

**Break 1: Delete the default route from the container**

```bash
# Delete the default route
sudo nsenter -t $CONTAINER_PID -n ip route del default

# Try to ping
sudo nsenter -t $CONTAINER_PID -n ping -c 1 8.8.8.8
```

**Expected result:**
```
connect: Network is unreachable
```

**What do you see in tcpdump?**

Nothing in any terminal — the packet never even leaves the container because there is no route.

**Fix it:**
```bash
sudo nsenter -t $CONTAINER_PID -n ip route add default via 172.17.0.1
```

---

**Break 2: Drop packets at iptables**

```bash
# Block all forwarding from the container
sudo iptables -I FORWARD -s $CONTAINER_IP -j DROP

# Try to ping
sudo nsenter -t $CONTAINER_PID -n ping -c 1 8.8.8.8
```

**What do you see in tcpdump?**

- **Terminal 1, 2, 3:** Packet leaves the container, crosses veth, reaches bridge
- **Terminal 4:** Nothing — packet is dropped before reaching host's eth0

**Fix it:**
```bash
sudo iptables -D FORWARD -s $CONTAINER_IP -j DROP
```

---

**Break 3: Remove the MASQUERADE rule**

```bash
# Find the MASQUERADE rule
sudo iptables -t nat -L POSTROUTING -n -v --line-numbers

# Delete it (replace X with the line number)
sudo iptables -t nat -D POSTROUTING <line-number>

# Try to ping
sudo nsenter -t $CONTAINER_PID -n ping -c 1 8.8.8.8
```

**What do you see in tcpdump?**

- **Terminal 1, 2, 3, 4:** Packet leaves with src=172.17.0.2
- **No reply** — because 8.8.8.8 cannot route back to 172.17.0.2 (private IP)

**Fix it:**
```bash
# Recreate the MASQUERADE rule
sudo iptables -t nat -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
```

---

### Part 12: Document the Complete Packet Flow (10 minutes)

Write down the complete packet flow in your own words:

**Outbound (Container → Internet):**

1. Container creates packet: src=172.17.0.2, dst=8.8.8.8
2. Container's routing table: send to default gateway 172.17.0.1
3. Packet leaves via container's eth0
4. veth pair: packet exits host side (veth1234)
5. docker0 bridge: receives packet, forwards to host routing table
6. iptables NAT POSTROUTING: MASQUERADE rewrites src to host's public IP
7. conntrack: creates entry to remember the translation
8. Host's eth0: packet leaves with src=host-public-ip, dst=8.8.8.8
9. Internet: packet reaches 8.8.8.8

**Inbound (Internet → Container):**

1. Reply arrives: src=8.8.8.8, dst=host-public-ip
2. Host's eth0: receives packet
3. iptables + conntrack: "This is a reply to the container's packet, rewrite dst to 172.17.0.2"
4. Host routing table: 172.17.0.2 is on docker0
5. docker0 bridge: forwards to veth1234
6. veth pair: packet enters container's eth0
7. Container receives: src=8.8.8.8, dst=172.17.0.2

---

### Part 13: Clean Up (5 minutes)

```bash
# Stop all tcpdump sessions (Ctrl+C in each terminal)

# Remove the container
sudo docker stop trace-test
sudo docker rm trace-test
```

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What are the 5 main stages a packet goes through from container to internet?
2. At which stage does NAT happen?
3. What role does conntrack play in the reply path?
4. If you see packets in Terminal 1 but not Terminal 4, what is broken?
5. If you see packets in Terminal 4 but no reply, what is the likely cause?

**Answers:**

1. Container eth0 → veth pair → docker0 bridge → iptables NAT → host eth0
2. iptables POSTROUTING chain (after routing decision, before leaving the host)
3. conntrack remembers the NAT translation and rewrites the reply's destination IP back to the container's IP
4. iptables is dropping the packet (FORWARD chain) or routing is broken
5. NAT is missing (MASQUERADE rule), so the reply is sent to the wrong IP

---

## Today I Learned (TIL) — Write This Down

In your notebook, write 5 bullet points:

- What did I learn today?
- What surprised me?
- What do I still not understand?

Example:

```
April 11, 2026 — Day 27: Container Network Trace

- I traced a packet from container to internet through 5 stages
- NAT happens in iptables POSTROUTING, after the routing decision
- conntrack is critical for NAT — it remembers translations for reply packets
- I can use tcpdump at multiple points to isolate exactly where a problem is
- Breaking different parts of the path helps me understand how each piece works
```

---

## Commands Cheat Sheet

**Complete Container Network Trace Setup:**

```bash
# 1. Start container
docker run -d --name trace nginx

# 2. Get container info
CONTAINER_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' trace)
CONTAINER_PID=$(docker inspect -f '{{.State.Pid}}' trace)
CONTAINER_IF=$(sudo nsenter -t $CONTAINER_PID -n ip link show eth0 | head -1 | awk '{print $1}' | tr -d ':')
HOST_VETH=$(ip link show | grep "^$CONTAINER_IF:" | awk '{print $2}' | cut -d@ -f1)

# 3. Set up tcpdump at each stage
# Terminal 1: Container's eth0
sudo nsenter -t $CONTAINER_PID -n tcpdump -i eth0 -n

# Terminal 2: Host's veth
sudo tcpdump -i $HOST_VETH -n

# Terminal 3: docker0 bridge
sudo tcpdump -i docker0 -n

# Terminal 4: Host's physical interface
sudo tcpdump -i eth0 -n

# 4. Generate traffic
sudo nsenter -t $CONTAINER_PID -n ping -c 1 8.8.8.8

# 5. Check conntrack
sudo conntrack -L | grep 8.8.8.8
```

---

## What's Next?

**Tomorrow (Day 28):** Week 4 Scenario — Re-do difficult labs and fill knowledge gaps

**Why it matters:** You have learned a LOT this week. Tomorrow is dedicated to reviewing difficult concepts, re-doing challenging labs, and solidifying your understanding before moving to Week 5.

---

**End of Day 27 Lab**

Excellent work. You just completed the most comprehensive networking lab of Week 3-4. You now understand EXACTLY how container networking works under the hood.
