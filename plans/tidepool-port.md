# Tidepool Spike: notify_parent Through JIT

## Context

ExoMonad runs Haskell logic through extism (WASM32-WASI). The boundary is proto-encoded bytes through a single `yield_effect` host function. This adds overhead: proto encode/decode per effect, slow GHC WASM32 dev cycle, STG stack bugs (GHC #25213).

Tidepool (`../tidepool`) compiles Haskell Core → Cranelift JIT. It uses freer-simple natively — effects yield as `(tag, request_ptr, continuation)` dispatched by an HList of Rust handlers. No proto, no WASM, no serialization.

**Goal:** Prove the boundary works for `notify_parent` as a Rust integration test. Same freer-simple effect pattern, different executor. Test-only — no MCP wiring, no server integration. If this works, it validates replacing extism entirely and shows the port path is mechanical (same effects, different glue).

## What Changes

| Layer | Current (extism) | Spike (Tidepool) |
|-------|-------------------|-------------------|
| **Haskell effects** | Proto-encoded `SuspendYield` coroutine | Native freer-simple `send` |
| **Boundary encoding** | Protobuf bytes | `FromCore`/`ToCore` derive macros |
| **Dispatch** | String namespace routing (`"events.notify_parent"`) | Positional tag in HList |
| **Rust handler** | `async fn handle(&self, effect_type: &str, payload: &[u8])` | `fn handle(&mut self, req: Self::Request, cx: &EffectContext)` |
| **Thread model** | WASM plugin lock, async trampoline | Dedicated std::thread, channel bridge |

## Implementation

### Step 1: Haskell spike module

**File:** `haskell/spike/NotifyParentSpike.hs`

Mirrors the real `notify_parent` handler using plain freer-simple effects. Same logic shape as `Events.hs:toolHandlerEff` — just `send` instead of `suspendEffect`.

```haskell
{-# LANGUAGE DataKinds, GADTs, TypeOperators #-}
module NotifyParentSpike where

import Control.Monad.Freer (Eff, send)
import Data.Text (Text)
import qualified Data.Text as T

-- Effect GADT: what the handler yields to Rust
data NotifyParentEff a where
  EmitEvent    :: Text -> Text -> NotifyParentEff ()
  NotifyParent :: Text -> Text -> NotifyParentEff Bool

-- Same logic shape as Events.hs toolHandlerEff
handleNotifyParent
  :: Text       -- status
  -> Text       -- message
  -> Maybe Int  -- pr_number
  -> Eff '[NotifyParentEff] (Either Text Bool)
handleNotifyParent status message prNumber = do
  send (EmitEvent "agent.completed" payload)
  let richMessage = message <> prSuffix prNumber
  success <- send (NotifyParent status richMessage)
  pure (Right success)
  where
    payload = "{\"status\":\"" <> status <> "\",\"message\":\"" <> message <> "\"}"

prSuffix :: Maybe Int -> Text
prSuffix (Just n) = " (PR #" <> T.pack (show n) <> ")"
prSuffix Nothing  = ""

-- Entry point for Tidepool
result :: Eff '[NotifyParentEff] (Either Text Bool)
result = handleNotifyParent "success" "Implemented feature X" (Just 42)
```

### Step 2: Rust types with FromCore/ToCore

**File:** `rust/exomonad-core/src/tidepool/types.rs`

```rust
use tidepool::{FromCore, ToCore};

#[derive(FromCore, Debug)]
pub enum NotifyParentRequest {
    #[core(name = "EmitEvent")]
    EmitEvent(String, String),
    #[core(name = "NotifyParent")]
    NotifyParent(String, String),
}

#[derive(ToCore)]
pub struct UnitResponse;

#[derive(ToCore)]
pub struct BoolResponse(pub bool);
```

### Step 3: Rust EffectHandler

**File:** `rust/exomonad-core/src/tidepool/handler.rs`

```rust
use tidepool::effect::{EffectHandler, EffectContext, EffectError};
use tidepool::repr::Value;

/// Captures dispatched effects for test assertion
pub struct NotifyParentSpikeHandler {
    pub emitted_events: Vec<(String, String)>,
    pub notify_calls: Vec<(String, String)>,
}

impl EffectHandler for NotifyParentSpikeHandler {
    type Request = NotifyParentRequest;

    fn handle(
        &mut self,
        req: Self::Request,
        cx: &EffectContext<'_>,
    ) -> Result<Value, EffectError> {
        match req {
            NotifyParentRequest::EmitEvent(event_type, payload) => {
                self.emitted_events.push((event_type, payload));
                cx.respond(UnitResponse)
            }
            NotifyParentRequest::NotifyParent(status, message) => {
                self.notify_calls.push((status, message));
                cx.respond(BoolResponse(true))
            }
        }
    }
}
```

For the spike test, this is a mock handler that captures calls. The real integration would bridge to existing `EventHandler` via channels.

### Step 4: Module structure

**File:** `rust/exomonad-core/src/tidepool/mod.rs`

```rust
pub mod types;
pub mod handler;
```

**File:** `rust/exomonad-core/src/lib.rs` — add:

```rust
#[cfg(feature = "tidepool")]
pub mod tidepool;
```

### Step 5: Integration test

**File:** `rust/exomonad-core/tests/tidepool_spike.rs`

```rust
use std::path::Path;
use tidepool::{compile_haskell, JitEffectMachine};
use exomonad_core::tidepool::handler::NotifyParentSpikeHandler;

#[test]
fn notify_parent_through_tidepool() {
    // Compile Haskell spike module
    let (expr, table, _warnings) = compile_haskell(
        "../../haskell/spike/NotifyParentSpike.hs",
        "result",
        &[],
    ).expect("Haskell compilation failed");

    // JIT compile
    let mut machine = JitEffectMachine::compile(&expr, &table, 64 * 1024 * 1024)
        .expect("JIT compilation failed");

    // Run with mock handler
    let mut handler = NotifyParentSpikeHandler {
        emitted_events: vec![],
        notify_calls: vec![],
    };
    let mut handlers = frunk::hlist![handler];
    let result = machine.run(&table, &mut handlers, &())
        .expect("JIT execution failed");

    // Verify effects were dispatched
    let handler = &handlers.head;
    assert_eq!(handler.emitted_events.len(), 1);
    assert_eq!(handler.emitted_events[0].0, "agent.completed");
    assert_eq!(handler.notify_calls.len(), 1);
    assert_eq!(handler.notify_calls[0].0, "success");
    assert!(handler.notify_calls[0].1.contains("PR #42"));
}
```

### Step 6: Cargo.toml

**File:** `rust/exomonad-core/Cargo.toml`

```toml
[dependencies]
tidepool = { path = "../../tidepool", optional = true }
frunk = { version = "0.4", optional = true }

[features]
tidepool = ["dep:tidepool", "dep:frunk"]
```

Feature-gated — no impact on production build.

## Critical Files

| File | Change |
|------|--------|
| `haskell/spike/NotifyParentSpike.hs` | New — freer-simple notify_parent logic |
| `rust/exomonad-core/src/tidepool/mod.rs` | New — module declaration |
| `rust/exomonad-core/src/tidepool/types.rs` | New — FromCore/ToCore boundary types |
| `rust/exomonad-core/src/tidepool/handler.rs` | New — mock EffectHandler for test |
| `rust/exomonad-core/tests/tidepool_spike.rs` | New — integration test |
| `rust/exomonad-core/Cargo.toml` | Add optional tidepool + frunk deps |
| `rust/exomonad-core/src/lib.rs` | Add `#[cfg(feature = "tidepool")] pub mod tidepool;` |

## Prerequisites

- `tidepool-extract` on `$PATH` (or `TIDEPOOL_EXTRACT` env var)
- GHC with freer-simple available (for extraction — not WASM GHC)
- `nix develop` or equivalent environment

## Verification

```bash
# From repo root, in a feature branch
cargo test -p exomonad-core --features tidepool -- tidepool_spike
```

Expected: Haskell compiles → JIT runs → EmitEvent + NotifyParent effects dispatch → mock captures correct arguments → test passes.

## What This Proves

1. freer-simple effects dispatch natively through Tidepool without proto encoding
2. FromCore/ToCore handles the Haskell↔Rust boundary for domain types
3. The port path is mechanical: same `send` pattern, swap `suspendEffect` glue for native `send`
4. JitEffectMachine integrates into the exomonad-core crate
