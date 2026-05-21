//! Shared, dependency-light utilities.
//!
//! - [`retry`] — exponential backoff with jitter (Strategy + Decorator).
//! - [`ttl_cache`] — a time-to-live cache with eviction and statistics.

pub mod retry;
pub mod ttl_cache;
