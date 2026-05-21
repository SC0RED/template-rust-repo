# error

The error hierarchy returned across the service.

**Public API:** `ServiceError`, `ErrorKind`, `ProblemDetails`, `ErrorContext`.

**Patterns:**
- **Template Method** — `ErrorKind::{code, http_status, title}` give every error one uniform interface; callers never match on specific variants to render a response.
- **Registry** — `ErrorKind::from_code` resolves a wire code back to its kind, driven by the single `ErrorKind::ALL` source of truth.

**Constraints:**
- Internal code constructs a `ServiceError` and lets it propagate to a boundary (handler / worker / job entry point). Do **not** catch-and-suppress in business logic — catch only to add context and rethrow.
- External responses use `into_problem_details()` (RFC 7807). Add a new error by adding a variant to `ErrorKind` plus its arm in each `match` — the compiler enforces exhaustiveness.
