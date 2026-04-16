# GitHub Setup Instructions

## Option 1: Using GitHub Web Interface (Easiest)

1. **Create a new repository on GitHub:**
   - Go to https://github.com/new
   - Repository name: `ocp-networking-labs` (or your preferred name)
   - Description: "Complete 7-week hands-on curriculum for OpenShift networking - Zero to Expert"
   - Choose: Public (to share with others)
   - **DO NOT** initialize with README, .gitignore, or license (we already have these)
   - Click "Create repository"

2. **Connect your local repository to GitHub:**
   ```bash
   cd /root/claude/ocp-networking-labs
   
   # Add your GitHub repository as remote (replace USERNAME with your GitHub username)
   git remote add origin https://github.com/USERNAME/ocp-networking-labs.git
   
   # Push to GitHub
   git branch -M main
   git push -u origin main
   ```

3. **Enter your credentials when prompted:**
   - Username: Your GitHub username
   - Password: Use a Personal Access Token (not your GitHub password)
     - Create token at: https://github.com/settings/tokens
     - Select: repo (full control of private repositories)
     - Copy the token and paste it as password

---

## Option 2: Using GitHub CLI (gh)

If you have GitHub CLI installed:

```bash
cd /root/claude/ocp-networking-labs

# Login to GitHub
gh auth login

# Create repository and push
gh repo create ocp-networking-labs --public --source=. --remote=origin --push

# Follow the prompts
```

---

## Option 3: Using SSH (If you have SSH keys set up)

```bash
cd /root/claude/ocp-networking-labs

# Add remote with SSH URL (replace USERNAME)
git remote add origin git@github.com:USERNAME/ocp-networking-labs.git

# Push
git branch -M main
git push -u origin main
```

---

## After Pushing to GitHub

### Add Topics/Tags

Go to your repository on GitHub and add these topics:
- `openshift`
- `networking`
- `kubernetes`
- `hands-on-labs`
- `ocp`
- `training`
- `education`

### Enable GitHub Pages (Optional)

If you want to host the documentation as a website:
1. Go to Settings → Pages
2. Source: Deploy from a branch
3. Branch: main / (root)
4. Save

### Add Repository Description

Edit the "About" section with:
```
Complete 7-week hands-on curriculum for OpenShift networking. 
Transform from zero to expert with 49 practical labs covering 
core networking, containers, Kubernetes, and OVS/OVN.
```

### Recommended Repository Settings

- ✅ Issues: Enabled (for bug reports and suggestions)
- ✅ Discussions: Enabled (for Q&A and community)
- ✅ Wiki: Optional

---

## Sharing Your Repository

Once pushed, share the link:
```
https://github.com/USERNAME/ocp-networking-labs
```

Others can clone it with:
```bash
git clone https://github.com/USERNAME/ocp-networking-labs.git
cd ocp-networking-labs
./setup.sh
```

---

## Updating After Changes

When you make changes locally:
```bash
cd /root/claude/ocp-networking-labs
git add .
git commit -m "Description of your changes"
git push
```

---

## Getting a Personal Access Token

1. Go to: https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Note: "OCP Labs Repository Access"
4. Select scopes:
   - ✅ repo (all)
   - ✅ workflow (if using GitHub Actions)
5. Click "Generate token"
6. **Copy the token immediately** (you won't see it again)
7. Use this token as your password when pushing

---

## Troubleshooting

**Error: "remote origin already exists"**
```bash
git remote remove origin
git remote add origin https://github.com/USERNAME/ocp-networking-labs.git
```

**Error: "Authentication failed"**
- Make sure you're using a Personal Access Token, not your password
- Verify the token has the `repo` scope

**Error: "Permission denied (publickey)"**
- If using SSH, add your SSH key to GitHub
- Or use HTTPS method instead

---

## Need Help?

- GitHub Docs: https://docs.github.com/
- Creating a repository: https://docs.github.com/en/repositories/creating-and-managing-repositories
- Personal access tokens: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token
