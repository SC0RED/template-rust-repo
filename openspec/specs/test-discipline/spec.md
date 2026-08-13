<!-- Vendored from SC0RED/sc0red-standards@764f0cd.
     Do not edit here — fix it in the catalog and let the sync carry it. -->

## Purpose

Defines what a sc0red test suite is for.

A suite can hold high coverage and still tell you nothing, because it asserts how the code
is built rather than what it does. Such a suite fails on every refactor and passes through
every real defect — the worst of both, since it costs maintenance and buys no confidence.

These requirements aim the suite at behavior, and at the branches that run on the worst
day rather than the ones that run on every request.

Each requirement names how it is enforced.

## Requirements

### Requirement: Tests Assert Behavior

Tests MUST exercise a module's public surface and assert observable outcomes. Assertions
against private structure — internal fields, call ordering, the number of times a
collaborator was invoked — MUST NOT be made, because they encode the current
implementation as if it were the requirement.

Enforcement: gated on assertion presence; the behavior judgment is review-only.

#### Scenario: Test asserts an internal call count
- **GIVEN** A test asserting a private collaborator was called exactly twice
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — assert the outcome the caller observes

#### Scenario: Test with no assertions
- **GIVEN** A test that executes code and asserts nothing
- **WHEN** The analyzer runs
- **THEN** It MUST report the missing assertion

### Requirement: Bounded Mocking

Only process-external dependencies MAY be mocked, and in-process collaborators MUST be
exercised directly. External means network clients, clocks, filesystems, and third-party
services.

Mocking a collaborator you own couples the test to the shape of the code, so the test
passes while the integration between the two is broken.

Enforcement: gated against a configured allowlist of mockable dependencies.

#### Scenario: In-process collaborator mocked
- **GIVEN** A test mocking a domain service defined in the same codebase
- **WHEN** The mocking check runs
- **THEN** It MUST exit non-zero — exercise the real collaborator

### Requirement: Tests Are Documentation

A test name MUST state the case under test in terms of behavior. A reader MUST be able to
derive what the system does from the suite alone, without reading the implementation.

Enforcement: review-only.

#### Scenario: Uninformative test name
- **GIVEN** A test named for the function it calls rather than the case it covers
- **WHEN** The change is reviewed
- **THEN** It MUST be renamed to state the condition and the expected outcome

### Requirement: Failure Cases Are Covered

Every declared error boundary and every stated invariant MUST have a test that violates
it and asserts the resulting behavior. Files defining failure behavior MUST meet the
project's configured failure-path coverage bar, which is higher than the repository-wide
bar.

Repository-wide coverage averages error paths away: the happy path is easy to cover, so a
comfortable overall number can sit on top of error handling that has never once executed.

Enforcement: gated.

#### Scenario: Error-defining file below the failure-path bar
- **GIVEN** A file declaring typed errors whose coverage is under the configured bar
- **WHEN** The failure-coverage check runs
- **THEN** It MUST exit non-zero and report the file and its percentage

#### Scenario: Invariant with no violating test
- **GIVEN** A guard rejecting an out-of-range input, with tests covering only valid inputs
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — add a test that trips the guard

### Requirement: Coverage Threshold

The project's configured coverage threshold MUST gate the test command with a non-zero
exit. Paths excluded from measurement MUST be listed in configuration with a reason, not
excluded by annotations at the source.

The threshold and its exclusions are set per repository.

Enforcement: gated.

#### Scenario: Coverage falls below the threshold
- **GIVEN** A test run measuring below the configured threshold
- **WHEN** The test command completes
- **THEN** It MUST exit non-zero

### Requirement: Deterministic Tests

Tests MUST NOT depend on wall-clock time, network availability, execution order, or
unseeded randomness. A test that fails intermittently is worse than no test: it trains
everyone to re-run rather than investigate, and it hides the real failure it eventually
catches.

Enforcement: review-only. No repeat-run harness exists yet; this becomes gated when one
is built.

#### Scenario: Test depends on execution order
- **GIVEN** A test that passes in suite order and fails when run alone
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected as order-dependent

#### Scenario: Test reads the system clock
- **GIVEN** A test asserting behavior that changes with the current date
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — the clock MUST be injected

### Requirement: No Test-Only Production Seams

Production code MUST NOT branch on whether it is under test. A test-environment check in a
production path means the thing deployed is not the thing verified.

Enforcement: gated.

#### Scenario: Production path branches on test state
- **GIVEN** Production code taking a different path when a test flag is set
- **WHEN** The test-seam check runs
- **THEN** It MUST exit non-zero — inject the dependency the test needs to vary
