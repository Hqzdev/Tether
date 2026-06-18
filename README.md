# Tether
### The local command center for AI agent debugging.

Tether intercepts, visualizes, caches, replays, and mocks LLM calls so builders can understand every agent decision before it reaches production.

[Website](https://tetherapp.vercel.app) • [Docs](https://tetherapp.vercel.app/docs) • [GitHub](https://github.com/Hqzdev/Tether)

---

## Product Vision

AI agents are becoming production systems, but the tools around them still feel like logs, guesswork, and late-night incident reports.

Tether turns the invisible work of an agent into a living interface: every request, tool call, cached response, failure, replay, and cost signal becomes something a developer can inspect and trust. It is built for the moment when "the model did something weird" is no longer an acceptable debugging strategy.

The product is local-first by design. Prompts stay on the machine. API keys stay in the Keychain. Traces stay in local storage. Teams get the clarity of an observability platform without surrendering sensitive agent data to another cloud dashboard.

---

## Core Capabilities

### Moderation / Security

| Feature | Description |
| --- | --- |
| Local Privacy Engine | Capture prompts, responses, metadata, and provider calls without shipping sensitive traces to a third-party backend. |
| Keychain-Aware Secrets | Keep API credentials in macOS Keychain instead of scattering tokens across scripts, shells, and notebooks. |
| Audit-Ready Trace History | Review what happened, when it happened, which provider was called, and how the agent moved through the flow. |

### Engagement / Growth

| Feature | Description |
| --- | --- |
| Faster Debugging Loops | Turn unclear agent behavior into a visual story developers, founders, and product teams can discuss together. |
| Provider-Agnostic Workflow | Work across OpenAI, Anthropic, Ollama, LM Studio, LangChain, LangGraph, LlamaIndex, and OpenAI-compatible APIs. |
| Product-Grade Observability | Make agent quality easier to improve by seeing latency, cache hits, failures, and response structure in context. |

### Automation

| Feature | Description |
| --- | --- |
| Zero-SDK Proxy | Point your client at `http://localhost:8080/v1` and capture calls without rewriting your app. |
| Smart Response Caching | Reuse known responses during development to cut latency, cost, and repetitive provider calls. |
| Time-Travel Replay | Edit a previous response, replay a chain, and test downstream behavior without rerunning the entire workflow. |

### Monetization

| Feature | Description |
| --- | --- |
| Cost Visibility | See which calls cost money, which calls came from cache, and where development spend is leaking. |
| Latency-to-Value Signals | Understand whether a provider, model, cache layer, or tool step is slowing the experience down. |
| Usage-Aware Product Decisions | Connect agent behavior to cost, reliability, and product polish before scaling usage. |

### Community Infrastructure

| Feature | Description |
| --- | --- |
| Shared Debugging Language | Replace scattered terminal output with a clear UI your team can use to reason about agent behavior. |
| Local Test Workbench | Mock responses, reproduce failures, and iterate on agent flows without depending on live provider state. |
| Extensible Agent Surface | Designed to grow into a deeper infrastructure layer for local agent testing, replay, and observability. |

---

## Why This Product

1. **No-code first debugging**  
   Capture agent behavior through a local proxy instead of instrumenting every SDK call by hand.

2. **Modular system**  
   Use Tether as a visual debugger, cache layer, replay tool, privacy layer, or local observability console.

3. **Real-time analytics**  
   Inspect latency, cache state, model metadata, errors, and response flow while the agent is still running.

4. **Built for scale**  
   Start with one local workflow, then expand into repeatable debugging patterns for larger agent systems.

5. **Privacy-first architecture**  
   Agent traces, prompts, responses, and keys stay local by default.

6. **AI-native architecture**  
   Built around LLM calls, tool chains, replay, mocks, provider adapters, and the messy shape of modern agent workflows.

---

## UI Preview

This README intentionally avoids embedding generated screenshots. The repository does not include an
`images/` directory, so preview references should match screens that can be opened from the current
web and macOS app code.

---

## Tech Stack

| Layer | Stack |
| --- | --- |
| Frontend | Next.js 15 / React 19 / TypeScript |
| UI | Hugeicons / custom component system / macOS-inspired interface patterns |
| Styling | Custom CSS design tokens, adaptive layouts, dark and light theme support |
| Backend | Next.js API routes / Rust local proxy |
| Email | Resend-powered waitlist flow |
| Data | Local SQLite traces / local cache metadata |
| Hosting | Vercel-ready web deployment |

---

## Pages Overview

| Page or Route | Description |
| --- | --- |
| `/` | Product landing page with hero, product proof, sample trace inspector, setup steps, privacy review, feedback, and alpha access sections. |
| `/#features` | On-page product proof section with the Visual Tree Canvas and feature cards. |
| `/#demo` | On-page embedded sample trace inspector with graph, cache, replay, and privacy states. |
| `/#security` | On-page privacy review section with storage, key handling, telemetry, and replay evidence. |
| `/#download` | On-page feedback and alpha access section. |
| `/product`, `/features`, `/inspector`, `/how-it-works`, `/download` | Data-driven product information pages generated from `web/lib/site-pages.ts`. |
| `/developers`, `/documentation`, `/cli-reference`, `/changelog`, `/company`, `/privacy`, `/security`, `/contact` | Additional generated information pages. |
| `/docs` and `/docs/[slug]` | Documentation hub and detail pages generated from `web/lib/docs-pages.ts`. |
| `/api/waitlist` | Waitlist capture endpoint for early access requests. |
| `/api/feedback` | Landing-page feedback endpoint. |

---

## Visual Identity

Tether is designed like a premium developer instrument, not a marketing toy.

**Gradient system**  
Soft electric accents sit on top of dark, technical surfaces. Color is used for state, motion, and focus instead of decoration.

**Typography hierarchy**  
Large editorial headlines explain the product story, while compact interface typography keeps traces, metadata, and actions readable.

**Motion & micro-interactions**  
Subtle transitions make agent flow feel alive: nodes update, states shift, panels respond, and replay actions feel immediate.

**Capsule UI**  
Pills, segmented controls, compact status chips, and rounded command surfaces create a polished operating-system feel.

**Adaptive layouts**  
The site scales from landing-page storytelling to dense developer UI without losing rhythm, hierarchy, or scanability.

---

## Quick Start

```bash
git clone https://github.com/Hqzdev/Tether.git
cd Tether/web
npm install
npm run dev
```

The web app runs at:

```bash
http://localhost:3000
```

For a production build:

```bash
npm run build
npm start
```

---

## Connect CometAPI

CometAPI powers cross-model replay in the macOS inspector. After Tether has captured a node, you can replay the stored request with another model and compare the result in the replay diff sheet.

1. Open the macOS app.
2. Go to Settings -> Extensions.
3. Paste your CometAPI API key in the CometAPI section.
4. Click Save & Test.
5. Select any captured graph node, open the inspector footer, choose a model under Cross-model replay, and click Replay with that model.

The key is saved through the local proxy endpoint `PUT /api/settings/cometapi-key`. This CometAPI workflow does not require storing the key in macOS Keychain.

---

## Contributing

Read [CONTRIBUTING.md](./CONTRIBUTING.md) before making changes. Code style, required English function comments, and documentation ownership rules live in [CODESTYLE.md](./CODESTYLE.md).

---

## Roadmap

### Now

- Local proxy capture for OpenAI-compatible requests
- Visual trace graph for multi-step agent workflows
- Smart caching and replay-ready response history
- macOS-first interface with privacy-focused local storage

### Next

- Rich provider adapters for OpenAI, Anthropic, Ollama, and LM Studio
- Replay workbench for edited responses and deterministic test runs
- Download page, release channel, and polished DMG distribution
- Deeper docs for LangChain, LangGraph, and LlamaIndex workflows

### Future

- Platform expansion beyond local macOS workflows
- AI customization engine for trace summaries, test suggestions, and failure diagnosis
- Team-ready trace sharing with privacy controls
- Plugin ecosystem for agent frameworks, evals, and internal tools

---

## Built by Hqz.dev

Designed with obsession for community experience.
