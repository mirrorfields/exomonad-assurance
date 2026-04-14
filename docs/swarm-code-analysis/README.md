# Swarm Code Analysis — Proof of Concept

## Overview

This is a proof-of-concept extension to ExoMonad for **defensive vulnerability assurance** in open source code. It repurposes ExoMonad's tree-of-agents architecture for a different workload: instead of Opus decomposing software tasks and Gemini implementing them, the system uses cheap Gemini agents as **perceptual lenses** that emit structured observations (percepts), and a stronger reasoning tier (the TL) that synthesizes, compares, and adjudicates.

**Design slogan:** Senses perceive. Synthesis commits. Skills challenge. Sub-agents recurse.

## Architecture

```
TL (Opus) ─── judgment tier
  │
  ├── Evidence Curation skill      ← normalizes percepts, builds location index
  ├── Contradiction Detection skill ← compares cross-lens percepts, finds tensions
  │
  ├── Worker: Surface Cartographer  ← perception tier (Gemini)
  ├── Worker: Trust Boundary Mapper ← perception tier (Gemini)
  └── (more lenses later)
```

### Three-tier model

| Tier | Model | Role | Output |
|------|-------|------|--------|
| Perception | Gemini Flash | Read code through a narrow lens | Percepts (YAML) |
| Reasoning | TL (Opus) with skills | Curate, compare, detect contradictions | Findings |
| Judgment | TL (Opus) | Final assessment, follow-up routing | Assessment report |

## Artifacts

All analysis artifacts live on disk under the analysis directory:

```
$EXOMONAD_ANALYSIS_DIR/         (default: exomonad-analysis/ at project root)
├── percepts/                    ← worker outputs
│   ├── surface-cartographer.yaml
│   └── trust-boundary-mapper.yaml
├── curated/                     ← TL curation output
│   ├── percepts-normalized.yaml
│   ├── location-index.yaml
│   ├── cross-lens-hotspots.yaml
│   └── invalid.yaml
├── findings/                    ← TL contradiction detection output
│   ├── contradictions.yaml
│   └── summary.yaml
└── assessment.md                ← final TL assessment
```

### Why disk, not MCP?

1. **Preserve all traces.** Every intermediate artifact is inspectable and debuggable.
2. **No context window pressure.** The TL loads what it needs, when it needs it.
3. **Iterability.** Re-run a single skill without re-running the whole pipeline.
4. **Observability.** Anyone can inspect the `exomonad-analysis/` directory to see what happened.

## PoC scope

### Lenses (perception-tier workers)

| Lens | Role definition | What it sees |
|------|----------------|--------------|
| Surface Cartographer | `docs/swarm-code-analysis/roles/surface-cartographer.md` | External surfaces, entry points, attack surface map |
| Trust Boundary Mapper | `docs/swarm-code-analysis/roles/trust-boundary-mapper.md` | Trust transitions, validation boundaries, authority handoffs |

### TL skills (reasoning tier)

| Skill | Location | What it does |
|-------|----------|--------------|
| Evidence Curation | `.claude/skills/tl-evidence-curation/` | Load percepts, validate, normalize, deduplicate, build location index |
| Contradiction Detection | `.claude/skills/tl-contradiction-detection/` | Compare cross-lens percepts, classify relationships, produce findings |

### Shared schema

| Schema | Location |
|--------|----------|
| Percept v1 | `docs/swarm-code-analysis/schemas/percept-v1.md` |

## Workflow

### 1. Setup

```bash
# Set analysis directory (optional, defaults to exomonad-analysis/)
export EXOMONAD_ANALYSIS_DIR="exomonad-analysis"

# Create structure
mkdir -p $EXOMONAD_ANALYSIS_DIR/{percepts,curated,findings}
```

### 2. TL explores the codebase

If the TL doesn't already know the codebase structure, spawn an exploration worker:

```
spawn_worker(name="explore", task="Map the codebase structure. List all directories,
key entry points, and module boundaries. Write output to $EXOMONAD_ANALYSIS_DIR/codebase-map.yaml")
```

The TL reads the map and decides how to partition the codebase for worker coverage.

### 3. TL spawns perception workers

For each scope partition, spawn both lenses:

```
spawn_gemini(name="surface-scopeA", task=<surface cartographer instructions for scope A>)
spawn_gemini(name="trust-scopeA", task=<trust boundary mapper instructions for scope A>)
```

Workers write percepts to `$EXOMONAD_ANALYSIS_DIR/percepts/{lens-name}.yaml` and report completion via `notify_parent`.

### 4. TL curates evidence

After all workers complete, load the evidence curation skill and process percepts.

### 5. TL detects contradictions

Load the contradiction detection skill. Analyze cross-lens hotspots. Produce findings.

### 6. TL decides: iterate or assess

- **If contradictions or tensions point to areas needing deeper analysis** → spawn follow-up workers with narrower scope and more specific instructions. Return to step 3.
- **If findings are sufficient** → write the final assessment to `$EXOMONAD_ANALYSIS_DIR/assessment.md`.

### 7. Assessment

The assessment should follow the assurance format:

```markdown
# Security Assessment: {project}

## Scope
What was examined. What was not.

## Surface Map Summary
Key surfaces identified (from surface cartographer).

## Trust Boundary Summary
Key boundaries identified (from trust boundary mapper).

## Findings
For each finding:
- What the contradiction/tension is
- Where it lives (file, symbol)
- What it means in practice
- Recommended follow-up or remediation direction
- Confidence level

## Positive Observations
Invariants that appear correctly enforced. Boundaries that are explicit and well-guarded.
Assurance isn't just about finding problems.

## Coverage Notes
What was covered. What wasn't. Where the blind spots are.

## Recommended Next Steps
What lenses or scopes would produce the most value if run next.
```

## Worker scope sizing heuristic

Starting point for LoC allocation per worker:

| Code density | LoC per worker | Example |
|-------------|----------------|---------|
| Dense security logic (auth, parsing, crypto) | 500-1000 | Auth middleware, input validation, session management |
| Standard application code | 1000-2000 | CRUD handlers, config, utilities |
| Boilerplate / generated / low-risk | 2000+ | Migrations, type definitions, auto-generated code |

**Prefer overlapping coverage at scope boundaries** to avoid blind spots at the seams between workers.

## Validation test

To validate the PoC:

1. Pick a known-vulnerable open source component with a disclosed CVE
2. The vulnerability should require connecting observations across modules (not a trivial pattern match)
3. Run both lenses against it
4. Check whether the TL's findings point toward the known vulnerability's neighborhood

Pass criterion: findings identify the right area of concern, even if the exact vulnerability isn't pinpointed.

## Design docs

- `docs/swarm-code-analysis/exomonad-assurance-harness-notes.md` — full concept proposal
- `docs/swarm-code-analysis/Sensing_model_refinement.md` — the sensing model refinement (percepts vs claims)
