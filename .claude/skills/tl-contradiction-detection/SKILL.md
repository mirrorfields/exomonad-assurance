---
name: tl-contradiction-detection
description: Use after evidence curation to compare percepts from different lenses and identify contradictions, tensions, and inconsistencies in how the same code is observed. Primary reasoning skill for the judgment tier.
---

# Contradiction Detection

## When to use

After evidence curation is complete and `cross-lens-hotspots.yaml` has been written. This skill operates on locations where multiple lenses have produced observations.

## Core principles

1. **Disagreement is signal.** Percepts from different lenses describing the same code differently is the most valuable output of the sensing architecture.
2. **Contradiction is a strong claim.** Require evidence from at least two independent observations before calling something a contradiction.
3. **Tension is still useful.** If you can't prove contradiction but observations don't quite align, flag it as tension, not contradiction.
4. **Don't force agreement.** If two lenses produce compatible observations, that's fine — not every location needs to be a finding.

## Input

1. `$EXOMONAD_ANALYSIS_DIR/curated/cross-lens-hotspots.yaml` — locations with multi-lens percepts
2. `$EXOMONAD_ANALYSIS_DIR/curated/location-index.yaml` — full percept details per location
3. Source code files referenced in percepts (read on demand for verification)

## Classification categories

For each cross-lens location, classify the relationship between its percepts:

### Contradiction
Two percepts describe incompatible realities about the same code.

Example: Surface cartographer observes "endpoint has no authentication middleware." Trust boundary mapper observes "endpoint assumes caller is authenticated." These cannot both be true in a consistent system.

### Tension
Percepts are compatible but suggest something non-obvious or potentially fragile.

Example: Surface cartographer observes "config loaded from environment variable with no validation." Trust boundary mapper observes "downstream code assumes config values are sanitized." Not contradictory, but the assumption chain is fragile.

### Corroboration
Independent lenses agree on the observation. Strengthens confidence.

Example: Surface cartographer notes "external input reaches this parser." Trust boundary mapper notes "parser output is treated as trusted by consumers." Both describe the same trust gap from different angles.

### Independent
Percepts from different lenses describe different aspects with no meaningful relationship. No finding.

## Analysis procedure

### 1. Load cross-lens hotspots

Read `cross-lens-hotspots.yaml`. Prioritize locations with the most lens diversity (2+ lenses) and the most percepts.

### 2. For each hotspot, load percepts and source

From `location-index.yaml`, get all percepts for the location. Read the relevant source code to ground your analysis.

### 3. Classify each hotspot

Apply the classification categories above. For each:

- **Contradiction**: Write a contradiction finding
- **Tension**: Write a tension finding
- **Corroboration**: Write a corroboration note (lower priority, but record it)
- **Independent**: Skip. No finding needed.

### 4. Write findings

Output to: `$EXOMONAD_ANALYSIS_DIR/findings/contradictions.yaml`

```yaml
findings:
  - id: finding-001
    type: contradiction|tension|corroboration
    severity: high|medium|low
    location:
      file: "path/to/file.ext"
      symbol: "function_name"
      line_range: [42, 67]
    description: >
      <What the contradiction/tension is. Specific, mechanical, no hedging.>
    percepts_involved:
      - id: "surface-cartographer-003"
        lens: "surface-cartographer"
        key_observation: "<the part that conflicts>"
      - id: "trust-boundary-mapper-007"
        lens: "trust-boundary-mapper"
        key_observation: "<the part that conflicts>"
    verification: >
      <What was read from source code to confirm this finding. Be specific about
      what you checked and what you saw.>
    open_questions:
      - "<What remains uncertain. What would need deeper analysis to resolve.>"
    recommended_followup:
      - lens: "<which lens to apply>"
        scope: "<what to examine>"
        reason: "<why this would help>"
```

### 5. Write summary

Output to: `$EXOMONAD_ANALYSIS_DIR/findings/summary.yaml`

```yaml
analysis_summary:
  total_cross_lens_locations: <int>
  contradictions: <int>
  tensions: <int>
  corroboration_notes: <int>
  skipped_independent: <int>
  high_severity:
    - id: finding-001
      description: "<one-line summary>"
  medium_severity:
    - id: finding-002
      description: "<one-line summary>"
  recommended_next_wave:
    - scope: "<area to examine>"
      lenses: ["<which lenses>"]
      reason: "<why>"
```

## Decision criteria for spawning follow-up workers

After contradiction detection, decide:

1. **If contradictions or high-severity tensions exist in scope areas not yet covered** → spawn follow-up workers with narrower scope to investigate specific locations.
2. **If the current coverage is sufficient and findings are clear** → proceed to assessment writing.
3. **If findings are thin but coverage was broad** → consider spawning additional lenses (data-flow tracer, invariant extractor) for the most interesting locations.

## Reading source code for verification

When verifying a finding, read the source file at the percept's location. Check:

- Does the source code match what the percepts describe?
- Is there context the percepts missed (guards in other files, middleware in configuration)?
- Is the contradiction real, or does it resolve when you see the full picture?

If reading the source resolves a contradiction, downgrade it to "resolved" and note what resolved it. This is valuable — it means the percepts were useful even though the initial finding was a false positive.

## Anti-patterns

| Failure mode | What to do instead |
|---|---|
| Treating abstraction-level differences as contradictions | Surface cartographer describes "what accepts input." Trust boundary mapper describes "where trust changes." These are different questions, not contradictions. |
| Calling everything a tension | Be selective. If percepts genuinely don't relate, classify as independent. |
| Not reading source code for verification | Percepts are observations from cheap models. Always verify against the actual code before committing to a finding. |
| Overweighting surface-level observations | Surface cartographer percepts are inherently "shallower." Don't treat their absence of depth as contradiction with a deeper lens. |
| Producing findings for every cross-lens location | Most cross-lens locations will be independent. That's fine. Finding 3-5 real contradictions in a run is a strong result. |
| Hedging every finding into meaninglessness | If you found a contradiction, say so. Don't downgrade to tension just to be safe. The assessment step is where confidence gets calibrated. |
