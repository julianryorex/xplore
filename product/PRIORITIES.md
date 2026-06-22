# Priority Framework

## Tiers

| Tier | Meaning | Ship when |
|------|---------|-----------|
| **P0** | Launch blocker — app cannot earn money or retain real users without this | Immediately |
| **P1** | Core value — completes the promised group-travel loop | After P0 stable |
| **P2** | Monetization & growth — turns usage into revenue or viral loops | After ≥1 real multi-user trip flow works |
| **P3** | Expansion — new platforms, partnerships, polish | After paid tier validated |
| **P4** | Enhancement — quality-of-life, experimental | Backlog / opportunistic |

## Scoring rubric (for new requests)

When adding a request, estimate each 1–5 (5 = highest). **Priority tier is set by humans/PM**, not auto-calculated — use scores to inform placement.

| Dimension | Question |
|-----------|----------|
| **User impact** | How many users / how often does this unblock a job-to-be-done? |
| **Revenue impact** | Blocker / enabler / direct revenue / none |
| **Strategic fit** | Does it strengthen group-native differentiation? |
| **Effort** | S / M / L / XL engineering estimate |
| **Risk** | Technical, legal, or platform risk if we delay |

## Revenue impact labels

Used in [BACKLOG.md](./BACKLOG.md):

| Label | Meaning |
|-------|---------|
| `blocker` | Cannot charge or operate legally/safely without it (e.g. auth) |
| `enabler` | Required before paywall, limits, or billing make sense |
| `direct` | Directly generates revenue (subscription, credits, affiliate) |
| `retention` | Improves repeat trips → indirect revenue |
| `indirect` | Brand, polish, or cost reduction |
| `none` | Important but not monetization-related |

## Agent / developer rules

1. **Never skip P0** for a flashy P2 feature unless the user explicitly reprioritizes.
2. Prefer requests that **remove hardcoded demo assumptions** (`itineraryId`, `userId`, `ph4kd` paths).
3. Match existing architecture: feature-first modules, Cubits, Freezed models, Firebase + Hive.
4. Update request status when starting (`in_progress`) and finishing (`done` + PR link).
