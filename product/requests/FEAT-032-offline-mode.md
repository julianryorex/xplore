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

Cache active trip itinerary in Hive (partially started in FEAT-006). Optional offline map region download (Google Maps offline API or static snapshots for itinerary stops only).

## Dependencies

- FEAT-006, FEAT-020 (Plus gating)

## Notes / history

- 2025-06-22: Created
