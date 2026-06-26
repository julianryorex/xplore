# FEAT-009: Home redesign

| Field | Value |
|-------|-------|
| **ID** | FEAT-009 |
| **Priority** | P1 |
| **Status** | `in_progress` |
| **Revenue impact** | retention / indirect |
| **Effort** | M |
| **Owner** | — |

## Problem

Home had three issues: the "Daily Plans → See all" action wrongly opened the
create sheet; there was no hero treatment for the active trip; and the active
trip always rendered a standing "Invite friends" prompt (`_InviteTripCard`),
which reads as *incomplete* for a solo traveller — at odds with the FEAT-007
solo-first principle.

## Proposed solution

Design-led pass (done after FEAT-007/008 so Home renders real, dev-clutter-free
content):

- **Hero active-trip card** — gradient cover, title, destination, dates,
  group-size line, and an *available* invite action (icon button), never a nag.
- **Real empty state** — a "Plan your next trip" prompt whose primary CTA
  launches the FEAT-007 flow.
- **Correct CTAs** — the "Your trip" section action and empty-state button both
  launch `/create-trip`; removed the broken "See all → create sheet".
- **Solo-first copy** — a 1-member trip reads "Solo trip", and invite is an
  action you can take, not a prompt you must clear.

## User stories

- As a user, I want Home to show my active trip front-and-centre, so I land
  back in context.
- As a solo traveller, I want Home to feel complete without inviting anyone.

## Acceptance criteria

- [x] Primary CTA launches the FEAT-007 create flow (no more create sheet).
- [x] Hero active-trip card with cover, dates, destination, group size.
- [x] Real populated/empty/error states for the trip section.
- [x] `_InviteTripCard` standing prompt reframed into an available invite action.
- [ ] Member **avatars** on the hero (deferred — needs member profile fetch; shows count for now).

## Success metrics

- Create-flow entries from Home.
- Reduced confusion taps on the old "See all" action (qualitative).

## Dependencies

- FEAT-007 (create flow) and FEAT-008 (dev page) land first.

## Related code

- `lib/screens/home_page.dart` — `_TripHero`, `_ActiveTripCard`, `_CreateTripPrompt`

## Open questions

- Member avatars vs. count on the hero (needs a members/profile fetch path).
- Cover image: gradient placeholder until real cover selection ships.

## Notes / history

- 2026-06-26: Created and implemented on `feat/trip-creation-dev-home`.
