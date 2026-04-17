# Day 14: Weekend Scenario 2 — "Port 443 not reachable on my server"

**Date:** Sunday, March 22, 2026  
**Phase:** 1 - Core Networking Fundamentals (Week 2 Review)  
**Time:** 2 hours (full troubleshooting scenario)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Apply Weeks 1-2 knowledge to a complex troubleshooting scenario
- Systematically debug firewall, routing, and service issues
- Use iptables, systemd, ss, and tcpdump together
- Document your troubleshooting process
- Explain the root cause and fix

---

## The Scenario

**Support Ticket #67890:**

> Subject: Port 443 not reachable on my server  
> Priority: Critical  
> From: Security Team
>
> We have a web server running nginx on port 443 (HTTPS). External clients cannot reach it. The service is running, but connections time out.
>
> Please investigate and resolve immediately.

**Additional Information:**
- Server IP: 192.168.1.100
- Service: nginx (HTTPS on port 443)
- Firewall: firewalld / iptables
- OS: RHEL 9.2
- Expected behavior: External clients should be able to connect to `https://192.168.1.100`

---

## Your Mission

Using ALL the Week 1-2 skills you learned, you need to:

1. **Verify the service is running**
2. **Check if the port is listening**
3. **Test local connectivity**
4. **Test remote connectivity**
5. **Check firewall rules**
6. **Check routing**
7. **Identify the root cause**
8. **Fix the issue**
9. **Document everything**

---

## Part 1: Analyze the Problem (10 minutes)

Before touching any commands, think through this systematically.

**Given:**
- nginx is "running"
- Port 443 should be open
- External clients cannot connect (timeout)

**Possible causes:**

1. **Service is NOT actually running**
2. **Service is running but NOT listening on port 443**
3. **Service is listening but only on localhost (127.0.0.1)**
4. **Firewall is blocking port 443**
5. **Routing issue (no route to server)**
6. **iptables DROP rule blocking traffic**
7. **SELinux blocking traffic** (advanced, but possible)

**Your task:**

On paper, write down the 5 most likely causes in order of probability.

**Suggested order:**

1. Firewall blocking (most common)
2. Service not listening on correct IP
3. iptables rule blocking
4. Service not actually running
5. Routing issue

---

## Part 2: Verify the Service is Running (10 minutes)

**Step 1: Check if nginx is running**

```bash
systemctl status nginx
```

**Expected output (if running):**

```
● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; vendor preset: disabled)
   Active: active (running) since Sun 2026-03-22 10:00:00 UTC; 2h ago
 Main PID: 1234 (nginx)
   CGroup: /system.slice/nginx.service
           ├─1234 nginx: master process /usr/sbin/nginx
           └─1235 nginx: worker process
```

**Your task:**

1. Check if nginx is **active (running)**
2. Check if it is **enabled** (starts on boot)
3. If it is NOT running, start it: `sudo systemctl start nginx`

**Record your result:**

```
Step 2.1 Result:
[ ] nginx is running
[ ] nginx is stopped — STARTING IT
```

---

**Step 2: Check nginx logs**

```bash
journalctl -u nginx -n 50
```

**Look for errors like:**

- "bind() to 0.0.0.0:443 failed (98: Address already in use)"
- "could not open error log file"
- "permission denied"

**Your task:**

1. View the last 50 lines of nginx logs
2. Note any errors

**Record your result:**

```
Step 2.2 Result:
[ ] No errors in logs
[ ] Errors found: _________________
```

---

## Part 3: Check if Port 443 is Listening (15 minutes)

**Step 1: Check if anything is listening on port 443**

```bash
ss -tulpn | grep :443
```

**Expected output (if nginx is listening):**

```
tcp   LISTEN 0      128    0.0.0.0:443    0.0.0.0:*    users:(("nginx",pid=1234,fd=6))
```

**What to check:**

- **Protocol:** tcp (should be tcp, not udp)
- **State:** LISTEN (should be LISTEN)
- **Local Address:** `0.0.0.0:443` (listening on ALL interfaces) or `192.168.1.100:443` (specific IP)
- **Process:** nginx (should be nginx, pid 1234)

**Possible issues:**

| Output | Problem |
|--------|---------|
| No output | Nothing is listening on port 443 |
| `127.0.0.1:443` | Only listening on localhost (not reachable externally) |
| Different process (e.g., apache) | Port is already in use by another service |

**Your task:**

1. Run `ss -tulpn | grep :443`
2. Verify nginx is listening
3. Check if it's listening on `0.0.0.0` (all interfaces) or `127.0.0.1` (localhost only)

**Record your result:**

```
Step 3.1 Result:
[ ] nginx listening on 0.0.0.0:443 (good)
[ ] nginx listening on 127.0.0.1:443 (BAD — only localhost)
[ ] Nothing listening on port 443 (BAD)
[ ] Another process listening on port 443 (BAD)
```

---

**Step 2: Test local connectivity**

```bash
curl -k https://localhost
```

**What `-k` means:** Skip TLS certificate verification (for self-signed certs).

**Expected output (if nginx is working):**

```
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

**Expected output (if nginx is NOT working):**

```
curl: (7) Failed to connect to localhost port 443: Connection refused
```

**Your task:**

1. Test `curl -k https://localhost`
2. Test `curl -k https://192.168.1.100`

**Record your result:**

```
Step 3.2 Result:
[ ] curl https://localhost works
[ ] curl https://localhost fails
[ ] curl https://192.168.1.100 works
[ ] curl https://192.168.1.100 fails
```

---

## Part 4: Check Firewall Rules (20 minutes)

**Step 1: Check if firewalld is running**

```bash
systemctl status firewalld
```

**Your task:**

1. Check if firewalld is active
2. If it is, proceed to Step 2
3. If it is not, check iptables instead (Step 3)

---

**Step 2: Check firewalld rules (if firewalld is running)**

```bash
sudo firewall-cmd --list-all
```

**Expected output:**

```
public (active)
  target: default
  interfaces: eth0
  services: ssh dhcpv6-client
  ports: 
  protocols: 
  ...
```

**Your task:**

1. Check if **https** is in the **services** list
2. Check if **443/tcp** is in the **ports** list
3. If neither is present, port 443 is BLOCKED

**Fix (if port 443 is blocked):**

```bash
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload
```

**Verify:**

```bash
sudo firewall-cmd --list-all
```

You should see `https` in the services list.

**Record your result:**

```
Step 4.2 Result:
[ ] https service is allowed
[ ] https service was BLOCKED — FIXED IT
```

---

**Step 3: Check iptables rules (if firewalld is NOT running)**

```bash
sudo iptables -L -n -v
```

**Your task:**

1. Look for a rule that **ACCEPTs** port 443
2. Look for a rule that **DROPs** or **REJECTs** port 443

**Example ACCEPT rule:**

```
ACCEPT     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:443
```

**Example DROP rule:**

```
DROP       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:443
```

**If port 443 is blocked, add a rule:**

```bash
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
```

**Verify:**

```bash
sudo iptables -L INPUT -n -v | grep 443
```

**Record your result:**

```
Step 4.3 Result:
[ ] iptables ACCEPT rule exists for port 443
[ ] iptables DROP rule was blocking — FIXED IT
```

---

## Part 5: Test Remote Connectivity (15 minutes)

**Now test from an external machine.**

**From another machine (or use nc locally):**

```bash
nc -zv 192.168.1.100 443
```

**Expected output (if port is open):**

```
Connection to 192.168.1.100 443 port [tcp/https] succeeded!
```

**Expected output (if port is blocked):**

```
nc: connect to 192.168.1.100 port 443 (tcp) failed: Connection timed out
```

**Your task:**

1. Test from an external machine
2. If it fails, go back to firewall rules
3. If it succeeds, test with curl

**Record your result:**

```
Step 5 Result:
[ ] nc test succeeded — port is open
[ ] nc test failed — port is still blocked
```

---

## Part 6: Capture Traffic with tcpdump (15 minutes)

Let's see if packets are even arriving.

**Step 1: Start tcpdump on the server**

```bash
sudo tcpdump -i any 'tcp port 443' -n
```

**Step 2: From another terminal (or another machine), try to connect**

```bash
curl -k https://192.168.1.100
```

**Step 3: Go back to tcpdump output**

**Expected output (if packets are arriving):**

```
IP 192.168.1.50.54321 > 192.168.1.100.443: Flags [S], seq 123456, win 29200
IP 192.168.1.100.443 > 192.168.1.50.54321: Flags [S.], seq 789012, ack 123457
```

**What this means:**

- SYN packet arrived (client trying to connect)
- SYN-ACK sent back (server accepted connection)
- Connection succeeded

**Expected output (if packets are NOT arriving):**

```
(no output)
```

**What this means:**

- Packets are blocked before reaching the server
- Firewall is dropping them
- Routing issue

**Your task:**

1. Start tcpdump
2. Try to connect from another machine
3. Check if SYN packets arrive

**Record your result:**

```
Step 6 Result:
[ ] SYN packets arrive — firewall is NOT blocking
[ ] No packets arrive — firewall IS blocking
```

---

## Part 7: Check if nginx is Listening on the Correct IP (10 minutes)

**If nginx is only listening on 127.0.0.1, external clients cannot connect.**

**Step 1: Check nginx configuration**

```bash
sudo grep -r "listen" /etc/nginx/
```

**Expected output (good):**

```
listen 443 ssl;
listen [::]:443 ssl;
```

OR

```
listen 0.0.0.0:443 ssl;
```

**Expected output (bad):**

```
listen 127.0.0.1:443 ssl;
```

**If it's listening on 127.0.0.1, edit the config:**

```bash
sudo vi /etc/nginx/nginx.conf
```

**Change:**

```
listen 127.0.0.1:443 ssl;
```

**To:**

```
listen 443 ssl;
```

**Then reload nginx:**

```bash
sudo systemctl reload nginx
```

**Verify:**

```bash
ss -tulpn | grep :443
```

Should now show `0.0.0.0:443`.

**Record your result:**

```
Step 7 Result:
[ ] nginx listening on all interfaces (0.0.0.0)
[ ] nginx was listening on localhost only — FIXED IT
```

---

## Part 8: Check Routing (10 minutes)

**If the server is on a different network, check routing.**

**On the client machine:**

```bash
traceroute -n 192.168.1.100
```

**Expected output:**

```
 1  192.168.1.1       1.234 ms
 2  192.168.1.100     2.345 ms
```

**If it hangs at hop 1, there's a routing issue.**

**On the server, check if it has a default gateway:**

```bash
ip route show
```

**Expected output:**

```
default via 192.168.1.1 dev eth0
192.168.1.0/24 dev eth0 proto kernel scope link src 192.168.1.100
```

**If no default gateway, add one:**

```bash
sudo ip route add default via 192.168.1.1
```

**Record your result:**

```
Step 8 Result:
[ ] Routing is correct
[ ] No default gateway — FIXED IT
```

---

## Part 9: Root Cause Analysis (15 minutes)

Fill in this table based on your findings:

| Test | Result | Root Cause? |
|------|--------|-------------|
| nginx is running | [ ] Yes [ ] No | |
| Port 443 is listening | [ ] Yes [ ] No | |
| Listening on 0.0.0.0 | [ ] Yes [ ] No | |
| curl localhost works | [ ] Yes [ ] No | |
| curl 192.168.1.100 works | [ ] Yes [ ] No | |
| firewalld allows port 443 | [ ] Yes [ ] No | |
| iptables allows port 443 | [ ] Yes [ ] No | |
| nc from external works | [ ] Yes [ ] No | |
| tcpdump sees packets | [ ] Yes [ ] No | |
| Routing is correct | [ ] Yes [ ] No | |

**Now answer:**

1. What was the root cause?
2. What layer of the OSI model was the problem?
3. What was the fix?

**Example answers:**

**Scenario A: Firewall blocked port 443**

1. Root cause: firewalld did not allow port 443
2. OSI Layer: Layer 4 (Transport — iptables operates at Layer 3/4)
3. Fix: `sudo firewall-cmd --add-service=https --permanent && sudo firewall-cmd --reload`

**Scenario B: nginx listening on localhost only**

1. Root cause: nginx configured to listen on 127.0.0.1 instead of 0.0.0.0
2. OSI Layer: Layer 4 (Transport — binding issue)
3. Fix: Edit `/etc/nginx/nginx.conf`, change `listen 127.0.0.1:443` to `listen 443`, reload nginx

**Scenario C: iptables DROP rule**

1. Root cause: iptables rule was dropping port 443 traffic
2. OSI Layer: Layer 4 (Transport)
3. Fix: `sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT`

---

## Part 10: Document Your Work (20 minutes)

Fill out this troubleshooting log:

```
Troubleshooting Log — Support Ticket #67890
Date: March 22, 2026
Engineer: [Your Name]

Symptom:
- External clients cannot reach https://192.168.1.100
- Connection times out

Steps Taken:
1. Checked nginx status — [Result]
2. Checked if port 443 is listening — [Result]
3. Tested curl https://localhost — [Result]
4. Tested curl https://192.168.1.100 — [Result]
5. Checked firewalld rules — [Result]
6. Checked iptables rules — [Result]
7. Tested nc from external machine — [Result]
8. Captured traffic with tcpdump — [Result]
9. Checked nginx configuration — [Result]
10. Checked routing — [Result]

Root Cause:
[Write your root cause here]

OSI Layer:
[Which layer had the problem?]

Fix Applied:
[Write the fix command(s) here]

Verification:
[How did you verify the fix worked?]

Lessons Learned:
[What did you learn from this?]
```

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What command checks if a port is listening?
2. What does `ss -tulpn` show?
3. What does `firewall-cmd --list-all` show?
4. How do you allow port 443 in firewalld?
5. What does `0.0.0.0:443` mean vs `127.0.0.1:443`?
6. What does tcpdump show you?
7. What is the difference between Connection refused and Connection timed out?

**Answers:**

1. `ss -tulpn | grep :443`
2. All listening TCP and UDP ports
3. Active firewall rules
4. `sudo firewall-cmd --add-service=https --permanent && sudo firewall-cmd --reload`
5. `0.0.0.0:443` = all interfaces. `127.0.0.1:443` = localhost only
6. Live packet capture
7. Connection refused = port is closed. Connection timed out = firewall is blocking

---

## Today I Learned (TIL) — Write This Down

Example:

```
March 22, 2026 — Day 14: Week 2 Scenario

- Systematic troubleshooting: service → listening port → firewall → routing
- ss -tulpn shows what ports are listening and which process
- firewalld vs iptables: firewalld is a wrapper around iptables
- 0.0.0.0:443 = listening on all IPs, 127.0.0.1:443 = localhost only
- tcpdump -i any 'tcp port 443' captures traffic on all interfaces
- Connection timeout = firewall blocking, connection refused = service not listening
- Always document troubleshooting steps
```

---

## Commands Cheat Sheet

```bash
# Check service status
systemctl status nginx

# Check listening ports
ss -tulpn | grep :443

# Test local connectivity
curl -k https://localhost

# Check firewalld status
systemctl status firewalld

# List firewall rules
sudo firewall-cmd --list-all

# Allow HTTPS in firewalld
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload

# Check iptables rules
sudo iptables -L -n -v

# Add iptables rule
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT

# Test remote connectivity
nc -zv <ip> 443

# Capture traffic
sudo tcpdump -i any 'tcp port 443' -n

# Check nginx config
sudo grep -r "listen" /etc/nginx/

# Reload nginx
sudo systemctl reload nginx

# Check routing
ip route show
traceroute -n <ip>
```

---

## What's Next?

**Week 1-2 Complete!**

You have completed the Core Networking Fundamentals phase. You now understand:

**Week 1:**
- OSI Model
- IP Addressing & Subnetting
- DNS
- TCP vs UDP
- Routing, Switching, ARP
- NAT

**Week 2:**
- iptables
- Common Protocols (SSH, HTTP, HTTPS, etc.)
- VLANs
- Time Sync (chrony/NTP)
- systemd and journalctl
- Cgroups

**Next week (Week 3-4):** Linux & Container Networking
- Network namespaces
- veth pairs
- Bridges
- Container networking
- Docker/Podman networking

---

**End of Day 14 Lab — Weeks 1-2 Complete!**

Congratulations! You have built a solid foundation in networking. Take a break this weekend, then start Week 3 on Monday.
