# Allie Setup Guide
**Hardware, Directory Structure, and Initial Configuration**

---

## Hardware

### The Drive

- **Type:** External SSD (USB-C preferred for speed and compatibility)
- **Size:** 1TB recommended (Bill's documents, knowledge base, and future inbox growth)
- **Format:** APFS (macOS) or exFAT (cross-platform compatibility)
- **Name:** `Allie` — must be named exactly this so the mount path is `/Volumes/Allie`

### Naming the Drive

On macOS:
1. Plug in the drive
2. Open Disk Utility
3. Select the volume
4. Click the name field and rename to `Allie`
5. Verify: `ls /Volumes/Allie` should work

---

## Directory Structure

Create the full directory tree:

```bash
mkdir -p /Volumes/Allie/allie/index
mkdir -p /Volumes/Allie/allie/workspace
mkdir -p /Volumes/Allie/allie/logs
mkdir -p /Volumes/Allie/allie/inbox
mkdir -p /Volumes/Allie/allie/agent
mkdir -p /Volumes/Allie/allie/carryon
mkdir -p /Volumes/Allie/knowledge/notes
mkdir -p /Volumes/Allie/knowledge/research
mkdir -p /Volumes/Allie/knowledge/code-projects
mkdir -p /Volumes/Allie/knowledge/writing
mkdir -p /Volumes/Allie/archive
mkdir -p /Volumes/Allie/sources/local-mac
mkdir -p /Volumes/Allie/sources/icloud
mkdir -p /Volumes/Allie/sources/github
mkdir -p /Volumes/Allie/sources/google-drive
mkdir -p /Volumes/Allie/sources/domain-servers
mkdir -p /Volumes/Allie/sources/dropbox
mkdir -p /Volumes/Allie/sources/other-drives
mkdir -p /Volumes/Allie/readmes
```

---

## Directory Descriptions

### `allie/` — Allie's Working Brain
Everything Allie uses to operate.

| Subdirectory | Purpose |
|---|---|
| `agent/` | Agent specification files. `00-allie-agent.md` is the primary spec. |
| `carryon/` | Session continuity. `carryon.json` is read at startup, written at shutdown. |
| `inbox/` | Drop documents here for Allie to process. PDFs, text, docs. |
| `index/` | Allie's index of knowledge base contents (auto-maintained). |
| `workspace/` | Active working files. Drafts in progress. Temporary outputs. |
| `logs/` | Session logs. Optional but useful for audit trail. |

### `knowledge/` — Bill's Knowledge Base
The curated, processed body of Bill's knowledge.

| Subdirectory | Purpose |
|---|---|
| `notes/` | Raw notes, quick captures, thinking out loud |
| `research/` | Research materials, synthesized documents, source material |
| `writing/` | Articles, essays, web content, published and draft |
| `code-projects/` | Code files, scripts, technical projects |

### `sources/` — Pointers to External Data
These directories contain pointer files (not the actual data) to where Bill's data lives externally. Allie can use these as a map when she needs to go find something.

| Subdirectory | Points To |
|---|---|
| `local-mac/` | Paths on Bill's Mac |
| `icloud/` | iCloud Drive locations |
| `github/` | GitHub repos |
| `google-drive/` | Google Drive folders |
| `domain-servers/` | Bill's web servers |
| `dropbox/` | Dropbox folders |
| `other-drives/` | Other external drives |

### `readmes/` — This Documentation
All documentation for how Allie is built and operated.

### `archive/` — Retired Work
Completed projects, old versions, anything no longer active but worth keeping.

---

## Initial Files to Create

After creating directories, create these essential files:

1. `allie/agent/00-allie-agent.md` — Who Allie is
2. `allie/carryon/carryon.json` — Initial session state
3. `readmes/00-how-to-build-allie.md` — This documentation set

---

## Opening Claude Code on Allie

```bash
# From terminal:
cd /Volumes/Allie
claude
```

Or use the Claude Code app and set the working directory to `/Volumes/Allie`.

Claude Code will operate with `/Volumes/Allie` as root, giving Allie full access to her drive.

---

## Moving Documents to Inbox

Drop documents into `allie/inbox/` and tell Allie:
> "There are new documents in your inbox. Please process them."

Allie will read, extract key information, and file insights into the appropriate knowledge directories.
