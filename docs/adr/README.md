# Architecture Decision Records

Each ADR captures one significant decision: its context, the choice made, and the
consequences. ADRs are **append-only** — a superseded decision is marked `Superseded by
NNNN`, never deleted or rewritten.

Format per record: **Context · Decision · Consequences · Status**.

## Index

| # | Title | Status |
|---|-------|--------|
| [0001](./0001-modular-monolith.md) | Modular monolith over networked microservices | Accepted |
| [0002](./0002-trait-based-service-boundaries.md) | Trait-based service boundaries | Accepted |

> Planned (to be written as their phase lands):
> - 0003 — Async trace ingestion to decouple the proxy hot path (Phase 3)
> - 0004 — OpenAPI as the single source of truth for wire DTOs (Phase 4)
