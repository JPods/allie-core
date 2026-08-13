# ACTION — CityRoadkills ↔ MeshMobility/Noelle API Integration
**Owner:** Claude Code + Noelle + Alice
**Created:** 2026-07-29
**Status:** Open
**Priority:** High — enables mass deployment of city letters

## What

When a user clicks "Draft Letter" for a city, the letter template should auto-populate
with data from MeshMobility/Noelle:

1. **Deaths/year** — from FARS crash data (already in MeshMobility overlays)
2. **Total crashes** — from all-severity data (where available)
3. **Worst intersection** — highest crash density location name
4. **Population** — from census data (already in PersonalizeTransit)
5. **Network cost** — from PersonalizeTransit calculator
6. **Annual savings** — from PersonalizeTransit calculator
7. **Walk score** — from PersonalizeTransit
8. **Guideway miles** — from PersonalizeTransit (road miles ÷ 14)

## How

### Option A: Server-side API (Andi)
Add endpoint to MeshMobility: `/api/city-brief?city=Tulsa&state=OK`
Returns JSON with all fields. Letter.html fetches on load.

### Option B: Pre-computed JSON
Generate `city-data.json` at build time from crash_data_registry + PersonalizeTransit DB.
Letter.html loads it client-side. No server dependency.

### Option C: Noelle generates per-city data file
Each city folder gets a `data.json` with pre-computed stats.
Noelle writes it when the city is first designed in MeshMobility.
Letter.html reads `folder/data.json`.

**Recommendation:** Option C — most sovereign (data travels with the city folder),
works offline, Noelle owns it.

## Alice's Role

When a council member responds to a letter:
1. Alice creates a WC3 Action record tracking the response
2. Response text goes to Alice's observation pipeline
3. Alice adds notes to the city's vector store entry
4. Patterns across cities (which arguments work, which don't) feed back to letter template
5. Alice tracks: sent date, response date, response type (positive/negative/silence)

## Leftshoe Integration

Every city letter interaction feeds the leftshoe store:
- **Scars:** Cities that responded negatively — what argument failed?
- **Judgments:** Cities that responded positively — what worked?
- **Values:** Patterns across cities that refine the approach

### Implementation: Alice note-taking for leftshoe

Add to Alice's observation pipeline:
```python
# When a city response is logged
def on_city_response(city, state, response_type, response_text):
    # 1. Create WC3 Action
    action = wcapi.save(model="action", data={
        "name": f"City response: {city}, {state}",
        "status": response_type,  # positive, negative, silence
        "description": response_text,
        "refs": {"keywords": [f"city:{city}", f"state:{state}", "source:cityroadkills"]},
    })
    
    # 2. Add to leftshoe store
    if response_type == "positive":
        identity_store.add("judgments", 
            f"{city}, {state} responded positively to roadkills letter. {response_text}")
    elif response_type == "negative":
        identity_store.add("scars",
            f"{city}, {state} rejected roadkills letter. {response_text}. What failed?")
    
    # 3. Add to city vector store for Noelle
    noelle_vectors.add(f"cityroadkills_{city}_{state}", response_text)
```

## Noelle's city-data.json Format

```json
{
  "city": "Tulsa",
  "state": "OK",
  "county": "Tulsa County",
  "population": 413000,
  "deaths_per_year": 50,
  "total_crashes_per_year": null,
  "worst_intersection": "I-44 & Highway 75",
  "worst_intersection_crashes": 23,
  "walk_score": 37,
  "road_miles": 2000,
  "guideway_miles": 143,
  "network_cost": "$6.8B",
  "annual_savings": null,
  "co2_reduction": null,
  "fars_features": 1039,
  "data_sources": ["FARS 2020-2024", "Census ACS"],
  "noelle_notes": "3rd most dangerous city in Oklahoma. 19% above national average.",
  "letter_sent": null,
  "response": null
}
```

## Next Steps

1. Noelle: generate data.json for each existing city folder from FARS + census data
2. Letter.html: fetch `folder/data.json` on load, auto-fill all fields
3. Alice: add response tracking endpoint
4. Leftshoe: wire city responses into identity store
