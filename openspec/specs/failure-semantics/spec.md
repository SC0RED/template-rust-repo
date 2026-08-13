<!-- Vendored from SC0RED/sc0red-standards@693d3f5.
     Do not edit here — fix it in the catalog and let the sync carry it. -->

## Purpose

Defines what a sc0red codebase does when something goes wrong. The organizing rule is
that a failure must reach a place where somebody can act on it. Code that quietly
substitutes a default for a failure is the most expensive habit in a codebase: the
system appears healthy, the caller cannot distinguish success from silence, and the
operator learns about it from a user.

Each requirement names how it is enforced. "Gated" means a script or analyzer fails the
build. "Review-only" means nothing mechanical checks it — it shapes what gets written
and what a reviewer looks for, and it can be violated without anything turning red.

## Requirements

### Requirement: Fail Fast

Code MUST NOT substitute a value when an internal invariant is violated. If a value that
should exist does not, the failure MUST travel to a boundary rather than be replaced by
a default, an empty collection, or a zero.

Failing fast means refusing to invent a value. It does **not** mean terminating the
process. Returning an error, propagating it, or raising to the nearest declared boundary
are all correct. Panicking, aborting, or unwrapping in library code are not — they take
the decision away from the caller who was in a position to make it.

This does not forbid defaults for genuinely optional external input. A missing optional
environment variable resolving to a documented default is correct: that is a boundary
reading absent input, not internal code hiding a broken invariant.

Enforcement: review-only.

#### Scenario: Internal lookup falls back to empty
- **GIVEN** Code that looks up a record it just created and substitutes an empty value if absent
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — the absence is an invariant violation and MUST surface as an error

#### Scenario: Failure converted into a process exit
- **GIVEN** A library function that panics rather than returning an error when parsing fails
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — return the error and let the boundary decide what to do

### Requirement: Error Boundaries Are Named

Errors MUST be absorbed only at boundaries declared in the project's configuration.
A boundary is a place with somewhere to report to and a decision to make: a request
handler, a queue consumer, a scheduled-job entry point, a top-level orchestrator.

Everywhere else, a failure MUST propagate.

Enforcement: gated.

#### Scenario: Error absorbed outside a declared boundary
- **GIVEN** A service function converting a failed call into a default value
- **WHEN** The error-boundary check runs
- **THEN** It MUST exit non-zero, name the file and line, and point at the boundary list

#### Scenario: New boundary is declared deliberately
- **GIVEN** A new queue consumer that must not crash the process on a poison message
- **WHEN** Its file is added to the configured boundary list with a stated reason
- **THEN** The check MUST pass — the absorption is now a recorded decision

### Requirement: No Silent Swallow

A caught error MUST be rethrown, logged with context, or converted into a typed failure
result. Discarding a caught error MUST NOT occur.

Enforcement: gated.

#### Scenario: Empty catch committed
- **GIVEN** A catch block with no body
- **WHEN** The analyzer runs
- **THEN** It MUST report a violation and the build MUST fail

### Requirement: Contextual Rethrow Is the Only Wrap

Catching an error to attach context and rethrowing MUST be accepted — the context being
the operation attempted and the identifier involved. Catching an error to substitute a
value, or to convert a failure into a success, MUST NOT.

Enforcement: review-only.

#### Scenario: Wrap adds context and rethrows
- **GIVEN** A function catching a failure, attaching the record identifier, and rethrowing
- **WHEN** The change is reviewed
- **THEN** It MUST be accepted

#### Scenario: Wrap converts failure into success
- **GIVEN** A function catching a failure and returning an empty collection
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — the caller cannot distinguish "none" from "broken"

### Requirement: Typed Error Taxonomy

An error crossing a **module boundary** MUST carry a machine-readable code, so callers
match on the code rather than on prose that changes with the wording.

This applies at module boundaries only. A helper returning a failure to its immediate
caller inside the same module does not need a taxonomy, and building one there trades a
few lines of working code for several times as many that say nothing new. Where the
language provides a conventional error type that already carries a machine-readable
kind, using it satisfies this requirement.

Enforcement: review-only.

#### Scenario: Caller branches on a message string
- **GIVEN** A caller comparing an error's text against a literal to decide whether to retry
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — the error MUST carry a code the caller can match

#### Scenario: Taxonomy built for a single internal helper
- **GIVEN** A ten-line module-private function given a bespoke error enum and code registry
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — the error does not cross a module boundary

### Requirement: Failure Paths Are Observable

Every declared error boundary MUST emit a record sufficient to diagnose the failure
without reproducing it: what was attempted, which entity was involved, and the underlying
cause. Correlation identity MUST propagate to that record without being threaded through
every intermediate signature.

Records MUST NOT contain regulated or personally identifying data. What is being
processed belongs in the record only as an identifier.

Enforcement: review-only.

#### Scenario: Boundary logs a bare failure
- **GIVEN** A request handler logging only that an operation failed
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — the record MUST identify the operation, the entity, and the cause

#### Scenario: Record carries regulated data
- **GIVEN** An error record embedding the full request body of a clinical message
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — reference the record by identifier instead
