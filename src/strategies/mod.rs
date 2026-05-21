//! Strategy-pattern modules.
//!
//! Every strategy family in a Sc0red service follows one structure (see
//! [`signature`] as the reference): a `types` module with the trait, a
//! `registry` for register/get/reset, one file per implementation, a barrel,
//! and a README.

pub mod signature;
