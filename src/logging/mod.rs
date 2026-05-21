//! Structured logging.
//!
//! Two GoF patterns:
//! - **Factory** — [`init`] builds the configured `tracing` subscriber from a
//!   [`LogConfig`] (JSON in production, human-readable in development).
//! - **Singleton-state** — the global subscriber is installed exactly once,
//!   guarded by a [`OnceLock`], so repeated [`init`] calls are safe no-ops.
//!
//! Correlation IDs attach through `tracing` spans: open a [`request_span`] at a
//! request or job boundary and every event emitted inside it carries the id.

use std::str::FromStr;
use std::sync::OnceLock;

use tracing::{Level, Span};

static INITIALIZED: OnceLock<()> = OnceLock::new();

/// Output format for log records.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogFormat {
    /// One JSON object per line — for production log aggregation.
    Json,
    /// Human-readable, for local development.
    Human,
}

impl LogFormat {
    /// Parse from a string, defaulting to [`LogFormat::Json`] for anything
    /// unrecognized (the production-safe default).
    #[must_use]
    pub fn parse(value: &str) -> Self {
        match value.trim().to_ascii_lowercase().as_str() {
            "human" | "pretty" | "text" => Self::Human,
            _ => Self::Json,
        }
    }
}

/// Logging configuration, typically built once at startup.
#[derive(Debug, Clone)]
pub struct LogConfig {
    /// Maximum level to emit.
    pub level: Level,
    /// Output format.
    pub format: LogFormat,
    /// Service name; attach it to a root span so it appears on every record.
    pub service_name: String,
}

impl Default for LogConfig {
    fn default() -> Self {
        Self {
            level: Level::INFO,
            format: LogFormat::Json,
            service_name: "service".to_owned(),
        }
    }
}

impl LogConfig {
    /// Build from `LOG_LEVEL`, `LOG_FORMAT`, and `SERVICE_NAME`, falling back to
    /// [`LogConfig::default`] for any unset or unparseable value.
    #[must_use]
    pub fn from_env() -> Self {
        let default = Self::default();
        let level = std::env::var("LOG_LEVEL")
            .ok()
            .and_then(|raw| Level::from_str(raw.trim()).ok())
            .unwrap_or(default.level);
        let format =
            std::env::var("LOG_FORMAT").map_or(default.format, |raw| LogFormat::parse(&raw));
        let service_name = std::env::var("SERVICE_NAME").unwrap_or(default.service_name);
        Self {
            level,
            format,
            service_name,
        }
    }
}

/// Error returned when installing the global subscriber fails because a
/// different one was already installed by something outside this module.
#[derive(Debug, thiserror::Error)]
#[error("failed to install global log subscriber: {0}")]
pub struct LogInitError(String);

/// Install the global subscriber from `config`.
///
/// Idempotent: the first call wins; later calls are no-ops, so it is safe to
/// call from multiple entry points.
///
/// # Errors
///
/// Returns [`LogInitError`] if a different global subscriber was already
/// installed by code outside this module.
pub fn init(config: &LogConfig) -> Result<(), LogInitError> {
    if INITIALIZED.get().is_some() {
        return Ok(());
    }
    let builder = tracing_subscriber::fmt().with_max_level(config.level);
    let installed = match config.format {
        LogFormat::Json => builder.json().try_init(),
        LogFormat::Human => builder.try_init(),
    };
    installed.map_err(|error| LogInitError(error.to_string()))?;
    let _ = INITIALIZED.set(());
    Ok(())
}

/// Open a span tagging every event inside it with `correlation_id`. Enter it at
/// a request or job boundary so downstream logs are correlated:
///
/// ```ignore
/// let _guard = request_span("req-123").entered();
/// ```
#[must_use]
pub fn request_span(correlation_id: &str) -> Span {
    tracing::info_span!("request", correlation_id = correlation_id)
}

#[cfg(test)]
mod tests {
    use tracing::subscriber::with_default;
    use tracing::Level;

    use super::{init, request_span, LogConfig, LogFormat};

    #[test]
    fn log_format_parses_with_json_default() {
        assert_eq!(LogFormat::parse("json"), LogFormat::Json);
        assert_eq!(LogFormat::parse("JSON"), LogFormat::Json);
        assert_eq!(LogFormat::parse("human"), LogFormat::Human);
        assert_eq!(LogFormat::parse("  pretty "), LogFormat::Human);
        assert_eq!(LogFormat::parse("text"), LogFormat::Human);
        assert_eq!(LogFormat::parse("anything-else"), LogFormat::Json);
    }

    #[test]
    fn default_config_is_info_json() {
        let config = LogConfig::default();
        assert_eq!(config.level, Level::INFO);
        assert_eq!(config.format, LogFormat::Json);
        assert_eq!(config.service_name, "service");
    }

    #[test]
    fn from_env_reads_overrides_then_falls_back_to_defaults() {
        std::env::set_var("LOG_LEVEL", "debug");
        std::env::set_var("LOG_FORMAT", "human");
        std::env::set_var("SERVICE_NAME", "billing");
        let overridden = LogConfig::from_env();
        assert_eq!(overridden.level, Level::DEBUG);
        assert_eq!(overridden.format, LogFormat::Human);
        assert_eq!(overridden.service_name, "billing");

        std::env::remove_var("LOG_LEVEL");
        std::env::remove_var("LOG_FORMAT");
        std::env::remove_var("SERVICE_NAME");
        let defaulted = LogConfig::from_env();
        assert_eq!(defaulted.level, Level::INFO);
        assert_eq!(defaulted.format, LogFormat::Json);
        assert_eq!(defaulted.service_name, "service");
    }

    #[test]
    fn init_is_idempotent() {
        let config = LogConfig::default();
        assert!(init(&config).is_ok());
        assert!(init(&config).is_ok());
    }

    #[test]
    fn request_span_is_named_request() {
        // Thread-local subscriber so the span is enabled (and the test is not
        // affected by whether a global subscriber happens to be installed).
        let subscriber = tracing_subscriber::fmt()
            .with_max_level(Level::INFO)
            .finish();
        with_default(subscriber, || {
            let span = request_span("req-1");
            assert_eq!(
                span.metadata().map(tracing::Metadata::name),
                Some("request")
            );
        });
    }
}
