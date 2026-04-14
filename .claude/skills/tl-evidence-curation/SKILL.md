---
name: tl-evidence-curation
description: Use after perception-tier workers complete. Loads percept files from disk, normalizes format, deduplicates, anchors to code locations, and prepares structured percept bundles for contradiction detection or synthesis.
---

# Evidence Curation

## When to use

After all workers in a wave have reported completion via `notify_parent`. Before running contradiction detection or any synthesis skill.

## Core principles

1. **Percepts live on disk.** Workers write YAML to `$EXOMONAD_ANALYSIS_DIR/percepts/`. The TL reads from disk, never from MCP messages.
2. **Preserve provenance.** Every percept retains its lens identity. Never merge percepts from different lenses into a single entry.
3. **Normalize, don't flatten.** Make percepts comparable across lenses. Do not erase meaningful differences in observation style.
4. **Deduplicate conservatively.** Only merge percepts that describe the exact same code location with the same observation. When in doubt, keep both.

## Input

Read all percept files from the analysis directory:

```bash
ls $EXOMONAD_ANALYSIS_DIR/percepts/*.yaml
```

Each file contains percepts from one lens. Load and parse all of them.

## Curation steps

### 1. Validate schema compliance

For each percept, verify:
- `lens` field is set and matches the source file
- `id` is unique across all loaded percepts
- `location.file` is present and non-empty
- `observation` is present and non-empty
- At least one `evidence` entry exists

Percepts failing validation go to a separate file: `$EXOMONAD_ANALYSIS_DIR/curated/invalid.yaml` with a note on what failed. Do not discard them — they may still contain useful signal.

### 2. Normalize locations

For each percept:
- Resolve relative file paths to project-root-relative paths
- If `symbol` is missing but `line_start`/`line_end` are present, try to infer the enclosing function/type from context
- If only `symbol` is present, leave line numbers as null (the reasoning tier can resolve if needed)

### 3. Build location index

Create an index grouping percepts by code location:

```
$EXOMONAD_ANALYSIS_DIR/curated/location-index.yaml
```

Structure:
```yaml
locations:
  - file: "path/to/file.ext"
    symbol: "function_name"
    line_range: [42, 67]
    percepts:
      - id: "surface-cartographer-003"
        lens: "surface-cartographer"
        observation_summary: "<first 100 chars>"
      - id: "trust-boundary-mapper-002"
        lens: "trust-boundary-mapper"
        observation_summary: "<first 100 chars>"
```

This index is the primary input to contradiction detection. Locations with percepts from multiple lenses are the most valuable — they represent the same code seen through different eyes.

### 4. Deduplicate

Only merge percepts when:
- Same `location.file` and same `location.symbol`
- Same lens
- Observation describes the same thing (not just same location)

When merging, keep the richer observation and add a `merged_from` field listing the original IDs.

### 5. Tag cross-lens locations

In the curated output, flag every location that has percepts from 2+ lenses:

```yaml
cross_lens_locations:
  - file: "src/auth/handler.rs"
    symbol: "handle_login"
    lenses: [surface-cartographer, trust-boundary-mapper]
    percept_count: 3
```

These are the high-value targets for contradiction detection.

### 6. Write curated output

```
$EXOMONAD_ANALYSIS_DIR/curated/percepts-normalized.yaml   # All percepts, validated and normalized
$EXOMONAD_ANALYSIS_DIR/curated/location-index.yaml         # Grouped by location
$EXOMONAD_ANALYSIS_DIR/curated/cross-lens-hotspots.yaml    # Multi-lens locations (for contradiction detection)
$EXOMONAD_ANALYSIS_DIR/curated/invalid.yaml                # Schema failures (for review)
```

## Scope estimation note

When spawning workers, use this heuristic for LoC allocation:
- **500-1000 LoC per worker** for dense, security-relevant code (auth, parsing, IPC)
- **1000-2000 LoC per worker** for routine code (utilities, config, logging)
- Prefer overlapping coverage at boundaries between worker scopes

This is a starting point. Tune based on percept density from the first wave.

## Anti-patterns

| Failure mode | What to do instead |
|---|---|
| Discarding "invalid" percepts | Preserve them separately. A percept with missing fields may still contain the most important observation of the run. |
| Merging percepts from different lenses | Each lens produces its own view. Different observations of the same code are the point, not a problem to fix. |
| Summarizing observations during curation | Pass observations through verbatim. Curation normalizes format, not content. |
| Loading everything into context at once | Use the location index to identify hotspots, then load only the percepts for those locations when running skills. |
