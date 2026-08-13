<!-- Vendored from SC0RED/sc0red-standards@764f0cd.
     Do not edit here — fix it in the catalog and let the sync carry it. -->

## Purpose

Defines how types carry guarantees through a sc0red codebase. The goal is that a value's
type tells you what has already been checked, so downstream code never re-validates and
never guesses.

Each requirement names how it is enforced.

## Requirements

### Requirement: Boundary Validation

External input MUST be validated exactly once, at the boundary where it enters the
system — request bodies, query parameters, environment variables, message payloads, and
third-party responses. Code inside that boundary MUST trust the validated value and MUST
NOT re-check it.

Enforcement: review-only.

#### Scenario: Internal code re-checks a validated value
- **GIVEN** A domain function that tests whether an already-validated identifier is non-empty
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — either the boundary failed to validate, or the check is dead

### Requirement: Parse, Don't Validate

Boundary validation MUST produce a type that makes the invalid state unrepresentable
downstream. Checking a value and passing along the original loose type is insufficient,
because the guarantee is then carried by convention rather than by the type.

Enforcement: review-only.

#### Scenario: Validation result is discarded
- **GIVEN** A handler that confirms a string is a well-formed email, then passes the plain string onward
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — validation MUST yield a distinct type the rest of the code accepts

### Requirement: No Escape-Hatch Types

The project's configured escape-hatch constructs MUST NOT appear outside the configured
allowlist. These are the constructs that silence the type system rather than satisfy it.

The specific constructs are set per repository, because what constitutes an escape hatch
is language-specific and the same invariant holds at different names.

Enforcement: gated.

#### Scenario: Escape hatch used outside the allowlist
- **GIVEN** Source code using a configured escape-hatch construct in a file not on the allowlist
- **WHEN** The check runs
- **THEN** It MUST exit non-zero, name the file and line, and the build MUST fail

### Requirement: Explicit Public Signatures

Every exported function MUST declare its return type. An inferred return type is not a
public contract: it changes silently when the implementation changes, so callers depend
on something nobody agreed to.

Enforcement: gated by the type checker in strict mode.

#### Scenario: Exported function relies on inference
- **GIVEN** An exported function with no declared return type
- **WHEN** The type checker runs in strict mode
- **THEN** It MUST report an error

### Requirement: Shared Types Are Declared

A type that crosses a module boundary MUST be named and defined in a dedicated location,
not declared inline at a use site. Structural types repeated at several call sites MUST
be replaced by one named definition.

Enforcement: review-only.

#### Scenario: Inline shape duplicated across modules
- **GIVEN** The same anonymous structure declared inline in three modules
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — one named type, defined once, imported by all three

### Requirement: No Suppression Comments

Suppression comments MUST NOT appear in the codebase — anything silencing a linter, type
checker, security scanner, or coverage requirement. A suppression converts a mechanical
guarantee back into prose, which is the failure mode this catalog exists to prevent.

Where a language genuinely requires an annotation to satisfy a framework, that exception
MUST be configured centrally, not written inline at the call site.

Enforcement: gated.

#### Scenario: Suppression comment committed
- **GIVEN** A file containing a linter-suppression comment
- **WHEN** The suppression check runs
- **THEN** It MUST exit non-zero and report the file and line

#### Scenario: Coverage suppression on an untested branch
- **GIVEN** A branch marked to be excluded from coverage measurement
- **WHEN** The suppression check runs
- **THEN** It MUST exit non-zero — the branch MUST be tested or deleted
