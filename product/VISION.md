# Product Vision

## One-liner

**Xplore keeps travel groups aligned — on the plan, on the map, and in the memories.**

## Target users

### Primary — Friend-group trip organizer (the "planner")

- Ages 25–40, plans 1–3 group trips per year (bachelor parties, reunions, multi-city adventures).
- Already the person with the Google Doc, Splitwise group, and iMessage thread.
- Pain: coordinating *where everyone is* and *what's next* without constant texting.

### Secondary — Trip participant

- Wants a low-friction view of today's plan and where friends are.
- Contributes photos; doesn't want to install five single-purpose apps.

### Future — Tour operators & retreat hosts (B2B)

- Runs recurring group trips; needs white-label or multi-group admin.
- Higher willingness to pay; lower volume than consumer.

## Jobs to be done

| Job | Current support | Gap |
|-----|-----------------|-----|
| "See today's plan at a glance" | Strong UI (carousel + drill-down) | Tied to demo JSON, single trip |
| "Know where my friends are right now" | Real-time Firebase sync + map markers | Hardcoded user/trip; no invites |
| "Share trip photos in one place" | Upload + Hive cache + Firebase Storage | No cross-device fetch; no per-trip scoping in UI |
| "Plan the trip without spreadsheet hell" | Gemini experiment (not in UI) | Not wired to main flow |
| "Join a trip my friend set up" | Not built | Blocker for real usage |

## Positioning

Compete on **group-native** design — not a generic itinerary app bolted onto a map. Differentiators to protect:

- Avatar markers on a dark neon map (visual identity already strong).
- Itinerary ↔ map ↔ gallery as one trip context, not three apps.
- AI-assisted planning as a premium wedge once foundation exists.

## North-star metrics

| Metric | Definition | Why |
|--------|------------|-----|
| **Active trips** | Trips with ≥2 members and activity in last 7 days | Core unit of value |
| **Trip completion rate** | % of created trips that reach end date with ≥1 gallery upload | Retention signal |
| **Invites accepted / sent** | Viral loop health | Growth without paid UA |
| **Paid trip organizers** | Users on a paid tier or who bought AI credits | Revenue |

## Non-goals (for now)

- Full OTA booking stack (flights/hotels) — affiliate links only later.
- Solo traveler mode — group context is the product.
- Social network / discovery feed — trips are private by default.
