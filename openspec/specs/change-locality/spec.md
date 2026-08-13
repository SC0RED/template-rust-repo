<!-- Vendored from SC0RED/sc0red-standards@764f0cd.
     Do not edit here — fix it in the catalog and let the sync carry it. -->

## Purpose

Defines how a sc0red codebase stays workable as it is changed.

A codebase can satisfy every architectural rule and still be miserable to modify, because
the cost of a change is not how much code you write — it is how much you must understand
first, and how much else moves when you are done. These requirements bound that cost.
They are the ones that decide whether a change six months from now takes an hour or a
week.

Each requirement names how it is enforced.

## Requirements

### Requirement: Blast Radius Is Bounded

A single behavior change MUST be achievable within the project's configured module
budget. When one change requires coordinated edits across more modules than that, it is
evidence the seam is in the wrong place — the modules are not independent, they are
entangled.

The budget is set per repository, and it MUST be calibrated against that repository's
own history rather than chosen by intuition. A budget that fires on a quarter of real
commits is not a gate, it is noise, and people learn to raise it without reading it.
Measure the distribution first and set the budget where the tail begins.

Genuinely cross-cutting work — a rename, a dependency upgrade, a new lint — will exceed
any budget, and MUST do so as a stated exception rather than a silent habit.

Enforcement: gated by change-spread measurement against the base branch.

#### Scenario: Change spreads past the budget
- **GIVEN** A change touching more top-level modules than the configured budget
- **WHEN** The blast-radius check runs
- **THEN** It MUST exit non-zero and list the modules touched

#### Scenario: Cross-cutting change raises the budget deliberately
- **GIVEN** A dependency upgrade that necessarily touches every module
- **WHEN** The budget is raised in configuration with a stated reason
- **THEN** The check MUST pass — the breadth is now a recorded decision

### Requirement: Minimal Public Surface

A module MUST export only what its consumers use. Every export is a promise; an unused
export is a promise nobody asked for that still constrains refactoring.

Enforcement: review-only. No unused-export analyzer exists yet.

#### Scenario: Export with no consumers
- **GIVEN** A module exporting a type no other module imports
- **WHEN** The change is reviewed
- **THEN** The unused export MUST be removed

### Requirement: Compatible Seams

A change to a module's public surface MUST either preserve existing call sites or update
all of them within the same change. A partially migrated surface MUST NOT be committed,
because the intermediate state is one nobody designed and everybody has to reason about.

Enforcement: gated by the compiler or type checker where the language permits; otherwise
review-only.

#### Scenario: Signature changed, callers left behind
- **GIVEN** A change altering an exported signature and updating two of its five callers
- **WHEN** The build runs
- **THEN** It MUST fail on the three unmigrated callers

### Requirement: Reversible Migrations

A schema or data migration MUST state how to undo it, or state why it cannot be undone.
An irreversible migration is sometimes correct; an accidentally irreversible one turns a
bad deploy into an outage with no exit.

Enforcement: gated.

#### Scenario: Migration with no stated reversal
- **GIVEN** A migration file with neither a paired down-migration nor a stated waiver
- **WHEN** The migration check runs
- **THEN** It MUST exit non-zero and name the file

#### Scenario: Deliberately irreversible migration
- **GIVEN** A migration that drops a column, headed by a stated irreversibility note
- **WHEN** The migration check runs
- **THEN** It MUST pass — the one-way door is a recorded decision

### Requirement: No Action at a Distance

Behavior MUST NOT depend on global mutable state or on runtime patching of another
module's members. A caller MUST be able to predict what a function does from its inputs
and its declared dependencies.

Enforcement: review-only.

#### Scenario: Behavior switched by a global flag
- **GIVEN** A function whose result depends on a module-level variable set elsewhere at runtime
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — pass the value as an argument

### Requirement: No Import-Time Side Effects

Loading a module MUST NOT perform input or output, spawn background work, read the clock,
or mutate global state. Import-time effects make load order significant, and load order is
the hardest kind of dependency to see, because nothing in any signature mentions it.

Enforcement: gated.

#### Scenario: Module opens a connection at import
- **GIVEN** A module establishing a database connection at load time
- **WHEN** The import-effects check runs
- **THEN** It MUST exit non-zero — the connection belongs in an initializer the caller invokes
