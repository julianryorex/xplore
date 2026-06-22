# Monetization Strategy

Revenue should follow **real group usage**, not pre-launch feature count. Ship P0 foundation first; turn on paid tiers once trips have multiple members and repeat usage.

## Recommended model: Freemium + organizer pays

### Free tier — "Xplore"

Enough to run one real trip and prove value:

- 1 active trip at a time
- Up to 6 trip members
- Shared itinerary, map, gallery
- Limited gallery storage (e.g. 500 MB per trip)
- Manual itinerary editing only

### Paid tier — "Xplore Plus" (~$4.99/mo or $19.99/trip pass)

Organizer or any member can upgrade; benefits apply to the whole trip:

- Unlimited active trips
- Up to 20 members per trip
- AI itinerary generation (included quota, e.g. 5 full trips/mo)
- Extended gallery storage (e.g. 10 GB per trip)
- Offline itinerary export
- Priority location sync interval

**Why organizer-pays:** One decision-maker, aligns with Splitwise/TripIt patterns, reduces payment friction for guests.

### Add-on: AI credits

For users who want AI planning without full subscription:

- $2.99 per AI-generated multi-day itinerary
- Bundles: 3 for $6.99

Uses existing `flutter_gemini` dependency; gate by server-side or client-side quota once auth exists.

## Secondary revenue (P3+)

| Stream | Mechanism | Notes |
|--------|-----------|-------|
| **Activity affiliates** | Deep links from `LocationPlanModel` stops to GetYourGuide, Viator, OpenTable | Requires Places enrichment; disclose affiliate relationship |
| **Storage overage** | $0.99/GB/mo beyond tier limit | Offsets Firebase Storage COGS |
| **B2B / tour operator** | Per-group monthly seat pricing | Needs admin dashboard, branding — later horizon |

## Unit economics to watch

| Cost driver | Mitigation |
|-------------|------------|
| Firebase Realtime DB (location polling) | Tier location update interval; stale-marker UX already exists |
| Firebase Storage (gallery) | Compression (re-enable when iOS SDK allows), storage caps on free tier |
| Gemini API | Credit limits, cache generated itineraries, user-edited regen only |
| Google Maps | Static map snapshots for sharing vs. live map sessions |

## Monetization gates in the backlog

Features tagged `Revenue: enabler` in [BACKLOG.md](./BACKLOG.md) should not ship before:

1. Firebase Auth + per-user identity
2. Trip entity with membership (replaces `itineraryId` / `userId` constants)
3. Basic analytics events (trip created, invite accepted, upgrade tapped)

## Pricing experiments (post-MVP)

- Trip pass vs. subscription A/B on first upgrade prompt
- "Sponsor this trip" — one payment unlocks Plus for all members for trip duration
- Annual plan for frequent travelers ($29.99/yr)
