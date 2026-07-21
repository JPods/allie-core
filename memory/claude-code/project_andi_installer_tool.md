---
name: Andi one-touch installer tool
description: Future tool to replace manual Ubuntu install; box ships pre-loaded or single-command network install; current manual process is the spec
type: project
---

Build a tool that eliminates the manual Ubuntu install process for Andi hardware. Two paths:

1. **Pre-loaded**: Box ships with Andi already installed. Customer plugs in power + ethernet, Andi announces on network, owner claims from phone/laptop.
2. **Network installer**: Single command from any Mac/PC installs everything onto target hardware.

**Why:** The manual process (ISO download, balenaEtcher, USB boot, walk through installer, configure services) is too complex for non-technical users. Each step is a failure point. Bill experienced multiple blockers during IT15 setup (monitor input, BIOS keys, dd failures, forgotten credentials).

**How to apply:** The 2026-07-20 manual IT15 install is the specification — every step we did manually becomes a step the tool automates. Don't build this yet — finish the manual install first, then codify it.
