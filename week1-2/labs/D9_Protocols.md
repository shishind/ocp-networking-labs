# Day 9: Common Protocols — SSH, HTTP, HTTPS, SMTP, FTP

**Date:** Tuesday, March 17, 2026  
**Phase:** 1 - Core Networking Fundamentals  
**Time:** 1.5 hours (45 min learn + 45 min lab)

---

## Learning Objectives

By the end of this lab, you will be able to:
- Identify common network protocols and their ports
- Understand what each protocol does
- Use curl to analyze HTTP/HTTPS traffic
- Map protocols to OSI layers
- Troubleshoot protocol-specific issues

---

## Plain English: What Is a Protocol?

A **protocol** is a set of rules for communication. Like how English has grammar rules, network protocols have rules for how computers talk.

**Example:**

- **HTTP** says: "To request a webpage, send 'GET /index.html HTTP/1.1'"
- **SSH** says: "To login securely, exchange encryption keys first"
- **SMTP** says: "To send email, say 'MAIL FROM: sender@example.com'"

**Without protocols, computers would not understand each other.**

---

## Common Protocols (Memorize These)

| Protocol | Port | OSI Layer | What It Does | Example Use |
|----------|------|-----------|--------------|-------------|
| **SSH** | 22 | 7 (Application) | Secure remote login | `ssh user@server` |
| **DNS** | 53 | 7 (Application) | Name resolution | `dig google.com` |
| **HTTP** | 80 | 7 (Application) | Web traffic (plain text) | `curl http://example.com` |
| **HTTPS** | 443 | 7 (Application) | Web traffic (encrypted) | `curl https://example.com` |
| **SMTP** | 25 | 7 (Application) | Send email | Mail server to mail server |
| **FTP** | 21 | 7 (Application) | File transfer (insecure) | `ftp ftp.example.com` |
| **MySQL** | 3306 | 7 (Application) | Database | Application → Database |
| **PostgreSQL** | 5432 | 7 (Application) | Database | Application → Database |
| **Kubernetes API** | 6443 | 7 (Application) | K8s API server | `kubectl` → API server |

**All of these are Layer 7 (Application) protocols.**

---

## HTTP — How the Web Works

**HTTP (HyperText Transfer Protocol)** is how web browsers talk to web servers.

**Basic flow:**

```
Client: "GET /index.html HTTP/1.1"
Server: "HTTP/1.1 200 OK\n<html>...</html>"
```

**HTTP Methods:**

| Method | What It Does | Example |
|--------|--------------|---------|
| **GET** | Retrieve data | Get a webpage |
| **POST** | Send data | Submit a form |
| **PUT** | Update data | Update a record |
| **DELETE** | Delete data | Delete a record |

**HTTP Status Codes:**

| Code | Meaning | Example |
|------|---------|---------|
| **200** | OK | Request succeeded |
| **301** | Moved Permanently | Redirect to new URL |
| **404** | Not Found | Page does not exist |
| **500** | Internal Server Error | Server crashed |

---

## HTTPS — HTTP with Encryption

**HTTPS (HTTP Secure)** is HTTP encrypted with **TLS (Transport Layer Security)**.

**Why it matters:**

- **HTTP** = Plain text (anyone can read it)
- **HTTPS** = Encrypted (only you and the server can read it)

**In OpenShift:**

- **Routes** expose services via HTTP/HTTPS
- **TLS certificates** enable HTTPS
- Without HTTPS, passwords and data are sent in plain text

---

## SSH — Secure Remote Login

**SSH (Secure Shell)** lets you log in to a remote machine securely.

**Example:**

```bash
ssh user@192.168.1.10
```

**What happens:**

1. Client connects to server on port 22
2. Server sends its public key
3. Client and server negotiate encryption
4. You enter your password (encrypted)
5. You get a shell

**In OpenShift:**

- You SSH to nodes for troubleshooting
- `oc debug node/<node-name>` uses SSH under the hood

---

## DNS — The Phone Book of the Internet

We covered DNS on Day 3, but here's the protocol summary:

**DNS (Domain Name System)** translates names to IP addresses.

**Example:**

```bash
dig google.com
```

**What happens:**

1. Client sends DNS query to DNS server (port 53, UDP)
2. DNS server looks up `google.com` → `142.250.185.46`
3. DNS server sends reply
4. Client now knows the IP address

**Protocol:** UDP (port 53) for queries, TCP (port 53) for zone transfers

---

## SMTP — How Email Is Sent

**SMTP (Simple Mail Transfer Protocol)** is how email servers talk to each other.

**Example:**

```
Client: HELO mail.example.com
Server: 250 Hello mail.example.com

Client: MAIL FROM:<sender@example.com>
Server: 250 OK

Client: RCPT TO:<recipient@example.com>
Server: 250 OK

Client: DATA
Client: Subject: Test email
Client: This is the body
Client: .
Server: 250 Message accepted
```

**Port:** 25 (SMTP), 587 (Submission), 465 (SMTPS — encrypted)

---

## FTP — File Transfer (Insecure)

**FTP (File Transfer Protocol)** transfers files between machines.

**Problem:** FTP sends passwords in **plain text**. Never use it over the internet.

**Better alternatives:**

- **SFTP** (SSH File Transfer Protocol) — port 22
- **SCP** (Secure Copy) — port 22
- **HTTPS** file upload

---

## Hands-On Lab

### Part 1: Analyze HTTP with curl (15 minutes)

Let's see HTTP in action.

**Step 1: Run curl with verbose output**

```bash
curl -v http://example.com
```

**Expected output:**

```
* Trying 93.184.216.34:80...
* Connected to example.com (93.184.216.34) port 80
> GET / HTTP/1.1
> Host: example.com
> User-Agent: curl/7.68.0
> Accept: */*
>
< HTTP/1.1 200 OK
< Content-Type: text/html; charset=UTF-8
< Content-Length: 1256
<
<!doctype html>
<html>
...
```

**Your task:**

1. Find the **TCP connection** line (`* Connected to ...`)
2. Find the **HTTP request** (`> GET / HTTP/1.1`)
3. Find the **HTTP response** (`< HTTP/1.1 200 OK`)
4. Find the **status code** (200)

**Map to OSI layers:**

| Step | OSI Layer |
|------|-----------|
| DNS lookup (example.com → 93.184.216.34) | Layer 7 (Application — DNS) |
| TCP connection (port 80) | Layer 4 (Transport — TCP) |
| HTTP request (GET /) | Layer 7 (Application — HTTP) |
| HTTP response (200 OK) | Layer 7 (Application — HTTP) |

---

### Part 2: Analyze HTTPS with curl (15 minutes)

**Step 1: Run curl with verbose output for HTTPS**

```bash
curl -v https://google.com
```

**Expected output:**

```
* Trying 142.250.185.46:443...
* Connected to google.com (142.250.185.46) port 443
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
> GET / HTTP/1.1
> Host: google.com
> User-Agent: curl/7.68.0
>
< HTTP/1.1 301 Moved Permanently
< Location: https://www.google.com/
```

**Your task:**

1. Find the **TCP connection** on port 443
2. Find the **TLS handshake** lines
3. Find the **HTTP request**
4. Find the **status code** (301 — redirect)

**Notice:**

- HTTPS uses **port 443** (not 80)
- There is a **TLS handshake** before HTTP (encryption setup)
- The HTTP request is the same as HTTP (but encrypted)

---

### Part 3: Test SSH Connection (10 minutes)

**Step 1: SSH to localhost**

```bash
ssh localhost
```

**What happens:**

1. SSH connects to port 22
2. Server sends its public key
3. You are prompted for a password
4. You get a shell

**Your task:**

1. Try to SSH to localhost
2. If it fails, check if SSH is running: `systemctl status sshd`
3. If you don't have SSH set up, just understand the concept

**Alternate test:**

```bash
nc -zv localhost 22
```

If port 22 is open, SSH is listening.

---

### Part 4: Test DNS with dig (10 minutes)

**Step 1: Query Google DNS**

```bash
dig google.com
```

**Expected output:**

```
; <<>> DiG 9.16.1 <<>> google.com
;; QUESTION SECTION:
;google.com.                    IN      A

;; ANSWER SECTION:
google.com.             300     IN      A       142.250.185.46

;; Query time: 15 msec
;; SERVER: 192.168.1.1#53(192.168.1.1)
```

**Your task:**

1. Find the **QUESTION SECTION** (what you asked)
2. Find the **ANSWER SECTION** (the IP address)
3. Find the **SERVER** line (which DNS server answered)

**Map to OSI layers:**

- DNS query = Layer 7 (Application)
- UDP port 53 = Layer 4 (Transport)

---

### Part 5: Identify Protocols in OpenShift (10 minutes)

In OpenShift, many protocols are used:

| Component | Protocol | Port | Purpose |
|-----------|----------|------|---------|
| API Server | HTTPS | 6443 | Kubernetes API |
| Ingress HTTP | HTTP | 80 | Routes (plain) |
| Ingress HTTPS | HTTPS | 443 | Routes (TLS) |
| CoreDNS | DNS | 53 | Pod DNS queries |
| etcd | HTTPS | 2379, 2380 | Cluster database |
| Kubelet | HTTPS | 10250 | Node agent |
| Metrics | HTTPS | 10251 | Metrics collection |

**Your task:**

If you have access to an OpenShift cluster, run:

```bash
ss -tulpn | grep -E ':(6443|443|80|53|2379|10250)'
```

This shows which ports are listening.

If you don't have access, just memorize the table above.

---

## Protocol Troubleshooting

| Symptom | Protocol | Troubleshooting Command |
|---------|----------|-------------------------|
| Cannot reach website | HTTP/HTTPS | `curl -v http://example.com` |
| Cannot resolve name | DNS | `dig example.com` |
| Cannot SSH to server | SSH | `nc -zv <server> 22` |
| Cannot reach database | MySQL/PostgreSQL | `nc -zv <server> 3306` or `5432` |
| Cannot reach API server | Kubernetes API | `curl -k https://<server>:6443` |

---

## Self-Check Questions

Answer these WITHOUT looking at your notes:

1. What port does HTTP use? HTTPS?
2. What port does SSH use?
3. What port does DNS use?
4. What is the difference between HTTP and HTTPS?
5. What HTTP status code means "OK"?
6. What HTTP status code means "Not Found"?
7. What protocol does OpenShift use for the API server?

**Answers:**

1. HTTP = 80, HTTPS = 443
2. SSH = 22
3. DNS = 53
4. HTTPS is HTTP encrypted with TLS
5. 200
6. 404
7. HTTPS (port 6443)

---

## Today I Learned (TIL) — Write This Down

Example:

```
March 17, 2026 — Day 9: Common Protocols

- HTTP = port 80 (plain text), HTTPS = port 443 (encrypted)
- SSH = port 22 (secure remote login)
- DNS = port 53 (name resolution, UDP for queries)
- SMTP = port 25 (email), FTP = port 21 (file transfer, insecure)
- HTTP status codes: 200 OK, 301 redirect, 404 not found, 500 server error
- OpenShift API server = HTTPS port 6443
- Use curl -v to see HTTP headers and status codes
```

---

## Commands Cheat Sheet

```bash
# Analyze HTTP request
curl -v http://example.com

# Analyze HTTPS request
curl -v https://example.com

# Test if port is open
nc -zv <host> <port>

# Check SSH server status
systemctl status sshd

# DNS lookup
dig example.com

# DNS lookup with specific server
dig @8.8.8.8 example.com

# Show listening ports
ss -tulpn

# Show only specific ports
ss -tulpn | grep -E ':(80|443|22|53)'

# Test Kubernetes API
curl -k https://<api-server>:6443/version
```

---

## What's Next?

**Tomorrow (Day 10):** VLANs — Virtual LANs and Why OCP Uses Them

**Practice tonight:**
- Run `curl -v` on different websites and identify the status codes
- Run `dig` on different domains and identify the IP addresses
- Test SSH to localhost

---

**End of Day 9 Lab**

Good job. Tomorrow we learn about VLANs — how one physical network can be divided into multiple virtual networks.
