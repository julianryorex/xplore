# Product Backlog

Ranked feature requests for Xplore. **Work top-to-bottom within each tier.**

Legend: **Status** — `backlog` · `ready_for_dev` (full spec written) · `in_progress` · `done` · `wont_do`

> **Next up:** [FEAT-006 Production itinerary data layer](./requests/FEAT-006-itinerary-firebase-sync.md) — makes the active trip from FEAT-002 load real cloud itinerary data instead of demo JSON.

---

## P0 — Launch blockers

Cannot onboard real groups or operate as a product without these.

| ID | Feature | Revenue | Effort | Status | Request |
|----|---------|---------|--------|--------|---------|
| FEAT-003 | Trip invites & join flow | blocker | L | backlog | [→](./requests/FEAT-003-trip-invites.md) |
| FEAT-005 | Onboarding flow | blocker | M | backlog | [→](./requests/FEAT-005-onboarding.md) |
| FEAT-006 | Production itinerary data layer | blocker | L | backlog | [→](./requests/FEAT-006-itinerary-firebase-sync.md) |

---

## P1 — Core group-travel value

Completes the promise: plan together, stay together, remember together.

| ID | Feature | Revenue | Effort | Status | Request |
|----|---------|---------|--------|--------|---------|
| FEAT-010 | Wire Gemini AI itinerary generation into UI | retention | L | backlog | [→](./requests/FEAT-010-ai-itinerary-ui.md) |
| FEAT-011 | Gallery sync across devices (cloud fetch) | retention | M | backlog | [→](./requests/FEAT-011-gallery-cloud-sync.md) |
| FEAT-012 | Push notifications | retention | M | backlog | [→](./requests/FEAT-012-push-notifications.md) |
| FEAT-013 | Background location updates | retention | L | backlog | [→](./requests/FEAT-013-background-location.md) |
| FEAT-014 | Trip-scoped gallery & storage paths | enabler | S | backlog | [→](./requests/FEAT-014-trip-scoped-gallery.md) |
| FEAT-015 | Profile sync (name, avatar to cloud) | retention | M | backlog | [→](./requests/FEAT-015-profile-cloud-sync.md) |
| FEAT-016 | Itinerary checklist completion sync | retention | M | backlog | [→](./requests/FEAT-016-itinerary-completion-sync.md) |
| FEAT-017 | Map marker info & last-seen UX | indirect | S | backlog | [→](./requests/FEAT-017-map-marker-info.md) |

---

## P2 — Monetization & growth

Turn active trips into revenue and viral loops.

| ID | Feature | Revenue | Effort | Status | Request |
|----|---------|---------|--------|--------|---------|
| FEAT-020 | Subscription / Xplore Plus paywall | direct | L | backlog | [→](./requests/FEAT-020-subscription-paywall.md) |
| FEAT-021 | AI itinerary credits & usage limits | direct | M | backlog | [→](./requests/FEAT-021-ai-credits.md) |
| FEAT-022 | Gallery storage tiers & limits | direct | M | backlog | [→](./requests/FEAT-022-storage-tiers.md) |
| FEAT-023 | Trip recap & shareable link | indirect | M | backlog | [→](./requests/FEAT-023-trip-recap-share.md) |
| FEAT-024 | Trip organizer role & permissions | enabler | M | backlog | [→](./requests/FEAT-024-organizer-roles.md) |
| FEAT-025 | Analytics & funnel events | enabler | M | backlog | [→](./requests/FEAT-025-analytics-events.md) |
| FEAT-026 | Referral / invite rewards | indirect | M | backlog | [→](./requests/FEAT-026-referral-invites.md) |

---

## P3 — Expansion

New platforms, partnerships, and power features.

| ID | Feature | Revenue | Effort | Status | Request |
|----|---------|---------|--------|--------|---------|
| FEAT-030 | Android platform support | indirect | L | backlog | [→](./requests/FEAT-030-android-support.md) |
| FEAT-031 | Activity booking affiliate links | direct | M | backlog | [→](./requests/FEAT-031-activity-affiliates.md) |
| FEAT-032 | Offline itinerary & map tiles | retention | L | backlog | [→](./requests/FEAT-032-offline-mode.md) |
| FEAT-033 | In-app trip chat / activity feed | retention | L | backlog | [→](./requests/FEAT-033-trip-chat.md) |
| FEAT-034 | Expense splitting (Splitwise-lite) | retention | L | backlog | [→](./requests/FEAT-034-expense-splitting.md) |
| FEAT-035 | CI/CD pipeline | indirect | M | backlog | [→](./requests/FEAT-035-cicd-pipeline.md) |
| FEAT-036 | Test suite (unit, widget, integration) | indirect | L | `in_progress` | [→](./requests/FEAT-036-test-suite.md) |

---

## P4 — Enhancements

Quality-of-life and experimental; pick up when higher tiers are stable.

| ID | Feature | Revenue | Effort | Status | Request |
|----|---------|---------|--------|--------|---------|
| FEAT-040 | Map transit directions | none | M | backlog | [→](./requests/FEAT-040-map-transit.md) |
| FEAT-041 | Collaborative itinerary voting | retention | M | backlog | [→](./requests/FEAT-041-itinerary-voting.md) |
| FEAT-042 | Video gallery support | retention | M | backlog | [→](./requests/FEAT-042-video-gallery.md) |
| FEAT-044 | Neighborhood / geofence alerts | retention | L | backlog | [→](./requests/FEAT-044-geofence-alerts.md) |
| FEAT-045 | B2B tour operator dashboard | direct | XL | backlog | [→](./requests/FEAT-045-b2b-dashboard.md) |
| FEAT-046 | Profile avatar map-marker pipeline | retention | M | backlog | [→](./requests/FEAT-046-map-avatar-marker-pipeline.md) |

---

## Done

Shipped features live in [`requests/done/`](./requests/done/). Move a spec here when the work merges; update its `Status` to `done` and note the PR.

| ID | Feature | Shipped | Request |
|----|---------|---------|---------|
| FEAT-001 | User authentication (Firebase Auth) | PR #73 | [→](./requests/done/FEAT-001-user-authentication.md) |
| FEAT-002 | Trip entity & multi-trip management (foundation) | PR #79 | [→](./requests/done/FEAT-002-trip-management.md) |
| FEAT-004 | Replace hardcoded trip/user IDs | PR #76 | [→](./requests/done/FEAT-004-remove-hardcoded-ids.md) |
| FEAT-043 | Re-enable image compression (iOS 26) | PR #71 | [→](./requests/done/FEAT-043-image-compression.md) |

---

## Suggested implementation order (first 6 sprints)

1. ~~**FEAT-001** Auth → **FEAT-004** Remove hardcoded IDs~~ ✅
2. ~~**FEAT-002** Trips~~ ✅ → **FEAT-006** Itinerary Firebase sync
3. **FEAT-003** Invites → **FEAT-005** Onboarding
4. **FEAT-014** Trip-scoped gallery → **FEAT-011** Gallery cloud fetch
5. **FEAT-025** Analytics → **FEAT-010** AI itinerary UI
6. **FEAT-024** Organizer roles → **FEAT-020** Subscription paywall

See [MONETIZATION.md](./MONETIZATION.md) for why paywall comes after multi-user trips work.
