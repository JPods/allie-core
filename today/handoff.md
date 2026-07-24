# Handoff — 2026-07-24T04:00Z

## What Was Done This Session (2026-07-22 to 2026-07-24)

### CrashHarvester — 39 States with All-Severity Data
- Overnight harvest: 22 states from ArcGIS endpoints (zero failures)
- Probe script (`probe_states.py`): searched all 21 portal-required states, found usable endpoints in all 21
- Harvested 15 new states tonight: AL(116K), AR, GA(3K), IN(180K), KY, LA, MI(72K), NE, NH(5K), NJ(11K), OH(23K), SC(9K), SD(36K), WV(5K), WY(2K)
- **OK data issue**: The `ok_all` FeatureServer (`CrashDataReportforGISstory`) returns Arizona data, not Oklahoma. Removed. OK needs OHSO contact (Action #395). FARS fatal covers OK statewide.
- All crash data synced to Andi

### Mac↔Andi Sync
- `allie-andi-sync.sh` — syncs knowledge, apps, vectors
- launchd agent `com.allie.andi-sync` — every 4 hours, knowledge only
- Aliases: `andi-sync`, `andi-sync full`

### Vector Stores — All Updated on Both Machines
- Mac: Allie(4207), Claude(1997), Alice(5536), Noelle(51347)
- Andi: Allie(3295), Claude(1299), Alice(79), Noelle(49670)

### 10xMakers.com — Live
- Deployed to Hostinger (GoDaddy addon domain on jpods.com hosting)
- Physical Internet framing, Digital/Physical parallel, Tesla/Lamarr/Edison/Congress quotes
- 5X5 Free Market section, liberty mechanism, community/information/learning tools
- Domain portfolio documented (7 GoDaddy domains) — Action #393 to transfer to Cloudflare (needs helper, due 2026-08-20)

### MeshMobility Updates
- **Save**: server save (requires auth) + Save Local (File System Access API, no auth)
- **Auth**: email verification with 6-digit code via Gmail SMTP, 30-day session, profile form creates WC3 contact with source_name=meshmobility.com
- **Session fix**: SESSION_COOKIE_SECURE=False for CF tunnel, permanent on every request
- **Local auth bypass**: localhost requests auto-authenticated as bill@jpods.com
- **Run**: instant Dijkstra travel times (no simulation needed), enables Isochrone immediately
- **Isochrone**: disabled until Run completes (travel times for all station pairs)
- **Library**: US states sorted to top, Open zooms to network, Clone works
- **Build on Lines**: preserves existing network (no longer erases)
- **Landing**: 10xMakers + Training Videos buttons added
- **Training page**: `/training` route with video card grid, sections by category
- **Emails from Andi**: `bill.james+ar@jpods.com` (SMTP via Gmail)

### WC_HQ Architecture
- Connection/Bundle for ALL sync (commerce + operational + deploy)
- `deploy` and `training` purpose choices added to sync app
- Readmes updated: 21-sync-integration.md, dual-hosting-model.md
- Training video script: WC3-SYNC-01 (3-4 min, DataBrowser for Connections/Bundles)
- Decision: WC_HQ is not a separate app — same WC3, different role

### WC3 Database
- Local Mac DB (commerce_expert) restored to Andi (wc_jpods) — 2233 contacts, all actions
- DB permissions fixed for webclerk user
- MeshMobility service account created (meshmobility@jpods.com)
- wcapi auth fixed to use JWT tokens + correct /wcapi/save/ pattern

### Contacts & Actions
- 7 crash data researchers created: Mehrara Molan (Ole Miss/MS), Wang (JSU/MS), Vachal (NDSU/ND), Edara+Sun (Mizzou/MO), Abbate (RIDOT/RI), Williams (MS DPS)
- Action #393: Transfer domains to Cloudflare (due 2026-08-20)
- Action #394: MM Library — WC3 Document records for maps (due 2026-07-30)
- Action #395: Reach out to crash data researchers (due 2026-07-30)

## Next Session Should
1. Fix OK crash data — contact OHSO or find real statewide endpoint
2. WC3 wcapi `/wcapi/get/` returns 500 — serialization bug from DB restore, needs debugging
3. MeshMobility training videos — Bill has 5-10 to add
4. Test full auth flow on meshmobility.com (session persistence after refresh)
5. Run probe_states.py periodically to discover new endpoints
6. Sync local DB to Andi after any contact/action changes

## Open Issues
- wcapi GET endpoint 500 error on Andi (Contact serialization)
- OK statewide crash data unavailable (OHSO contact needed)
- NJ only partial (Burlington County + Newark, not statewide — CSV download at nj.gov is the statewide source)
- Alice on Andi has only 79 chunks (WC3 model files not synced)
