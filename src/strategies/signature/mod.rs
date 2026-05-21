//! Webhook signature validation — the canonical Strategy + Registry structure.
//!
//! This module is the reference shape every strategy family copies:
//! - [`types`] — the [`SignatureStrategy`] trait (the Strategy interface).
//! - [`registry`] — [`SignatureRegistry`] with register/get/reset.
//! - one file per implementation ([`github`] → [`GithubSignature`]).
//! - this barrel + a `README.md`.
//!
//! Add a strategy by implementing [`SignatureStrategy`] in its own file and
//! registering it — no other file changes.

mod github;
mod registry;
mod types;

pub use github::GithubSignature;
pub use registry::SignatureRegistry;
pub use types::SignatureStrategy;

/// Build a registry pre-loaded with the built-in strategies.
#[must_use]
pub fn default_registry() -> SignatureRegistry {
    let mut registry = SignatureRegistry::new();
    registry.register(Box::new(GithubSignature));
    registry
}

#[cfg(test)]
mod tests {
    use super::default_registry;

    #[test]
    fn default_registry_includes_github() {
        let registry = default_registry();
        assert!(registry.get("github").is_some());
    }
}
