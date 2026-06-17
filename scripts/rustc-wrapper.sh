#!/bin/sh
# rustc wrapper referenced by .cargo/config.toml's `rustc-wrapper`.
#
# Why a wrapper and not `rustc-wrapper = "sccache"` directly: committing a hard
# sccache requirement breaks `cargo build` for anyone (or any CI step) that
# doesn't have sccache installed. This wrapper uses sccache when it's on PATH
# and falls back to invoking the compiler directly when it isn't — so the
# shared compile cache is an optimization, never a requirement.
#
# Cargo invokes this as:  rustc-wrapper.sh <path-to-rustc> <rustc-args...>
# sccache expects exactly that shape, so we just prepend `sccache`.
#
# Per-agent worktrees each keep their own ./target (no build-lock contention),
# but share sccache's object cache — so a fresh worktree doesn't pay a full
# cold recompile. See docs/guides/PARALLEL_AGENTS.md.

if command -v sccache >/dev/null 2>&1; then
    exec sccache "$@"
fi
exec "$@"
