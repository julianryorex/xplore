# Features Under Consideration

A holding area for product ideas that are promising but **not yet promoted to a full spec**. These are lighter than `requests/FEAT-*.md` on purpose. When one is ready to schedule, copy it into `requests/` via [`requests/_TEMPLATE.md`](./requests/_TEMPLATE.md), give it a FEAT number, and add it to [BACKLOG.md](./BACKLOG.md).

Keep entries short: what it is, why it's valuable, rough effort, and how it relates to existing work.

---

## Experience / engagement

- **Public shareable itinerary / trip page** — a live, read-only web link to a trip (pre/during), like Wanderlog "guides". Acquisition loop. Distinct from FEAT-023 (post-trip recap). Effort M.
- **Activity feed with substance** — fill the notifications shell with real trip events ("Maya added 3 stops", "Liam joined", "12 new photos"). Gives the app a heartbeat. Bridges FEAT-012. Effort M.
- **Comments / reactions on stops** — lightweight collaboration between full chat (FEAT-033) and formal voting (FEAT-041); often the sweet spot. Effort S–M.
- **Trip countdown / anticipation moment** — countdown to the start date with a bit of delight; drives pre-trip opens. Effort S.
- **Inline weather per day / destination** — show forecast on day cards; a light standalone slice of FEAT-037's weather data; big perceived-quality lift. Effort S–M.

## From the launch-post vision

Features described in [launch-post.html](./launch-post.html) that have no spec yet.

- **Regroup** — one tap picks a meeting point that is fair for everyone and sends each person walking directions. Builds on FEAT-013 and FEAT-040. Effort M.
- **Split up, meet back** — parallel tracks for part of a day, with a planned point where they rejoin. Builds on FEAT-019. Effort L.
- **Remix a trip** — publish a finished itinerary as a template another group can copy and let Scout adapt. Trips stay private unless published. Effort M.
- **Watch and car** — next stop and leave-by time on the wrist; regroup directions in CarPlay and Android Auto. Effort L.
- **Browser preview for guests** — an invite link shows the full itinerary on the web before install, and joining needs only a name. Extends FEAT-003. Effort M.
- **Web app for planning** — full planning on a big screen. Effort XL.
- **Live translation** — menus and signs translated from inside a stop. Effort M.

## Cross-cutting foundations

- **Localization, currency & units, destination time zones** — table stakes for international travel; currently single-locale. Show local time at the destination. Effort M–L.
- **Accessibility pass** — fixed dark/liquid-glass theme; review contrast, dynamic type, VoiceOver. Effort M.

## Monetization-leaning

- **Printed travel books / auto recap reels** — tasteful paid physical/share product leveraging the gallery (Polarsteps model). Extends FEAT-023. Effort M–L. Revenue: direct.

---

## Promoted to specs

Moved out of this doc into `requests/` (kept here for traceability):

- In-trip Today/Now view → FEAT-018
- Richer itinerary block types → FEAT-019
- Collaborative packing list & checklist → FEAT-038
- Saved places / wishlist + share-in capture → FEAT-039
- Personal travel profile & stats → FEAT-048
- Tool-augmented AI planning & travel integrations → FEAT-037
- Destination arrival moments → FEAT-047

## Notes / history

- 2026-06-26: Created from the UX/monetization gap review.
