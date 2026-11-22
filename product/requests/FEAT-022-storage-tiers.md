# FEAT-022: Gallery Storage Tiers & Limits

| Field | Value |
|-------|-------|
| **ID** | FEAT-022 |
| **Priority** | P2 |
| **Status** | `backlog` |
| **Revenue impact** | direct |
| **Effort** | M |
| **Owner** | — |

## Problem

Firebase Storage costs scale with full-resolution gallery uploads (the full-detail original is uploaded intentionally; only the local thumbnail is compressed). Free users could upload unbounded photos without revenue offset.

## Proposed solution

Track aggregate bytes per trip in Firestore (updated on upload complete). Soft warnings at 80%; block uploads at the cap unless the trip is upgraded or the buyer adds storage at **$0.99 per GB per month**. Show usage in trip settings.

## Acceptance criteria

- [ ] Per-trip byte counter maintained
- [ ] Upload blocked with paywall at free tier cap (500 MB default)
- [ ] Trip Pass and Plus cap of 10 GB per trip; Hosts cap of 50 GB per trip
- [ ] Storage overage purchase at $0.99/GB/mo

## Dependencies

- FEAT-011 (trip-scoped gallery paths, shipped), FEAT-020, FEAT-043 (compression reduces COGS)

## Notes / history

- 2025-06-22: Created
- 2026-11-22: Aligned with the launch-post vision ([launch-post.html](../launch-post.html)).
