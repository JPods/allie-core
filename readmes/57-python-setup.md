# 57 — Python Setup: Single Framework

**Created:** 2026-07-16
**Status:** Active — cleanup in progress
**Rule:** One Python, one venv per project, Homebrew ARM only

---

## The Problem We Had

Multiple Python installations accumulated over years — Framework installs, Homebrew
Intel (x86 via Rosetta), Homebrew ARM, and python.org packages. Different projects
pointed to different Pythons. Venvs broke silently when the underlying install was
updated or removed. Debugging which Python was actually running required detective work.

---

## Target State

```
/opt/homebrew/bin/python3  →  Python 3.13 (Homebrew ARM)
                               │
                               ├── ~/Allie/venv/
                               ├── ~/Documents/CommerceExpert/webClerk3/venv/
                               ├── ~/Documents/MeshMobility/venv/
                               └── (one venv per project, always named "venv/")
```

**One Python. One venv per project. No exceptions.**

---

## Current Inventory (as of 2026-07-16)

### Installed Pythons — what stays, what goes

| Python | Location | Source | Status |
|--------|----------|--------|--------|
| 3.13.3 | `/opt/homebrew/bin/python3` | Homebrew ARM | **KEEP — primary** |
| 3.12.12 | `/opt/homebrew/bin/python3.12` | Homebrew ARM | **KEEP — brew dependency** |
| 3.13.3 | `/usr/local/bin/python3` | python.org Framework | **REMOVE** |
| 3.13t | `/usr/local/bin/python3.13t` | python.org free-threaded | **REMOVE** |
| 3.10.17 | `/usr/local/bin/python3.10` | Homebrew Intel | **REMOVE** |
| 3.9.22 | `/usr/local/bin/python3.9` | Homebrew Intel | **REMOVE** |
| 3.8 | `/usr/local/Cellar/python@3.8/` | Homebrew Intel | **REMOVE** |
| 3.7 | `/usr/local/Cellar/python@3.7/` | Homebrew Intel | **REMOVE** |
| 2.7 | `/Library/Frameworks/Python.framework/Versions/2.7/` | Framework (2022) | **REMOVE** |

### Venvs — what stays, what goes

| Venv | Python | Status |
|------|--------|--------|
| `~/Allie/venv/` | 3.13 Homebrew ARM | **KEEP — primary Allie venv** |
| `~/Allie/.venv/` | 3.13 Homebrew ARM (uv) | **REMOVE — duplicate** |
| `~/Allie/source/` | 3.13 Homebrew ARM | **REMOVE — accidental** |
| `~/Allie/and/` | 3.13 Homebrew ARM | **REMOVE — accidental** |
| `~/Allie/allie/source/` | 3.13 (assumed) | **REMOVE — accidental** |
| `~/Allie/allie/and/` | 3.13 (assumed) | **REMOVE — accidental** |
| `~/Documents/CommerceExpert/webClerk3/venv/` | 3.12 Homebrew ARM | **REBUILD on 3.13** |
| `~/Documents/CommerceExpert/webClerk3/venv312/` | 3.12 Homebrew ARM | **REMOVE — duplicate** |
| `~/Documents/CommerceExpert/webClerk3/pyvenv.cfg` | 3.13 (root-level, wrong) | **REMOVE** |
| `~/Documents/CommerceExpert/webClerk3-venv/` | 3.13 (outside project) | **REMOVE** |
| `~/Documents/CommerceExpert/Motors/.venv/` | 3.13 Framework (/usr/local) | **REBUILD on Homebrew** |

---

## Cleanup Steps

### Step 1 — Remove accidental and duplicate venvs

```bash
# Allie — keep only venv/
rm -rf ~/Allie/.venv
rm -rf ~/Allie/source
rm -rf ~/Allie/and
rm -rf ~/Allie/allie/source
rm -rf ~/Allie/allie/and

# WC3 — keep only venv/ (will rebuild)
rm -rf ~/Documents/CommerceExpert/webClerk3/venv312
rm -rf ~/Documents/CommerceExpert/webClerk3/pyvenv.cfg
rm -rf ~/Documents/CommerceExpert/webClerk3-venv
```

### Step 2 — Remove python.org Framework installs

```bash
# Python 2.7 Framework (from 2022)
sudo rm -rf /Library/Frameworks/Python.framework/Versions/2.7

# Python 3.13 Framework (python.org installer — NOT Homebrew)
sudo rm -rf /Library/Frameworks/Python.framework/Versions/3.13
sudo rm -rf /Library/Frameworks/PythonT.framework

# Remove Framework symlinks from /usr/local/bin
sudo rm -f /usr/local/bin/python3
sudo rm -f /usr/local/bin/python3-config
sudo rm -f /usr/local/bin/python3-intel64
sudo rm -f /usr/local/bin/python3.13
sudo rm -f /usr/local/bin/python3.13-config
sudo rm -f /usr/local/bin/python3.13-intel64
sudo rm -f /usr/local/bin/python3.13t
sudo rm -f /usr/local/bin/python3.13t-config
sudo rm -f /usr/local/bin/python3.13t-intel64
sudo rm -f /usr/local/bin/python3t
sudo rm -f /usr/local/bin/python3t-config
sudo rm -f /usr/local/bin/python3t-intel64
sudo rm -f /usr/local/bin/pythonw
sudo rm -f /usr/local/bin/pythonw2
sudo rm -f /usr/local/bin/pythonw2.7

# Remove Framework directory if empty
sudo rmdir /Library/Frameworks/Python.framework/Versions 2>/dev/null
sudo rmdir /Library/Frameworks/Python.framework 2>/dev/null
```

### Step 3 — Remove Homebrew Intel Pythons

```bash
# These live in /usr/local/Cellar (Intel Homebrew, via Rosetta)
/usr/local/bin/brew uninstall python@3.7
/usr/local/bin/brew uninstall python@3.8
/usr/local/bin/brew uninstall python@3.9
/usr/local/bin/brew uninstall python@3.10

# Check if anything depends on them first:
/usr/local/bin/brew uses --installed python@3.9
/usr/local/bin/brew uses --installed python@3.10
```

### Step 4 — Rebuild project venvs on Homebrew ARM Python 3.13

```bash
# WC3
cd ~/Documents/CommerceExpert/webClerk3
rm -rf venv
/opt/homebrew/bin/python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate  # verify

# Motors
cd ~/Documents/CommerceExpert/Motors
rm -rf .venv
/opt/homebrew/bin/python3 -m venv venv    # rename .venv → venv
source venv/bin/activate
pip install -r requirements.txt           # if exists

# MeshMobility
cd ~/Documents/MeshMobility
rm -rf venv
/opt/homebrew/bin/python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Allie (verify existing venv is correct)
cd ~/Allie
source venv/bin/activate
python --version   # should say 3.13.3
which python       # should say ~/Allie/venv/bin/python
```

### Step 5 — Verify clean state

```bash
# Only these should exist:
which python3                          # /opt/homebrew/bin/python3
python3 --version                      # 3.13.3
ls /usr/local/bin/python*              # should be empty or only python3.10 remnants
ls /Library/Frameworks/Python*         # should not exist
find ~/Documents ~/Allie -name "pyvenv.cfg" -maxdepth 3
# Should show exactly:
#   ~/Allie/venv/pyvenv.cfg
#   ~/Documents/CommerceExpert/webClerk3/venv/pyvenv.cfg
#   ~/Documents/CommerceExpert/Motors/venv/pyvenv.cfg
#   ~/Documents/MeshMobility/venv/pyvenv.cfg
```

---

## Rules Going Forward

### 1. One Python installation

Homebrew ARM Python 3.13 at `/opt/homebrew/bin/python3`. No Framework installs,
no pyenv, no conda, no system Python for projects.

When Python 3.14 ships, upgrade via `brew upgrade python@3.13` → rebuild all venvs.

### 2. One venv per project, always named `venv/`

```bash
cd ~/project
/opt/homebrew/bin/python3 -m venv venv
source venv/bin/activate
```

Not `.venv`, not `venv312`, not `source`, not a venv outside the project directory.
Always `venv/`. Always inside the project root.

### 3. Always activate before running

```bash
source venv/bin/activate
python manage.py runserver   # uses venv Python
```

Never call `/opt/homebrew/bin/python3` directly for project work. The venv ensures
the right packages are available and isolated.

### 4. requirements.txt is the package manifest

Every project maintains `requirements.txt`. After adding a package:

```bash
pip install newpackage
pip freeze > requirements.txt
```

Rebuilding a venv from scratch:
```bash
rm -rf venv
/opt/homebrew/bin/python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 5. .gitignore excludes venvs

Every project's `.gitignore` includes:
```
venv/
```

Venvs are local, machine-specific, and reproducible from `requirements.txt`.

---

## GEEKOM IT15 — Python Setup

When the GEEKOM arrives (~2026-07-20), Python setup on Ubuntu Server is simpler:

```bash
sudo apt install python3.12 python3.12-venv python3-pip
```

Same rules apply: one venv per project, always named `venv/`, always activate first.
Ubuntu's system Python stays untouched — venvs isolate everything.

---

## Quick Reference

```bash
# Which Python am I using?
which python3              # should be /opt/homebrew/bin/python3
python3 --version          # should be 3.13.x

# Am I in a venv?
echo $VIRTUAL_ENV          # blank = no venv active

# Create a new project venv
/opt/homebrew/bin/python3 -m venv venv
source venv/bin/activate

# Rebuild a broken venv
rm -rf venv
/opt/homebrew/bin/python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Find all venvs on the system
find ~/Documents ~/Allie -name "pyvenv.cfg" -maxdepth 3
```
