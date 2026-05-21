//! Retry with exponential backoff and jitter.
//!
//! Two GoF patterns:
//! - **Strategy** — [`RetryConfig`] parameterizes the backoff (attempts, base
//!   and max delay, growth factor) without changing the retry algorithm.
//! - **Decorator** — [`retry`] wraps any fallible operation, transparently
//!   adding retry behavior around it.
//!
//! Jitter (±25%) spreads retries so a fleet of callers does not synchronize into
//! a thundering herd against a recovering dependency.

use std::thread::sleep;
use std::time::Duration;

use rand::Rng;

/// Backoff configuration — the Strategy that parameterizes [`retry`].
#[derive(Debug, Clone, Copy)]
pub struct RetryConfig {
    /// Maximum number of attempts, including the first. Must be at least 1.
    pub max_attempts: u32,
    /// Delay before the first retry; scaled exponentially thereafter.
    pub base_delay: Duration,
    /// Hard upper bound on any single delay (applied after jitter).
    pub max_delay: Duration,
    /// Exponential growth factor applied per attempt.
    pub multiplier: u32,
}

impl Default for RetryConfig {
    fn default() -> Self {
        Self {
            max_attempts: 3,
            base_delay: Duration::from_millis(100),
            max_delay: Duration::from_secs(10),
            multiplier: 2,
        }
    }
}

impl RetryConfig {
    /// Delay before the retry following `attempt` (0-indexed): the base delay
    /// scaled by `multiplier^attempt`, jittered ±25%, then hard-capped at
    /// `max_delay`.
    fn delay_for(self, attempt: u32) -> Duration {
        let base_ms = u64::try_from(self.base_delay.as_millis()).unwrap_or(u64::MAX);
        let cap_ms = u64::try_from(self.max_delay.as_millis()).unwrap_or(u64::MAX);
        let factor = u64::from(self.multiplier).saturating_pow(attempt);
        let scaled = base_ms.saturating_mul(factor).min(cap_ms);
        Duration::from_millis(apply_jitter(scaled).min(cap_ms))
    }
}

/// Spread a millisecond delay across ±25% of its value.
fn apply_jitter(delay_ms: u64) -> u64 {
    if delay_ms == 0 {
        return 0;
    }
    let span = delay_ms / 4;
    let offset = rand::rng().random_range(0..=span.saturating_mul(2));
    delay_ms.saturating_sub(span).saturating_add(offset)
}

/// Error returned when every retry attempt is exhausted, carrying the count and
/// the final underlying error.
#[derive(Debug, thiserror::Error)]
#[error("retry exhausted after {attempts} attempt(s): {source}")]
pub struct RetryExhausted<E>
where
    E: std::error::Error + 'static,
{
    /// The number of attempts made before giving up.
    pub attempts: u32,
    /// The error from the final attempt.
    #[source]
    pub source: E,
}

/// Run `operation`, retrying per `config` while `is_retryable` accepts the error.
///
/// Returns the first success. A non-retryable error returns immediately; once
/// `config.max_attempts` is reached the final error is wrapped in
/// [`RetryExhausted`].
///
/// # Errors
///
/// Returns [`RetryExhausted`] if the operation never succeeds within the
/// configured attempts, or fails with a non-retryable error.
pub fn retry<T, E, P, F>(
    config: RetryConfig,
    is_retryable: P,
    mut operation: F,
) -> Result<T, RetryExhausted<E>>
where
    E: std::error::Error + 'static,
    P: Fn(&E) -> bool,
    F: FnMut() -> Result<T, E>,
{
    let mut attempt: u32 = 0;
    loop {
        match operation() {
            Ok(value) => return Ok(value),
            Err(error) => {
                attempt = attempt.saturating_add(1);
                let exhausted = attempt >= config.max_attempts;
                if exhausted || !is_retryable(&error) {
                    return Err(RetryExhausted {
                        attempts: attempt,
                        source: error,
                    });
                }
                sleep(config.delay_for(attempt - 1));
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use std::cell::Cell;
    use std::time::Duration;

    use super::{retry, RetryConfig};

    #[derive(Debug, thiserror::Error)]
    #[error("boom")]
    struct Boom;

    fn instant_config(max_attempts: u32) -> RetryConfig {
        RetryConfig {
            max_attempts,
            base_delay: Duration::ZERO,
            max_delay: Duration::ZERO,
            multiplier: 2,
        }
    }

    #[test]
    fn returns_on_first_success() {
        let calls = Cell::new(0);
        let result: Result<u32, _> = retry(
            instant_config(3),
            |_: &Boom| true,
            || {
                calls.set(calls.get() + 1);
                Ok(7)
            },
        );
        assert_eq!(result.unwrap(), 7);
        assert_eq!(calls.get(), 1);
    }

    #[test]
    fn retries_then_succeeds() {
        let calls = Cell::new(0);
        let result: Result<u32, _> = retry(
            instant_config(5),
            |_| true,
            || {
                calls.set(calls.get() + 1);
                if calls.get() < 3 {
                    Err(Boom)
                } else {
                    Ok(42)
                }
            },
        );
        assert_eq!(result.unwrap(), 42);
        assert_eq!(calls.get(), 3);
    }

    #[test]
    fn non_retryable_error_stops_immediately() {
        let calls = Cell::new(0);
        let result = retry::<(), Boom, _, _>(
            instant_config(5),
            |_| false,
            || {
                calls.set(calls.get() + 1);
                Err(Boom)
            },
        );
        let exhausted = result.unwrap_err();
        assert_eq!(exhausted.attempts, 1);
        assert_eq!(calls.get(), 1);
    }

    #[test]
    fn gives_up_after_max_attempts() {
        let result = retry::<(), Boom, _, _>(instant_config(3), |_| true, || Err(Boom));
        assert_eq!(result.unwrap_err().attempts, 3);
    }

    #[test]
    fn delay_is_hard_capped_at_max_delay() {
        let config = RetryConfig {
            max_attempts: 20,
            base_delay: Duration::from_millis(100),
            max_delay: Duration::from_millis(200),
            multiplier: 2,
        };
        for attempt in 0..15 {
            assert!(config.delay_for(attempt) <= Duration::from_millis(200));
        }
    }

    #[test]
    fn zero_base_delay_yields_zero() {
        assert_eq!(instant_config(3).delay_for(5), Duration::ZERO);
    }

    #[test]
    fn default_config_is_sane() {
        let config = RetryConfig::default();
        assert_eq!(config.max_attempts, 3);
        assert_eq!(config.multiplier, 2);
        assert!(config.base_delay <= config.max_delay);
    }
}
