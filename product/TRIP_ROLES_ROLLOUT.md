# Trip Roles Rollout Plan

A product-level plan for shipping itinerary editing and trip roles (owner, admin, member).
It says what a group can do after each stage and in what order to build it. The rules
themselves live in [FEAT-024](./requests/FEAT-024-organizer-roles.md); the itinerary edit
path lives in [FEAT-006](./requests/FEAT-006-itinerary-firebase-sync.md).

Each stage is something a real group could use on its own. Stages 1 to 3 together are the
smallest version worth giving to a real group.

## Decisions this plan rests on

- Everyone joins a trip as a member. Only the owner promotes a member to admin.
- Only the owner and admins change the itinerary. Members see it read-only.
- No cap on the number of admins.
- Every change records who made it and when. Nothing in the app shows this yet.
- The plan is assumed to be drafted by Scout and adjusted by people. Stops are real places
  by default; a custom stop with no place is the fallback.
- Last write wins if two people edit at the same moment.

## Stage 1 — The owner can edit the plan

- The owner can add a stop by searching for a real place, so the stop gets a map pin,
  opening hours and directions.
- The owner can add a custom stop for something that is not a place. It is marked as custom
  and has no pin.
- The owner can swap a stop for another place, edit its note, delete it and reorder stops.
- The owner can add, rename and remove days, from an "Edit days" row on Home.
- Tapping a stop still opens its detail page for everyone; the owner edits from an Edit
  button there.
- A failed save shows a clear message with a retry; the plan never disappears while saving.
- Every change records who made it and when, from the first edit, even though nothing shows it.
  The author can be a person or Scout.

**Needs:** place search. The app does not call Google Places directly; search goes through
our backend, and stage 1 uses mock place data until that exists. A picked place's details
are saved on the stop so viewing the plan never searches again.

**Not in stage 1:** any "by Scout" labelling. It is hidden until Scout ships.

**Why first:** whoever drafts the plan, a person has to be able to correct it, and roles mean
nothing until there is something to edit. Until Scout is wired into the app this stage is
tested against seeded or hand-entered stops.

**Designs:** https://claude.ai/artifact/JpjPa1wEPNsurcpghrpV2r (private canvas).

## Stage 2 — Members can see who runs the trip

- A people list for the trip, with a badge on the owner.
- Members see the plan with no edit controls, rather than controls that fail.
- A short line telling members who to ask for a change.

**Why second:** it makes the read-only experience feel intended, and it is the screen that
promotion lives on.

## Stage 3 — The owner can promote an admin

- From the people list, the owner makes a member an admin or takes it away, with a confirmation.
- The admin gets the same editing as the owner in stage 1.
- Edit controls appear or disappear on that person's phone straight away.
- The person is told they were promoted.
- Admins get a badge in the people list.

**Why third:** this is the core of the feature, and it needs both the editing from stage 1
and the people list from stage 2.

## Stage 4 — Admins help run the trip

- Admins can create and share invite links.
- Admins can change the trip name, dates and places.
- Members lose those two abilities if they have them today. What members can currently do
  here has not been checked.

## Stage 5 — Owner housekeeping

- Remove a person from the trip.
- Transfer ownership to someone else.
- The owner cannot leave until they transfer; members and admins can leave freely.
- Delete the trip.

## Later, when the features they depend on exist

- Members suggest options and admins open votes — needs voting
  ([FEAT-041](./requests/FEAT-041-itinerary-voting.md)).
- Scout only changes the plan when an owner or admin asks — needs Scout in the app
  ([FEAT-037](./requests/FEAT-037-travel-integrations.md)).
- Show who changed what, and undo, using the record kept since stage 1.
