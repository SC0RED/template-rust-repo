//! Sc0red Rust service template — library crate.
//!
//! The library holds all logic so it can be unit-tested; `main.rs` is a thin
//! binary that wires it up. Each module is a worked example of a pattern every
//! service reuses — copy and adapt rather than reinventing:
//!
//! - [`error`] — the error hierarchy (Template Method + Registry), RFC 7807.
//! - [`util`] — retry with backoff (Strategy + Decorator) and a TTL cache.
//! - [`logging`] — structured logging setup (Factory + Singleton-state).
//! - [`strategies`] — the canonical Strategy + Registry structure.

pub mod error;
pub mod logging;
pub mod strategies;
pub mod util;
