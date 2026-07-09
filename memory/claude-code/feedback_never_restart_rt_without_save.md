---
name: Never restart MeshMobility without confirming save
description: Server restart destroys in-memory network; cost Bill 1 hour of Greenville editing on 2026-07-05
type: feedback
---

NEVER restart the MeshMobility server without confirming Bill has saved his work AND verifying the save captured his actual network. The curl backup trick only saves what the server holds, which may differ from the browser if the server was restarted mid-session.
**Why:** Bill lost an hour of Greenville network editing on 2026-07-05 when server restarted and curl saved the test network instead of his work.
**How to apply:** Before any server restart: (1) ask Bill to save, (2) verify file size is reasonable (>100KB for a real network, not 16KB), (3) only then restart. When changing Python backend code, warn Bill explicitly.
