//! A time-to-live cache with size-bounded eviction and hit/miss statistics.
//!
//! Entries expire after a fixed TTL; when the cache is full, the oldest entry
//! (by insertion order) is evicted to make room. Statistics are integer-only so
//! the cache stays dependency-free and lossless — [`hit_rate_permille`] reports
//! the hit rate in parts-per-thousand rather than a lossy float.
//!
//! [`hit_rate_permille`]: TtlCache::hit_rate_permille

use std::collections::HashMap;
use std::hash::Hash;
use std::time::{Duration, Instant};

struct CacheEntry<V> {
    value: V,
    expires_at: Instant,
    sequence: u64,
}

/// Outcome of a lookup, computed while borrowing the map immutably so the
/// follow-up mutation (stats, eviction of the expired key) borrows cleanly.
enum Lookup<V> {
    Hit(V),
    Expired,
    Miss,
}

/// A bounded, expiring key/value cache.
pub struct TtlCache<K, V> {
    entries: HashMap<K, CacheEntry<V>>,
    ttl: Duration,
    max_size: usize,
    next_sequence: u64,
    hits: u64,
    misses: u64,
    expirations: u64,
    evictions: u64,
}

impl<K, V> TtlCache<K, V>
where
    K: Eq + Hash + Clone,
    V: Clone,
{
    /// Create a cache where entries live for `ttl` and at most `max_size`
    /// entries are retained.
    #[must_use]
    pub fn new(ttl: Duration, max_size: usize) -> Self {
        Self {
            entries: HashMap::new(),
            ttl,
            max_size,
            next_sequence: 0,
            hits: 0,
            misses: 0,
            expirations: 0,
            evictions: 0,
        }
    }

    /// Fetch a live value, cloning it. Expired entries are removed and counted
    /// as both an expiration and a miss.
    pub fn get(&mut self, key: &K) -> Option<V> {
        let now = Instant::now();
        let lookup = match self.entries.get(key) {
            None => Lookup::Miss,
            Some(entry) if now < entry.expires_at => Lookup::Hit(entry.value.clone()),
            Some(_) => Lookup::Expired,
        };
        match lookup {
            Lookup::Hit(value) => {
                self.hits = self.hits.saturating_add(1);
                Some(value)
            }
            Lookup::Expired => {
                self.entries.remove(key);
                self.expirations = self.expirations.saturating_add(1);
                self.misses = self.misses.saturating_add(1);
                None
            }
            Lookup::Miss => {
                self.misses = self.misses.saturating_add(1);
                None
            }
        }
    }

    /// Insert or replace `key`, evicting the oldest entry first if inserting a
    /// new key would exceed `max_size`.
    pub fn set(&mut self, key: K, value: V) {
        if !self.entries.contains_key(&key) && self.entries.len() >= self.max_size {
            self.evict_oldest();
        }
        let sequence = self.next_sequence;
        self.next_sequence = self.next_sequence.saturating_add(1);
        self.entries.insert(
            key,
            CacheEntry {
                value,
                expires_at: Instant::now() + self.ttl,
                sequence,
            },
        );
    }

    /// Remove all entries. Statistics are preserved.
    pub fn clear(&mut self) {
        self.entries.clear();
    }

    fn evict_oldest(&mut self) {
        let oldest = self
            .entries
            .iter()
            .min_by_key(|(_, entry)| entry.sequence)
            .map(|(key, _)| key.clone());
        if let Some(key) = oldest {
            self.entries.remove(&key);
            self.evictions = self.evictions.saturating_add(1);
        }
    }

    /// The number of live entries currently stored.
    #[must_use]
    pub fn len(&self) -> usize {
        self.entries.len()
    }

    /// Whether the cache holds no entries.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    /// Cache hits served so far.
    #[must_use]
    pub const fn hits(&self) -> u64 {
        self.hits
    }

    /// Cache misses so far (includes expirations).
    #[must_use]
    pub const fn misses(&self) -> u64 {
        self.misses
    }

    /// Entries removed because they had expired on lookup.
    #[must_use]
    pub const fn expirations(&self) -> u64 {
        self.expirations
    }

    /// Entries removed to stay within `max_size`.
    #[must_use]
    pub const fn evictions(&self) -> u64 {
        self.evictions
    }

    /// Hit rate in parts-per-thousand: `hits * 1000 / (hits + misses)`, or 0
    /// when there have been no lookups.
    #[must_use]
    pub const fn hit_rate_permille(&self) -> u64 {
        let total = self.hits.saturating_add(self.misses);
        match self.hits.saturating_mul(1000).checked_div(total) {
            Some(rate) => rate,
            None => 0,
        }
    }
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::TtlCache;

    #[test]
    fn returns_a_live_value_as_a_hit() {
        let mut cache: TtlCache<&str, u32> = TtlCache::new(Duration::from_secs(60), 8);
        cache.set("a", 1);
        assert_eq!(cache.get(&"a"), Some(1));
        assert_eq!(cache.hits(), 1);
        assert_eq!(cache.misses(), 0);
    }

    #[test]
    fn missing_key_is_a_miss() {
        let mut cache: TtlCache<&str, u32> = TtlCache::new(Duration::from_secs(60), 8);
        assert_eq!(cache.get(&"absent"), None);
        assert_eq!(cache.misses(), 1);
    }

    #[test]
    fn expired_entry_is_removed_and_counted() {
        let mut cache: TtlCache<&str, u32> = TtlCache::new(Duration::ZERO, 8);
        cache.set("a", 1);
        assert_eq!(cache.get(&"a"), None);
        assert_eq!(cache.expirations(), 1);
        assert_eq!(cache.misses(), 1);
        assert!(cache.is_empty());
    }

    #[test]
    fn oldest_entry_is_evicted_when_full() {
        let mut cache: TtlCache<&str, u32> = TtlCache::new(Duration::from_secs(60), 2);
        cache.set("a", 1);
        cache.set("b", 2);
        cache.set("c", 3); // evicts "a", the oldest
        assert_eq!(cache.get(&"a"), None);
        assert_eq!(cache.get(&"b"), Some(2));
        assert_eq!(cache.get(&"c"), Some(3));
        assert_eq!(cache.evictions(), 1);
        assert_eq!(cache.len(), 2);
    }

    #[test]
    fn replacing_a_key_does_not_evict() {
        let mut cache: TtlCache<&str, u32> = TtlCache::new(Duration::from_secs(60), 1);
        cache.set("a", 1);
        cache.set("a", 2);
        assert_eq!(cache.get(&"a"), Some(2));
        assert_eq!(cache.evictions(), 0);
    }

    #[test]
    fn clear_removes_entries_but_keeps_stats() {
        let mut cache: TtlCache<&str, u32> = TtlCache::new(Duration::from_secs(60), 8);
        cache.set("a", 1);
        let _ = cache.get(&"a");
        cache.clear();
        assert!(cache.is_empty());
        assert_eq!(cache.hits(), 1);
    }

    #[test]
    fn hit_rate_permille_is_integer_and_safe_when_empty() {
        let mut cache: TtlCache<&str, u32> = TtlCache::new(Duration::from_secs(60), 8);
        assert_eq!(cache.hit_rate_permille(), 0);
        cache.set("a", 1);
        let _ = cache.get(&"a"); // hit
        let _ = cache.get(&"b"); // miss
        assert_eq!(cache.hit_rate_permille(), 500);
    }
}
