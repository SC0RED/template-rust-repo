# logging

Structured logging setup, built on `tracing`.

**Public API:** `LogConfig`, `LogFormat`, `init`, `request_span`, `LogInitError`.

**Patterns:**
- **Factory** — `init` builds the configured subscriber (JSON vs human) from `LogConfig`.
- **Singleton-state** — the global subscriber is installed exactly once via a `OnceLock`; repeat `init` calls are no-ops.

**Constraints:**
- Call `init` once at startup (`LogConfig::from_env()` reads `LOG_LEVEL`, `LOG_FORMAT`, `SERVICE_NAME`).
- Attach correlation IDs with `request_span(id).entered()` at a request/job boundary — do not thread the id through every function call.
