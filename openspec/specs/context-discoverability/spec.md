<!-- Vendored from SC0RED/sc0red-standards@693d3f5.
     Do not edit here — fix it in the catalog and let the sync carry it. -->

## Purpose

Defines what a sc0red codebase must tell a reader who arrives with no prior knowledge.

Most agents work from a narrow window onto a large codebase. They cannot ask a colleague
what a module is for, and they will not infer a constraint that is written down somewhere
they never open. What is not discoverable from the code and its immediate surroundings
effectively does not exist, and the resulting change will be locally reasonable and
globally wrong.

These requirements make the context an agent needs reachable from where it is working.

Each requirement names how it is enforced.

## Requirements

### Requirement: Repository Map

The repository MUST carry a map naming each top-level module, the responsibility it
holds, and the spec that governs it. The map MUST be reachable from the repository root.

Enforcement: gated by a presence and coverage check.

#### Scenario: New top-level module absent from the map
- **GIVEN** A new top-level module added without a corresponding map entry
- **WHEN** The map check runs
- **THEN** It MUST exit non-zero and name the unmapped module

### Requirement: Module Orientation

A module above the project's configured file-count trigger MUST include a short README
stating its purpose in one sentence, its public API, the pattern it follows if any, and
any constraint a newcomer would otherwise violate.

Below the trigger, the file names are the orientation. The trigger is set per repository.

Enforcement: gated by a presence check; content quality is review-only.

#### Scenario: Module grows past the trigger without orientation
- **GIVEN** A module that now exceeds the configured file count and has no README
- **WHEN** The orientation check runs
- **THEN** It MUST exit non-zero and name the module

### Requirement: Invariants Documented at the Enforcement Point

A non-obvious invariant MUST be stated where it is enforced, not only in external
documentation. A reader modifying the enforcing code MUST encounter the reason without
having to know that a document exists.

Enforcement: review-only.

#### Scenario: Guard with no stated reason
- **GIVEN** A guard rejecting inputs above a threshold, with the reason recorded only in a design document
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — the constraint and its origin belong at the guard

### Requirement: Decision Records for Non-Obvious Choices

A choice a competent reader would question MUST carry a recorded rationale: what was
chosen, what was rejected, and what would change the answer. Without it, the next agent
re-litigates a settled question or silently reverses it.

Enforcement: review-only.

#### Scenario: Surprising choice with no rationale
- **GIVEN** A change adopting a slower approach where an obvious faster one exists
- **WHEN** The change is reviewed with no recorded reason
- **THEN** It MUST be rejected — record why the obvious approach was rejected

### Requirement: Agent Instruction File Is Bounded

The repository's agent instruction file MUST stay within the configured line budget and
MUST NOT restate anything a gate already enforces. Detail belongs in documentation the
file points to.

An instruction file that repeats mechanical rules trains readers to skim it, which
defeats the parts that only exist as instruction. The budget is set per repository.

Enforcement: gated on size; the duplication judgment is review-only.

#### Scenario: Instruction file exceeds its budget
- **GIVEN** An agent instruction file above the configured line budget
- **WHEN** The size check runs
- **THEN** It MUST exit non-zero

#### Scenario: Instruction file restates a gated rule
- **GIVEN** An instruction file listing forbidden constructs a linter already rejects
- **WHEN** The change is reviewed
- **THEN** The restatement MUST be removed and the gate cited instead

### Requirement: Machine-Readable Project Context

The repository MUST carry a machine-readable project context file supplying its stack,
constraints, and per-artifact rules to every planning request an agent makes.

Documentation an agent might read is weaker than context an agent always receives. This
requirement exists because the difference between those two is the difference between a
standard that holds and one that is merely written down.

Enforcement: gated by a presence and schema check.

#### Scenario: Repository has no project context file
- **GIVEN** A repository whose spec directory exists but which carries no project context file
- **WHEN** The context check runs
- **THEN** It MUST exit non-zero — the constraints reach the agent only by chance

#### Scenario: Context file present but empty
- **GIVEN** A project context file that parses but carries no context block
- **WHEN** The context check runs
- **THEN** It MUST exit non-zero — the file exists and carries nothing
