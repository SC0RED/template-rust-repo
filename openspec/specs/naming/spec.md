<!-- Vendored from SC0RED/sc0red-standards@693d3f5.
     Do not edit here — fix it in the catalog and let the sync carry it. -->

## Purpose

Defines how things are named in a sc0red codebase.

Naming is the cheapest documentation there is and the only kind that arrives at the point
of use. A reader who must open a definition to learn what a value holds has already paid
more than a good name would have cost.

These requirements state the invariants. The specific case conventions and forbidden
words are set per repository, because a rule that fights a language's idioms produces
noise, and noise trains people to route around the gate.

Each requirement names how it is enforced.

## Requirements

### Requirement: Case Conventions

Identifiers MUST follow the project's configured case conventions for their kind: types,
functions, constants, variables, and files.

Where a language's compiler or formatter already enforces a convention mechanically, the
project MUST rely on that rather than reimplementing the check.

Enforcement: gated.

#### Scenario: Identifier violates the configured convention
- **GIVEN** A declaration whose casing does not match the convention for its kind
- **WHEN** The naming check runs
- **THEN** It MUST exit non-zero and name the identifier

### Requirement: Intention-Revealing Names

A name MUST state what the thing is or does, without reference to its implementation or
its type. Names that describe storage rather than meaning MUST NOT be used.

This replaces any blanket rule requiring a fixed prefix. A mandatory verb prefix fights
languages whose accessors are idiomatically named for the field they return, and a rule
that must be suppressed to write idiomatic code is a rule that has stopped working.

Enforcement: review-only.

#### Scenario: Name describes storage rather than meaning
- **GIVEN** A value named for its container rather than its contents
- **WHEN** The change is reviewed
- **THEN** It MUST be renamed to state what it holds

#### Scenario: Idiomatic accessor without a verb prefix
- **GIVEN** An accessor named for the field it returns, following the language's convention
- **WHEN** The change is reviewed
- **THEN** It MUST be accepted — the name already states what it yields

### Requirement: Forbidden Abbreviations

Identifiers MUST NOT use abbreviations from the project's configured list. The list MUST
exclude tokens that collide with the language's keywords or idioms.

Enforcement: gated.

#### Scenario: Forbidden abbreviation introduced
- **GIVEN** A declaration using an identifier on the configured list
- **WHEN** The abbreviation check runs
- **THEN** It MUST exit non-zero and report the suggested full word

#### Scenario: Language-colliding token is not on the list
- **GIVEN** A token that is a keyword or established idiom in the project's language
- **WHEN** The configured list is reviewed
- **THEN** That token MUST NOT appear on it

### Requirement: No Generic Module Names

Module and file names MUST describe a specific responsibility. `utils`, `helpers`,
`common`, `misc`, and equivalents MUST NOT be used — they name a location rather than a
responsibility, so they accumulate whatever had nowhere else to go.

Enforcement: gated.

#### Scenario: Generic module name introduced
- **GIVEN** A new file named with a generic term
- **WHEN** The naming check runs
- **THEN** It MUST exit non-zero and name the file

### Requirement: Names Encode Constraint

Where a value carries an invariant, the name MUST carry it too — a unit, a currency, a
scale, a validation state, a trust level. A bare name invites a caller to supply a value
that is the right type and the wrong thing.

Enforcement: review-only.

#### Scenario: Value with an implicit unit
- **GIVEN** A parameter named for a duration with no unit in the name or the type
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — the unit MUST appear in the name or be carried by the type

#### Scenario: Value with an implicit trust level
- **GIVEN** A parameter holding unvalidated external input named identically to its validated form
- **WHEN** The change is reviewed
- **THEN** It MUST be rejected — the name MUST distinguish validated from raw
