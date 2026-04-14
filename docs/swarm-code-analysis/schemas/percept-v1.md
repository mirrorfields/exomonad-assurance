# Percept Schema v1

The percept is the fundamental unit of observation in the sensing architecture. It is a structured, code-anchored observation produced through a specific perceptual lens, with no obligation to interpret its own significance.

Percepts are the output of **perception-tier** agents (cheap, fast models reading code through a narrow lens). They are consumed by the **reasoning tier** (synthesis, contradiction detection, adjudication).

---

## Schema

```yaml
lens: <string>                    # Which sense produced this (surface-cartographer, trust-boundary-mapper, etc.)
id: <string>                      # Unique within this worker's output: {lens}-{sequence_number}
scope: <string>                   # What was examined to produce this percept

location:
  file: <string>                  # File path relative to project root
  symbol: <string|null>           # Function, type, module, or class name
  line_start: <int|null>          # Start line (inclusive)
  line_end: <int|null>            # End line (inclusive)

observation: <string>             # What was perceived, descriptively. No judgment, no conclusion.
context: <string>                 # What's adjacent, what transformation is happening, what's upstream/downstream
texture: <string>                 # simple|complex, familiar|unusual, consistent|anomalous — relative to surroundings
open_edges: <list[string]>        # What this observation connects to that wasn't in scope (symbols, files, flows)

evidence:
  - description: <string>         # What this evidence shows
    location: <string>            # Code reference supporting it (file:line or symbol)
```

## Design principles

1. **No confidence score.** Cheap models can't calibrate confidence reliably. Confidence is a synthesis-layer construct.
2. **No security relevance rating.** That requires judgment the perception tier shouldn't provide.
3. **No claims.** A percept describes what was observed, not what it means.
4. **Location anchoring is mandatory.** Every percept must be traceable to code.
5. **Texture is subjective by design.** It encodes the worker's sense of normalcy — useful for synthesis, not to be treated as ground truth.
6. **Open edges are the most important field for routing.** They tell the reasoning tier where to look next.

## File format

Workers write percepts as a single YAML file to the analysis directory:

```
$EXOMONAD_ANALYSIS_DIR/percepts/{lens-name}.yaml
```

Each file contains a list of percepts. Multiple workers with the same lens writing to the same scope should append with unique IDs.

## Relationship to other artifacts

- **Percepts** → consumed by skills (evidence curation, contradiction detection)
- **Findings** → produced by the reasoning tier from percepts (not yet defined; will be v2 schema)
- **Assessment** → final output from the TL, synthesizing all findings
