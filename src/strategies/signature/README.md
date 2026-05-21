# strategies/signature

Webhook signature validation — the **canonical Strategy + Registry structure**
every strategy family in the codebase copies.

**Public API:** `SignatureStrategy` (trait), `SignatureRegistry`, `GithubSignature`, `default_registry`.

**Structure (copy this for any new strategy family):**
- `types.rs` — the trait (the Strategy interface).
- `registry.rs` — `register` / `get` / `reset`, owned and injectable (no global state).
- one file per implementation (`github.rs`).
- `mod.rs` — barrel + `default_registry()` factory.
- this `README.md`.

**Constraints:**
- Verification MUST be constant-time (`hmac::Mac::verify_slice`) — never compare signatures byte-by-byte.
- Add a strategy by implementing `SignatureStrategy` in a new file and registering it; nothing else changes.
