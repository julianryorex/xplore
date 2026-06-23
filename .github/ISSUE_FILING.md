# Issue filing (agents & Slack)

GitHub Issues are the **execution queue**. Product intent stays in `product/requests/FEAT-*.md` and [BACKLOG.md](../product/BACKLOG.md).

| Layer | Owns |
|-------|------|
| `product/requests/` | Problem, acceptance criteria, priority rationale |
| GitHub Issue | Actionable work — linkable from PRs, closeable when done |
| Slack `#xplore-requests` | Where human or agent requests start; Issue Filer replies in thread |

Only the **Issue Filer** agent creates GitHub issues. Other agents emit structured proposals.

When a PR completes an issue, its description must include `Closes #N` (see
[AGENTS.md](../AGENTS.md) and [.github/pull_request_template.md](./pull_request_template.md)).

---

## Issue Filer (Cursor Automation)

Create one automation in Cursor with these settings:

| Field | Value |
|-------|--------|
| **Name** | `xplore Issue Filer` |
| **Trigger** | Slack — new message in `#xplore-requests` |
| **Repo** | `julianryorex/xplore` (branch `main`) |
| **Tools** | Post to Slack, Read Slack, shell (`gh`) |
| **Completion** | React with `:white_check_mark:` on the triggering message when done |

### Instructions (paste into automation prompt)

```text
You file GitHub issues for julianryorex/xplore. You do NOT implement code.

When triggered by a Slack message in #xplore-requests:

1. Read the triggering message and thread context.

2. Deduplicate before creating anything:
   - Run: gh issue list --repo julianryorex/xplore --state open --limit 100
   - Search product/BACKLOG.md and product/requests/ for similar FEAT IDs or titles.
   - If a match exists, reply in the Slack thread with the existing issue or FEAT link. Stop.

3. Determine the request type:
   - References FEAT-XXX or "file issue for FEAT-…" → read product/requests/FEAT-XXX-*.md and file from that spec (label source:product).
   - Freeform feature idea → draft issue from product/requests/_TEMPLATE.md sections (label needs-feat-file if no spec exists).
   - Contains an issue-proposal block (see below) → parse fields from the block (label source:agent unless source says otherwise).

4. Create the issue with gh issue create:
   - Title: "[FEAT-XXX] …" for features, "[improvement] …" for improvements
   - Labels: type (feature or improvement), priority (P0–P4), source (source:slack, source:agent, or source:product), and needs-feat-file when applicable
   - Body sections: Problem, Proposed solution (if feature), Acceptance criteria (checkbox list), Related code, Product spec (path or "needs FEAT file"), Source

5. If the idea is substantial and no FEAT file exists, open a PR that adds product/requests/FEAT-XXX-slug.md (copy _TEMPLATE.md), adds a row to product/BACKLOG.md, and links the new issue in the PR body. Use the next free FEAT number after scanning existing files.

6. Reply in the Slack thread with the issue URL and a one-line summary.

Never create duplicate issues. Never implement feature code in this automation.
```

### Optional second automation (PR review handoff)

| Field | Value |
|-------|--------|
| **Trigger** | GitHub — comment added on pull request |
| **Filter** | Comment body contains `issue-proposal` |
| **Instructions** | Parse the HTML comment block, dedupe, create issue with label source:agent, comment on PR: "Tracked in #N (out of scope for this PR)." |

---

## issue-proposal block (for other agents)

Review, triage, and scout agents **must not** run `gh issue create`. Instead, append this block to a PR comment or Slack message:

```markdown
<!-- issue-proposal
title: Retry gallery uploads on transient Firebase errors
type: improvement
priority: P2
source: pr-review
related: lib/features/gallery/bloc/gallery_cubit.dart
problem: Uploads fail silently when the network drops mid-transfer.
acceptance:
- Retry up to 3 times with exponential backoff
- Surface failed state in UI after exhaustion
-->
```

| Field | Required | Values |
|-------|----------|--------|
| `title` | yes | Short issue title |
| `type` | yes | `feature` or `improvement` |
| `priority` | yes | `P0` … `P4` |
| `source` | yes | e.g. `pr-review`, `triage`, `slack` |
| `related` | no | Comma-separated paths under `lib/` |
| `problem` | yes | One paragraph |
| `acceptance` | yes | One criterion per line (with or without `- `) |

The Issue Filer parses this block and creates the issue.

---

## Manual filing (gh CLI)

```bash
gh issue create \
  --repo julianryorex/xplore \
  --title "[FEAT-036] Test suite" \
  --label "feature,P3,source:product" \
  --body "$(cat <<'EOF'
## Problem
…

## Acceptance criteria
- [ ] …

## Related code
- `test/itinerary_demo_smoke_test.dart`

## Product spec
product/requests/FEAT-036-test-suite.md

## Source
Manual / FEAT promotion
EOF
)"
```

---

## Labels

Synced from [.github/labels.yml](./labels.yml) on push to `main`.

| Label | Use |
|-------|-----|
| `feature` / `improvement` | Issue type |
| `P0` … `P4` | Priority (see product/PRIORITIES.md) |
| `source:slack` | From `#xplore-requests` |
| `source:agent` | From another agent's proposal |
| `source:product` | Promoted from existing FEAT spec |
| `needs-feat-file` | Issue filed before product spec exists |

After merging this setup, run the **Sync GitHub labels** workflow once from the Actions tab (workflow_dispatch) if labels are missing before the first `gh issue create`.
