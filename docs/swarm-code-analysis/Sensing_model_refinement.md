# The Sensing Model: A Refinement of the Worker Architecture

## Working notes — April 2026

This document captures a key architectural refinement to the AI-Swarm Harness concept proposal. The core insight is that cheap models in the swarm should be treated as **senses**, not as workers or sub-agents. This changes the intermediate representation, the division of labor, and the economics of the entire system.

---

## 1. The problem with the "claim" model

The original proposal framed the terminal artifact of cheap-model work as a **claim with evidence** — a structured assertion about system behavior, with confidence, assumptions, and supporting code spans. Claims are propositional: "X is true of this system."

The problem is that claims require a level of epistemic commitment and confidence calibration that cheap models don't reliably produce. Forcing claim structure at the perception layer creates two failure modes:

- **Over-commitment**: the model states something precise it doesn't actually have evidence for, because the format demands a definite assertion.
- **Under-commitment**: the model hedges the claim into unfalsifiability, because it correctly senses its own uncertainty but has no way to express "I noticed something" without asserting what it means.

Code reading — especially by cheap models under narrow instructions — produces something **pre-propositional**. You notice a shape, a tension, an anomaly, before you can articulate what's true or false about it. The intermediate representation should reflect that.

---

## 2. Senses, not workers

The reframing: cheap models are **extensions of the synthesizing model's mind**. They are perceptual organs, not independent reviewers.

An eye doesn't assert "there is a threat." It produces structured visual data that a brain interprets. Similarly, a perception-tier model doesn't need to conclude anything. It needs to report what it perceives, through a specific perceptual lens, in a form useful to the reasoning layer above.

This is liberating because it stops asking cheap models to do something they're bad at (epistemic commitment, security judgment, confidence calibration) and instead asks them to do something they're good at (structured extraction, pattern matching, exhaustive enumeration under clear instructions).

### What changes

- The 10 analyst roles remain as **perceptual lenses** — they define what to look at and how, not what to conclude.
- The output format shifts from claims to **percepts** — structured observations with no obligation to interpret their own significance.
- The claim is no longer a worker output. It becomes a **synthesis-layer construct**, produced only by models strong enough to commit to one.
- The skill layer (contradiction detection, challenge, adjudication) operates on claims that were synthesized from percepts, not on raw worker assertions.

### The new flow

1. **Perception tier** produces percepts (structured observations through specific lenses).
2. **Reasoning tier** synthesizes percepts into claims (propositional assertions with evidence and conditions).
3. **Judgment tier** challenges, adjudicates, and routes claims.

The linchpin moves from the worker output to the synthesis step.

---

## 3. What a percept looks like

A percept is a structured observation anchored to code, produced through a specific perceptual lens, with no confidence score and no security relevance rating. Tentative structure:

```
lens:          which sense produced this (surface cartographer, trust boundary mapper, etc.)
location:      code span, symbol, module, flow
observation:   what was perceived, descriptively
context:       what's adjacent, what transformation is happening, what's upstream/downstream
texture:       simple/complex, familiar/unusual, consistent/anomalous relative to surroundings
open_edges:    what this observation connects to that wasn't in scope
```

No confidence. No security relevance rating. No "claim." Just structured perception with enough context to be useful to something smarter.

### Alternative intermediate representations considered

Several other formats were evaluated before settling on percepts:

- **Observations** (descriptive reports) — close to percepts but less structured; harder to route and compare across lenses.
- **Annotations** (code-anchored labels with context) — great for spatial reasoning and tooling, but fragment easily and resist synthesis.
- **Questions** (interrogative: "does this invariant hold across retries?") — natural to produce, but push all assertive work to the skill layer which may lack sufficient context.
- **Constraints** (declarative: "for safety, X must hold") — interesting because they separate the "what should be" model from the "what is" model, but require more judgment than cheap models should be asked for.
- **Tensions** (relational: "these two things pull against each other") — often what skilled reviewers notice first, but hard to standardize.

Percepts subsume most of these. An observation is a percept without the lens metadata. A tension is a percept whose texture field says "anomalous." A question is a natural downstream artifact of percept synthesis. The percept format is designed to be the lowest-commitment, highest-utility representation that still supports structured reasoning above.

---

## 4. The three-tier model architecture

The sensing model leads naturally to a three-tier architecture where different model providers are used at each tier, matched to the cognitive demands and cost profile of each layer.

### Perception tier

**Models**: Gemini Flash or equivalent cheap, fast models.

**Role**: Read code through a specific lens. Emit percepts. Run many passes, possibly redundantly across the same code with different lenses. Cost per pass is negligible.

**What's needed**: Good instruction-following, structured extraction, pattern matching. Not deep reasoning.

### Reasoning tier

**Models**: GLM-5.1 or similar mid-range models with strong multi-step reasoning.

**Role**: Receive percept bundles from a domain. Apply the skill layer — contradiction detection, synthesis, challenge, adjudication. Produce structured intermediate findings. This requires sustained coherent reasoning over structured input, not raw code reading.

**Why GLM-5.1 is interesting here**: zAI claims low drift in multi-step reasoning. If true, this is exactly the tier where that property matters most — the skills require holding a coherent analytical frame across many structured inputs. Also extremely cheap at current pricing.

**Key risk**: The "low drift" claim needs empirical validation on this specific task. Benchmarks test different things than sustained synthesis over messy percept bundles.

### Judgment tier

**Models**: Opus or equivalent frontier model.

**Role**: The root mind. Sees compressed, pre-structured, already-challenged output from the reasoning tier. Makes final calls on cross-domain contradictions, priority, and architectural-level findings. Touches raw code only when something specific needs verification. Most of its effort goes to synthesis, challenge, and cross-domain reasoning.

### The cost arbitrage argument

This architecture is a direct response to the brute-force approach (e.g., running a massive SOTA model for thousands of iterations over raw code). Instead of paying frontier-model cost for perception, you pay:

- Near-zero cost for ten Gemini perception passes
- Low cost for two or three GLM-5.1 synthesis passes
- Moderate cost for one Opus judgment pass

The hypothesis: if the intermediate representations are good, the Opus judgment pass is *more effective* than a raw Opus code-reading pass, because it operates on pre-structured, multi-angle, already-partially-synthesized input.

Perception scales cheaper than cognition. That's the bet.

---

## 5. ExoMonad implementation implications

ExoMonad operates at the CLI tool level — agents are spawned by opening tmux tabs and executing the relevant CLI tool (gemini-cli, Claude Code pointed at a different API, etc.). The MCP tool surface provides steering and communication. This means:

- Adding a new model provider is just "run a different binary with the right API key."
- No SDK integration, no provider-specific API wrappers.
- The abstraction boundary is the terminal session plus MCP tools, and that's provider-agnostic by nature.
- A GLM-5.1 reasoning agent is just Claude Code pointed at the zAI API, spawned in a tmux pane, with the same MCP tool surface.

The real work is therefore not infrastructure — it's the **instruction and contract layer**:

- Perception-tier agents need system prompts that say "you are a sense, here is your lens, emit percepts in this shape."
- Reasoning-tier agents need system prompts that say "you receive percept bundles, apply these analytical skills, emit findings in this shape."
- The judgment-tier TL needs to know what it's looking at and what decisions are in its scope.

The percept and finding schemas need to be robust enough that provider-specific behavioral differences don't corrupt the intermediate representations.

---

## 6. Validation approach

The cheapest useful experiment:

1. Pick a known-vulnerable open source component with a disclosed CVE — something where the vulnerability requires connecting observations across modules (trust boundary confusion, invariant violation through composition), not a trivial pattern match.
2. Run the perception tier against it with three or four lenses.
3. Feed the percepts to a GLM-5.1 reasoning agent. See whether the synthesized output points toward the known issue or the right neighborhood.
4. Run the same percepts through Opus as the reasoning tier and compare.

This directly tests whether GLM-5.1 holds up at the mid-tier, and whether the perception-reasoning split produces useful signal. Cost is minimal.

---

## 7. Relationship to the existing proposal

This document refines but does not replace the concept proposal. Specifically:

- The **10 analyst roles** remain intact as perceptual lenses. Their "what it looks for" and "core question" sections are essentially sense instructions.
- The **5 skills** (contradiction detection, claim challenge, evidence curation, priority routing, domain adjudication) remain intact but now operate on claims synthesized from percepts, not on raw worker assertions.
- The **sub-agent architecture** remains intact. Sub-agents are local synthesizing minds that perceive through workers and reason through skills.
- The **output contract** changes. Workers emit percepts, not claims. Claims are constructed at the reasoning tier. The claim schema from Section 15 of the original proposal applies to the reasoning tier's output, not to worker output.
- The **anti-patterns** section gains a new entry: "Asking perception-tier models to make epistemic commitments they can't reliably calibrate."

The design slogan from the original proposal updates from:

> Roles observe. Skills transform. Sub-agents recurse.

to:

> Senses perceive. Synthesis commits. Skills challenge. Sub-agents recurse.

---

## 8. Open questions

- **Percept schema stability**: The proposed percept structure is tentative. It needs iteration against real code to find the right level of structure — too rigid and it forces artificial uniformity across lenses, too loose and synthesis can't operate on it.
- **Cross-lens percept correlation**: How does the reasoning tier match percepts from different lenses that refer to the same code but describe different aspects? Location anchoring helps, but semantic correlation across lenses is a harder problem.
- **Perception noise vs. signal**: If cheap models produce noisy percepts, does the multi-lens design genuinely compensate, or do systematic biases (shared training data, similar failure modes across providers) create correlated blind spots?
- **GLM-5.1 empirical validation**: The mid-tier reasoning hypothesis is untested. Needs the controlled experiment described in Section 6.
- **Percept volume management**: Ten lenses across a large codebase produce a lot of percepts. The reasoning tier needs strategies for batching, prioritizing, and discarding low-information percepts without losing signal.
