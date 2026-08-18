# Allie Reflection — 2026-08-17
*Model: deepseek-r1:8b | 82s | Generated: 22:04*

---

### Patterns
- **Recurring OSL Issues**: JPods privacy enforcement (OSL-02), Athena privacy corpus (OSL-03), and booking tokens (OSL-05) persist across multiple sessions. These are Must Fix items that consistently appear, indicating unresolved systemic issues in the jpods-plugin.
- **SketchUp Clearance Height (WI-001)**: The structural geometry stub at 7.5m conflicts with the clearance height of 4.6m, causing potential gaps in beam connections. This pattern surfaces repeatedly in design and build sessions, suggesting a cross-domain failure between SketchUp and physical specifications.
- **Two-Category Fix Pattern**: From prior sessions, tag assignment fixes require both pipeline geometry updates and retagging (e.g., 2026-05-18). This pattern reappears in recent work, solidifying the need for dual-process fixes.

### Emerging Lessons
- **Systematic Migration Works**: The successful migration of JPods code (from TFTS arcs) proves that studying existing code before rewriting is critical. Blind rewrites fail, while methodical migration succeeds.
- **Must Fix Items Dominate**: OSL reminders consistently list the same unresolved issues, indicating a need for prioritized fixes over new features. Privacy and security (OSL-02, OSL-03) are recurring blockers.

### Cross-Domain Flags
- **SketchUp Clearance → Physical Robots**: The 7.5m structural stub (WI-001) conflicts with the 4.6m clearance height, risking physical build failures if not resolved. This could cause beam misalignment or sensor errors in robot testing.
- **Query Builder → DataBrowser**: The date range filter in DataBrowser (deployed Aug 15) requires cross-domain sync with Alice’s search intent, affecting user experience in both frontend and backend logic.

### Wisdom Connections
- **WI-001 (Clearance Height)**: The principle is that structural geometry must align with clearance heights to avoid gaps. If the 7.5m stub isn’t adjusted, physical builds will fail, proving the WhatIf materialized.
- **Systematic Migration (TFTS)**: The principle is to study existing code before migrating. This was validated in JPods code migration (Aug 15) and should be applied to SketchUp/SketchUp exports.
- **Rejected Path**: Blind rewrites (TFTS) are still tempting, but the lesson is clear: study first.

### Understanding Candidates
**U-SK-001**  
ID: U-SK-001  
Title: Structural Alignment with Clearance Heights  
Principle: Structural geometry (stubs) must align with clearance heights to avoid gaps in beam connections.  
Evidence: WI-001 (SketchUp clearance issue) and Aug 15 build logs.  
Cross-domain: Yes (affects physical builds).

### Questions for Bill
- Why is the 4.6m clearance height non-negotiable, despite the 7.5m structural stub conflict?  
- Why are OSL-02/OSL-03 not prioritized higher in sprint planning?  
- Why was the booking token design (OSL-05) deferred indefinitely?

### Open Questions
1. How to automate the retagging process for geometry fixes (two-category pattern).  
2. How to verify the clearance height issue in SketchUp without physical prototypes.  
3. Why does the `jpods-plugin` directory keep triggering missing directory warnings?  

### Priority for Next Session
Fix OSL-02 (JPods privacy enforcement) and WI-001 (SketchUp clearance gap) immediately, as they are blocking physical and data integrations.