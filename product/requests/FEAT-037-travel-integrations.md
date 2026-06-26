# FEAT-037: Tool-Augmented AI Planning & Travel Integrations

| Field | Value |
|-------|-------|
| **ID** | FEAT-037 |
| **Priority** | P3 |
| **Status** | `backlog` |
| **Revenue impact** | direct |
| **Effort** | XL |
| **Owner** | — |

## Problem

Generated itineraries (FEAT-010) reason from model training data alone: stops can be stale or invented, there are no real prices, and high-intent moments ("book this tour", "get a ride to the next stop", "where do we stay?") have no action. This both caps plan quality and leaves affiliate/booking revenue on the table. Competitors that win on quality (Mindtrip, Layla) do so by grounding the LLM in **live data** (real POIs, prices, availability) and by turning the plan into something you can actually **book and run your trip from**.

## Proposed solution

An umbrella epic that turns Xplore's AI planner into a **tool-augmented travel agent** and a set of **lifecycle integrations**. The LLM (Gemini, via function calling) becomes an orchestrator that calls real data/booking tools instead of hallucinating, and itinerary surfaces gain contextual booking/transport actions. Integrations are mostly **affiliate-based**, so they generate revenue without charging the user — complementing the paywall (FEAT-020) rather than competing with it.

Build it as a **decoupled tool layer** (one adapter per provider, ideally MCP-style tool/server boundaries) so the generation logic stays independent of any single vendor, and providers can be added/swapped without touching the planning flow.

### Integration surface (by trip lifecycle)

- **Before — booking/logistics:** flights (Duffel/Amadeus for booking; Skyscanner/Kiwi for affiliate), lodging (Booking.com/Expedia affiliate; Airbnb via affiliate/deep link only — no open API), trains/buses/car (Omio, Trainline, Kayak), activities & tickets (GetYourGuide, Viator, Klook — see FEAT-031), restaurant reservations (OpenTable/Resy/Google Reserve).
- **During — in-destination:** rideshare deep links/ETA (Uber/Lyft/Bolt), public transit & directions (Google Directions/Citymapper — see FEAT-040), Apple/Google Wallet passes.
- **After / cross-cutting:** expense splitting (see FEAT-034), calendar export (Google/Apple), booking-confirmation email parsing to auto-populate the trip (Wanderlog/TripIt pattern).
- **LLM-grounding data (not user-facing buttons):** Google Places/Maps (POI details, ratings, photos, hours, `place_id`), weather (forecast-aware planning), currency/FX.

### LLM-as-orchestrator (the core unlock)

Expose provider adapters to Gemini as callable tools, e.g. `search_places(query, near)`, `find_flights(origin, dest, dates)`, `search_stays(area, dates, budget)`, `estimate_ride(from, to)`, `get_weather(place, date)`. The model plans by calling these and reasoning over real results, which fixes hallucination and the `place_id` credibility gap, and enables weather/route-aware adjustments.

## User stories

- As a traveler, I want generated stops to be real, currently-open places with ratings and photos, so I trust the plan.
- As an organizer, I want to book a tour, reserve a table, or hail a ride from inside the itinerary, so I don't app-switch.
- As a planner, I want the AI to adjust the day when it's forecast to rain or when stops are far apart, so the plan is realistic.
- As the business, we want affiliate/booking revenue from high-intent actions without paywalling core planning.

## Acceptance criteria

- [ ] A provider-agnostic tool/adapter layer (one adapter per integration; swappable; MCP-style boundary preferred)
- [ ] Gemini function-calling wired to grounding tools (Places + weather at minimum) feeding generation
- [ ] At least one bookable affiliate action live end-to-end (e.g. activities via GetYourGuide/Viator) with affiliate disclosure
- [ ] Rideshare and directions actions on itinerary stops (deep link + ETA)
- [ ] Tool calls cached; AI+tool usage gated by credits (FEAT-021)
- [ ] Graceful degradation when a provider is unavailable (fall back to non-tool generation)

## Success metrics

- ≥X% of generated stops resolve to a real `place_id` with rating/photo
- Affiliate click-through and booking conversion from itinerary CTAs
- AI plans with tool grounding edited (not discarded) at a higher rate than ungrounded plans

## Dependencies

- **FEAT-010** (Gemini itinerary generation) and **FEAT-021** (AI credits/limits) must land first — this augments that engine
- **FEAT-006** (production itinerary data layer) for persisting enriched stops
- Subsumes / coordinates with **FEAT-031** (activity affiliates), **FEAT-040** (map transit), **FEAT-034** (expenses)
- External: partner/affiliate agreements; booking APIs require approval, volume thresholds, and PCI/compliance for in-app payments

## Related code

- `pubspec.yaml` — `flutter_gemini` (function calling)
- `lib/features/itinerary/models/itinerary_models.dart` — `LocationPlanModel.placeId` (enrichment target)
- `lib/screens/itinerary_focus_page.dart` — booking/rideshare/directions CTAs
- `lib/features/map/` — `MapCanvas` for live-pinned, route-aware plans

## Open questions

- Build the tool layer as in-process adapters vs. true MCP servers?
- Which provider per category to launch first (highest affiliate yield vs. easiest integration)?
- In-app booking (Duffel/payments, heavier compliance) vs. affiliate redirect only for v1?
- How aggressively to cache tool results to control cost/latency?

## Notes / history

- 2026-06-26: Created. Out-of-scope for the near-term trip-creation work (FEAT-007); scheduled late, after the AI engine (FEAT-010/021). Originated from integrations brainstorm (flights, rideshare, lodging) + the competitor finding that grounded, tool-augmented generation is what separates top AI planners.
