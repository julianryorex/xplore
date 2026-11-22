# FEAT-024: Trip Roles & Permissions (Owner, Admin, Member)

| Field | Value |
|-------|-------|
| **ID** | FEAT-024 |
| **Priority** | P2 |
| **Status** | `backlog` |
| **Revenue impact** | enabler |
| **Effort** | M |
| **Owner** | — |

## Problem

Everyone who joins a trip has the same standing, and only the creator can edit the itinerary. A trip usually has one planner and one or two co-planners; the rest of the group follows the plan. There is no way for the planner to share editing with a co-planner, and no data model that says who may change what. Billing also assumes an identifiable organizer.

## Proposed solution

Three roles on the trip membership record: `owner`, `admin`, `member`.

- **Everyone joins as a member.** An invite link always grants `member`; there is no invite that grants admin.
- **Only the owner promotes.** The owner can promote a member to admin and demote an admin back to member, from the trip's people list.
- **Only the owner and admins change the itinerary.** Members see the plan read-only. This extends the owner-only editing model in FEAT-006 to "owner or admin"; it does not open editing to the whole group.
- **Members still take part.** They vote on options (FEAT-041), add to the wishlist (FEAT-039), upload photos, share location and mark their own progress. Those are the member's ways to influence the plan without editing it.

### Permission matrix

| Action | Owner | Admin | Member |
|--------|:-----:|:-----:|:------:|
| View itinerary, map, gallery | ✓ | ✓ | ✓ |
| Share location, go invisible | ✓ | ✓ | ✓ |
| Upload photos, delete own photos | ✓ | ✓ | ✓ |
| Vote, add to wishlist | ✓ | ✓ | ✓ |
| Buy a Trip Pass for the trip (FEAT-020) | ✓ | ✓ | ✓ |
| Leave the trip | — | ✓ | ✓ |
| Add, edit, delete, reorder days and stops | ✓ | ✓ | — |
| Ask Scout to change the plan (FEAT-037) | ✓ | ✓ | — |
| Open and close votes | ✓ | ✓ | — |
| Create and share invite links | ✓ | ✓ | — |
| Edit trip name, dates, places | ✓ | ✓ | — |
| Promote member to admin, demote admin | ✓ | — | — |
| Remove a person from the trip | ✓ | — | — |
| Transfer ownership | ✓ | — | — |
| Delete the trip | ✓ | — | — |

## Decisions (locked)

- **No cap on admins.** The owner can promote as many members as they like.
- **Record who edits, do not show it yet.** Every itinerary change stores who made it and when. Nothing in the app displays this for now; it is there so attribution, history and undo can be added later without a gap in the record.
- **Last write wins.** If two editors change the plan at the same moment, the later save stands. No conflict handling in this version.

## User stories

- As an owner, I want to make my co-planner an admin, so they can change the plan without me.
- As an owner, I want everyone else to be unable to edit, so nobody changes the group's day by accident.
- As a member, I want to see who the admins are, so I know who to ask for a change.
- As an admin, I want to be told when I am promoted, so I know I can edit.

## Acceptance criteria

- [ ] Role stored per member on the trip (`owner` / `admin` / `member`); existing trips are migrated with the creator as `owner` and everyone else as `member`
- [ ] Joining through an invite link always results in `member`
- [ ] Owner can promote a member to admin and demote an admin from the people list, behind the shared confirmation dialog
- [ ] Itinerary writes are allowed for owner and admins only, enforced in the Firestore rule, in `ItineraryCubit.canEdit`, and by hiding edit chrome for members
- [ ] Scout plan changes are accepted only when requested by an owner or admin
- [ ] Every itinerary change records who made it and when; nothing is displayed yet
- [ ] No limit on the number of admins per trip
- [ ] A role change takes effect on the affected device without a restart (edit chrome appears or disappears live)
- [ ] People list shows a role badge for the owner and admins
- [ ] Promote, demote, remove, transfer ownership and delete trip are owner-only in UI and rules
- [ ] A trip always has exactly one owner; the owner cannot leave without transferring ownership first
- [ ] Rules tests cover: member write denied, admin write allowed, admin cannot change roles, member cannot promote themselves

## Success metrics

- Share of active trips with at least one admin besides the owner
- Itinerary edits made by admins vs. the owner
- Zero itinerary writes from members in rules logs

## Dependencies

- FEAT-002 (trip membership), FEAT-006 (itinerary edit path; this spec widens its gate)
- Consumed by FEAT-020 (who can buy), FEAT-037 (who can direct Scout), FEAT-041 (who opens votes), FEAT-045 (Hosts)

## Related code

- `lib/features/trip/models/` — trip membership record
- `lib/features/itinerary/bloc/itinerary_cubit.dart` — `_canEdit`
- `infra/rules/firestore.rules` — `validItineraryUpdate` and trip membership rules

## Open questions

- Can admins remove members, or does that stay owner-only as specified here?
- The launch post calls invitees "guests". Keep `member` as the stored role and "guest" as marketing copy, or introduce a separate pre-install guest state for the browser preview?

## Notes / history

- 2025-06-22: Created
- 2026-11-22: Aligned with the launch-post vision ([launch-post.html](../launch-post.html)) — every member could edit.
- 2026-11-22: Reversed the "every member can edit" model. Editing is limited to the owner and admins; invitees join as members and the owner promotes. Roles renamed from `owner` / `organizer` / `member` to `owner` / `admin` / `member`. Decided: no admin cap, edits are recorded but not shown, last write wins.
