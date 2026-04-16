# Day 12: systemd and journalctl — Managing Services and Logs

**Date:** Friday, March 20, 2026  
**Phase:** 1 - Core Networking Fundamentals  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Understand what systemd is and why it exists
- Start, stop, and check service status
- Enable services to start on boot
- Read logs with journalctl
- Troubleshoot failing services
- Understand systemd units and dependencies

---

## Plain English: What Is systemd?

**systemd** is the **service manager** for Linux. It starts, stops, and manages background services (called "daemons").

Think of it like the manager of a restaurant:
- **Services** = Employees (chef, waiter, dishwasher)
- **systemd** = Manager (hires, fires, schedules)

**Examples of services:**
- **sshd** = SSH server (lets you log in remotely)
- **chronyd** = Time sync (we covered this yesterday)
- **NetworkManager** = Network configuration
- **firewalld** = Firewall
- **kubelet** = Kubernetes node agent (in OpenShift)

**Without systemd, you would have to manually start every service when you boot your computer.**

---

## Key systemd Concepts

| Concept | What It Is | Example |
|---------|------------|---------|
| **Unit** | A systemd object (service, timer, socket, etc.) | `sshd.service` |
| **Service** | A background daemon | `chronyd.service` |
| **Target** | A group of services (like a runlevel) | `multi-user.target` |
| **Enable** | Start service on boot | `systemctl enable sshd` |
| **Disable** | Do not start on boot | `systemctl disable sshd` |
| **Active** | Service is currently running | `Active: active (running)` |
| **Inactive** | Service is stopped | `Active: inactive (dead)` |

---

## systemctl — The systemd Command

**systemctl** is the command-line tool to control systemd.

**Common commands:**

| Command | What It Does |
|---------|--------------|
| `systemctl status <service>` | Check if service is running |
| `systemctl start <service>` | Start service |
| `systemctl stop <service>` | Stop service |
| `systemctl restart <service>` | Restart service |
| `systemctl enable <service>` | Enable service (start on boot) |
| `systemctl disable <service>` | Disable service (do not start on boot) |
| `systemctl is-active <service>` | Check if running (returns "active" or "inactive") |
| `systemctl is-enabled <service>` | Check if enabled (returns "enabled" or "disabled") |

---

## Hands-On Lab

### Part 1: Check Service Status (10 minutes)

Let's check if NetworkManager is running.

```bash
systemctl status NetworkManager
```

**Expected output:**

```
● NetworkManager.service - Network Manager
   Loaded: loaded (/usr/lib/systemd/system/NetworkManager.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2026-03-16 10:00:00 UTC; 4 days ago
 Main PID: 1234 (NetworkManager)
   CGroup: /system.slice/NetworkManager.service
           └─1234 /usr/sbin/NetworkManager --no-daemon

Mar 20 12:34:56 hostname NetworkManager[1234]: <info> device (eth0): state change...
```

**What each line means:**

| Line | Meaning |
|------|---------|
| **Loaded:** | Service definition file is loaded |
| **enabled** | Service starts on boot |
| **Active:** | Service is currently running |
| **Main PID:** | Process ID of the service |
| **CGroup:** | Control group (resource isolation) |
| **Logs:** | Recent log messages |

**Your task:**

1. Run `systemctl status NetworkManager`
2. Check if it is **active (running)**
3. Check if it is **enabled** (starts on boot)
4. Note the **Main PID**

---

### Part 2: Start and Stop a Service (10 minutes)

Let's test with the `chronyd` service.

**Step 1: Check status**

```bash
systemctl status chronyd
```

**Step 2: Stop the service**

```bash
sudo systemctl stop chronyd
```

**Step 3: Check status again**

```bash
systemctl status chronyd
```

**Expected output:**

```
● chronyd.service - NTP client/server
   Loaded: loaded (/usr/lib/systemd/system/chronyd.service; enabled; vendor preset: enabled)
   Active: inactive (dead) since Fri 2026-03-20 12:40:00 UTC; 5s ago
```

**Notice:** `Active: inactive (dead)` means the service is stopped.

**Step 4: Start the service**

```bash
sudo systemctl start chronyd
```

**Step 5: Check status**

```bash
systemctl status chronyd
```

**Expected:** `Active: active (running)`

**Your task:**

1. Stop chronyd
2. Verify it's stopped
3. Start chronyd
4. Verify it's running

---

### Part 3: Enable and Disable a Service (10 minutes)

**Enable** means "start this service on boot."

**Step 1: Check if chronyd is enabled**

```bash
systemctl is-enabled chronyd
```

**Expected output:**

```
enabled
```

**Step 2: Disable it**

```bash
sudo systemctl disable chronyd
```

**Expected output:**

```
Removed /etc/systemd/system/multi-user.target.wants/chronyd.service.
```

**Step 3: Check again**

```bash
systemctl is-enabled chronyd
```

**Expected output:**

```
disabled
```

**Step 4: Re-enable it**

```bash
sudo systemctl enable chronyd
```

**Expected output:**

```
Created symlink /etc/systemd/system/multi-user.target.wants/chronyd.service → /usr/lib/systemd/system/chronyd.service.
```

**Your task:**

1. Disable chronyd
2. Verify it's disabled
3. Re-enable chronyd
4. Verify it's enabled

**Important:** Disabling a service does NOT stop it. It only prevents it from starting on boot.

---

### Part 4: View Logs with journalctl (15 minutes)

**journalctl** is the command to read systemd logs.

**Basic usage:**

```bash
journalctl -u NetworkManager
```

**What the flags mean:**
- `-u` = Unit (service name)

**Expected output:**

```
Mar 20 10:00:00 hostname NetworkManager[1234]: <info> device (eth0): state change...
Mar 20 10:05:00 hostname NetworkManager[1234]: <info> DHCP: address 192.168.1.100
```

**Common journalctl options:**

| Option | What It Does |
|--------|--------------|
| `-u <service>` | Show logs for specific service |
| `-n 50` | Show last 50 lines |
| `-f` | Follow (tail) logs in real-time |
| `--since "1 hour ago"` | Show logs from last hour |
| `--since "2026-03-20 10:00:00"` | Show logs since specific time |
| `-p err` | Show only errors |
| `-p warning` | Show warnings and errors |
| `--no-pager` | Print all (don't use less) |

**Your task:**

1. View NetworkManager logs: `journalctl -u NetworkManager -n 50`
2. Follow logs in real-time: `journalctl -u NetworkManager -f` (press Ctrl+C to stop)
3. View only errors: `journalctl -u NetworkManager -p err`

---

### Part 5: Troubleshoot a Failing Service (15 minutes)

**Scenario:** A service is failing to start. How do you troubleshoot?

**Step 1: Check status**

```bash
systemctl status <service>
```

Look for:
- **Active: failed** = Service crashed
- **Active: inactive (dead)** = Service stopped
- **Error messages** in the log output

**Step 2: View full logs**

```bash
journalctl -u <service> -n 100
```

Look for errors like:
- "Permission denied"
- "Address already in use"
- "Failed to start"

**Step 3: Check the service file**

```bash
systemctl cat <service>
```

This shows the service configuration.

**Example:**

```bash
systemctl cat sshd
```

**Output:**

```
[Unit]
Description=OpenSSH server daemon
After=network.target

[Service]
ExecStart=/usr/sbin/sshd -D
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

**What it means:**

- **ExecStart:** Command to run
- **After:** Start after network is up
- **Restart:** Restart if it crashes
- **WantedBy:** Start when multi-user.target is reached (normal boot)

**Your task:**

1. Pick a service (e.g., `sshd` or `chronyd`)
2. Check its status
3. View its logs
4. View its service file with `systemctl cat`

---

### Part 6: List All Services (10 minutes)

**See all running services:**

```bash
systemctl list-units --type=service --state=running
```

**See all failed services:**

```bash
systemctl list-units --type=service --state=failed
```

**See all enabled services:**

```bash
systemctl list-unit-files --type=service --state=enabled
```

**Your task:**

1. List all running services
2. Count how many are running
3. Check if any services have failed

---

## OpenShift and systemd

**In OpenShift, systemd manages:**

- **kubelet** = Kubernetes node agent
- **crio** = Container runtime
- **NetworkManager** = Network config
- **chronyd** = Time sync

**Common troubleshooting:**

```bash
# Check kubelet status
systemctl status kubelet

# View kubelet logs
journalctl -u kubelet -n 100

# Restart kubelet
sudo systemctl restart kubelet

# Check if kubelet is enabled
systemctl is-enabled kubelet
```

**If kubelet is not running, pods will not start.**

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What is systemd?
2. What command checks if a service is running?
3. What is the difference between `start` and `enable`?
4. What command shows logs for a service?
5. How do you follow logs in real-time?
6. How do you restart a service?

**Answers:**

1. systemd is the service manager for Linux (starts/stops/manages daemons)
2. `systemctl status <service>`
3. `start` = run now. `enable` = start on boot
4. `journalctl -u <service>`
5. `journalctl -u <service> -f`
6. `sudo systemctl restart <service>`

---

## Today I Learned (TIL) — Write This Down

Example:

```
March 20, 2026 — Day 12: systemd and journalctl

- systemd = service manager for Linux
- Commands: systemctl status (check), start (run), stop, restart, enable (on boot), disable
- journalctl = read systemd logs
- Common flags: -u <service> (specific service), -n 50 (last 50 lines), -f (follow)
- Active: active (running) = good. Active: failed = crashed
- OpenShift uses systemd for kubelet, crio, NetworkManager
- Troubleshooting: systemctl status → journalctl -u <service> → systemctl cat <service>
```

---

## Commands Cheat Sheet

```bash
# Check service status
systemctl status <service>

# Start service
sudo systemctl start <service>

# Stop service
sudo systemctl stop <service>

# Restart service
sudo systemctl restart <service>

# Enable service (start on boot)
sudo systemctl enable <service>

# Disable service
sudo systemctl disable <service>

# Check if running
systemctl is-active <service>

# Check if enabled
systemctl is-enabled <service>

# View logs for service
journalctl -u <service>

# View last 50 log lines
journalctl -u <service> -n 50

# Follow logs in real-time
journalctl -u <service> -f

# Show only errors
journalctl -u <service> -p err

# Show logs since 1 hour ago
journalctl -u <service> --since "1 hour ago"

# View service configuration
systemctl cat <service>

# List running services
systemctl list-units --type=service --state=running

# List failed services
systemctl list-units --type=service --state=failed

# Reload systemd (after editing service file)
sudo systemctl daemon-reload
```

---

## What's Next?

**Tomorrow (Day 13):** Cgroups — How Linux Limits Resources

**Practice tonight:**
- Check status of NetworkManager, chronyd, sshd
- View logs for each service
- Practice starting/stopping a service

---

**End of Day 12 Lab**

Good job. Tomorrow we learn about cgroups — how Linux limits CPU, memory, and network for each process (critical for containers).
