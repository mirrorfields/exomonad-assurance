---
name: tl-analysis-orchestration
description: Use when conducting a swarm code analysis session. Covers the full workflow: scoping the codebase, spawning perception-tier workers with the right lens instructions, curating their percepts, detecting contradictions, iterating, and writing the final assessment. Load this skill at the start of an analysis run.
---

# Analysis Orchestration

End-to-end workflow for defensive vulnerability assurance using the sensing architecture.

## Setup

Before starting, ensure the analysis directory exists:

```bash
export EXOMONAD_ANALYSIS_DIR="${EXOMONAD_ANALYSIS_DIR:-exomonad-analysis}"
mkdir -p $EXOMONAD_ANALYSIS_DIR/{percepts,curated,findings}
```

## Phase 1: Map the codebase

If you don't know the codebase structure, spawn an exploration worker first:

```
spawn_worker(name="explore", task="Map the directory structure of this codebase.
List all top-level directories, their purpose, key entry points, and approximate LoC.
Focus on: HTTP handlers, CLI entrypoints, config loading, auth modules, IPC, parsers,
database access. Write your findings to $EXOMONAD_ANALYSIS_DIR/codebase-map.yaml
in this format:

directories:
  - path: src/
    purpose: <one line>
    key_files: [list]
    approx_loc: <number>
    security_relevance: high|medium|low

entry_points:
  - file: <path>
    type: http|cli|config|ipc|parser|db
    description: <one line>

Then call notify_parent with the summary.")
```

Read the map. Decide how to partition the codebase into scopes for workers.

## Phase 2: Scope partitioning

### Sizing heuristic

| Code density | LoC per worker | Examples |
|-------------|----------------|---------|
| Dense security logic | 500-1000 | Auth, parsing, crypto, IPC |
| Standard application code | 1000-2000 | CRUD, config, utilities |
| Low-risk code | 2000+ | Types, migrations, generated code |

**Overlap at scope boundaries.** Assign boundary modules to both adjacent scopes.

### Partition by security-relevant structure, not file layout

Prefer:
- Input processing surface as one scope
- Auth/identity as one scope
- State transitions/persistence as one scope
- External dependency boundaries as one scope

File layout is a starting heuristic. The security story is usually orthogonal.

## Phase 3: Spawn perception workers

For each scope, spawn **both lenses** (surface cartographer + trust boundary mapper). They produce different views of the same code.

### How to spawn with lens instructions

The lens instructions must be embedded in the `task` field. Workers get the base worker protocol (`worker.md` context) automatically. The task text adds the lens on top.

Use `spawn_worker` for ephemeral workers (no branch, no PR). Use `spawn_gemini` with `isolation="worktree"` for persistent workers that file PRs.

**Surface Cartographer:**

```
spawn_worker(name="surface-{scope}", task="You are a perception-tier agent operating through the **surface cartographer** lens.

YOUR LENS: Map every external surface — inputs, events, or actors that can influence control flow or privileged state.

Look for: network handlers, CLI entrypoints, file readers, env/config loaders, job consumers, schedulers, plug-in hooks, reflection/dynamic dispatch, background workers with external input, admin paths, IPC channels, database query surfaces.

YOUR SCOPE: <describe the scope precisely — directories, modules, files>

DO NOT: assess severity, make claims about what should/shouldn't be exposed, score or rank, speculate about exploitability, skip surfaces because they look safe, truncate output.

OUTPUT: Write all percepts to $EXOMONAD_ANALYSIS_DIR/percepts/surface-cartographer.yaml using this format:

```yaml
lens: surface-cartographer
scope: \"<your scope>\"
percepts:
  - id: surface-cartographer-001
    scope: \"<subscope>\"
    location:
      file: \"path/to/file\"
      symbol: function_or_type_name
      line_start: 42
      line_end: 67
    observation: >
      Descriptive observation of the surface. What it accepts, how it's reached.
      Follow at least one call deeper. Note what the surface connects to.
    context: >
      What's adjacent. What downstream systems this surface touches.
      What data flows in. What transformations happen before control flow diverges.
    texture: \"simple|complex, familiar|unusual, consistent|anomalous\"
    open_edges:
      - \"<symbol or file this surface connects to outside your scope>\"
    evidence:
      - description: \"<what this evidence shows>\"
        location: \"file:line or symbol\"
```

Each surface gets its own percept. Do not group multiple surfaces into one entry.
If you didn't read downstream code, put it in open_edges instead of context.

WHEN DONE: Call notify_parent with:
  Surface Cartographer complete. Scope: <scope>. Percepts: <count>. Surfaces: <categorized count>. Output: $EXOMONAD_ANALYSIS_DIR/percepts/surface-cartographer.yaml")
```

**Trust Boundary Mapper:**

```
spawn_worker(name="trust-{scope}", task="You are a perception-tier agent operating through the **trust boundary mapper** lens.

YOUR LENS: Map every trust transition — where the system changes how much it trusts data, identity, metadata, or state.

Look for: identity boundaries (auth transitions, session creation, token verification), validation boundaries (unvalidated→validated, parsing→logic), authority boundaries (user→service, tenant→platform, permission checks), data boundaries (local→remote, cache→authority, unsigned→signed), execution boundaries (parser→executor, data→control flow, FFI, IPC).

Not all boundaries are explicit. Look for guard clauses, middleware chains, data transformation that changes shape, error handling distinguishing trusted/untrusted paths, test fixtures setting up auth contexts.

YOUR SCOPE: <describe the scope precisely — directories, modules, files>

DO NOT: assess whether boundaries are strong enough, make claims about what should be checked, skip boundaries because the framework handles it, score or rank, speculate about bypasses, truncate.

OUTPUT: Write all percepts to $EXOMONAD_ANALYSIS_DIR/percepts/trust-boundary-mapper.yaml using this format:

```yaml
lens: trust-boundary-mapper
scope: \"<your scope>\"
percepts:
  - id: trust-boundary-mapper-001
    scope: \"<subscope>\"
    location:
      file: \"path/to/file\"
      symbol: function_or_type_name
      line_start: 42
      line_end: 67
    observation: >
      Descriptive observation of the trust boundary. What changes here — identity,
      validation state, authority level, data interpretation. Name both sides:
      what's upstream and what's downstream.
    context: >
      What's happening around this boundary. What checks are visible.
      Whether the boundary is explicit (guard, middleware) or implicit (assumption).
    texture: \"simple|complex, familiar|unusual, consistent|anomalous\"
    open_edges:
      - \"<symbol or file this boundary connects to outside your scope>\"
    evidence:
      - description: \"<what this evidence shows>\"
        location: \"file:line or symbol\"
```

Each boundary transition gets its own percept. Always note when enforcement is absent.
A boundary with no visible check is more interesting than one with an explicit guard.

WHEN DONE: Call notify_parent with:
  Trust Boundary Mapper complete. Scope: <scope>. Percepts: <count>. Boundaries: <categorized count>. Implicit: <count>. Output: $EXOMONAD_ANALYSIS_DIR/percepts/trust-boundary-mapper.yaml")
```

### Spawning pattern

Spawn all workers for a scope in parallel:

```
# Scope A — both lenses
spawn_worker(name="surface-auth", task=<surface cartographer instructions for auth scope>)
spawn_worker(name="trust-auth", task=<trust boundary mapper instructions for auth scope>)

# Scope B — both lenses
spawn_worker(name="surface-handlers", task=<surface cartographer instructions for handler scope>)
spawn_worker(name="trust-handlers", task=<trust boundary mapper instructions for handler scope>)
```

After spawning, **return immediately**. Idle until workers report via `notify_parent`.

## Phase 4: Curate evidence

After all workers in the wave report completion, load the **tl-evidence-curation** skill and follow its procedure. This produces:

- `curated/percepts-normalized.yaml`
- `curated/location-index.yaml`
- `curated/cross-lens-hotspots.yaml`
- `curated/invalid.yaml`

## Phase 5: Detect contradictions

Load the **tl-contradiction-detection** skill. Analyze cross-lens hotspots. Produce:

- `findings/contradictions.yaml`
- `findings/summary.yaml`

## Phase 6: Iterate or assess

Read `findings/summary.yaml`. Decide:

- **Contradictions or high-severity tensions in uncovered areas** → spawn follow-up workers with narrower scope. Return to Phase 3.
- **Findings are sufficient** → proceed to assessment.

Maximum 3 iteration waves. After that, write the assessment with what you have.

## Phase 7: Write assessment

Write to `$EXOMONAD_ANALYSIS_DIR/assessment.md`:

```markdown
# Security Assessment: {project}

## Scope
What was examined. What was not. Worker count and wave count.

## Surface Map Summary
Key surfaces from the surface cartographer percepts.

## Trust Boundary Summary
Key boundaries from the trust boundary mapper percepts.
Count of explicit vs implicit boundaries.

## Findings
[For each finding from contradictions.yaml]
### {finding-id}: {title}
- **Type:** contradiction | tension
- **Severity:** high | medium | low
- **Location:** file:symbol
- **Description:** what the finding is
- **Percepts involved:** which lenses produced the conflicting observations
- **Verification:** what source code was checked
- **Recommended follow-up:** what to do next

## Positive Observations
Invariants that appear correctly enforced. Boundaries that are explicit and well-guarded.

## Coverage Notes
What was covered. What wasn't. Where the blind spots are.

## Recommended Next Steps
Which additional lenses would produce the most value.
```

## Anti-patterns

| Failure mode | What to do instead |
|---|---|
| Spawning one worker for the whole codebase | Partition into scopes. 500-2000 LoC per worker. |
| Running only one lens per scope | Always run both lenses on each scope. The value is in the comparison. |
| Reading all percepts into context at once | Use the location index. Load only what you need for each step. |
| Skipping evidence curation | Curation builds the cross-lens index. Without it, contradiction detection has no input. |
| Iterating forever | Cap at 3 waves. Write the assessment with what you have. |
| Writing a vague assessment | Each finding must trace back to specific percepts with specific code locations. |
