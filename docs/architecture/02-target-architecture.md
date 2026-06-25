# 2. Target Architecture

A **Cargo workspace** of small, single-responsibility crates ("services"). They are wired
together at startup into **one process** (`tether-proxy`), but each is independently
compilable, testable, and — if cloud/team mode is ever needed — independently deployable.

## 2.1 Crate / service map (Rust)

```
proxy/                         ← Cargo workspace root
├── Cargo.toml                 (workspace members)
├── crates/
│   ├── tether-domain/           shared model types + error kinds (no I/O, no deps on others)
│   ├── tether-contracts/        service interface traits + DTOs (+ OpenAPI annotations)
│   ├── tether-storage/          SQLite pool, migrations, low-level row mappers
│   ├── tether-crypto/           AES-GCM helpers for stored secrets
│   ├── tether-gateway/          transparent reverse proxy: routing, forwarding, response tee
│   ├── tether-cache/            sha256-keyed response store (get / put / clear)
│   ├── tether-trace/            trace ingestion, summarization, cost calc, query API
│   ├── tether-auth/             JWT issue/verify, Google OAuth
│   ├── tether-settings/         profile + app settings + encrypted API keys
│   └── tether-http/             Axum router assembly: mounts each service's routes
└── src/main.rs                bootstrap: build deps, compose services, serve (thin)
```

### Dependency direction (no cycles)

```
            tether-domain  ◄── everything depends on this (types only)
                ▲
        tether-contracts   (traits + DTOs; depends on domain)
                ▲
   ┌────────────┼─────────────┬───────────┬──────────┐
 cache        trace          auth      settings   ← service crates
   │            │             │          │        (each impls a contract trait,
   └──── tether-storage / tether-crypto ──────┘          │         talks to storage, never to
                ▲                                     │         a sibling's internals)
            tether-gateway  (uses cache + trace via their traits)
                ▲
            tether-http  (mounts routes from every service)
                ▲
            src/main.rs (composition root)
```

**Rule:** a service crate may depend on `tether-domain`, `tether-contracts`, `tether-storage`,
`tether-crypto` — never on another service crate's internals. Cross-service calls go through
a `tether-contracts` trait. The composition root (`main.rs`) is the only place that knows the
concrete wiring.

## 2.2 Why this enables future scale without paying for it now

Each service exposes a trait in `tether-contracts`, e.g.:

```rust
// tether-contracts/src/cache.rs
#[async_trait]
pub trait CacheService: Send + Sync {
    async fn get(&self, key: &CacheKey) -> Result<Option<CachedResponse>, DomainError>;
    async fn put(&self, key: CacheKey, value: CachedResponse) -> Result<(), DomainError>;
    async fn clear(&self) -> Result<(), DomainError>;
}
```

- **Today (local):** `tether-gateway` holds an `Arc<dyn CacheService>` that is the in-process
  `tether-cache` impl. Zero network cost.
- **Later (cloud, optional):** add a `CacheServiceHttpClient` impl of the same trait. The
  gateway is unchanged. Only the composition root swaps the binding.

This is the payoff of microservice *thinking* without microservice *operations*.

## 2.3 Hot-path decoupling: async trace ingestion

The latency-sensitive forward path must not block on trace persistence.

```
 gateway forwards request ──► tee response ──► return to client (fast path ends here)
                                   │
                                   └──► send CapturedCall to an in-process mpsc channel
                                                 │
                                   tether-trace ingestion worker (background task)
                                   summarize → cost → persist to trace_calls
```

The gateway depends on a `TraceSink` trait (`fn capture(&self, call: CapturedCall)`); the
local impl is "push to channel". This keeps forwarding fast and makes trace logic testable
in isolation.

## 2.4 SwiftUI app target architecture

Keep the existing package products, but reorganize into **feature-scoped** folders with each
file ≤200 lines and a clear layer split. The Codex observer is treated as an **ingestion
adapter** (a source of `TraceSnapshot`), mirroring the backend's "trace source" concept.

```
TetherModules/Sources/
├── Core/
│   ├── Models/           one type per file (AgentNode.swift, TraceSnapshot.swift, …)
│   └── Features/         TCA reducers (one feature per folder)
├── Networking/
│   ├── ProxyAPI/         TraceAPIClient split by endpoint group
│   └── Codex/            CodexLogObserver split: Database / Query / Mapper / SnapshotBuilder
├── UI/
│   ├── DesignSystem/     palette, LiquidGlass modifier, theme — separate files
│   └── <Feature>/        view + subviews per feature, ≤200 lines each
└── App/                  composition root, dependency wiring
```

State (`TraceStore`) is split into: the observable store, the `ProxyConnectionStatus` model,
a `TraceRefreshCoordinator` (polling/refresh), a `SessionsController`, and a pure
`SnapshotCombiner`. See [04-code-organization](./04-code-organization.md) for the exact split.

## 2.5 Single source of truth for DTOs

`tether-contracts` carries the wire DTOs and is annotated to emit an **OpenAPI** spec
(`/openapi.json`). The Swift `Codable` models are documented as *generated/derived* from that
spec (see [05-documentation-strategy](./05-documentation-strategy.md)), eliminating the
hand-maintained drift between Rust and Swift model definitions.

## 2.6 Auto-fix execution layer

Auto-fix is a confirmed execution layer on top of the trace graph, not part of
capture. The capture path records what happened. The action path proposes and
executes a recovery only after the user confirms the exact plan.

```
failed trace node
      │
      ▼
Tether.app ActionEngine builds ActionPlan
      │
      ▼
ConfirmActionSheet shows exact commands/API calls and credential use
      │
      ▼
KeychainStore reads token after confirmation
      │
      ▼
POST /internal/actions/execute
      │
      ▼
Rust executor runs localhost-only action
      │
      ▼
repair action row + repair graph node
```

### App components

```
Tether.app
├── FailedNodeView        failed node + Auto-fix entry point
├── ConfirmActionSheet    exact action list, credential use, and risk summary
├── RepairResultView      graph node/result view after execution
├── ActionEngine.swift    builds plans and sends confirmed execution requests
└── KeychainStore.swift   reads credentials only after confirmation
```

### Proxy components

```
Rust proxy
├── action_router.rs      /internal/actions/execute
├── trace_db.rs           repair action persistence and repair graph nodes
└── executors/
    ├── github.rs         GitHub API calls and gh-backed flows
    ├── llm_retry.rs      replay/retry with a patched prompt
    └── shell.rs          sandboxed local shell commands
```

### Repair action storage

Repair actions are stored separately from raw captured calls, then rendered into
the graph as repair nodes linked back to the failed node.

```sql
CREATE TABLE repair_actions (
  id          TEXT PRIMARY KEY,
  session_id  TEXT NOT NULL,
  caused_by   TEXT NOT NULL,
  action_type TEXT NOT NULL,
  payload     TEXT NOT NULL,
  status      TEXT NOT NULL,
  result      TEXT,
  created_at  INTEGER NOT NULL
);
```

### Security boundary

Credentials remain app-owned. Tokens live in macOS Keychain, are read only after
the user confirms the action plan, and are sent to the proxy only for that one
localhost request. The proxy must not persist tokens, echo them into logs, or
write them into trace/repair rows.

### V1 scope

Priority order:

1. GitHub executor: `git push`, PR creation, and retrying failed GitHub API calls
   with a confirmed token.
2. LLM retry executor: confirmed prompt patch and downstream replay only.
3. Shell executor: sandboxed commands such as dependency install or validation.

Non-goals for v1:

- no autonomous mode
- no token storage in proxy or SQLite
- no custom credential manager beyond Keychain
- no remote execution
- no shell execution without an explicit sandbox and confirmation step
