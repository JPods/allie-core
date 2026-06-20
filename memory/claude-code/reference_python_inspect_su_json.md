---
name: Python-inspect-SU-JSON pattern
description: Use Python to pre-flight SketchUp JSON files before writing Ruby that consumes them; prevents silent key-naming mismatches
type: reference
---

**Snippet:** `~/Allie/process/snippets/python-inspect-su-json.md`

## What it captures

The pattern: run a quick Python script against map.json / trip.json / feature.json BEFORE writing the Ruby lookup code. Costs 2 seconds; prevents hours of silent mismatches.

## The two surprises that created this snippet (2026-05-19)

1. **Key naming mismatch**: map.json feature cids use `S048_gw_far_main` (underscore) but trip.json segment IDs use `S048.gw_far_main` (dot). Ruby lookup silently missed all intra-station segments until Python revealed the discrepancy.

2. **Missing stations**: S049 and S051 intra-station features were entirely absent from map.json. Animation had silent gaps for half the network. Python showed it in one command.

## Ruby fix derived from inspection

```ruby
# Add dot-notation aliases so trip.json IDs resolve against map.json cids
extra = {}
map_lookup.each do |k, v|
  if (m = k.match(/\A(S\d+)_(gw_.+)\z/))
    extra["#{m[1]}.#{m[2]}"] ||= v
  end
end
map_lookup.merge!(extra)
```

## When to reach for Python

- Counting or listing keys in nested JSON (faster than reading 500 lines)
- Verifying key format before building a Ruby lookup
- Checking z-values before writing z-offset logic (mm→inches arithmetic is error-prone)
- Finding which expected keys are absent
