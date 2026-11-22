# FEAT-032: Offline Itinerary & Map Tiles

| Field | Value |
|-------|-------|
| **ID** | FEAT-032 |
| **Priority** | P3 |
| **Status** | `backlog` |
| **Revenue impact** | retention |
| **Effort** | L |
| **Owner** | — |

## Problem

Travelers lose connectivity abroad. Itinerary and map are useless without network — Plus tier promises offline export.

## Proposed solution

Cache active trip itinerary in Hive (partially started in FEAT-006). Download the itinerary, tickets and trip-wallet documents, and **map tiles for the trip area** automatically the night before departure. Edits made offline sync when the phone reconnects. Included with Trip Pass and Plus (FEAT-020).

## Dependencies

- FEAT-006, FEAT-020 (Plus gating)

## Notes / history

- 2025-06-22: Created
- 2026-11-22: Aligned with the launch-post vision ([launch-post.html](../launch-post.html)).
