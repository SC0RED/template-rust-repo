# Design Patterns Guide

Each pattern below is a worked, tested example in `src/`. Copy and adapt these
rather than inventing new structures — consistency is what keeps the codebase
legible to humans and agents alike. Don't introduce a pattern where a plain
function or struct will do.

| Pattern | Where | What it does |
|---------|-------|--------------|
| Template Method | `src/error/mod.rs` (`ErrorKind`) | Every error answers the same questions (`code`, `http_status`, `title`) through one interface; the kind supplies shared structure, each variant the specifics. |
| Registry | `src/error/mod.rs` (`ErrorKind::from_code`) | Reverse lookup from a wire code to its kind, driven by a single `ALL` source of truth. |
| Strategy | `src/util/retry.rs` (`RetryConfig`) | Parameterizes backoff (attempts, delays, growth) without changing the retry algorithm. |
| Decorator | `src/util/retry.rs` (`retry`) | Wraps any fallible operation, transparently adding retry behavior. |
| Factory | `src/logging/mod.rs` (`init`) | Builds the configured `tracing` subscriber (JSON vs human) from `LogConfig`. |
| Singleton-state | `src/logging/mod.rs` (`OnceLock`) | The global subscriber is installed exactly once; repeat `init` calls are no-ops. |
| Strategy + Registry | `src/strategies/signature/` | The **canonical structure** every strategy family copies: trait (`types`) + registry (register/get/reset) + one file per implementation + barrel + README. |

## The canonical Strategy + Registry structure

This is the load-bearing convention. `src/strategies/signature/` is the
reference; any new strategy family (routing, runners, auth, …) MUST follow the
same shape:

```
strategies/<family>/
  types.rs      # the trait — the Strategy interface
  registry.rs   # SomeRegistry with register / get / reset (owned, injectable)
  <impl>.rs     # one file per concrete strategy
  mod.rs        # barrel (pub use) + a default_registry() factory
  README.md     # purpose, public API, constraints
```

Adding a strategy is then exactly two steps — implement the trait in a new file,
register it — and **no other file changes**. The compiler enforces the trait
contract; the registry keeps lookup explicit (no global mutable state, no
convention-based auto-discovery).

## Error handling

Construct a `ServiceError` (`src/error/`) and let it propagate to a boundary
(handler, worker, job entry point); render it there with `into_problem_details()`
(RFC 7807). Do not catch-and-suppress in business logic — the only acceptable
catch is "add context and rethrow".
