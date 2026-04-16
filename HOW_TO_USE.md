# How to Use These Labs - Quick Start

## For Students: Get Started in 5 Minutes

### Step 1: Clone the Repository
```bash
git clone https://github.com/shishind/ocp-networking-labs.git
cd ocp-networking-labs
```

### Step 2: Set Up Your Environment
```bash
# Run the automated setup (Ubuntu/Debian/RHEL/Fedora)
sudo ./setup.sh

# Verify everything is installed
./verify-setup.sh
```

### Step 3: Start Learning
```bash
# Read the master guide
cat README.md

# Start with Day 1
cd week1-2/labs
cat D1_OSI_Model.md

# Follow the hands-on exercises in the lab file
```

---

## Daily Learning Routine (1.5 hours)

**45 minutes - Learn:**
- Read the day's lab markdown file
- Take notes by hand (not typing)

**45 minutes - Practice:**
- Do ALL the hands-on exercises
- Type every command yourself (no copy-paste)
- If something breaks, try to fix it first

**15 minutes - Reflect:**
- Write 5 bullet points: "What did I learn today?"
- Add to your TIL (Today I Learned) notes

---

## Learning Path

```
Week 1-2: Core Networking (OSI, IP, DNS, TCP/UDP)
   ↓
Week 3-4: Linux & Containers (namespaces, veth, bridges, Docker)
   ↓
Week 5-6: Kubernetes (Services, CoreDNS, NetworkPolicy)
   ↓
Week 7: OpenShift (OVS, OVN, Routes, the 4 Traffic Flows)
```

**Important:** Don't skip ahead! Each week builds on the previous.

---

## Quick Reference While Learning

```bash
# Phase-specific cheat sheets
cat cheat-sheets/Phase1_Core_Networking_CheatSheet.md
cat cheat-sheets/Phase2_Linux_Container_CheatSheet.md
cat cheat-sheets/Phase3_Kubernetes_CheatSheet.md
cat cheat-sheets/Phase4_OpenShift_CheatSheet.md

# One-page quick reference
cat cheat-sheets/Master_Commands_QuickRef.md
```

---

## What You Need

**Minimum:**
- A Linux machine (VM or physical)
- Ubuntu 20.04+, RHEL 8+, Fedora, or similar
- 2 GB RAM, 20 GB disk
- Internet connection

**Setup handles:**
- Installing all networking tools
- Docker/Podman for container labs
- kubectl and kind for Kubernetes labs
- All required dependencies

---

## Help & Support

**If you get stuck:**
1. Check the lab's "Self-Check Questions" section
2. Review the relevant cheat sheet
3. Try the command with `--help` flag
4. Open an issue on GitHub: https://github.com/shishind/ocp-networking-labs/issues

**If setup fails:**
- Run `./verify-setup.sh` to see what's missing
- Check `QUICK_START.md` for troubleshooting
- Open an issue with the error message

---

## Tips for Success

✅ **DO:**
- Follow the labs in order (Day 1 → Day 2 → Day 3...)
- Type every command yourself
- Spend 1.5 hours per day consistently
- Write daily TIL notes
- Do weekend scenarios

❌ **DON'T:**
- Skip to advanced topics
- Copy-paste commands
- Rush through exercises
- Skip the hands-on practice

---

## Share Your Progress

- Star the repository if you find it helpful
- Share your TIL notes with the community
- Open issues for corrections or improvements
- Contribute better examples via Pull Requests

---

## Repository Link

**Share this link:**
```
https://github.com/shishind/ocp-networking-labs
```

**Clone command:**
```bash
git clone https://github.com/shishind/ocp-networking-labs.git
```

---

## Time Commitment

- **Per day:** 1.5 hours (45 min learn + 45 min practice)
- **Per week:** 10-12 hours (weekdays + weekend scenario)
- **Total:** 7 weeks to complete
- **Result:** Expert-level OCP networking troubleshooting skills

---

Good luck! Start with Week 1, Day 1, and type every command yourself. You've got this.
