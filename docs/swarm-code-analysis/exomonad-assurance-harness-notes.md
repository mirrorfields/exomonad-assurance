
# AI-Swarm Harness for Open Source Vulnerability Assurance

## Working Draft

This document captures and tidies the ideas developed in discussion around building an AI-agent harness for **defensive vulnerability review and assurance** in open source code, with **ExoMonad** as the orchestration substrate.

The intended use is explicitly **blue-team** and **assurance-oriented**:

- audit open source projects we depend on
- improve system legibility
- identify ambiguous or weakly enforced trust assumptions
- report or fix issues responsibly
- generate remediation-oriented artifacts maintainers can use

This is **not** framed around exploit development, weaponization, or bounty-chasing. The operating goal is to make systems more understandable, more auditable, and easier to repair.

---

## 1. Core framing

The central idea is that vulnerability hunting in source code is not mainly a code-reading problem. It is a **search-under-uncertainty** problem.

What the harness is really doing is not merely reviewing code, but **collapsing uncertainty about where reality can diverge from intended behavior**.

That shift in framing matters because it changes the primary design question from:

> Where do we start reading?

into:

> What class of uncertainty are we trying to force into visibility?

This naturally leads to multiple review lenses rather than a single traversal strategy. A useful system should not have one master workflow. It should have a **portfolio of workflows**, each of which produces different evidence and fails in different ways.

### 1.1 The modern form of “many eyes”

The old open source adage that “given enough eyes, all bugs are shallow” is only useful under a stricter condition:

- the eyes must be **meaningfully different**
- they must produce outputs that can be compared and challenged
- there must be a way to turn observations into **verifiable claims**

A swarm of cheap models all reading code in the same way does not create many eyes. It creates one eye with many threads.

The real requirement is **epistemic diversity**:

- one worker maps attack surfaces
- another maps trust boundaries
- another extracts invariants
- another traces data transformations
- another infers state transitions
- another examines capability flow
- another looks for contradictions between all of the above

The expensive model is then not merely a manager. It becomes an **adjudicator of competing world models**.

---

## 2. Philosophical approaches to the task

The harness should not assume that vulnerability review begins from one canonical starting point. There are multiple valid entry strategies, and they correspond to different search strategies.

### 2.1 Attack-surface-first

This approach begins with everything that accepts input, influences control flow, crosses process boundaries, or mutates privileged state.

It asks:

> Where can the world touch the system?

This is highly effective for:

- services
- CLIs with file or network input
- daemons
- schedulers
- plug-in systems
- control planes
- parsers and processors

This lens tends to find high-value issues quickly because it biases toward externally reachable behavior.

Its weakness is that it can miss deep invariant violations that only become dangerous after internal composition.

The key is to classify surfaces not just by existence, but by semantics:

- input shape
- degree of attacker control
- normalization steps
- trust level on arrival
- downstream subsystems touched
- privileged effects reachable

### 2.2 Invariant-first

This approach starts from the opposite side. Rather than asking how data enters, it asks:

> What must never be false if this subsystem is to remain safe?

Examples of invariants include:

- identity remains bound to action
- authorization precedes mutation
- normalization precedes comparison
- parser output has one stable meaning
- tenant context is never dropped
- capability scope only narrows, never silently widens
- state transitions occur in valid order

This is especially useful for:

- authorization logic
- tenancy isolation
- policy engines
- caches
- distributed systems
- business logic
- systems with subtle correctness/security coupling

This approach is often more powerful than simple call-graph review because severe issues are often **violations of cross-module invariants**, not single bad lines of code.

It also explains why a “break the code into detailed specs” workflow is not adjacent to vulnerability review; it is often a prerequisite for it.

### 2.3 Data-flow-first

This is the semantic taint perspective.

It asks:

> How does meaning change as data moves?

This is not only about where bytes go. It is about where interpretation changes:

- parsing
- decoding
- deserialization
- normalization
- canonicalization
- schema conversion
- template expansion
- policy translation
- stringification and re-encoding
- path and URL handling
- identity and scope mapping

Many issues live in **semantic gaps**:

- one layer thinks the data means one thing
- the next layer thinks it means something slightly different
- one component sanitizes for one use, but the data is consumed in another

This approach is especially valuable where different subsystems assign different meanings to the same material.

### 2.4 State-machine-first

This approach treats time as a first-class review dimension.

It asks:

> What state transitions exist, what order is assumed, and what happens if the order slips?

This is the right lens for:

- race conditions
- TOCTOU-style issues
- stale authorization
- retries and replay
- partial rollback
- background jobs
- cache/source-of-truth divergence
- eventually consistent behavior that becomes temporarily unsafe

Many reviews stay too static. They understand values, but not timing. State-machine modeling corrects that.

### 2.5 Trust-boundary-first

This is more precise than attack-surface-first.

It asks:

> Where does responsibility transfer, and what assumptions are made at the handoff?

Examples include:

- unauthenticated → authenticated
- user-controlled → validated
- untrusted text → executable structure
- unsigned → signed
- local process → remote service
- parser → evaluator
- tenant scope → platform scope
- cache → source of authority

Many serious bugs are not mere input-validation failures. They are **boundary confusion**:

- the code assumes another layer already checked something
- a downstream component treats upstream material as more trustworthy than it is
- trust silently widens during transformation

### 2.6 Complexity / anomaly-first

This strategy focuses on code that is expensive to understand or likely to be under-specified.

Typical signals include:

- custom parsers
- compatibility layers
- migration code
- fallback paths
- error handling with many branches
- cache invalidation logic
- unsafe / FFI edges
- reflection / dynamic dispatch
- hand-rolled protocol logic
- tests that imply hidden invariants

This is less principled than other approaches, but very useful for triage. Complexity correlates imperfectly with risk, but often points to under-specified behavior.

### 2.7 Differential / contradiction-first

This is one of the most AI-native approaches.

The idea is not to trust one worker’s understanding. It is to ask multiple workers to produce **different partial descriptions of the same mechanism**, and then hunt for contradictions.

Examples:

- one worker writes the behavioral spec
- one extracts authorization assumptions
- one models state transitions
- one lists error paths
- one summarizes what the tests imply

The stronger model then asks:

> Which of these descriptions cannot all be true at once?

Vulnerabilities often reveal themselves as inconsistent narratives:

- docs imply a stronger guarantee than the code enforces
- an error path bypasses a check that nominal paths require
- a parser canonicalizes less than downstream consumers assume
- the test suite encodes a stronger invariant than the implementation actually provides

---

## 3. The central unit of work: claims, not summaries

A core design decision is that the terminal artifact produced by workers should not be free-form summary text. The useful unit is a **claim with evidence**.

Each worker should emit claims in a structured form:

- what the code appears to guarantee
- what evidence supports the claim
- what assumptions the claim depends on
- what scope was reviewed
- what remains unknown
- what might falsify the claim
- how security-relevant the claim is
- how confident the worker is

This leads naturally to a **claim ledger** or **claim graph** rather than a heap of prose.

That shift is crucial because vulnerabilities often appear when a claim fails under conditions nobody tracked explicitly. If assumptions remain implicit, they cannot be challenged systematically.

### 3.1 Why claims matter more than summaries

Summaries sound coherent even when their underlying evidence is weak.

Claims can be:

- compared
- falsified
- contradicted
- deduplicated
- routed for follow-up
- tied back to source spans

This makes the entire swarm more auditable.

---

## 4. Breadth workers vs depth workers

The swarm should be divided into two labor classes.

### 4.1 Breadth workers

These are the cheap models.

Their job is **coverage expansion**, not judgment. They:

- map modules
- enumerate surfaces
- infer subsystem purpose
- extract invariants
- trace flows
- model states
- identify hotspots

They should maximize recall and structured evidence.

### 4.2 Depth workers

This is the stronger model.

Its job is not line-by-line review. Its job is:

- adjudication
- contradiction analysis
- prioritization
- local and global synthesis
- task routing
- deciding where more depth is warranted

The expensive model’s comparative advantage is **global coherence over many partial views**.

It should ask questions like:

- what must be true for this subsystem to be safe?
- where is that enforced?
- which other subsystem relies on the same guarantee?
- do those subsystems define the guarantee differently?
- what path exists from attacker-influenced input to privileged effect under ambiguous interpretation?

---

## 5. The theorem-prover mental model

A useful mental model is that the system behaves like a theorem prover built from unreliable lemmas.

- cheap workers produce local lemmas (claims)
- some are correct
- some are vague
- some are subtly wrong
- the stronger model tries to assemble a coherent argument about safety
- contradictions point to false lemmas, missing premises, or broken assumptions

This is a better model than imagining the swarm as a pile of reviewers. It emphasizes:

- independent evidence
- explicit assumptions
- contradiction detection
- provenance
- conditional confidence rather than absolute confidence

---

## 6. The biggest failure mode: false coherence

The main risk with AI-agent review is not simply missing syntax-level bugs. It is generating a persuasive but incorrect story about the system.

Swarm architectures can make this worse if agreement is mistaken for truth.

Parallel agreement often reflects:

- common prompt bias
- shared traversal bias
- overfitting to obvious nominal flows
- workers inheriting the same mistaken assumptions

This means the system must be designed to **reward disagreement and challenge**.

Some workers should:

- argue that an invariant holds
- others should try to falsify it
- some should infer intent from docs and tests
- others should ignore those and infer behavior from code only

The design principle is:

> Do not only scale readers. Scale disagreement.

---

## 7. Assurance-oriented vs bounty-oriented systems

The intended use here is not bounty hunting or exploit-oriented triage. The harness is explicitly aimed at **open source assurance**.

That changes the objective function.

A bounty-oriented system tends to optimize for:

- producing plausible vulnerability claims quickly
- novelty
- external severity signaling

An assurance-oriented system should optimize for:

- spec quality
- evidence quality
- reproducibility
- repairability
- regression resistance
- maintainer usefulness

### 7.1 The assurance north star

A strong statement of the project’s ethos is:

> Use AI swarms to make open source systems legible enough that trust assumptions can be audited, challenged, and repaired.

This means the harness should produce value in at least three cases:

- a confirmed issue
- a high-risk ambiguity or under-specification
- positive evidence that an important invariant is correctly enforced

The third case matters. Good audits should strengthen confidence where appropriate, not merely emit alarms.

### 7.2 Fix-first review

A good assurance loop looks like this:

1. infer intended guarantees
2. locate ambiguous or weakly enforced guarantees
3. determine whether the ambiguity is security-relevant
4. express the smallest trustworthy repair
5. turn the repair into a regression barrier

This is a healthier pattern than speculative exploit theater.

### 7.3 Maintainer empathy

Every mature finding should be expressible as:

- the intended invariant
- the place where it is not fully enforced
- the practical consequence
- the smallest sensible remediation
- the regression test that should exist afterward

If the system cannot express a finding in that shape, the finding is not yet mature enough.

---

## 8. The worker-role / skill split

A critical design refinement is the separation between:

- **roles** that engage directly with source and emit findings
- **skills** that operate on findings, evidence, and task routing

### 8.1 Why roles 1–10 are worker roles

Roles 1–10 are **epistemic sensors**. They answer direct questions about the code:

- where the system is exposed
- what it appears to guarantee
- how trust changes
- how state changes
- what assumptions are visible
- where complexity concentrates

They are stable as worker identities.

### 8.2 Why roles 11–15 become skills

The later roles are **epistemic control functions**:

- contradiction analysis
- claim challenge
- evidence curation
- priority routing
- adjudication

These act on work product, not raw source.

They therefore fit better as **skills used by stronger models**, especially sub-agents coordinating their own scoped investigations.

This allows every sub-agent to become a local coordinator:

- spawn workers within its domain
- apply skills locally
- recurse when needed
- compress findings upward

That design supports very large codebases much better than a single central coordinator.

### 8.3 A design slogan

A useful shorthand for the architecture is:

> Roles observe. Skills transform. Sub-agents recurse.

---

## 9. The 10 analyst worker roles

These roles form the code-facing base layer.

### 9.1 Surface Cartographer

**Purpose**

Enumerate where the system can be influenced from outside or where privileged effects begin.

**Core question**

> What inputs, events, or external actors can influence control flow or privileged state?

**What it looks for**

- network handlers
- CLI entrypoints
- file readers
- env/config loaders
- job consumers
- schedulers
- plug-in hooks
- dynamic registration
- reflection or callback surfaces
- background workers with externally derived input
- admin or privileged paths

**Output focus**

- entrypoint
- input source
- attacker control level
- initial trust level
- downstream subsystems touched
- privileged effects reachable
- evidence and confidence

**Primary value**

Builds the system’s initial surface map.

**Failure mode**

Can become too syntactic and miss indirectly reachable or dynamically registered surfaces.

---

### 9.2 Trust Boundary Mapper

**Purpose**

Identify places where the system changes how much it trusts data, identity, metadata, or state.

**Core question**

> Where does responsibility transfer, and what assumptions are made at the handoff?

**What it looks for**

- unauthenticated → authenticated transitions
- unvalidated → validated transitions
- user space → service space
- local → remote handoff
- unsigned → signed transitions
- parser → executor transitions
- tenant scope → global scope shifts
- cache → authority transitions

**Output focus**

- boundary description
- upstream trust model
- downstream trust model
- explicit checks present
- checks assumed but not visible
- participating components
- risk notes and evidence

**Primary value**

Exposes where trust silently widens or handoff assumptions are ambiguous.

**Failure mode**

Can over-label ordinary calls as boundaries instead of focusing on true semantic transfers.

---

### 9.3 Spec Miner

**Purpose**

Infer subsystem contracts from code, types, tests, comments, configuration, and error behavior.

**Core question**

> If this subsystem had to be described as a contract, what would that contract say?

**What it looks for**

- subsystem purpose
- nominal inputs and outputs
- side effects
- preconditions
- postconditions
- error model
- stability assumptions
- hidden assumptions visible from tests or type constraints

**Output focus**

- subsystem purpose
- I/O and side effects
- preconditions and postconditions
- error semantics
- hidden assumptions
- evidence pointers

**Primary value**

Provides the substrate needed for invariant extraction and downstream contradiction analysis.

**Failure mode**

Can hallucinate intended behavior beyond what code and tests actually support.

---

### 9.4 Invariant Extractor

**Purpose**

Turn behavior and contracts into statements about what must always remain true for safety or correctness.

**Core question**

> What must never be false if this subsystem is to remain safe?

**What it looks for**

- identity/action binding
- auth-before-mutation guarantees
- monotonic state assumptions
- stable canonical form assumptions
- ownership or scope continuity
- tenant-context persistence
- ordering constraints
- consistency constraints across modules

**Output focus**

- invariant statement
- scope
- enforcement locations
- assumptions required
- likely break conditions
- missing enforcement candidates
- evidence pointers

**Primary value**

Produces the core safety model that later workers can challenge.

**Failure mode**

May focus on generic correctness invariants and miss security-relevant ones.

---

### 9.5 Data-Flow Tracer

**Purpose**

Follow trust-sensitive data through transformations, with emphasis on changes in meaning.

**Core question**

> How does attacker-influenced or trust-sensitive data change as it moves, and where can interpretation drift?

**What it looks for**

- sources
- intermediate transformations
- parser / decoder stages
- normalization and canonicalization
- policy translation
- ID / scope mapping
- sink behaviors
- privilege-relevant side effects

**Output focus**

- source
- transformations
- intermediate representations
- sinks
- validation observed
- meaning shifts
- evidence pointers

**Primary value**

Finds semantic gaps between producer assumptions and consumer assumptions.

**Failure mode**

May mechanically follow data while missing actual meaning changes.

---

### 9.6 State Machine Modeler

**Purpose**

Infer the meaningful states, transitions, timing assumptions, retries, and concurrency-sensitive behavior of the subsystem.

**Core question**

> What states exist, what transitions are allowed, and what happens if ordering breaks?

**What it looks for**

- explicit states
- implicit lifecycle phases
- guards and preconditions
- retry behavior
- replay behavior
- rollback behavior
- background concurrency
- stale state exposure
- cache coherence assumptions

**Output focus**

- states
- transitions
- guards
- temporal assumptions
- concurrent actors
- retry/replay notes
- evidence pointers

**Primary value**

Surfaces timing-sensitive and ordering-sensitive failure modes that static reading often misses.

**Failure mode**

May infer a cleaner state machine than the code truly implements.

---

### 9.7 Authorization / Capability Analyst

**Purpose**

Track how authority is created, proved, narrowed, widened, transferred, cached, or assumed.

**Core question**

> Where is authority established, and how does it move?

**What it looks for**

- authentication sources
- authorization decisions
- role and ownership checks
- delegation
- capability passing
- scope narrowing or widening
- service-to-service identity
- default/fallback behavior
- tenant binding

**Output focus**

- authority source
- proof mechanism
- scope and lifetime
- enforcement points
- implicit assumptions
- default and downgrade paths
- evidence pointers

**Primary value**

Makes authority flow visible rather than treating auth as isolated conditionals.

**Failure mode**

Can focus too much on explicit checks and miss authority implied by state, topology, or workflow.

---

### 9.8 Parser / Canonicalization Analyst

**Purpose**

Review interpretation logic: parsers, decoders, normalizers, adapters, and comparison rules.

**Core question**

> Can the same input mean different things at different layers?

**What it looks for**

- accepted variants
- canonical form rules
- lossy transformations
- ambiguous parsing
- path and URL normalization
- string vs structured representations
- downstream assumptions about format stability

**Output focus**

- parser / normalizer under review
- accepted variants
- canonical rules
- mismatch candidates across layers
- downstream assumptions
- ambiguous or lossy transforms
- evidence pointers

**Primary value**

Exposes interpretation defects that otherwise look like harmless format handling.

**Failure mode**

Can be too narrow if it only looks at designated parser modules and ignores ad hoc parsing elsewhere.

---

### 9.9 Dependency / Interop Analyst

**Purpose**

Inspect the semantics of library and system boundaries, not merely inventory dependencies.

**Core question**

> Where does this code rely on another component’s behavior more strongly than it realizes?

**What it looks for**

- SDK assumptions
- wrapper semantics
- serializer/deserializer boundaries
- FFI behavior
- cloud / API interaction assumptions
- persistence adapters
- queue semantics
- compatibility shims
- version drift assumptions

**Output focus**

- dependency boundary
- relied-on behavior
- explicit contract assumptions
- fallback behavior
- mismatch or drift candidates
- evidence pointers

**Primary value**

Finds risk where local code appears safe but depends on stronger external guarantees than are actually present.

**Failure mode**

Can collapse into dependency inventory rather than semantic interop review.

---

### 9.10 Hotspot Scout

**Purpose**

Act as triage. Find areas where understanding is expensive, under-specified, or full of exceptions.

**Core question**

> Where should the system spend more expensive reasoning next?

**What it looks for**

- unusual complexity
- custom parsing or protocol logic
- unsafe or FFI edges
- compatibility layers
- migration code
- fallback branches
- error handling with many special cases
- dynamic dispatch
- test suites implying hidden contracts

**Output focus**

- hotspot location
- signal type
- why it is suspicious
- recommended analyst roles to apply next
- evidence pointers

**Primary value**

Provides a suspicion map for routing deeper review.

**Failure mode**

High noise if complexity is mistaken for actual security relevance.

---

## 10. The skill layer for stronger models

These are the reasoning workflows used by more capable models, often at sub-agent level.

### 10.1 Contradiction Detection

**Purpose**

Identify claim sets that cannot all be true at once.

**Core question**

> Which outputs describe incompatible worlds?

**Responsibilities**

- distinguish genuine contradiction from abstraction mismatch
- identify evidence-quality asymmetry
- spot terminology drift that hides disagreement
- produce targeted follow-up questions

**Useful when**

- several workers examined the same subsystem from different perspectives
- local narratives look coherent but differ in assumptions
- docs/tests/types disagree with code behavior

**Must be true for the skill to be useful**

- worker output must preserve assumptions and evidence
- claims must be sufficiently explicit to compare
- scope boundaries must be known

**Failure mode**

False positives from comparing claims at incompatible abstraction levels.

---

### 10.2 Claim Challenge / Falsification

**Purpose**

Take a high-value claim and search for the minimal conditions under which it would fail.

**Core question**

> What would have to be true for this claim to break, and where might those conditions already exist?

**Responsibilities**

- target specific claims, not generic suspicion
- generate falsification conditions
- suggest precise follow-up workers or scopes
- downgrade confidence where evidence is thinner than claimed

**Useful when**

- a claim is central to the system’s safety model
- an invariant appears to be enforced everywhere
- one clean story has become too persuasive

**Must be true for the skill to be useful**

- claims must be well-scoped
- evidence must be inspectable
- the target claim must matter enough to justify challenge

**Failure mode**

Becoming ambient skepticism rather than targeted falsification.

---

### 10.3 Evidence Curation / Normalization

**Purpose**

Convert messy worker output into a structured, provenance-preserving claim graph.

**Core question**

> Can these findings be represented in a form that other reasoning layers can actually use?

**Responsibilities**

- normalize claim format
- separate claims from assumptions
- deduplicate near-identical findings
- preserve provenance and confidence
- record contradiction links
- preserve unresolved unknowns

**Useful when**

- multiple workers emit overlapping findings
- sub-agents need to report upward
- recursive investigations would otherwise pass prose blobs upward

**Must be true for the skill to be useful**

- output contracts must exist
- provenance must be available
- curation must preserve nuance, not erase it

**Failure mode**

Over-normalization that flattens meaningful differences.

---

### 10.4 Priority Routing

**Purpose**

Decide the best next use of attention and compute.

**Core question**

> Which uncertainty is both important and tractable enough to analyze next?

**Responsibilities**

- rank claim clusters by security relevance and ambiguity
- decide whether to recurse, re-check, escalate, or close
- choose which analyst roles to deploy next
- prevent “spawn more workers” from becoming the default response to uncertainty

**Useful when**

- a domain sub-agent has many possible follow-ups
- hotspots outnumber available analysis budget
- the investigation tree risks uncontrolled growth

**Must be true for the skill to be useful**

- findings must be scored or described with enough structure
- the cost of deeper analysis must be bounded
- scope must be clear enough to route well

**Failure mode**

Overweights flashy surface areas and underweights subtle invariant drift.

---

### 10.5 Domain Adjudication / Synthesis

**Purpose**

Produce a local domain verdict from a set of claims, contradictions, and unknowns.

**Core question**

> Given the current evidence, what does this domain actually appear to guarantee, and where is the uncertainty still meaningful?

**Responsibilities**

- separate supported findings from unresolved ambiguity
- identify likely false positives
- summarize the strongest local invariants and their weak points
- define what the parent agent should care about
- preserve contradiction and uncertainty markers in the compressed output

**Useful when**

- a sub-agent is preparing to report upward
- local analysis has produced many overlapping threads
- the investigation needs a scoped synthesis rather than more raw collection

**Must be true for the skill to be useful**

- enough evidence must exist to compare claims
- adjudication must not erase uncertainty for the sake of neatness
- local scope must be well-defined

**Failure mode**

Collapsing uncertainty too early because the narrative feels coherent.

---

### 10.6 Optional but likely valuable: Scope Partitioning

This did not start as a numbered role, but it emerged as a likely dedicated skill.

**Purpose**

Decide how a subsystem should be decomposed into child domains.

**Core question**

> What is the right axis of decomposition for this code: package, API family, trust boundary, stateful workflow, capability boundary, or semantic transformation chain?

**Responsibilities**

- partition a large domain into tractable child investigations
- avoid duplicate effort across children
- preserve cross-domain handoff points
- choose decomposition by security-relevant structure rather than file layout alone

**Failure mode**

Overfitting decomposition to the filesystem rather than to the security story.

---

## 11. Sub-agents as local coordinators

A major architectural decision is that coordination should not be centralized.

Each sub-agent should be able to:

- claim a domain
- spawn analyst workers within that domain
- apply skills locally
- recurse into child domains if needed
- compress findings into a structured package
- report upward without passing a wall of prose

This makes the system **self-similar** and scalable.

### 11.1 Why this matters for large codebases

Large codebases are not difficult merely because they contain many files. They are difficult because meaning is distributed unevenly:

- identity logic lives in one place
- policy logic in another
- parser assumptions in a third
- dangerous coupling in the glue code between them

A single coordinator gets overloaded because it must simultaneously do local reading and global reconciliation.

Sub-agents solve that by introducing **mid-level synthesis nodes**.

### 11.2 The decomposition pattern

A good recursive pattern is:

1. root coordinator identifies high-level domains
2. domain sub-agents spawn relevant analyst workers
3. domain sub-agents apply contradiction, curation, routing, and adjudication locally
4. domain sub-agents emit compressed evidence packages upward
5. the root compares domain outputs, finds cross-domain contradictions, and decides whether to recurse further

### 11.3 Security-relevant domain hierarchy over file hierarchy

The most effective decomposition is usually not directory structure.

Instead, domains should often be aligned to:

- input processing and normalization
- authorization and identity binding
- persistence and state transitions
- external dependency boundaries
- background job and retry semantics
- admin or control-plane paths
- parser families
- capability transitions

File/package hierarchy can be a starting heuristic, but the security story is usually orthogonal to the repo layout.

---

## 12. What must be true for infinite decomposition to remain useful

“Infinite decomposability” sounds attractive, but it only works if the information contracts are designed carefully.

### 12.1 Provenance must survive every layer

Every artifact should preserve:

- who made the claim
- what code span or symbol supports it
- under what assumptions the claim holds
- the scope that was reviewed
- how confident the worker is

If provenance is lost, the upper layers are reduced to trusting summaries.

### 12.2 Claims and assumptions must be first-class objects

Workers should not only exchange conclusions. They should exchange:

- claims
- assumptions
- unknowns
- evidence pointers
- follow-up suggestions

Otherwise the skill layer cannot challenge or reconcile anything rigorously.

### 12.3 Scoping rules must be strict

Every sub-agent needs a domain boundary that is explicit enough to:

- prevent duplication
- prevent orphaned handoffs
- define when escalation is appropriate
- make contradictions attributable to real cross-domain drift rather than scope confusion

### 12.4 Compression must be lossy in the right way

Compression is necessary, but only narrative should be lost.

The compressed form must retain:

- provenance
- assumptions
- contradictions
- unknowns
- confidence markers

The point is not to preserve every sentence. The point is to preserve **auditability**.

---

## 13. The three object types in the architecture

A clean extension to ExoMonad can be organized around three artifact classes.

### 13.1 Analyst Worker Spec

Defines:

- mission
- scope
- inputs
- evidence types the worker may produce
- required output schema
- common failure modes
- escalation hints

These correspond to the 10 analyst workers.

### 13.2 Reasoning Skill Spec

Defines:

- perspective
- triggering conditions
- prerequisites
- what must be true for the skill to be useful
- transformation steps
- required output shape
- common false-positive modes

These correspond to contradiction, challenge, curation, routing, adjudication, and possibly scope partitioning.

### 13.3 Sub-Agent Template

Defines:

- how a sub-agent claims a domain
- which analyst roles it uses first
- when it applies which skills
- when to recurse into child domains
- when to stop
- how it compresses and reports upward

This third object type is important. If roles and skills are defined but sub-agent behavior is implicit, mid-level coordination will become inconsistent.

---

## 14. Suggested minimal viable system

A sensible first iteration does not need all roles and all skills active at once.

### 14.1 Minimal worker-role set

The smallest useful analyst set is:

1. Surface Cartographer
2. Trust Boundary Mapper
3. Spec Miner
4. Invariant Extractor
5. Data-Flow Tracer
6. Contradiction-aware synthesis via stronger model
7. Adjudication via stronger model

However, since the architecture now cleanly separates workers from skills, the actual first complete analyst set can reasonably remain all 10.

### 14.2 Minimal skill set

The first skill pack should include:

- contradiction detection
- claim challenge / falsification
- evidence curation
- priority routing
- domain adjudication

Scope partitioning can be added early if decomposition quality turns out to be a bottleneck.

### 14.3 Minimal sub-agent templates

Two templates are sufficient for an early system:

#### Domain Investigator

Responsible for:

- a bounded subsystem or semantic domain
- spawning analyst workers
- applying skills locally
- escalating only compressed evidence upward

#### Cross-Domain Synthesizer

Responsible for:

- comparing outputs from multiple domain investigators
- identifying cross-domain contradiction
- surfacing boundary mismatch and invariant drift
- routing follow-up work where domain handoffs appear weak

This second template is disproportionately important because some of the most valuable findings will only emerge from comparing independently coherent domains.

---

## 15. Suggested output contract for workers and sub-agents

The output schema matters more than role wording. If outputs are not structurally comparable, contradiction and adjudication will not work.

A simple common envelope is:

```text
role
scope
question_being_answered
claims[]
assumptions[]
unknowns[]
confidence
evidence[]
suggested_followups[]
```

Each claim should be shaped roughly like:

```text
claim_id
statement
security_relevance
conditions
supporting_evidence
counter_evidence
confidence
```

This is intentionally simple. The important thing is that it preserves:

- explicit statement
- conditions of validity
- evidence
- contradictory evidence
- confidence
- downstream routing potential

---

## 16. Anti-patterns to avoid

### 16.1 A generic “security reviewer” worker

This sounds flexible but collapses role diversity. It becomes vague, redundant, and difficult to compare against specialized outputs.

### 16.2 Free-form summary as the primary artifact

Long prose is difficult to challenge, route, or adjudicate. Use claim structures first and prose second.

### 16.3 Full codebase coverage as the initial optimization target

The meaningful target is **security-relevant coverage**, not total coverage:

- surfaces
- boundaries
- invariants
- stateful workflows
- authority transitions

### 16.4 Letting the strongest model do all the reading

That wastes its comparative advantage. The stronger model should spend most of its effort on:

- synthesis
- challenge
- contradiction analysis
- prioritization
- cross-domain reasoning

### 16.5 Treating convergence as proof

Agreement is useful, but disagreement is more informative when the goal is trustworthy system understanding.

### 16.6 Recursive storytelling

If each layer only summarizes the layer below, the entire system becomes a polished hallucination stack.

Parents must receive not just conclusions but:

- assumptions
- unknowns
- contradiction notes
- provenance
- strongest evidence
- deferred questions

---

## 17. Blue-team terminal roles (downstream of mature findings)

The system discussed so far is the analyst and reasoning core. It should eventually feed terminal blue-team workflows that activate **only on mature claim clusters**.

These terminal roles should not be mixed into the early sensing stages.

### 17.1 Fix Candidate Synthesizer

**Purpose**

Propose the smallest trustworthy repairs that restore a violated invariant or remove a trust ambiguity.

**Focus**

- restore the invariant at the narrowest sensible boundary
- avoid widening blast radius
- preserve compatibility where possible
- decide whether the proper fix is code, validation, type change, API contract hardening, or documentation

### 17.2 Regression Test Designer

**Purpose**

Turn a mature finding into a reproducer and a future regression barrier.

**Focus**

- minimal repro shape
- correct assertion of expected behavior
- unit vs integration vs property test choice
- explicit preconditions and fixtures

### 17.3 Maintainer Brief Writer

**Purpose**

Produce a concise, respectful, reproducible report suitable for upstream maintainers.

**Focus**

- what appears wrong
- why it matters
- exact path or module involved
- how to reproduce or observe the issue
- what fix direction seems reasonable
- confidence and remaining unknowns

### 17.4 Architectural Hardening Recommender (later)

**Purpose**

Identify higher-level hardening opportunities where a one-off fix is insufficient.

**Focus**

- stronger invariants in types or schemas
- centralization of trust checks
- elimination of repeated parser logic
- removal of dangerous ambiguity across subsystems

---

## 18. Recommended project ethos and operating posture

This extension to ExoMonad should be framed as a system for **open source assurance**, not offensive research.

A concise expression of the ethos:

- code should be open enough to understand, audit, and improve
- trust assumptions should be visible rather than implicit
- ambiguity should be documented and challenged
- findings should become repairs, tests, and maintainable artifacts
- the harness should help improve the commons, not simply score discoveries

This ethos has direct architectural implications:

- emphasize contracts and invariants over novelty
- emphasize evidence over fluent narrative
- emphasize repairability over severity performance
- emphasize maintainers as the ultimate users of findings

---

## 19. Immediate implementation implications for ExoMonad

Because ExoMonad roles are defined in Haskell as a DSL for worker capabilities and instructions, the contract design needs to be very clear before implementation begins.

The hard part is not likely to be orchestration plumbing. The hard part is avoiding semantic drift in the role definitions.

The areas that need the most clarity up front are:

- role boundaries
- skill boundaries
- output schema
- confidence semantics
- scoping rules
- spawn criteria
- compression criteria
- provenance guarantees

If these contracts are crisp, the implementation becomes mostly engineering.

If these contracts are fuzzy, the system will be impressive-looking but difficult to trust.

### 19.1 Why this matters more in a DSL-backed role system

Once capabilities and instructions are encoded in a strongly-structured role DSL, changing conceptual boundaries later is expensive.

It is therefore worth arriving at implementation with:

- a settled role taxonomy
- explicit handoff rules
- clear task eligibility criteria
- shared output contracts
- known failure modes for each role and skill

In other words, this is one of the cases where architecture thinking first is not overdesign; it is risk reduction.

---

## 20. Suggested document and file set for the next phase

The next working artifacts should likely be:

### Templates

- `worker-spec-template.md`
- `skill-spec-template.md`
- `subagent-template.md`

### First filled examples

- `surface-cartographer.md`
- `contradiction-hunter-skill.md`
- `domain-investigator-template.md`

### Then the rest of the role pack

Analyst workers:

1. `surface-cartographer.md`
2. `trust-boundary-mapper.md`
3. `spec-miner.md`
4. `invariant-extractor.md`
5. `data-flow-tracer.md`
6. `state-machine-modeler.md`
7. `authorization-capability-analyst.md`
8. `parser-canonicalization-analyst.md`
9. `dependency-interop-analyst.md`
10. `hotspot-scout.md`

Skills:

1. `contradiction-detection.md`
2. `claim-challenge.md`
3. `evidence-curation.md`
4. `priority-routing.md`
5. `domain-adjudication.md`
6. `scope-partitioning.md` (optional early addition)

Sub-agent templates:

- `domain-investigator.md`
- `cross-domain-synthesizer.md`

Terminal blue-team roles (later phase):

- `fix-candidate-synthesizer.md`
- `regression-test-designer.md`
- `maintainer-brief-writer.md`
- `architectural-hardening-recommender.md`

---

## 21. Concluding design position

The emerging design is not simply “multi-agent code review.” It is a **claim engine for security-relevant system understanding**.

Its distinctive traits are:

- many differently-structured views rather than one repeated view
- roles for source-facing observation
- skills for evidence transformation and workflow control
- sub-agents that recurse locally rather than a single overloaded coordinator
- explicit support for contradiction, challenge, and uncertainty
- outputs designed for assurance, remediation, and maintainability

That is likely the right architecture for using a strong reasoning model to direct cheaper models over large open source codebases without losing the ability to explain, challenge, and repair what is found.

---

## 22. Short glossary of project language

For consistency while iterating, these terms can be used in a stable way:

### Claim
A structured statement about system behavior, invariants, or assumptions, with evidence and confidence.

### Assumption
A condition taken to be true for a claim to hold, but not fully demonstrated by the current evidence.

### Unknown
A material gap in evidence, scope, or interpretation.

### Evidence
Code spans, symbols, test behavior, configuration, types, comments, or structured outputs that support or challenge a claim.

### Role
A source-facing worker identity with a narrow question and a defined evidence/output contract.

### Skill
A reasoning workflow applied to findings rather than directly to raw source.

### Sub-agent
A scoped local coordinator that uses roles and skills to investigate a bounded domain.

### Domain
A subsystem, workflow, trust boundary cluster, or semantic area chosen as the scope of an investigation.

### Adjudication
The act of determining what the current evidence most strongly supports, what remains ambiguous, and what deserves further work.

### Assurance
Defensive review aimed at making trust assumptions legible, challengeable, and repairable.

---

## 23. Working principles checklist

Use this as a high-level design sanity check while implementing:

- roles should answer narrow code-facing questions
- skills should act on findings, not pretend to be roles
- every claim should have provenance
- assumptions and unknowns should never be hidden inside prose
- disagreement is a feature, not a defect
- the strongest model should spend most effort on synthesis and challenge
- decomposition should follow security-relevant structure, not just file layout
- compression should reduce narrative, not destroy evidence
- mature findings should terminate in fixes, tests, and maintainer-usable reports
- the system should be useful even when it finds ambiguity rather than a confirmed issue

---

## 24. Working one-line summary for the project (for internal use)

A swarm-based assurance system for open source code that uses specialized analyst workers, reasoning skills, and recursive sub-agents to extract, challenge, and repair security-relevant trust assumptions.
