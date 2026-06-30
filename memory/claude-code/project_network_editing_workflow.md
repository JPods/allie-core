---
name: Network editing workflow — CP connections
description: How CP connections should work: connect by clicking CPs, delete by Shift-click, Refresh reads disk, Build rebuilds. Network Display must stay in sync.
type: project
---

**Desired workflow:**
1. CP Calculate (toolbar) → shows CP rings
2. Click two CPs → connection added to network.json + Network Display
3. Press W → add waypoints along the connection
4. Shift-click a connection → delete ONE connection from network.json + Network Display
5. Refresh button → reload Network Display from network.json on disk
6. Build button → rebuild geometry from connections + refresh Network Display

**Current state (2026-06-29):**
- Clicking CPs to connect works, writes to network.json
- push_network_json now pushes to iframe (was no-op, fixed)
- Build auto-refreshes Network Display after completion (fixed)
- Shift-click delete NOT WORKING — handler doesn't fire or doesn't reach delete code
- Refresh button placed next to Build at bottom of Network pane
- M# labels changed to W# (waypoints not markers)
- Connections sorted by left-side CP in Network Display
- Duplicate CP no longer nukes all connections (just warns)

**Key files:**
- tools/connect_tool.rb — Shift-click handler (line 214+), commit (line 1296+)
- network/network_editor.rb — delete_connection, push_network_json
- dialogs/network_editor.html — renderConnections, loadContent (sorted), addConnection
- dialogs/console.html — Refresh + Build buttons at bottom of Network pane
