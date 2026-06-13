# TFTS — 2026-06-13T15:56:55Z

problem:   Vehicles placed at last 3 slot dist_mm values landed at ENTRY end (ps1/ps2/ps3),
           not exit end (ps7/ps8/ps9) — runner ended up at ps7, not ps9

fault_ref: (observed after switching to pslots.last(3): compact worked but runner was
            v3e at ps7 with loops=0; v1e was probe at ps9 with loops=0 after compact)

arc:
  - try:      Use pslots.last(3) dist_mm values as arc-distances along plat_pts.
              d_front = ps9 dist_mm (21250mm) / 25.4. Walk plat_pts from plat_pts[0].
    result:   v1e landed near entry, not exit. After compact: vehicles at ps7/ps8/ps9
              but runner tag was on the wrong vehicle.
    revealed: plat_pts for station_parking is loaded exit-first from geometry.json.
              The existing orientation block (lines 3110-3121) only corrects orientation
              when gw_platform_parking exists. station_parking has no gw_platform_parking,
              so pp_entry is nil, no reversal occurs, plat_pts stays exit-first.
              dist_mm values in lines.json are ENTRY-first (measured from entry end).
              Measuring 21250mm from the EXIT end walks backward — lands at ps1 position
              from the entry perspective (only 1250mm from entry end).

  - try:      Pre-call Sally.init_sequencer_for_station + Sally.init_from_model before
              vehicle placement. Sally's Pass 3 already orients slot positions entry-first
              using gw_platform_in* anchors. Use slot_positions_for_station(sid)[1] (ps1
              world position) to detect and correct plat_pts orientation.
    result:   succeeded — plat_pts reversed when needed, d_front correctly walks 21250mm
              from entry end, v1e lands at ps9 exit slot, tagged loops=1, dispatches first.

principle: plat_pts orientation for station_parking (no gw_platform_parking) is not
           self-correcting. The only reliable orientation anchor is Sally's ps1 world
           position, which Sally already computes correctly in init_from_model Pass 3
           via gw_platform_in* fallback chain. Pre-init Sally before vehicle placement
           and use slot_positions_for_station(sid)[1] to detect and correct plat_pts
           orientation. This generalizes: any test harness that places vehicles at
           arc-distance positions must verify plat_pts is entry-first before walking it.

domain:    SU
