<!-- Vendored from SC0RED/sc0red-standards@693d3f5.
     Do not edit here — fix it in the catalog and let the sync carry it. -->

## Purpose

Defines what a sc0red codebase refuses to accumulate.

Generated code fails in a characteristic way. It is rarely wrong on the happy path and
rarely ugly. It is *too much*: a near-copy of a function that already exists, an
interface with one implementation, a comment restating the line beneath it, a helper
nobody calls, a scope that quietly grew past what was asked. Each addition is defensible
alone. Together they produce a codebase where nobody can tell which of four similar
functions is the real one.

These requirements exist to make that accumulation visible while it is still one line.

Each requirement names how it is enforced.

## Requirements

### Requirement: No Duplicated Logic

Logic MUST NOT be copied into near-variants. Where two code paths differ only in values,
they MUST be one path taking those values as parameters. Where they differ in behavior,
the difference MUST be named rather than expressed as two similar bodies.

The similarity threshold is set per repository.

Enforcement: gated by duplication analysis.

#### Scenario: Near-copy exceeds the threshold
- **GIVEN** A new function differing from an existing one only in a literal value
- **WHEN** Duplication analysis runs
- **THEN** It MUST report the duplication and the build MUST fail

### Requirement: No Dead Code

Unreachable branches, unused exports, unreferenced files, and commented-out code MUST NOT
be committed. Deleted code is recoverable from history; code retained "in case" is a
permanent tax on every reader who must decide whether it matters.

Enforcement: gated.

#### Scenario: Unused export committed
- **GIVEN** A module exporting a function no code imports
- **WHEN** The dead-code check runs
- **THEN** It MUST report the unused export and the build MUST fail

#### Scenario: Commented-out block committed
- **GIVEN** A file containing a commented-out former implementation
- **WHEN** The analyzer runs
- **THEN** It MUST report it — history holds the old version

### Requirement: No Speculative Generality

An abstraction MUST have at least two current call sites. Interfaces, factories,
configuration hooks, and extension points MUST NOT be introduced for anticipated need.

The cost is asymmetric: collapsing a premature abstraction requires understanding every
call site, while introducing one later requires understanding only the code that exists.

Enforcement: review-only.

#### Scenario: Interface with a single implementation
- **GIVEN** A new interface with exactly one implementing type and one caller
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — call the concrete type until a second implementation exists

#### Scenario: Configuration hook nobody sets
- **GIVEN** A new setting whose value is never varied and has one default
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — inline the value

### Requirement: Scope Discipline

A change MUST NOT include work outside its stated intent. Unrelated refactors,
opportunistic renames, and drive-by reformatting MUST be separate changes, because
bundling them makes the intended change unreviewable.

Enforcement: review-only, assisted by change-size and file-spread reporting.

#### Scenario: Bug fix carries an unrelated refactor
- **GIVEN** A change whose stated intent is a one-line fix, also renaming symbols across four files
- **WHEN** The change is reviewed
- **THEN** It MUST be split — the fix reviewed on its own, the rename on its own

### Requirement: Comments Justify, Never Restate

A comment MUST explain why the code is as it is: the constraint that forced it, the
alternative rejected, the surprise a reader would otherwise hit. A comment restating what
the code already says MUST be removed — it duplicates the code and rots independently.

Enforcement: review-only.

#### Scenario: Comment restates the statement below it
- **GIVEN** A comment reading "increment the counter" above a counter increment
- **WHEN** The change is reviewed
- **THEN** It MUST be removed

#### Scenario: Comment records a non-obvious constraint
- **GIVEN** A comment explaining that a limit is imposed by an upstream API, with the limit named
- **WHEN** The change is reviewed
- **THEN** It MUST be kept

### Requirement: No Invented APIs

Every referenced symbol MUST resolve at build time. A plausible-looking call to a function
or field that does not exist MUST fail the build rather than reach review.

Enforcement: gated by the compiler or type checker.

#### Scenario: Reference to a nonexistent method
- **GIVEN** Code calling a method the target type does not define
- **WHEN** The build runs
- **THEN** It MUST fail and name the unresolved symbol

### Requirement: Configuration Has One Home

A tunable value MUST be defined once. Magic numbers, duplicated defaults, and the same
threshold restated at several call sites MUST NOT appear — they drift apart, and the
drift is invisible until behavior diverges.

Enforcement: gated by magic-number analysis where available; otherwise review-only.

#### Scenario: Same timeout repeated at call sites
- **GIVEN** The same timeout literal appearing in three call sites
- **WHEN** The analyzer runs
- **THEN** It MUST report the repetition — one named constant, referenced three times

### Requirement: Bounded File and Function Size

Files and functions MUST NOT exceed the project's configured budgets. When a file exceeds
its budget it MUST be split along a responsibility boundary, not at an arbitrary line.

The budgets are set per repository.

Enforcement: gated.

#### Scenario: File exceeds its budget
- **GIVEN** A source file above the configured line budget
- **WHEN** The size check runs
- **THEN** It MUST exit non-zero and name the file
