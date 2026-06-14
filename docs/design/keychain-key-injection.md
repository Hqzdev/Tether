# Design & Handoff: Keychain-backed API keys + proxy key injection

**Status:** Ready to implement
**Scope decided:** Keychain storage + proxy credential injection **now**; SQLite cache encryption documented as a **follow-up** (see §8).
**Target repo:** fork of `Hqzdev/Tether`
**Spec date:** 2026-06-11

---

## 1. Why this exists (the gap)

The README and landing page claim API keys live in the **macOS Keychain** and the app is **"air-gapped."** The current code does **not** deliver this:

- `proxy/src/main.rs::proxy()` forwards whatever `Authorization` header the SDK already sent, straight to the upstream. The proxy never sources a key itself.
- The only key *storage* that exists is the **Postgres** `user_settings.api_key_openai/anthropic` columns (AES-GCM via `proxy/src/crypto.rs`) — part of the optional web-auth feature, **not wired into the forwarding path**, and server-side.
- **There is zero Keychain code anywhere in the project.**

This work closes that gap for the local desktop flow: the macOS app stores provider keys in the Keychain, hands them to the local proxy at launch, and the proxy injects them onto upstream calls so the agent itself never needs to hold a key.

## 2. Goals / non-goals

**Goals**
- Store OpenAI + Anthropic API keys in the macOS Keychain via the app's Settings UI.
- Proxy injects the right credential header on upstream calls **only when the incoming request didn't carry its own** (client-supplied keys always win — backward compatible).
- No new third-party dependencies (Apple `Security` framework is a system framework; Rust side uses only `std` + already-present `http`/`axum` types).

**Non-goals (this PR)**
- Encrypting the local SQLite cache (`loom-cache.sqlite`). Designed in §8, deferred.
- Touching the Postgres web-auth key storage. Left as-is.
- Fabricating the Anthropic `anthropic-version` header (stays the client's responsibility; see §7).

## 3. Architecture

One spine serves the feature — a secret lives in the Keychain, the app reads it, the launcher passes it as an env var, the proxy injects it:

```
macOS Keychain --(Swift: KeychainStore)--> LocalProxyLauncher sets env --> Rust proxy
  generic-password items:            OPENAI_API_KEY=...                 - on forward, if the client
   - openai-api-key                  ANTHROPIC_API_KEY=...                sent no credential, inject
   - anthropic-api-key                                                   Authorization / x-api-key
```

Why env vars (not IPC): `LocalProxyLauncher` already builds the proxy's environment in `proxyEnvironment(runtimeDirectory:)`. Reusing that channel means **no new endpoint, no new protocol, no key ever written to disk by the proxy.** The environment of a 127.0.0.1-only child process started by the app is an acceptable boundary for a local-first tool.

## 4. Files touched

| File | Change | Module |
|---|---|---|
| `proxy/src/main.rs` | `AppState` gains two key fields; read them in `main()`; inject in `proxy()`; two helper fns | Rust |
| `proxy/.env.example` | document `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` | docs |
| `ui/Sources/Networking/KeychainStore.swift` | **new** — `Security`-framework generic-password wrapper | `Networking` |
| `ui/Sources/Networking/LocalProxyLauncher.swift` | read keys from `KeychainStore`, set env | `Networking` |
| `ui/Loom/Features/Settings/AppSettingsView.swift` | "Provider Keys" section + save on Save&Restart | app target |

**No `.pbxproj` edit needed.** `Networking` is a SwiftPM target whose sources are the `ui/Sources/Networking/` directory; SwiftPM compiles every `.swift` in it, and the Xcode app consumes the package as a product. A new file in that directory is picked up automatically.

## 5. Implementation — Rust (`proxy/src/main.rs`)

### 5a. Add fields to `AppState`

```rust
#[derive(Clone)]
pub(crate) struct AppState {
    client: reqwest::Client,
    openai_upstream: Arc<str>,
    anthropic_upstream: Arc<str>,
    db: Arc<Mutex<Connection>>,
    cache_enabled: bool,
    auth: Option<Arc<AuthContext>>,
    /// Provider credentials sourced from the local environment (the macOS app
    /// reads these out of the Keychain and passes them in at launch). When set,
    /// the proxy injects them on upstream calls that arrive without their own
    /// credential — so the agent never needs to hold the key.
    openai_api_key: Option<Arc<str>>,
    anthropic_api_key: Option<Arc<str>>,
}
```

### 5b. Read them in `main()` (after the `cache_enabled` line)

```rust
    let openai_api_key = read_api_key("OPENAI_API_KEY");
    let anthropic_api_key = read_api_key("ANTHROPIC_API_KEY");
```

And add to the `AppState { ... }` construction:

```rust
        openai_api_key,
        anthropic_api_key,
```

### 5c. Startup visibility (optional but recommended — "fail loud")

Insert before the `Point an agent here...` println:

```rust
    let key_label = |present: bool| if present { "injected from env" } else { "client-supplied" };
    println!(
        "  {DIM}openai key: {} · anthropic key: {}{RESET}",
        key_label(state.openai_api_key.is_some()),
        key_label(state.anthropic_api_key.is_some())
    );
```

### 5d. Inject in `proxy()` — right after the header-copy loop, before `let upstream = state...`

```rust
    // Inject provider credentials sourced from the local environment (Keychain)
    // only when the incoming request didn't carry its own. Client-supplied keys
    // always win, so this is backward compatible with key-bearing agents.
    inject_credentials(&mut headers, label, &state);
```

### 5e. Helper functions (place near the other free functions, e.g. above `is_hop_by_hop`)

```rust
/// Read a non-empty provider API key from the environment.
fn read_api_key(var: &str) -> Option<Arc<str>> {
    std::env::var(var)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .map(|value| Arc::from(value.as_str()))
}

/// Inject provider credentials into the outbound header set when the client
/// didn't supply its own. OpenAI uses `Authorization: Bearer <key>`; Anthropic
/// uses `x-api-key: <key>`. We deliberately do NOT fabricate `anthropic-version`
/// — that stays the client's responsibility (see spec §7).
fn inject_credentials(headers: &mut HeaderMap, label: &str, state: &AppState) {
    match label {
        "anthropic" => {
            if headers.contains_key("x-api-key") {
                return;
            }
            if let Some(key) = state.anthropic_api_key.as_deref() {
                match HeaderValue::from_str(key) {
                    Ok(mut value) => {
                        value.set_sensitive(true);
                        headers.insert(HeaderName::from_static("x-api-key"), value);
                    }
                    Err(_) => eprintln!(
                        "{RED}✖ ANTHROPIC_API_KEY is not a valid header value; not injecting{RESET}"
                    ),
                }
            }
        }
        _ => {
            if headers.contains_key("authorization") {
                return;
            }
            if let Some(key) = state.openai_api_key.as_deref() {
                match HeaderValue::from_str(&format!("Bearer {key}")) {
                    Ok(mut value) => {
                        value.set_sensitive(true);
                        headers.insert(HeaderName::from_static("authorization"), value);
                    }
                    Err(_) => eprintln!(
                        "{RED}✖ OPENAI_API_KEY is not a valid header value; not injecting{RESET}"
                    ),
                }
            }
        }
    }
}
```

**Notes for the implementer**
- `HeaderMap`, `HeaderName`, `HeaderValue` are already imported at the top of `main.rs`. No new imports.
- `HeaderValue::set_sensitive(true)` marks the value so it's redacted from `http`'s debug output — verify the signature against the resolved `http` crate version before relying on it; drop the line if absent (cosmetic only).
- `label` is already `"anthropic"` for `/v1/messages*` and `"openai"` otherwise (existing code). The `_` arm = OpenAI/Codex ("everything else").
- Injection happens **after** the verbatim header copy, so a client that *did* send a key still passes through untouched.

## 6. Implementation — Swift

### 6a. New file `ui/Sources/Networking/KeychainStore.swift`

```swift
import Foundation
import Security

/// Thin wrapper over the macOS Keychain (generic-password items) for provider
/// API keys. Uses only Apple's Security framework — no third-party dependency.
public enum KeychainStore {
    public static let service = "dev.tether.loom.providerKeys"

    public enum Account: String, CaseIterable {
        case openAIAPIKey = "openai-api-key"
        case anthropicAPIKey = "anthropic-api-key"
    }

    public static func read(_ account: Account) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return value
    }

    @discardableResult
    public static func save(_ account: Account, value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return delete(account)
        }
        guard let data = trimmed.data(using: .utf8) else { return false }

        let query = baseQuery(account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        if updateStatus == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
            return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    @discardableResult
    public static func delete(_ account: Account) -> Bool {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    public static func hasValue(_ account: Account) -> Bool {
        read(account) != nil
    }

    private static func baseQuery(_ account: Account) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue
        ]
    }
}
```

### 6b. `ui/Sources/Networking/LocalProxyLauncher.swift` — set env from Keychain

In `proxyEnvironment(runtimeDirectory:)`, before `return environment`:

```swift
        if let openAIKey = KeychainStore.read(.openAIAPIKey) {
            environment["OPENAI_API_KEY"] = openAIKey
        }
        if let anthropicKey = KeychainStore.read(.anthropicAPIKey) {
            environment["ANTHROPIC_API_KEY"] = anthropicKey
        }
```

`KeychainStore` is in the same `Networking` module — no import needed. Because the keys are read at launch, `LocalProxyLauncher.restart()` (already called by Settings) is what propagates a newly saved key to the running proxy.

### 6c. `ui/Loom/Features/Settings/AppSettingsView.swift` — UI

Add state to `ProxySettingsView`:

```swift
    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var openAIKeyStored = KeychainStore.hasValue(.openAIAPIKey)
    @State private var anthropicKeyStored = KeychainStore.hasValue(.anthropicAPIKey)
```

Add a section inside the main `VStack(spacing: 16)`, after `Upstream URLs`. **Match the live palette-styled components** — `SettingsSection`/`SettingsRow` take a `palette:` arg and fields use the `.settingsField(palette:)` modifier (not `.roundedBorder`):

```swift
                SettingsSection("Provider Keys", palette: palette) {
                    SettingsRow("OpenAI", palette: palette) {
                        SecureField(openAIKeyStored ? "•••••••• stored" : "sk-…", text: $openAIKey)
                            .settingsField(palette: palette)
                            .frame(maxWidth: 300)
                    }
                    SettingsRow("Anthropic", palette: palette) {
                        SecureField(anthropicKeyStored ? "•••••••• stored" : "sk-ant-…", text: $anthropicKey)
                            .settingsField(palette: palette)
                            .frame(maxWidth: 300)
                    }
                    Text("Stored in the macOS Keychain. The proxy injects these on upstream calls when your client doesn't send its own key.")
                        .font(.caption)
                        .foregroundStyle(palette.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
```

In `saveAndRestart()`, persist keys **after** settings are saved and **before** the restart so the relaunched proxy reads the new env:

```swift
    private func saveAndRestart() {
        do {
            let settings = try validatedSettings()
            ProxySettingsStore.save(settings)

            if !openAIKey.isEmpty {
                KeychainStore.save(.openAIAPIKey, value: openAIKey)
                openAIKey = ""
                openAIKeyStored = true
            }
            if !anthropicKey.isEmpty {
                KeychainStore.save(.anthropicAPIKey, value: anthropicKey)
                anthropicKey = ""
                anthropicKeyStored = true
            }

            LocalProxyLauncher.shared.restart()
            footerMessage = "Requires proxy restart"
            footerMessageIsError = false
        } catch {
            footerMessage = error.localizedDescription
            footerMessageIsError = true
        }
    }
```

Deleting a key is intentionally **not** wired in this PR (an empty field is treated as "leave unchanged"). Add a per-key "Remove" button calling `KeychainStore.delete(_:)` as a small follow-up if desired.

### 6d. `proxy/.env.example` — document the new vars

Add under the existing local proxy settings:

```
# Provider API keys. The macOS app sources these from the Keychain and passes
# them in at launch; you can also set them directly for headless/CLI use. When
# set, the proxy injects the credential on upstream calls that arrive without
# their own. Leave unset to require the agent to supply its own key.
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
```

## 7. Caveats the implementer + PR reviewer must know

1. **Keychain ACLs vs ad-hoc signing.** Keychain item access binds to the app's code-signing identity. `scripts/package-dmg.sh` currently ad-hoc signs (`codesign --sign -`), so there is no stable identity — expect a Keychain authorization prompt on launch and possibly again after each rebuild. For a smooth experience the project needs a real Developer ID signing identity. **Call this out in the PR; it is not a bug in this code.**
2. **Anthropic `anthropic-version` header.** We inject only `x-api-key`. Anthropic also requires `anthropic-version`; real clients (Claude Code, the SDKs) always send it, so a key-less agent that *also* omits `anthropic-version` will get a 400 from Anthropic. Documented, intentional — do not fabricate a version string.
3. **Env vars are visible to the child process only.** Keys are passed to the 127.0.0.1-only proxy child process's environment, never written to disk by the proxy. They are not logged (`set_sensitive(true)`; and `trace.rs` already stores no headers — verified during review). Acceptable for a local-first tool; note it in the PR's security section.
4. **Sandbox.** The app ships with `ENABLE_APP_SANDBOX=NO`. Keychain access works either way, but if the project later enables the sandbox, add the Keychain Sharing / `keychain-access-groups` entitlement.

## 8. Follow-up design: encrypting the local SQLite cache

`loom-cache.sqlite` stores prompts + responses in plaintext. Deferred from this PR; two viable approaches when picked up:

**Option A — SQLCipher (whole-file, recommended for strength).**
- Switch `rusqlite` to its SQLCipher-backed build (verify the exact feature flag against current `rusqlite` docs — it exposes a bundled-SQLCipher feature) and run `PRAGMA key = '<key>';` immediately after `Connection::open`.
- Key source: generate a random 32-byte key on first run, store it in the Keychain (new `Account` case, e.g. `cacheEncryptionKey`), pass to the proxy as `LOOM_DB_KEY` via the same launcher env channel.
- **Breaks `scripts/smoke-e2e.sh`**, which reads the cache with the stock `sqlite3` CLI (`sqlite3 "$DB_PATH" "select count(*)…"`). Fix: query through a SQLCipher-aware path or have the test open with the key. `CodexLogObserver` is unaffected (it reads Codex's own `~/.codex` DBs, not our cache).

**Option B — field-level AES-GCM (no new dependency).**
- Reuse the existing `aes-gcm` crate already in `Cargo.toml` (`proxy/src/crypto.rs::KeyCipher` is a ready pattern). Encrypt only the sensitive columns (`body`, `req_preview`, `model`, and the trace `prompt_*`/`response_text` columns) before insert; decrypt on read.
- Cache lookups still work — the cache key is a SHA-256 hash, not encrypted.
- The `sqlite3` CLI can still open the file (structure intact), so the smoke test keeps working; only column contents are ciphertext.
- More code surface than Option A and no protection for the DB structure/metadata.

Key-management spine is identical either way: random key → Keychain → env → proxy. Decide A vs B at implementation time.

## 9. Verification checklist

Rust:
- [ ] `cargo build --manifest-path proxy/Cargo.toml` clean.
- [ ] `cargo clippy` clean (the helpers add no warnings).
- [ ] Start proxy with `OPENAI_API_KEY` set; send a request **without** an `Authorization` header; confirm upstream receives `Authorization: Bearer …` (point `OPENAI_UPSTREAM` at a local echo server).
- [ ] Send a request **with** an `Authorization` header; confirm the client's value passes through unchanged (no override).
- [ ] Repeat both for `/v1/messages` + `ANTHROPIC_API_KEY` → `x-api-key`.
- [ ] `scripts/smoke-e2e.sh` still passes (no key set → pass-through path unchanged).

Swift / app:
- [ ] `swift build` in `ui/` compiles the `Networking` target with the new file.
- [ ] App builds in Xcode (`xcodebuild -project ui/Loom.xcodeproj -scheme Tether build`).
- [ ] Enter keys in Settings → Save & Restart → confirm Keychain items exist:
      `security find-generic-password -s dev.tether.loom.providerKeys -a openai-api-key`
- [ ] Restarted proxy log shows `openai key: injected from env`.
- [ ] End-to-end: configure an agent with **no** key pointed at `http://127.0.0.1:8080`; confirm the call succeeds using the Keychain key.

## 10. Suggested PR breakdown

1. **PR 1 — proxy injection** (`main.rs`, `.env.example`): self-contained, testable via curl + smoke test. Lowest risk, merge first.
2. **PR 2 — Keychain + Settings UI** (`KeychainStore.swift`, `LocalProxyLauncher.swift`, `AppSettingsView.swift`): depends on PR 1's env contract.
3. **PR 3 (later) — cache encryption** per §8.

Keeping injection and UI as separate PRs lets the Rust change land and get exercised (including headless/CLI users) before the macOS-only UI work.
