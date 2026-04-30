# Allie Security & Network Configuration

---

## Security Philosophy

Allie's security model is simple: **local-first, network-minimal**.

Bill's data lives on a physical drive he carries. It does not live in someone else's cloud. It does not sync to unknown servers. It does not depend on a subscription that can be revoked. The primary security measure is physical possession.

> The most secure server is the one under your desk — or in your bag.

---

## Threat Model

| Threat | Mitigation |
|---|---|
| Cloud provider data breach | Data is not in the cloud |
| Subscription/account termination | Drive is self-contained |
| API key exposure | Keys stored locally, rotated as needed |
| Physical drive theft | Drive encryption (FileVault / APFS encryption) |
| Malicious AI session | Claude Code operates in working directory only |
| Network interception | Minimal network surface; API calls only |

---

## Drive Encryption

The Allie SSD should be encrypted at rest.

**On macOS with APFS:**
- Format drive as APFS (Encrypted) in Disk Utility
- Store the encryption password in your password manager (not iCloud Keychain if avoiding cloud)
- FileVault on the host Mac provides additional protection

---

## Network Surface

Allie's network activity should be limited to:

1. **Claude API calls** — via Claude Code to Anthropic's API
   - These are encrypted in transit (HTTPS/TLS)
   - Content is governed by Anthropic's privacy policy
   - Minimize what goes over the API when working with sensitive material

2. **WebClerk local server** (optional) — see `07-security-network-webclerk-stub.md`
   - Serves local content at `localhost` only
   - Not exposed to the internet
   - Used for rendering knowledge/writing content locally

3. **No other network activity** by default

---

## API Key Management

The Claude Code API key is stored in:
- macOS Keychain, OR
- A local `.env` file outside the Allie drive (not on the drive itself)

Never commit API keys to any file on the drive that might be synced or shared.

---

## What Claude Code Can Access

Claude Code (when working directory is `/Volumes/Allie`) can:
- Read, write, and execute within `/Volumes/Allie`
- Make API calls to Anthropic
- Run shell commands as the current macOS user

Claude Code cannot (without explicit user permission):
- Access files outside `/Volumes/Allie` without being directed to
- Push to external services
- Expose ports without being asked

Always review tool calls before approving operations that reach outside the drive.

---

## Local-First Content Serving

For rendering Allie's `knowledge/writing/` HTML files:

- Use a local HTTP server (Python's `http.server` or WebClerk)
- Bind to `localhost` only — never `0.0.0.0` on an open network
- See `07-security-network-webclerk-stub.md` for WebClerk configuration

```bash
# Quick local server for reviewing writing content:
cd /Volumes/Allie/knowledge/writing
python3 -m http.server 8080 --bind 127.0.0.1
# Then open: http://localhost:8080
```

---

## Physical Security

- Keep the drive on your person when traveling
- Do not leave it in checked luggage or unattended bags
- Consider a drive label or engraving with contact info (not sensitive info)
- Know where your backups are

---

## Backup Strategy

The Allie drive is a primary. Back it up.

Recommended:
- **Time Machine** to a separate external drive
- **Periodic manual copy** of `knowledge/` and `allie/` to a secure backup location
- Do NOT use a cloud backup service that would defeat the local-first model (or use an encrypted vault service like Cryptomator if you must)

---

## Operational Security

- Don't describe the full contents of Allie's drive in conversations with third parties
- Don't paste sensitive documents into non-Claude interfaces
- Review Claude Code's tool approvals carefully — especially anything touching the filesystem
- Update `carryon.json` at session end so sensitive context doesn't persist in chat history indefinitely
