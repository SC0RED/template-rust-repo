//! Registry of signature strategies, looked up by name.
//!
//! An owned value (not global mutable state) so wiring is explicit and
//! injectable — construct one at startup and pass it where needed.

use std::collections::HashMap;

use super::types::SignatureStrategy;

/// Maps a strategy name to its implementation.
#[derive(Default)]
pub struct SignatureRegistry {
    strategies: HashMap<&'static str, Box<dyn SignatureStrategy>>,
}

impl SignatureRegistry {
    /// An empty registry.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Register `strategy` under its own [`name`](SignatureStrategy::name),
    /// replacing any existing strategy with the same name.
    pub fn register(&mut self, strategy: Box<dyn SignatureStrategy>) {
        self.strategies.insert(strategy.name(), strategy);
    }

    /// Look up a strategy by name.
    #[must_use]
    pub fn get(&self, name: &str) -> Option<&dyn SignatureStrategy> {
        self.strategies.get(name).map(|strategy| &**strategy)
    }

    /// Remove all registered strategies.
    pub fn reset(&mut self) {
        self.strategies.clear();
    }

    /// The number of registered strategies.
    #[must_use]
    pub fn len(&self) -> usize {
        self.strategies.len()
    }

    /// Whether the registry holds no strategies.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.strategies.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::super::github::GithubSignature;
    use super::SignatureRegistry;

    #[test]
    fn new_registry_is_empty() {
        let registry = SignatureRegistry::new();
        assert!(registry.is_empty());
        assert_eq!(registry.len(), 0);
    }

    #[test]
    fn register_then_get_returns_the_strategy() {
        let mut registry = SignatureRegistry::new();
        registry.register(Box::new(GithubSignature));
        assert_eq!(registry.len(), 1);
        let strategy = registry.get("github").expect("registered");
        assert_eq!(strategy.name(), "github");
    }

    #[test]
    fn get_unknown_name_returns_none() {
        let registry = SignatureRegistry::new();
        assert!(registry.get("nope").is_none());
    }

    #[test]
    fn reset_clears_the_registry() {
        let mut registry = SignatureRegistry::new();
        registry.register(Box::new(GithubSignature));
        registry.reset();
        assert!(registry.is_empty());
    }
}
