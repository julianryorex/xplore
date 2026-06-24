# Xplore Product

This folder is the **source of truth for product intent** — what Xplore is building, why, how it makes money, and which features to pick up next. Developers and agents should read here before starting net-new feature work.

## What Xplore is

Xplore is a **group-travel companion** for friends and families on a shared trip. The core loop:

1. **Plan together** — day-by-day itineraries with stops, descriptions, and completion checklists.
2. **Stay together** — live member locations on a styled Google Map with avatar markers.
3. **Remember together** — a collaborative photo gallery synced to the cloud.

The app is Flutter + Firebase today, with experimental Gemini AI for itinerary generation. Auth, trip context, and dynamic user IDs are shipped; itinerary data is still demo JSON until FEAT-006 — see [CURRENT_STATE.md](./CURRENT_STATE.md).

## How to use this folder

| Document | Purpose |
|----------|---------|
| [VISION.md](./VISION.md) | Target users, positioning, north-star metrics |
| [MONETIZATION.md](./MONETIZATION.md) | Revenue models and pricing hypotheses |
| [PRIORITIES.md](./PRIORITIES.md) | Priority tiers (P0–P4) and scoring rubric |
| [BACKLOG.md](./BACKLOG.md) | **Start here** — ranked index of all feature requests |
| [CURRENT_STATE.md](./CURRENT_STATE.md) | What ships today vs. gaps |
| [requests/](./requests/) | Open feature requests (detail + acceptance criteria) |
| [requests/done/](./requests/done/) | Shipped feature specs (archived from `requests/`) |
| [requests/_TEMPLATE.md](./requests/_TEMPLATE.md) | Copy this when adding a new request |
| [GitHub issue filing](../.github/ISSUE_FILING.md) | How agents file issues from Slack or PR review |

### Product specs vs GitHub issues

| Layer | Location | Purpose |
|-------|----------|---------|
| **Spec** | `requests/FEAT-*.md` or `requests/done/FEAT-*.md` + [BACKLOG.md](./BACKLOG.md) | Why, acceptance criteria, priority rationale |
| **Work item** | [GitHub Issues](https://github.com/julianryorex/xplore/issues) | Actionable task — link from PRs, close when shipped |

File new work via Slack `#xplore-requests` (Issue Filer agent) or the GitHub issue templates. Agents that spot follow-up work use an `issue-proposal` block — see [ISSUE_FILING.md](../.github/ISSUE_FILING.md).

### Adding a new request

1. Copy `requests/_TEMPLATE.md` → `requests/FEAT-XXX-short-slug.md`.
2. Fill in all sections; link related code paths under `lib/`.
3. Add a row to [BACKLOG.md](./BACKLOG.md) in the correct priority section.
4. Set `Status: backlog` unless work has started.

### Picking up work (developers & agents)

1. Read [BACKLOG.md](./BACKLOG.md) top-down within each tier — **P0 before P1**, etc.
2. Open the linked request file for acceptance criteria and code pointers.
3. Do not implement monetization gates (P2+) until P0 foundation (auth, trips, invites) is in place unless explicitly scoped.
4. After shipping, set `Status: done`, note the PR in the request file, move it to
   `requests/done/`, and move its row from the backlog tier tables to the **Done**
   section in [BACKLOG.md](./BACKLOG.md).

## Quick links to code

| Area | Entry points |
|------|----------------|
| App bootstrap | `lib/main.dart` |
| Routing | `lib/routes.dart` |
| Itinerary | `lib/features/itinerary/` |
| Live map | `lib/features/map/`, `lib/features/location/` |
| Gallery | `lib/features/gallery/` |
| Profile | `lib/features/profile/` |
| Hardcoded trip/user | `lib/constants/constants.dart` |

The README [Roadmap](../README.md#roadmap) lists engineering todos; this folder adds **product context and revenue-aware prioritization** on top of that list.
