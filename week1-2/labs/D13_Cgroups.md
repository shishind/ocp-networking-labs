# Day 13: Cgroups — How Linux Limits Resources

**Date:** Saturday, March 21, 2026  
**Phase:** 1 - Core Networking Fundamentals  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Understand what cgroups (control groups) are
- Explain how cgroups limit CPU, memory, and network
- View cgroup settings for a process
- Understand how containers use cgroups
- Troubleshoot resource limit issues in OpenShift

---

## Plain English: What Are Cgroups?

**Cgroups (Control Groups)** are how Linux **limits resources** for processes.

Think of it like a shared apartment:
- **Total resources** = Water, electricity, internet bandwidth
- **Each roommate** = A process or container
- **Cgroups** = Rules that say "You can use 25% of the water, 512MB of electricity, 1Mbps of internet"

**Without cgroups:**
- One process could use 100% CPU (starve other processes)
- One process could use all RAM (crash the system)
- Containers could not exist (no resource isolation)

**With cgroups:**
- Each process has limits (CPU, memory, disk I/O, network)
- Containers run in isolated cgroups
- Fair sharing of resources

**In OpenShift:**
- Every **pod** runs in a cgroup
- You set **resource requests** (guaranteed) and **limits** (maximum)
- Kubernetes uses cgroups to enforce these limits

---

## What Resources Can Cgroups Control?

| Resource | What It Limits | Example |
|----------|----------------|---------|
| **cpu** | CPU time (cores, shares) | Limit pod to 1 CPU core |
| **memory** | RAM usage | Limit pod to 512MB |
| **blkio** | Disk I/O bandwidth | Limit disk writes to 10MB/s |
| **net_cls** | Network class (QoS) | Tag network traffic for prioritization |
| **pids** | Number of processes | Limit to 100 processes |
| **cpuacct** | CPU accounting (usage stats) | Track how much CPU a pod used |

**Most important for OpenShift:** **cpu** and **memory**

---

## Cgroups v1 vs v2

There are **two versions** of cgroups:

| Version | Status | Used By |
|---------|--------|---------|
| **cgroups v1** | Legacy | RHEL 7, CentOS 7 |
| **cgroups v2** | Modern, unified | RHEL 8+, Fedora, RHEL 9, OpenShift 4.14+ |

**Key difference:**

- **v1** = Separate hierarchy for each resource (cpu, memory, blkio are separate trees)
- **v2** = Unified hierarchy (one tree for all resources)

**How to check which version you have:**

```bash
mount | grep cgroup
```

**cgroups v1:**

```
cgroup on /sys/fs/cgroup/cpu type cgroup (rw,cpu)
cgroup on /sys/fs/cgroup/memory type cgroup (rw,memory)
```

**cgroups v2:**

```
cgroup2 on /sys/fs/cgroup type cgroup2 (rw)
```

---

## Where Are Cgroups Stored?

**Cgroups are in `/sys/fs/cgroup/`**

**cgroups v1:**

```
/sys/fs/cgroup/cpu/
/sys/fs/cgroup/memory/
/sys/fs/cgroup/blkio/
```

**cgroups v2:**

```
/sys/fs/cgroup/
```

**Each process has a cgroup path:**

```bash
cat /proc/<PID>/cgroup
```

---

## Hands-On Lab

### Part 1: Find Your Shell's Cgroup (10 minutes)

**Step 1: Find your shell's PID**

```bash
echo $$
```

This prints the PID of your current shell (e.g., `12345`).

**Step 2: View the cgroup for your shell**

```bash
cat /proc/$$/cgroup
```

**Expected output (cgroups v2):**

```
0::/user.slice/user-1000.slice/session-3.scope
```

**Expected output (cgroups v1):**

```
11:blkio:/user.slice
10:memory:/user.slice/user-1000.slice/session-3.scope
9:cpu,cpuacct:/user.slice
```

**What it means:**

- Your shell is in the `user.slice` cgroup
- All user processes are under `user.slice`
- System processes are under `system.slice`

**Your task:**

1. Find your shell's PID
2. View its cgroup
3. Note the slice name (user.slice, system.slice, etc.)

---

### Part 2: View Memory Limit for a Process (10 minutes)

Let's check the memory limit for your shell.

**cgroups v2:**

```bash
cat /sys/fs/cgroup/user.slice/memory.max
```

**Expected output:**

```
max
```

This means "no limit" (unlimited memory).

**cgroups v1:**

```bash
cat /sys/fs/cgroup/memory/user.slice/memory.limit_in_bytes
```

**Expected output:**

```
9223372036854771712
```

This is the maximum 64-bit integer = "no limit."

**Your task:**

1. Find the memory limit for `user.slice`
2. Check if it's unlimited or has a specific limit

---

### Part 3: View CPU Limit for a Process (10 minutes)

**cgroups v2:**

```bash
cat /sys/fs/cgroup/user.slice/cpu.max
```

**Expected output:**

```
max 100000
```

This means:
- `max` = No CPU limit
- `100000` = Period (100ms)

**cgroups v1:**

```bash
cat /sys/fs/cgroup/cpu/user.slice/cpu.cfs_quota_us
cat /sys/fs/cgroup/cpu/user.slice/cpu.cfs_period_us
```

**Expected output:**

```
-1 (quota)
100000 (period)
```

`-1` = No limit.

**Your task:**

1. Find the CPU limit for `user.slice`
2. Check if it's unlimited or has a specific quota

---

### Part 4: View Cgroups for a Specific Process (15 minutes)

Let's find a running process and check its cgroups.

**Step 1: Find NetworkManager PID**

```bash
systemctl status NetworkManager | grep "Main PID"
```

**Example output:**

```
Main PID: 1234 (NetworkManager)
```

**Step 2: View its cgroup**

```bash
cat /proc/1234/cgroup
```

**Expected output:**

```
0::/system.slice/NetworkManager.service
```

**Step 3: Check its memory limit**

**cgroups v2:**

```bash
cat /sys/fs/cgroup/system.slice/NetworkManager.service/memory.max
```

**cgroups v1:**

```bash
cat /sys/fs/cgroup/memory/system.slice/NetworkManager.service/memory.limit_in_bytes
```

**Your task:**

1. Find the PID of `chronyd` or `sshd`
2. View its cgroup
3. Check its memory limit

---

### Part 5: Understand Container Cgroups (15 minutes)

**In containers (like Docker or Podman), each container runs in its own cgroup.**

**Example:** Run a container with resource limits:

```bash
podman run -d --name test-container --memory=512m --cpus=1.0 nginx
```

**What this does:**

- `--memory=512m` = Limit memory to 512MB
- `--cpus=1.0` = Limit to 1 CPU core

**Step 1: Find the container's PID**

```bash
podman inspect test-container | grep -i pid
```

**Example output:**

```
"Pid": 5678
```

**Step 2: View its cgroup**

```bash
cat /proc/5678/cgroup
```

**Expected output:**

```
0::/machine.slice/libpod-abc123.scope/container
```

**Step 3: Check its memory limit**

**cgroups v2:**

```bash
cat /sys/fs/cgroup/machine.slice/libpod-abc123.scope/container/memory.max
```

**Expected output:**

```
536870912
```

This is 512MB in bytes (512 * 1024 * 1024 = 536870912).

**Your task (if you have Podman or Docker):**

1. Run a test container with memory limit
2. Find its PID
3. View its cgroup
4. Verify the memory limit is set

**If you don't have Podman/Docker, just understand the concept.**

---

### Part 6: OpenShift Pod Cgroups (10 minutes)

**In OpenShift, each pod runs in a cgroup with limits set by the YAML.**

**Example pod YAML:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        memory: "256Mi"
        cpu: "500m"
      limits:
        memory: "512Mi"
        cpu: "1"
```

**What this does:**

- **Requests:** Guaranteed minimum (256MB RAM, 0.5 CPU)
- **Limits:** Maximum allowed (512MB RAM, 1 CPU)

**Kubernetes sets cgroups to enforce these limits.**

**How to check pod cgroups on an OpenShift node:**

```bash
oc debug node/<node-name>
chroot /host

# Find the pod's cgroup
crictl ps | grep my-pod

# Get the container ID
crictl inspect <container-id> | grep -i pid

# View the cgroup
cat /proc/<PID>/cgroup
```

**Your task (if you have access to an OpenShift cluster):**

1. Find a running pod
2. Debug the node where it's running
3. Find the container PID
4. View its cgroup

**If you don't have access, just understand the concept.**

---

## Cgroup File Reference

**Common cgroup files (v2):**

| File | What It Shows |
|------|---------------|
| `memory.max` | Memory limit |
| `memory.current` | Current memory usage |
| `cpu.max` | CPU quota and period |
| `cpu.stat` | CPU usage stats |
| `pids.max` | Process limit |
| `pids.current` | Current number of processes |

**Common cgroup files (v1):**

| File | What It Shows |
|------|---------------|
| `memory.limit_in_bytes` | Memory limit |
| `memory.usage_in_bytes` | Current memory usage |
| `cpu.cfs_quota_us` | CPU quota (microseconds) |
| `cpu.cfs_period_us` | CPU period (microseconds) |
| `tasks` | List of PIDs in this cgroup |

---

## Troubleshooting with Cgroups

| Symptom | Cause | How to Check |
|---------|-------|--------------|
| Container killed (OOMKilled) | Exceeded memory limit | Check `memory.max` and `memory.current` |
| Pod throttled (CPU) | Exceeded CPU limit | Check `cpu.stat` for `throttled_time` |
| Too many processes | Hit PID limit | Check `pids.max` and `pids.current` |

**Example: Check if a pod hit memory limit:**

```bash
cat /sys/fs/cgroup/.../memory.current
cat /sys/fs/cgroup/.../memory.max
```

If `memory.current` >= `memory.max`, the pod was OOMKilled.

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What are cgroups?
2. What resources can cgroups control?
3. Where are cgroups stored?
4. What command shows a process's cgroup?
5. What is the difference between cgroups v1 and v2?
6. In OpenShift, what enforces resource limits on pods?

**Answers:**

1. Control groups — Linux kernel feature to limit resources (CPU, memory, etc.)
2. cpu, memory, blkio (disk I/O), net_cls (network), pids (processes)
3. `/sys/fs/cgroup/`
4. `cat /proc/<PID>/cgroup`
5. v1 = separate hierarchies for each resource. v2 = unified hierarchy
6. cgroups (set by Kubernetes based on pod resource requests/limits)

---

## Today I Learned (TIL) — Write This Down

Example:

```
March 21, 2026 — Day 13: Cgroups

- Cgroups = control groups, limit CPU/memory/disk/network per process
- Files in /sys/fs/cgroup/
- Check process cgroup: cat /proc/<PID>/cgroup
- cgroups v1 = separate hierarchies. v2 = unified hierarchy
- Containers use cgroups for isolation (each container = separate cgroup)
- OpenShift uses cgroups to enforce pod resource limits
- memory.max = limit, memory.current = current usage
- OOMKilled = pod exceeded memory.max
```

---

## Commands Cheat Sheet

```bash
# Find your shell's PID
echo $$

# View process cgroup
cat /proc/<PID>/cgroup

# Check cgroups version
mount | grep cgroup

# View memory limit (cgroups v2)
cat /sys/fs/cgroup/user.slice/memory.max

# View memory usage (cgroups v2)
cat /sys/fs/cgroup/user.slice/memory.current

# View CPU limit (cgroups v2)
cat /sys/fs/cgroup/user.slice/cpu.max

# View memory limit (cgroups v1)
cat /sys/fs/cgroup/memory/user.slice/memory.limit_in_bytes

# View memory usage (cgroups v1)
cat /sys/fs/cgroup/memory/user.slice/memory.usage_in_bytes

# List all cgroups
systemd-cgls

# Show cgroup tree
systemd-cgtop

# Run a container with limits (Podman)
podman run -d --memory=512m --cpus=1.0 nginx
```

---

## What's Next?

**Tomorrow (Day 14):** Weekend Scenario 2 — "Port 443 not reachable on my server"

**Practice tonight:**
- Find the cgroup for NetworkManager
- Check its memory and CPU limits
- Run `systemd-cgls` to see the cgroup tree

---

**End of Day 13 Lab**

Good job. Tomorrow is the final weekend scenario — you will troubleshoot a full networking issue using all Week 1-2 skills.
