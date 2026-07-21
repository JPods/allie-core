# Handoff — 2026-07-21

## Where We Left Off
GEEKOM IT15 has Ubuntu 26.04 LTS installed successfully. Machine hostname is "andi". Sitting at the login prompt but Bill doesn't remember the username/password he set during install. May need to reinstall — the USB installer (8GB SD card via balenaEtcher) is ready and the process is now well-understood. No services deployed yet — still at Phase 1 (bare OS).

## Do This First Next Session
1. Log into the IT15 or reinstall Ubuntu if credentials are lost. During reinstall, use username `bill` and a memorable password — write it down.
2. Run `ip addr` on the IT15 to get the IP address.
3. From Mac: `ssh bill@192.168.x.x` to confirm SSH works, then set up `~/.ssh/config` with `Host andi` alias.
4. Run `ssh-copy-id bill@192.168.x.x` for passwordless access.
5. Begin Phase 1 of deployment guide: `sudo apt update && sudo apt upgrade -y`, install PostgreSQL, Redis, Nginx, Python, ufw.

## Open Problems
- Bill may not remember IT15 login credentials — reinstall may be needed (fast, ~15 min with existing USB)
- No static IP assigned yet — need DHCP reservation on router or netplan config
- First monitor (LG) couldn't display IT15 output — likely resolution mismatch, not input source. Second monitor worked. Once headless (SSH only), this doesn't matter.

## What Was Decided (and Why)
- **Andi is hardware-bundled**: Andi ships with physical hardware (Mac Mini, IT15, etc). Each business owns their box + AI + data. This is Desktop Hosting (2002 Wiley book) made real — not SaaS.
- **Opt-in sharing with Allie**: Users can choose to share patterns/learnings from their Andi back to Allie. Follows CarryOn sovereignty model — enumerated, revocable. Allie gets patterns, not raw data.
- **Future: one-touch installer**: Current manual process (ISO + Etcher + USB boot + walk through installer) is the specification for a future automated tool. Box should ship pre-loaded or install via single network command.
- **balenaEtcher is the standard**: dd command failed (sudo issues, no feedback). balenaEtcher is proven reliable for Linux USB installers. Saved to memory.
- **Ubuntu 26.04 LTS** (not 24.04 as originally planned) — newer, Bill already downloaded it, everything applies the same.

## Files Changed This Session
- `readmes/agents/andi.md` — already existed from prior session (no changes this session)
- `readmes/58-production-deployment.md` — already existed (no changes this session)
- `.claude/projects/-Users-williamjames-Allie/memory/feedback_balenaetcher.md` — new: balenaEtcher preference
- `.claude/projects/-Users-williamjames-Allie/memory/project_andi_hardware_agent.md` — new: Andi = hardware + intelligence product
- `.claude/projects/-Users-williamjames-Allie/memory/project_andi_installer_tool.md` — new: future one-touch installer spec
- `.claude/projects/-Users-williamjames-Allie/memory/MEMORY.md` — updated with new entries
