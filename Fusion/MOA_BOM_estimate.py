#!/usr/bin/env python3
"""
MOA BOM Cost Estimate — based on Najjar quote and tube weights

Approach: Calculate steel weight per guideway section from tube specs,
then derive $/kg all-in rate from Najjar's JD 157,700 quote.
Apply that rate to estimate MOA network costs.

Known from specs and Najjar quote:
- 170m guideway section quoted at JD 157,700 = $222,491
- CHS Schedule 80 pipes, St-37/2 (DIN 17100), 250 N/mm²
- Columns: A1085 HSS 16x0.5 and HSS 20x0.5
- Steel density: 7850 kg/m³
"""

import json
import math

# ══ TUBE WEIGHT CALCULATIONS ══
# CHS = Circular Hollow Section
# Weight per meter = π × (OD - t) × t × density
# density of steel = 7850 kg/m³

def chs_weight_per_meter(od_mm, wall_mm):
    """Weight per meter for circular hollow section in kg/m"""
    od = od_mm / 1000  # convert to meters
    t = wall_mm / 1000
    return math.pi * (od - t) * t * 7850

# ══ TRUSS MEMBERS — estimated from typical JPods truss geometry ══
# An 8-panel truss segment spans approximately 20m (170m / ~8.5 segments)
# Typical CHS truss has: top chord, bottom chord, diagonals, verticals

# Schedule 80 pipe sizes commonly used in JPods truss:
tubes = {
    "top_chord": {"od_mm": 114.3, "wall_mm": 8.56, "desc": "4.5\" Sch 80"},  # NPS 4
    "bottom_chord": {"od_mm": 114.3, "wall_mm": 8.56, "desc": "4.5\" Sch 80"},
    "diagonal": {"od_mm": 88.9, "wall_mm": 7.62, "desc": "3\" Sch 80"},
    "vertical": {"od_mm": 60.3, "wall_mm": 5.54, "desc": "2\" Sch 80"},
    "bracing": {"od_mm": 48.3, "wall_mm": 5.08, "desc": "1.5\" Sch 80"},
}

print("═══ TUBE WEIGHTS ═══")
for name, spec in tubes.items():
    wt = chs_weight_per_meter(spec["od_mm"], spec["wall_mm"])
    spec["kg_per_m"] = wt
    print(f"  {spec['desc']:20s} ({name:15s}): {wt:.2f} kg/m")

# ══ ESTIMATE STEEL PER 170m GUIDEWAY SECTION ══
# This is a rough estimate based on typical truss geometry
# Two parallel guideways (inbound + outbound), each with:
# - 2 chords (top + bottom) × 170m = 340m per guideway
# - Diagonals: approx 1.5× chord length = 255m per guideway
# - Verticals: approx 0.5× chord length = 85m per guideway
# - Bracing/ribs: approx 0.3× chord length = 51m per guideway
# × 2 guideways = all doubled

print("\n═══ ESTIMATED STEEL PER 170m SECTION ═══")
section_170m = {}
members = {
    "Top chords": ("top_chord", 170 * 2 * 2),        # 2 guideways × 2 chords
    "Bottom chords": ("bottom_chord", 170 * 2 * 2),
    "Diagonals": ("diagonal", 170 * 1.5 * 2),         # estimated
    "Verticals": ("vertical", 170 * 0.5 * 2),
    "Bracing/ribs": ("bracing", 170 * 0.3 * 2),
}

total_weight_170m = 0
for desc, (tube_type, total_length) in members.items():
    wt = tubes[tube_type]["kg_per_m"] * total_length
    section_170m[desc] = {"length_m": total_length, "weight_kg": wt}
    total_weight_170m += wt
    print(f"  {desc:20s}: {total_length:7.0f}m × {tubes[tube_type]['kg_per_m']:.2f} kg/m = {wt:,.0f} kg")

# Add columns (from BOM: ~26 piers)
# HSS 16x0.5 = 406.4mm OD, 12.7mm wall
col_wt = chs_weight_per_meter(406.4, 12.7)  # HSS 16x0.5
col_count = 26
col_height = 5.5  # meters (from Najjar: 5.50m free height)
col_total = col_wt * col_count * col_height
total_weight_170m += col_total
print(f"  {'Columns (26×5.5m)':20s}: {col_count * col_height:7.0f}m × {col_wt:.2f} kg/m = {col_total:,.0f} kg")

# Connection hardware, base plates, misc (estimate 15% of structural)
misc = total_weight_170m * 0.15
total_weight_170m += misc
print(f"  {'Misc (15%)':20s}: {'':7s}   {'':>10s}   = {misc:,.0f} kg")

print(f"\n  TOTAL ESTIMATED STEEL: {total_weight_170m:,.0f} kg ({total_weight_170m/1000:.1f} tonnes)")

# ══ DERIVE $/KG FROM NAJJAR QUOTE ══
najjar_jd = 157700
najjar_usd = 222491  # as stated in quote
usd_per_kg = najjar_usd / total_weight_170m

print(f"\n═══ COST ANALYSIS ═══")
print(f"  Najjar quote: JD {najjar_jd:,} = ${najjar_usd:,}")
print(f"  Estimated steel weight: {total_weight_170m:,.0f} kg")
print(f"  All-in rate: ${usd_per_kg:.2f}/kg (steel + fabrication + painting + overhead)")
print(f"  For reference: raw steel ~$0.80-1.20/kg, so fabrication is ~{usd_per_kg/1.0:.1f}x raw")

# ══ MOA NETWORK ESTIMATE ══
print(f"\n═══ MOA NETWORK ESTIMATE ═══")

moa_guideway_miles = 5  # approximate
moa_guideway_km = moa_guideway_miles * 1.609
moa_stations = 8

# Guideway cost
guideway_weight = total_weight_170m * (moa_guideway_km * 1000 / 170)
guideway_cost = guideway_weight * usd_per_kg
print(f"  Guideway: {moa_guideway_miles} miles ({moa_guideway_km:.1f} km)")
print(f"  Guideway steel: {guideway_weight:,.0f} kg ({guideway_weight/1000:.0f} tonnes)")
print(f"  Guideway cost at Najjar rate: ${guideway_cost:,.0f}")
print(f"  Per mile: ${guideway_cost/moa_guideway_miles:,.0f}")
print(f"  Per km: ${guideway_cost/moa_guideway_km:,.0f}")

# Station estimate (rough — stations not in Najjar quote)
station_steel_estimate = 15000  # kg per station (stairs, platform, structure)
station_cost = station_steel_estimate * usd_per_kg * moa_stations
print(f"\n  Stations: {moa_stations} × ~{station_steel_estimate:,} kg = {station_steel_estimate * moa_stations:,} kg")
print(f"  Station cost estimate: ${station_cost:,.0f}")

# Solar structure (from Najjar: not included, estimate separately)
solar_per_km = 5000  # kg per km of solar support structure
solar_weight = solar_per_km * moa_guideway_km
solar_cost = solar_weight * usd_per_kg * 0.7  # simpler fabrication
print(f"\n  Solar structure: {solar_weight:,.0f} kg")
print(f"  Solar structure cost: ${solar_cost:,.0f}")

# Bogies (from Fusion BOM: 42 parts per bogie, estimate 500 kg each)
bogie_count = 20  # for MOA fleet
bogie_cost_each = 25000  # rough estimate per bogie
bogie_total = bogie_count * bogie_cost_each
print(f"\n  Bogies: {bogie_count} × ${bogie_cost_each:,} = ${bogie_total:,}")

# Total
total = guideway_cost + station_cost + solar_cost + bogie_total
print(f"\n  ═══════════════════════════════")
print(f"  ESTIMATED STEEL/FABRICATION TOTAL: ${total:,.0f}")
print(f"  This is FABRICATION ONLY — does not include:")
print(f"    - Concrete foundations")
print(f"    - Solar panels")
print(f"    - Electrical/controls")
print(f"    - Shipping from Jordan")
print(f"    - Site erection")
print(f"    - Engineering/permitting")
print(f"\n  NOTE: These are rough estimates based on tube geometry assumptions.")
print(f"  Actual weights should come from Fusion360 mass properties.")
print(f"  The $/kg rate from Najjar is Jordan pricing — US fab will differ.")
