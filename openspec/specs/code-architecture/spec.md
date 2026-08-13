<!-- Vendored from SC0RED/sc0red-standards@764f0cd.
     Do not edit here — fix it in the catalog and let the sync carry it. -->

## Purpose

Defines the structural shape every sc0red codebase must hold: where responsibility
lives, which direction dependencies run, and how modules present themselves to each
other. These are contracts about the codebase, not about any product it serves.

Each requirement names how it is enforced. "Gated" means a script or analyzer fails
the build. "Review-only" means nothing mechanical checks it — it shapes what gets
written and what a reviewer looks for, and it can be violated without anything
turning red. That distinction is stated so nobody mistakes an aspiration for a gate.

## Requirements

### Requirement: Layered Architecture

Code MUST separate boundary, orchestration, domain, and adapter concerns. Boundary code
handles transport and input validation. Orchestration sequences use cases. Domain holds
business rules and owns no external dependency. Adapters implement domain-defined
interfaces to reach databases, queues, and third-party services.

Separation is about which concern each piece of code holds, not about how many files or
modules it is spread across. A short handler whose rules are three lines does not need
four modules to hold them; splitting it produces ceremony, not architecture. The
requirement bites when a concern is in the wrong place, not when concerns share a file.

Enforcement: review-only.

#### Scenario: Transport handler contains business rules
- **GIVEN** A request handler that queries the database and applies eligibility rules inline
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — the rules belong in domain, the query behind an adapter

#### Scenario: Domain reaches for a client library
- **GIVEN** A domain module that imports an HTTP client to fetch a rate
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — domain declares an interface, an adapter implements it

#### Scenario: Trivial handler split into a module tree
- **GIVEN** A signup handler with two rules, restructured into six modules and a trait
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — the concerns were already separable within one file

### Requirement: Dependency Direction

Dependencies MUST point inward: boundary depends on orchestration, orchestration on
domain, domain on nothing outside itself. An adapter MUST depend on a domain-defined
interface rather than the domain depending on the adapter.

Enforcement: review-only. No import-graph analyzer exists yet; this becomes gated when
one is built.

#### Scenario: Inward-pointing import is rejected
- **GIVEN** A domain file importing from an adapter module
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected and the offending import named

### Requirement: No Circular Dependencies

The module import graph MUST be acyclic.

Enforcement: review-only. No import-graph analyzer exists yet.

#### Scenario: Two modules import each other
- **GIVEN** Module A imports from module B and module B imports from module A
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected and the cycle named

### Requirement: Module Public Surface

Each module MUST declare an explicit public API. Consumers MUST import only from that
declared surface, never from a module's internal files.

Enforcement: review-only. No import-graph analyzer exists yet.

#### Scenario: Consumer reaches past the public surface
- **GIVEN** Module A imports a helper directly from module B's internal file
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — B's public surface is the only supported entry

### Requirement: Bounded Responsibility

A type MUST NOT exceed the project's configured public-member budget, and a function
MUST NOT exceed its configured parameter budget. Additional parameters MUST be carried
in a named structure rather than appended to a signature.

The budgets themselves are not stated here. They are set per repository so a language
whose idioms differ can hold the same invariant at a different number.

Enforcement: gated by complexity and parameter-count analysis.

#### Scenario: Signature grows past the budget
- **GIVEN** A function taking one more positional parameter than the configured budget
- **WHEN** The analyzer runs
- **THEN** It MUST report a violation and the build MUST fail

### Requirement: Explicit Wiring

Configuration, dependency wiring, and control flow MUST be discoverable by reading the
code. Behavior MUST NOT depend on an undocumented naming convention, an implicit
registration side effect, or a value derived from a file path.

Enforcement: review-only.

#### Scenario: Behavior derived from an undocumented convention
- **GIVEN** A service that loads configuration from a path inferred from its class name
- **WHEN** An agent adds a new service
- **THEN** The convention is undiscoverable from the code and the change MUST be rejected

### Requirement: Side Effects at the Edge

Input and output MUST be confined to adapter layers — network calls, filesystem access,
database queries, clock reads, and randomness. Domain and orchestration code MUST
receive these as injected dependencies or resolved values.

Enforcement: review-only.

#### Scenario: Domain reads the clock
- **GIVEN** A domain function calling the system clock directly to decide expiry
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — the current time is an input, passed in by the caller

### Requirement: Single Responsibility Per File

Each source file MUST have one stated responsibility. File names MUST describe that
responsibility specifically. Generic names — `utils`, `helpers`, `common`, `misc` — MUST
NOT be used, because they accumulate unrelated code and no reader can predict contents.

Enforcement: gated by a naming check for generic names; the responsibility judgment is
review-only.

#### Scenario: Generic module name rejected
- **GIVEN** A new file named `utils` in the project's source directory
- **WHEN** The naming check runs
- **THEN** It MUST exit non-zero and name the offending file
