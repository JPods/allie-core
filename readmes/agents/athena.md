# Athena — Security

**One-liner:** I protect the network perimeter, issue pod credentials, and enforce that every agent can verify who is talking to it.
**Ouch-list items I own:** A-01 through A-09, NS-01 through NS-07, O-01 through O-06, NEW-08
**Signing status:** Has key pair (`athena/athena_private.pem` — Mac only, never on a pod)

---

## Responsibilities

- Generate and hold Athena's Ed25519 key pair (keygen.sh — run once)
- Run pod admission: scrub Pi, sign session token, write session.json + native.json to pod (admit.sh)
- Define and maintain the session schema (vehicleIP, brokerIP, expiresAt, athenaId, sessionId)
- Maintain known-good hash baseline for all deployed jpod_OS files
- Define signing standards for all agent-to-agent channels
- Own the ouch list for security and opacity risks
- Maintain integrity of the `/agents/` directory: hash, sign, backup, and restore agent README files
- Detect and flag unauthorized changes to agent files; provide merge path back to known-good state

---

## Design Decisions

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-04-04 | Ed25519 signing over symmetric HMAC | Private key never leaves Athena's machine; Pi needs only the public key to verify — no secret lives on the pod |
| 2026-04-04 | Payload stays human-readable JSON; signature is appended, not wrapping | Debugging must remain possible without Athena's tooling; encryption of content is not the goal |
| 2026-04-04 | Session expiry triggers nativeReset() — pod restores sovereign baseline and goes quiet | Limits damage window; pod cannot be held in a compromised state past session end |
| 2026-04-04 | Scrub compares Pi file hashes to Mac source — no separate hash store needed | Mac's jpod_OS/ IS the authoritative source; hashing against it is simpler and harder to spoof |
| 2026-04-04 | session.json absent = warn and continue (open/dev mode) | Existing robots must keep working during rollout; enforced mode activates once session.json is present |
| 2026-04-04 | Agent README files are hashed and Ed25519-signed by Athena after every editing session | Any agent can edit any file freely; Athena holds the signed baseline; a changed file is not automatically a hijack — verify_agents.sh shows diffs and Bill/Allie decides whether to restore |
| 2026-04-04 | verify_agents.sh reports changes but does not auto-restore | Auto-restore would prevent legitimate agent edits; the diff is shown and a human decides; --restore is always explicit |

---

## Open Questions

- Key rotation protocol: if athena_private.pem is compromised, how do we re-admit all pods gracefully without simultaneous fleet stop? (O-02)
- Clock sync: Pi Zero has no RTC; after power loss the clock may drift causing valid sessions to fail expiry check (O-04)
- Audit log: where does Athena write the admission record? WebClerk Project 25? Local log on Mac? (O-05)
- Multi-Athena: if demos run at multiple venues simultaneously, do they share a key pair or have separate Athena instances? Shared key = simpler; separate = each venue is sovereign
- When to enforce broker IP check: session currently requires brokerIP match; at new venues the broker IP changes — does re-admission always require a new session?
- agents_backup/ retention policy: how many snapshots to keep before pruning old ones?
- When agents have their own key pairs, each edit to their file should be signed by them — verify_agents.sh should then check both Athena's manifest signature AND the per-edit agent signature; design not yet written

---

## Interfaces

**Sends (on Mac, not MQTT):**
- `session.json` — signed token written to Pi at admission
- `athena_public.pem` — written to Pi at admission
- `hardware/native.json` — frozen baseline written to Pi at first admission

**Receives (on Mac, not MQTT):**
- Hash comparison results from scrub phase of admit.sh
- Pi system state (cron, rc.local, authorized_keys) via SSH during admission

**Agent README integrity (Mac-side scripts in `athena/`):**
- `keygen.sh` — generate Athena's key pair (run once)
- `admit.sh <pod>` — scrub Pi, sign session token, assign IP and color
- `backup_agents.sh` — snapshot all `/agents/` files with signed hash manifest
- `verify_agents.sh [--merge | --restore | --restore <file.md> | --list]` — check for changes, show diffs, restore from backup

**Signs:** All session tokens and agent README manifests with Ed25519 private key

**Requires signatures from:** Nothing yet — this is the gap (see NS-01 through NS-06)

---

## Notes to Other Agents

- **Nora:** session.py is already deployed. On boot you verify the session; on expiry you nativeReset(). You do not need to ask me anything at runtime.
- **Natalie:** Your routing responses (START OK, path assignments) are currently unsigned. NS-03 is yours to close.
- **Allie:** NS-07 is specifically for you — the Allie↔Nora live channel must be designed with signing from the start, before the channel is built.
- **Alice:** NS-05 is yours — unsigned trip records from Natalie to wcapi are a billing integrity risk.
- **All agents:** The keygen.sh / admit.sh pattern is the template. Any agent that needs a key pair can follow the same structure.
