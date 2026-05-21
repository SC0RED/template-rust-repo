//! GitHub webhook signature strategy: header `X-Hub-Signature-256: sha256=<hex>`.

use hmac::{Hmac, Mac};
use sha2::Sha256;

use super::types::SignatureStrategy;

type HmacSha256 = Hmac<Sha256>;

/// Verifies GitHub's `sha256=<hex>` HMAC-SHA256 webhook signatures.
#[derive(Debug, Default, Clone, Copy)]
pub struct GithubSignature;

impl SignatureStrategy for GithubSignature {
    fn name(&self) -> &'static str {
        "github"
    }

    fn verify(&self, secret: &[u8], body: &[u8], provided: &str) -> bool {
        let Some(hex_signature) = provided.strip_prefix("sha256=") else {
            return false;
        };
        let Ok(expected) = hex::decode(hex_signature) else {
            return false;
        };
        let Ok(mut mac) = HmacSha256::new_from_slice(secret) else {
            return false;
        };
        mac.update(body);
        // Constant-time comparison — never short-circuits on a partial match.
        mac.verify_slice(&expected).is_ok()
    }
}

#[cfg(test)]
mod tests {
    use hmac::{Hmac, Mac};
    use sha2::Sha256;

    use super::{GithubSignature, SignatureStrategy};

    type HmacSha256 = Hmac<Sha256>;

    fn sign(secret: &[u8], body: &[u8]) -> String {
        let mut mac = HmacSha256::new_from_slice(secret).expect("hmac key");
        mac.update(body);
        format!("sha256={}", hex::encode(mac.finalize().into_bytes()))
    }

    #[test]
    fn accepts_a_valid_signature() {
        let secret = b"top-secret";
        let body = b"{\"event\":\"push\"}";
        assert!(GithubSignature.verify(secret, body, &sign(secret, body)));
    }

    #[test]
    fn rejects_a_tampered_body() {
        let secret = b"top-secret";
        let header = sign(secret, b"original");
        assert!(!GithubSignature.verify(secret, b"tampered", &header));
    }

    #[test]
    fn rejects_a_missing_prefix() {
        let secret = b"top-secret";
        let body = b"payload";
        let bare = sign(secret, body).replace("sha256=", "");
        assert!(!GithubSignature.verify(secret, body, &bare));
    }

    #[test]
    fn rejects_non_hex_signature() {
        assert!(!GithubSignature.verify(b"secret", b"payload", "sha256=not-hex!!"));
    }

    #[test]
    fn exposes_its_name() {
        assert_eq!(GithubSignature.name(), "github");
    }
}
