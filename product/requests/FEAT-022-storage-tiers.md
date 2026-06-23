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

Track aggregate bytes per trip in Firestore (updated on upload complete). Soft warnings at 80%; block uploads at cap unless Plus or storage add-on. Show usage in trip settings.

## Acceptance criteria

- [ ] Per-trip byte counter maintained
- [ ] Upload blocked with paywall at free tier cap (500 MB default)
- [ ] Plus tier higher cap (10 GB default)

## Dependencies

- FEAT-014, FEAT-020, FEAT-043 (compression reduces COGS)

## Notes / history

- 2025-06-22: Created
