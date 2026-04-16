# PoC Validation Plan

## Target CWEs

### Primary: CWE-918 (SSRF)

The quintessential trust boundary confusion. External surface (URL-accepting input) meets internal trust assumption (internal services unreachable). Requires seeing both simultaneously.

**What the contradiction looks like:**
- Surface Cartographer: finds user-controlled URL input that the server fetches
- Trust Boundary Mapper: finds internal service calls assuming only trusted callers
- Cross-lens signal: unprotected URL input + assumption that internal network is safe

### Secondary: CWE-862 (Missing Authorization)

Where authorization is assumed but not enforced. Surface (reachable actions) meets boundary (assumed auth).

**What the contradiction looks like:**
- Surface Cartographer: maps CRUD endpoints, some with authorization middleware, some without
- Trust Boundary Mapper: finds handler code assuming the caller is authorized
- Cross-lens signal: unprotected endpoint + assumption of authorization

## Why these CWEs

Both require cross-module reasoning — the bug is never in one function. Both produce strong signal from exactly the two lenses we have (surface cartographer + trust boundary mapper). Both are common enough to find good CVE targets in open source.

## Why NOT these CWEs for the PoC

| CWE | Reason |
|-----|--------|
| CWE-89 (SQLi), CWE-79 (XSS) | Too pattern-matchable. Single-function bugs. Don't test cross-lens comparison. |
| CWE-502 (Deserialization) | Often lives in libraries, not application code. May need dependency/interop lens. |
| CWE-362 (TOCTOU) | Needs state machine modeler lens, which we don't have yet. |
| CWE-400 (Resource Exhaustion) | Not a trust boundary problem. Wrong architecture for this PoC. |

## Target selection criteria

Look for CVEs in projects that are:
- **Open source** with publicly disclosed details
- **Non-trivial** (>5k LoC) so there's real cross-module reasoning
- **Written in a language where trust boundaries are visible** — Go, Rust, Python preferred. Heavily-frameworked Java/Spring abstracts the boundary away.
- **The vulnerability requires connecting observations across modules**, not a trivial pattern match at a single call site

## Pass/fail criterion

The TL's findings should point toward the known vulnerability's **neighborhood** — not necessarily the exact bug, but the right area of concern. If the cross-lens comparison identifies the module/subsystem where the vulnerability lives and describes the trust gap, the PoC succeeds.

## Workflow

1. Find a suitable CVE (CWE-918 or CWE-862) in an open source project
2. Clone the vulnerable version (pre-fix commit)
3. Run `exomonad init` in the target project
4. TL loads `tl-analysis-orchestration` skill
5. Execute the 7-phase workflow:
   - Phase 1: Map codebase
   - Phase 2: Scope partitioning
   - Phase 3: Spawn both lenses per scope
   - Phase 4: Evidence curation
   - Phase 5: Contradiction detection
   - Phase 6: Iterate (max 3 waves)
   - Phase 7: Assessment
6. Compare assessment against known CVE details
7. Document what worked, what didn't, what the lenses missed
