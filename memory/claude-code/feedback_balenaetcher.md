---
name: Use balenaEtcher for Linux installers
description: balenaEtcher is proven reliable for flashing Linux ISOs to USB; dd command fails silently or requires sudo hassle
type: feedback
---

Always use **balenaEtcher** to create Linux USB installers. Do not suggest `dd` as the primary method.

**Why:** Bill has repeatedly found balenaEtcher more successful than any other method for building Linux installers. The `dd` approach failed during IT15 Ubuntu setup (sudo issues, no feedback on success/failure). balenaEtcher is graphical, gives clear progress, and just works.

**How to apply:** When setting up any Linux install (IT15, Pi, or future machines), recommend balenaEtcher first. Skip the `dd` command unless Bill specifically asks for it.
