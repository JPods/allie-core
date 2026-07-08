# Handoff — 2026-07-07 (Evening)

## Do This First
1. **Restart Route-Time** if not running — `cd /Users/williamjames/Documents/08_JPods/03_Technology/00_working_code && bash route_time/runserver.sh`
2. Verify `rtb.webclerk.com` and `wcb.webclerk.com` are serving (tunnel auto-starts on boot)
3. Test `rtb.webclerk.com/citytool` — Census API key is live

## Where We Left Off

### Cloudflare — DONE
- Tunnel `wc_hq_tunnel` running as system service, healthy
- `rtb.webclerk.com` → Route-Time:5050
- `wcb.webclerk.com` → WebClerk3:8000
- `rtb.webclerk.com/citytool` → CityTool (serves from original file location)
- jpods.us on Cloudflare nameservers (propagated)
- webclerk.com on Cloudflare nameservers (active)

### Route-Time — Committed & pushed (bill_dev)
- Tools + Overlays panels in right sidebar (consolidated from left palette)
- Keys 1-9: placement, zoom, walk radius
- Fixed scale bars: 0.75mi walk + 5mi
- On-demand overlay fetch for any US city (AADT, FARS, census)
- All 50 states harvested: 123MB on 5TB at `/Volumes/Allie/data/overlays/`
- Data files gitignored, 5TB is durable store
- Asheville NC tested — all overlays loading, Noelle Draft working

### Tulsa Network Sizing — Analysis complete
- Vector analysis: 263 guideway mi, 183 stations, 329 total structures
- CityTool validation: 189 mi (city), $3.78B build, $1.61B/yr savings, 7yr payback
- PDF saved: `route-time_maps/Tulsa_CityTool.pdf`
- Conservative payback (7yr) — car ownership unwinds slowly

## Open Issues
- CityTool on jpods.com/library needs Census API key uploaded to Hostinger
- Cloudflare Access (email verification for public RT/WC3) not yet configured
- Crash density overlay is FARS fatals only — true all-severity needs state DOT data
- AADT on-demand fetch limited (2000-record HPMS cap) — state files on 5TB more complete
- jpods.us tunnel routes not yet added (webclerk.com only)

## Tomorrow
- Upload CityTool with API key to Hostinger (library.jpods.com)
- Capital pitch document: CityTool → Route-Time → Station Report flow
- Cloudflare Access for email verification on public endpoints
- Consider `citytool.jpods.us` and `rt.jpods.us` as clean public URLs
- Asheville network design session with Noelle

## Key Insight
Oil depletes with use; ingenuity increases with use. JPods is a 10x paradigm shift. Every network built teaches the next one. The capital pitch leads with this framing before any numbers.
