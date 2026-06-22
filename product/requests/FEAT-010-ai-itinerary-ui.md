# FEAT-010: Wire Gemini AI Itinerary Generation into UI

| Field | Value |
|-------|-------|
| **ID** | FEAT-010 |
| **Priority** | P1 |
| **Status** | `backlog` |
| **Revenue impact** | retention |
| **Effort** | L |
| **Owner** | — |

## Problem

README advertises AI itinerary generation via Gemini, and `flutter_gemini` is in `pubspec.yaml`, but there is no user-facing flow. Organizers still need manual entry — a major friction point and missed premium differentiator.

## Proposed solution

Add **"Plan with AI"** entry on trip creation or itinerary empty state: prompt for destination, dates, vibe → call Gemini → parse JSON into `ItineraryModel` → preview → save to Firebase (FEAT-006). Gate regens behind FEAT-021 credits on free tier.

## User stories

- As an organizer, I want a draft 3-day Tokyo plan from a sentence, so I don't start from scratch.
- As a Plus subscriber, I want unlimited AI regens while refining the trip.

## Acceptance criteria

- [ ] UI flow: prompt → loading → editable preview → confirm
- [ ] Output validates against `ItineraryModel.fromJson`
- [ ] Uses `GEMINI_API_KEY` from `assets/.env`
- [ ] Error states for API failure / malformed JSON
- [ ] Save generated plan to active trip

## Success metrics

- ≥30% of new trips use AI assist at least once
- AI-generated plans edited (not discarded) > 50%

## Dependencies

- FEAT-006, FEAT-002; FEAT-021 for monetization limits

## Related code

- `pubspec.yaml` — `flutter_gemini`
- `assets/.env` — `GEMINI_API_KEY`
- `lib/features/itinerary/models/itinerary_models.dart`

## Open questions

- Structured output / JSON mode vs. prompt engineering?
- Include Google Places enrichment for `place_id`?

## Notes / history

- 2025-06-22: Created
