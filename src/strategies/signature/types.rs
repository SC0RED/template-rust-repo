//! The `SignatureStrategy` trait — the Strategy interface for verifying the
//! authenticity of an inbound webhook.

/// Verifies that a request body carries a valid signature for a shared secret.
///
/// Implementations MUST compare in constant time (e.g. via
/// [`hmac::Mac::verify_slice`]) so a timing side-channel cannot leak the
/// expected signature.
pub trait SignatureStrategy: Send + Sync {
    /// The name this strategy is registered and looked up under (e.g. `"github"`).
    fn name(&self) -> &'static str;

    /// Verify the `provided` header value against the HMAC of `body` keyed by
    /// `secret`. Returns `true` only on a valid, constant-time match.
    fn verify(&self, secret: &[u8], body: &[u8], provided: &str) -> bool;
}
