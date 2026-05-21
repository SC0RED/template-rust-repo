//! Error hierarchy for Sc0red services.
//!
//! Two GoF patterns (see `README.md`):
//!
//! - **Template Method** — every error answers the same questions through one
//!   interface: [`ErrorKind::code`], [`ErrorKind::http_status`],
//!   [`ErrorKind::title`]. The kind supplies the shared structure; each variant
//!   the specifics. Callers handle every error uniformly.
//! - **Registry** — [`ErrorKind::from_code`] is the reverse lookup from a
//!   machine-readable wire code back to its kind, driven by a single source of
//!   truth ([`ErrorKind::ALL`]).
//!
//! External responses use the RFC 7807 [`ProblemDetails`] shape (see the
//! `api-design` spec). Internal code constructs a [`ServiceError`] and lets it
//! propagate to a boundary, where it is rendered.

use std::collections::BTreeMap;

use serde::Serialize;

/// Structured, debugging-oriented key/value context attached to an error.
///
/// A `BTreeMap` (not a `HashMap`) so serialization order is deterministic,
/// which keeps logs and snapshot tests stable.
pub type ErrorContext = BTreeMap<String, String>;

/// Machine-readable classification of a [`ServiceError`].
///
/// Client kinds map to 4xx (the caller can fix the request); server kinds map
/// to 5xx (the caller cannot).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrorKind {
    /// Request failed validation at a boundary (400).
    Validation,
    /// A malformed request that is not a field-level validation failure (400).
    BadRequest,
    /// Caller is not authenticated (401).
    Authentication,
    /// Caller is authenticated but not permitted (403).
    Authorization,
    /// Requested resource does not exist (404).
    NotFound,
    /// Request conflicts with current state (409).
    Conflict,
    /// Caller exceeded a rate limit (429).
    RateLimit,
    /// An unexpected internal failure (500).
    Processing,
    /// Misconfiguration detected at runtime (500).
    Configuration,
    /// A downstream dependency returned an error (502).
    ExternalService,
    /// A dependency is temporarily unavailable (503).
    ServiceUnavailable,
    /// An operation exceeded its deadline (504).
    OperationTimeout,
}

impl ErrorKind {
    /// Every kind, the single source of truth the registry iterates.
    pub const ALL: [Self; 12] = [
        Self::Validation,
        Self::BadRequest,
        Self::Authentication,
        Self::Authorization,
        Self::NotFound,
        Self::Conflict,
        Self::RateLimit,
        Self::Processing,
        Self::Configuration,
        Self::ExternalService,
        Self::ServiceUnavailable,
        Self::OperationTimeout,
    ];

    /// The stable, machine-readable wire code (e.g. `"VALIDATION_ERROR"`).
    #[must_use]
    pub const fn code(self) -> &'static str {
        match self {
            Self::Validation => "VALIDATION_ERROR",
            Self::BadRequest => "BAD_REQUEST",
            Self::Authentication => "AUTHENTICATION_ERROR",
            Self::Authorization => "AUTHORIZATION_ERROR",
            Self::NotFound => "NOT_FOUND",
            Self::Conflict => "CONFLICT",
            Self::RateLimit => "RATE_LIMIT_EXCEEDED",
            Self::Processing => "PROCESSING_ERROR",
            Self::Configuration => "CONFIGURATION_ERROR",
            Self::ExternalService => "EXTERNAL_SERVICE_ERROR",
            Self::ServiceUnavailable => "SERVICE_UNAVAILABLE",
            Self::OperationTimeout => "OPERATION_TIMEOUT",
        }
    }

    /// The HTTP status code this kind maps to.
    #[must_use]
    pub const fn http_status(self) -> u16 {
        match self {
            Self::Validation | Self::BadRequest => 400,
            Self::Authentication => 401,
            Self::Authorization => 403,
            Self::NotFound => 404,
            Self::Conflict => 409,
            Self::RateLimit => 429,
            Self::Processing | Self::Configuration => 500,
            Self::ExternalService => 502,
            Self::ServiceUnavailable => 503,
            Self::OperationTimeout => 504,
        }
    }

    /// A short human-readable title for the RFC 7807 response.
    #[must_use]
    pub const fn title(self) -> &'static str {
        match self {
            Self::Validation => "Validation Error",
            Self::BadRequest => "Bad Request",
            Self::Authentication => "Authentication Required",
            Self::Authorization => "Forbidden",
            Self::NotFound => "Not Found",
            Self::Conflict => "Conflict",
            Self::RateLimit => "Rate Limit Exceeded",
            Self::Processing => "Internal Error",
            Self::Configuration => "Configuration Error",
            Self::ExternalService => "External Service Error",
            Self::ServiceUnavailable => "Service Unavailable",
            Self::OperationTimeout => "Operation Timed Out",
        }
    }

    /// Registry reverse-lookup: resolve a kind from its wire [`code`](Self::code).
    ///
    /// Returns `None` for an unknown code.
    #[must_use]
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|kind| kind.code() == code)
    }
}

/// The canonical error type returned across a Sc0red service.
///
/// Construct one with [`ServiceError::new`], optionally attach
/// [`with_context`](ServiceError::with_context), and let it propagate to a
/// boundary where [`into_problem_details`](ServiceError::into_problem_details)
/// renders the response.
#[derive(Debug, thiserror::Error)]
#[error("{code}: {detail}", code = self.kind.code())]
pub struct ServiceError {
    kind: ErrorKind,
    detail: String,
    context: ErrorContext,
}

impl ServiceError {
    /// Create an error of `kind` with a human-readable `detail`.
    #[must_use]
    pub fn new(kind: ErrorKind, detail: impl Into<String>) -> Self {
        Self {
            kind,
            detail: detail.into(),
            context: ErrorContext::new(),
        }
    }

    /// Attach one structured context entry; chainable.
    #[must_use]
    pub fn with_context(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.context.insert(key.into(), value.into());
        self
    }

    /// The kind of this error.
    #[must_use]
    pub const fn kind(&self) -> ErrorKind {
        self.kind
    }

    /// Render to the RFC 7807 problem-details shape for an API response.
    #[must_use]
    pub fn into_problem_details(self) -> ProblemDetails {
        ProblemDetails {
            type_uri: format!("urn:sc0red:error:{}", self.kind.code()),
            title: self.kind.title().to_owned(),
            status: self.kind.http_status(),
            code: self.kind.code(),
            detail: self.detail,
            context: self.context,
        }
    }
}

/// RFC 7807 Problem Details — the wire shape of an error response.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ProblemDetails {
    /// A URI reference identifying the problem type.
    #[serde(rename = "type")]
    pub type_uri: String,
    /// Short, human-readable summary of the problem type.
    pub title: String,
    /// The HTTP status code.
    pub status: u16,
    /// The machine-readable error code.
    pub code: &'static str,
    /// Human-readable explanation specific to this occurrence.
    pub detail: String,
    /// Structured debugging context; omitted from JSON when empty.
    #[serde(skip_serializing_if = "BTreeMap::is_empty")]
    pub context: ErrorContext,
}

#[cfg(test)]
mod tests {
    use super::{ErrorKind, ProblemDetails, ServiceError};

    #[test]
    fn every_kind_has_a_unique_code() {
        let mut codes: Vec<&str> = ErrorKind::ALL.iter().map(|kind| kind.code()).collect();
        let count = codes.len();
        codes.sort_unstable();
        codes.dedup();
        assert_eq!(codes.len(), count, "error codes must be unique");
    }

    #[test]
    fn from_code_round_trips_for_every_kind() {
        for kind in ErrorKind::ALL {
            assert_eq!(ErrorKind::from_code(kind.code()), Some(kind));
        }
    }

    #[test]
    fn from_code_returns_none_for_unknown() {
        assert_eq!(ErrorKind::from_code("NOPE"), None);
    }

    #[test]
    fn client_kinds_are_4xx_and_server_kinds_are_5xx() {
        assert_eq!(ErrorKind::Validation.http_status(), 400);
        assert_eq!(ErrorKind::Authentication.http_status(), 401);
        assert_eq!(ErrorKind::Authorization.http_status(), 403);
        assert_eq!(ErrorKind::NotFound.http_status(), 404);
        assert_eq!(ErrorKind::Conflict.http_status(), 409);
        assert_eq!(ErrorKind::RateLimit.http_status(), 429);
        assert_eq!(ErrorKind::Processing.http_status(), 500);
        assert_eq!(ErrorKind::ExternalService.http_status(), 502);
        assert_eq!(ErrorKind::ServiceUnavailable.http_status(), 503);
        assert_eq!(ErrorKind::OperationTimeout.http_status(), 504);
    }

    #[test]
    fn every_kind_has_a_nonempty_title() {
        for kind in ErrorKind::ALL {
            assert!(!kind.title().is_empty());
        }
    }

    #[test]
    fn display_includes_code_and_detail() {
        let error = ServiceError::new(ErrorKind::NotFound, "user 7 does not exist");
        assert_eq!(error.to_string(), "NOT_FOUND: user 7 does not exist");
        assert_eq!(error.kind(), ErrorKind::NotFound);
    }

    #[test]
    fn problem_details_carries_code_status_and_context() {
        let problem = ServiceError::new(ErrorKind::Validation, "email is required")
            .with_context("field", "email")
            .into_problem_details();
        assert_eq!(problem.status, 400);
        assert_eq!(problem.code, "VALIDATION_ERROR");
        assert_eq!(problem.title, "Validation Error");
        assert_eq!(problem.type_uri, "urn:sc0red:error:VALIDATION_ERROR");
        assert_eq!(
            problem.context.get("field").map(String::as_str),
            Some("email")
        );
    }

    #[test]
    fn problem_details_serializes_rfc7807_fields() {
        let problem: ProblemDetails =
            ServiceError::new(ErrorKind::NotFound, "missing").into_problem_details();
        let json = serde_json::to_value(&problem).expect("serialize");
        assert_eq!(json["type"], "urn:sc0red:error:NOT_FOUND");
        assert_eq!(json["status"], 404);
        assert_eq!(json["code"], "NOT_FOUND");
        // Empty context is omitted entirely.
        assert!(json.get("context").is_none());
    }
}
