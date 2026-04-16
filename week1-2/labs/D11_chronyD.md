# Day 11: chrony and NTP — Time Synchronization

**Date:** Thursday, March 19, 2026  
**Phase:** 1 - Core Networking Fundamentals  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Understand why time synchronization matters
- Explain what NTP (Network Time Protocol) does
- Use chrony to check time sync status
- Troubleshoot time drift issues
- Explain why OpenShift requires accurate time

---

## Plain English: Why Does Time Matter?

**Every computer has a clock.** But computer clocks drift over time — they speed up or slow down.

**Without time synchronization:**
- Logs are out of order (you can't tell what happened when)
- TLS certificates fail (they have expiration times)
- Distributed databases break (Kubernetes etcd requires accurate time)
- Authentication fails (Kerberos requires time within 5 minutes)

**With time synchronization:**
- All machines agree on the current time
- Logs are in order
- Everything just works

**In OpenShift:**

If node clocks are more than **5 seconds** out of sync, weird things happen:
- API server rejects requests
- etcd cluster becomes unstable
- Pods fail to schedule

**Time sync is CRITICAL.**

---

## NTP — Network Time Protocol

**NTP (Network Time Protocol)** is how computers synchronize their clocks.

**How it works:**

```
Your computer:  "What time is it?"
NTP server:     "It's 12:34:56.789 UTC"
Your computer:  "Okay, adjusting my clock..."
```

**NTP servers:**

- **Public NTP servers:** pool.ntp.org, time.google.com, time.cloudflare.com
- **Private NTP servers:** Your datacenter might run its own

**Stratum levels:**

| Stratum | What It Is | Example |
|---------|------------|---------|
| 0 | Atomic clock, GPS | Ultra-precise time source |
| 1 | NTP server directly connected to Stratum 0 | time.google.com |
| 2 | NTP server syncing from Stratum 1 | Your datacenter NTP server |
| 3+ | NTP clients syncing from Stratum 2 | Your OpenShift nodes |

**Your machine should sync from Stratum 1 or 2 servers.**

---

## chrony — The Modern NTP Client

**chrony** is the NTP client used on Red Hat Enterprise Linux (RHEL), Fedora, CentOS.

**Why chrony instead of ntpd?**

- **Faster** — Syncs time quicker
- **Better for VMs** — Handles clock jumps (VMs pause/resume)
- **Better for laptops** — Works even when offline

**Components:**

- **chronyd** = The daemon (background service)
- **chronyc** = The command-line tool to query status

---

## Hands-On Lab

### Part 1: Check Time Sync Status (10 minutes)

Run this command:

```bash
chronyc tracking
```

**Expected output:**

```
Reference ID    : C0A80001 (192.168.0.1)
Stratum         : 3
Ref time (UTC)  : Thu Mar 19 12:34:56 2026
System time     : 0.000123456 seconds fast of NTP time
Last offset     : +0.000098765 seconds
RMS offset      : 0.000234567 seconds
Frequency       : 12.345 ppm slow
Residual freq   : +0.012 ppm
Skew            : 0.123 ppm
Root delay      : 0.012345678 seconds
Root dispersion : 0.001234567 seconds
Update interval : 64.5 seconds
Leap status     : Normal
```

**What each field means:**

| Field | Meaning |
|-------|---------|
| **Reference ID** | NTP server you are syncing from |
| **Stratum** | Distance from the atomic clock (lower is better) |
| **System time** | How far off you are from NTP time |
| **Last offset** | Last time adjustment |
| **Frequency** | Clock drift rate (ppm = parts per million) |
| **Update interval** | How often chrony checks NTP server |
| **Leap status** | Normal = good, other values = problem |

**Your task:**

1. Run `chronyc tracking`
2. Find the **Stratum** (should be 2, 3, or 4)
3. Find the **System time offset** (should be close to 0)
4. Find the **Reference ID** (your NTP server)

**Good status:**

- Stratum: 2-4
- System time offset: < 0.1 seconds
- Leap status: Normal

**Bad status:**

- Stratum: 16 (not synced)
- System time offset: > 1 second
- Leap status: Not synchronized

---

### Part 2: Check NTP Sources (10 minutes)

Run this command:

```bash
chronyc sources -v
```

**Expected output:**

```
  .-- Source mode  '^' = server, '=' = peer, '#' = local clock.
 / .- Source state '*' = current best, '+' = combined, '-' = not combined,
| /             'x' = may be in error, '~' = too variable, '?' = unusable.
||                                                 .- xxxx [ yyyy ] +/- zzzz
||      Reachability register (octal) -.           |  xxxx = adjusted offset,
||      Log2(Polling interval) --.      |          |  yyyy = measured offset,
||                                \     |          |  zzzz = estimated error.
||                                 |    |           \
MS Name/IP address         Stratum Poll Reach LastRx Last sample
===============================================================================
^* time.google.com              1   6   377    34   +123us[ +456us] +/-   15ms
^+ pool.ntp.org                 2   6   377    35   -234us[ -567us] +/-   25ms
^- time.cloudflare.com          1   6   377    36   +789us[+1012us] +/-   30ms
```

**What the symbols mean:**

| Symbol | Meaning |
|--------|---------|
| `^` | Server mode (you are syncing from this server) |
| `*` | Current best source (actively used) |
| `+` | Combined source (used for accuracy) |
| `-` | Not combined (available but not used) |
| `x` | May be in error (bad source) |
| `?` | Unusable (cannot reach) |

**Your task:**

1. Run `chronyc sources -v`
2. Find the source with `*` (your primary NTP server)
3. Check the **Reach** column (should be 377 octal = all reachable)
4. Check the **Stratum** (should be 1-3)

**Good status:**

- At least one source with `*` or `+`
- Reach = 377
- Last sample < 1ms

**Bad status:**

- All sources marked `?` (cannot reach)
- Reach = 0 (no response)

---

### Part 3: Check chronyd Service Status (5 minutes)

Run this command:

```bash
systemctl status chronyd
```

**Expected output:**

```
● chronyd.service - NTP client/server
   Loaded: loaded (/usr/lib/systemd/system/chronyd.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2026-03-16 10:00:00 UTC; 3 days ago
 Main PID: 1234 (chronyd)
   CGroup: /system.slice/chronyd.service
           └─1234 /usr/sbin/chronyd
```

**Your task:**

1. Check if chronyd is **active (running)**
2. Check if it is **enabled** (starts on boot)

**If chronyd is not running:**

```bash
sudo systemctl start chronyd
sudo systemctl enable chronyd
```

---

### Part 4: Force Time Sync (10 minutes)

**If your clock is very wrong** (more than 1000 seconds off), chrony will NOT automatically fix it.

**You need to force a sync:**

```bash
sudo chronyc makestep
```

**Expected output:**

```
200 OK
```

**What this does:**

- Immediately jumps the clock to the correct time
- Normally chrony slowly "slews" the clock (adjusts gradually)
- Use `makestep` only when the clock is very wrong

**Your task:**

1. Check current time: `date`
2. Check NTP time offset: `chronyc tracking | grep "System time"`
3. If offset is large, run `sudo chronyc makestep`
4. Verify: `chronyc tracking`

---

### Part 5: Add a Custom NTP Server (10 minutes)

**Scenario:** Your datacenter has a local NTP server at `192.168.1.1`.

**Edit the chrony configuration:**

```bash
sudo vi /etc/chrony.conf
```

**Add this line:**

```
server 192.168.1.1 iburst
```

**What `iburst` means:**

- Send multiple requests at startup (faster sync)

**Restart chronyd:**

```bash
sudo systemctl restart chronyd
```

**Verify:**

```bash
chronyc sources
```

You should see `192.168.1.1` in the list.

**Your task:**

1. Edit `/etc/chrony.conf`
2. Add a test NTP server (you can use `time.google.com`)
3. Restart chronyd
4. Verify with `chronyc sources`

**Note:** If the server does not exist, it will appear as `?` (unusable).

---

### Part 6: Troubleshoot Time Drift (15 minutes)

**Scenario:** Your clock is drifting (system time is consistently wrong).

**Step 1: Check tracking**

```bash
chronyc tracking
```

Look for:
- **System time offset:** Should be close to 0
- **Frequency:** Clock drift rate (should be < 100 ppm)

**Step 2: Check sources**

```bash
chronyc sources
```

Look for:
- At least one source with `*` (best source)
- Reach = 377 (all packets received)

**Step 3: Check for firewall blocking NTP**

```bash
sudo iptables -L -n | grep 123
```

NTP uses **UDP port 123**. If it's blocked, chrony cannot sync.

**Step 4: Manually force sync**

```bash
sudo chronyc -a makestep
```

**Step 5: Check logs**

```bash
journalctl -u chronyd -n 50
```

Look for errors like:
- "No suitable source for synchronisation"
- "Backward time jump detected"

**Your task:**

1. Run through all 5 troubleshooting steps
2. Document any issues you find
3. Fix them if possible

---

## OpenShift and Time Sync

**In OpenShift:**

- **All nodes must have accurate time** (within 5 seconds)
- **etcd** requires accurate time (database consistency)
- **TLS certificates** have expiration times (time must be correct)
- **Kerberos** requires time within 5 minutes

**Best practice:**

- Configure all nodes to sync from the same NTP server
- Monitor time drift with Prometheus
- Alert if offset > 1 second

**How to check time on OpenShift nodes:**

```bash
oc debug node/<node-name>
chroot /host
chronyc tracking
```

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What does NTP stand for?
2. What port does NTP use?
3. What is Stratum in NTP?
4. What command checks time sync status?
5. What does `chronyc sources` show?
6. What does `makestep` do?
7. Why does OpenShift require accurate time?

**Answers:**

1. Network Time Protocol
2. UDP port 123
3. Distance from the atomic clock (Stratum 1 = closest)
4. `chronyc tracking`
5. Shows NTP servers you are syncing from
6. Immediately jumps the clock to the correct time
7. etcd requires accurate time, TLS certificates check expiration, Kerberos requires time sync

---

## Today I Learned (TIL) — Write This Down

Example:

```
March 19, 2026 — Day 11: chrony and NTP

- NTP = Network Time Protocol, synchronizes computer clocks
- chrony = modern NTP client for RHEL/Fedora
- Commands: chronyc tracking (status), chronyc sources (NTP servers)
- Stratum = distance from atomic clock (1 = best, 16 = not synced)
- NTP uses UDP port 123
- makestep = force clock to jump immediately
- OpenShift requires time sync within 5 seconds for etcd and TLS
- Check logs: journalctl -u chronyd
```

---

## Commands Cheat Sheet

```bash
# Check time sync status
chronyc tracking

# Show NTP sources
chronyc sources -v

# Check chronyd service
systemctl status chronyd

# Start chronyd
sudo systemctl start chronyd

# Enable chronyd (start on boot)
sudo systemctl enable chronyd

# Force time sync
sudo chronyc makestep

# Check current time
date

# Check time in UTC
date -u

# Edit chrony config
sudo vi /etc/chrony.conf

# Restart chronyd
sudo systemctl restart chronyd

# Check logs
journalctl -u chronyd -n 50

# Check if NTP port is blocked
sudo iptables -L -n | grep 123
```

---

## What's Next?

**Tomorrow (Day 12):** systemd and journalctl — Managing Services and Logs

**Practice tonight:**
- Run `chronyc tracking` and understand every field
- Run `chronyc sources` and identify your best NTP server
- Check chronyd logs for any errors

---

**End of Day 11 Lab**

Good job. Tomorrow we learn about systemd — how Linux manages services like NetworkManager and chronyd.
