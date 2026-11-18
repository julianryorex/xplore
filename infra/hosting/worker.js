// Cloudflare Worker for xplore.olympuslabs.ai, the host of trip invite links
// (FEAT-003). It does three jobs:
//
// 1. Serves the Apple App Site Association file, so iOS opens /join links
//    straight in the app when it is installed.
// 2. Serves /join as a page with Open Graph tags. Messages, WhatsApp, Slack and
//    others read these to draw the rich link card (image + trip name) when the
//    app shares the bare link.
// 3. Gives people without the app a landing page for the invite.
//
// Static files in ./public (the preview image, icons) are served by Cloudflare
// before this script runs. Keep AASA in sync with
// infra/hosting/apple-app-site-association.

const AASA = {
  applinks: {
    details: [
      {
        appIDs: ["NY5PB8UM8W.com.olympuslabs.xplore"],
        components: [{ "/": "/join*", comment: "Trip invite links" }],
      },
    ],
  },
};

// Firestore ids are 20-char auto ids and tokens are 32 hex chars; anything
// outside this shape never reaches the Firestore URL.
const ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/.well-known/apple-app-site-association") {
      return new Response(JSON.stringify(AASA), {
        headers: { "Content-Type": "application/json", "Cache-Control": "max-age=3600" },
      });
    }

    if (url.pathname === "/join" || url.pathname === "/join/") {
      const invite = await lookupInvite(env, url.searchParams.get("trip"), url.searchParams.get("token"));
      return new Response(renderInvitePage({ invite, url, env }), {
        headers: {
          "Content-Type": "text/html; charset=utf-8",
          // Short, so a revoked invite stops advertising itself soon.
          "Cache-Control": "public, max-age=300",
          "X-Robots-Tag": "noindex",
        },
      });
    }

    if (url.pathname === "/") {
      return Response.redirect(env.GET_APP_URL, 302);
    }

    return new Response("Not found", { status: 404 });
  },
};

/**
 * Reads the invite doc through the Firestore REST API (the security rules let
 * anyone holding the token `get` it). Returns `{ status, title, memberCount }`,
 * where status is "valid", "inactive" or "unknown"; network or permission
 * failures degrade to "unknown" so the page still renders a generic invite.
 */
export async function lookupInvite(env, tripId, token) {
  if (!tripId || !token || !ID_PATTERN.test(tripId) || !ID_PATTERN.test(token)) {
    return { status: "unknown" };
  }

  const docUrl =
    `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}` +
    `/databases/${env.FIRESTORE_DATABASE_ID}/documents/trips/${tripId}/invites/${token}`;

  let doc;
  try {
    const response = await fetch(docUrl, { cf: { cacheTtl: 60 } });
    if (response.status === 404) {
      return { status: "inactive" };
    }
    if (!response.ok) {
      return { status: "unknown" };
    }
    doc = await response.json();
  } catch {
    return { status: "unknown" };
  }

  const fields = doc.fields ?? {};
  const expiresAt = fields.expiresAt?.timestampValue;
  const revoked = fields.revoked?.booleanValue === true;
  const expired = expiresAt != null && Date.parse(expiresAt) <= Date.now();
  if (revoked || expired) {
    return { status: "inactive" };
  }

  const title = (fields.tripTitle?.stringValue ?? "").trim();
  const memberCount = Number(fields.memberCount?.integerValue ?? 0);
  return { status: "valid", title: title || null, memberCount };
}

function renderInvitePage({ invite, url, env }) {
  const origin = url.origin;
  const isValid = invite.status === "valid";
  const isInactive = invite.status === "inactive";
  const tripTitle = isValid ? invite.title : null;

  // og:title is the line under the image in a Messages card, so it carries the
  // trip name the way a shared Maps pin carries the place name.
  const ogTitle = tripTitle ?? "Trip invite";
  const ogDescription = isInactive
    ? "This invite link is no longer active."
    : tripTitle
      ? `You're invited to join “${tripTitle}” on Xplore.`
      : "You're invited to join a trip on Xplore.";

  const headline = isInactive ? "This invite is no longer active" : (tripTitle ?? "You're invited");
  const eyebrow = isInactive ? "Trip invite" : tripTitle ? "You're invited to" : "Trip invite";
  const body = isInactive
    ? "Ask the person who sent it for a fresh link."
    : "Plan the itinerary, share the map and keep everyone in sync — together on Xplore.";
  const members = isValid && invite.memberCount > 0 ? memberLabel(invite.memberCount) : null;

  const canonical = `${origin}${url.pathname}${url.search}`;
  const image = `${origin}/og-invite.png`;

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${escapeHtml(tripTitle ? `${tripTitle} · Xplore` : "Xplore trip invite")}</title>
<meta name="description" content="${escapeHtml(ogDescription)}">
<meta name="theme-color" content="#000000">
<meta name="color-scheme" content="dark">
<meta name="robots" content="noindex">
<link rel="canonical" href="${escapeHtml(canonical)}">
<link rel="icon" href="/favicon.png" type="image/png">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">

<meta property="og:type" content="website">
<meta property="og:site_name" content="Xplore">
<meta property="og:title" content="${escapeHtml(ogTitle)}">
<meta property="og:description" content="${escapeHtml(ogDescription)}">
<meta property="og:url" content="${escapeHtml(canonical)}">
<meta property="og:image" content="${image}">
<meta property="og:image:secure_url" content="${image}">
<meta property="og:image:type" content="image/png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="Xplore trip invite">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${escapeHtml(ogTitle)}">
<meta name="twitter:description" content="${escapeHtml(ogDescription)}">
<meta name="twitter:image" content="${image}">

<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Manrope:wght@800&display=swap" rel="stylesheet">
<style>
  :root {
    --bg: #000000;
    --card: #1c1c1e;
    --raised: #2c2c2e;
    --separator: #38383a;
    --label: #ffffff;
    --secondary: #a1a1a8;
    --accent: #4fbf93;
    --accent-soft: rgba(79, 191, 147, 0.17);
    --on-accent: #06201a;
  }
  * { box-sizing: border-box; }
  html, body { margin: 0; background: var(--bg); color: var(--label); }
  body {
    min-height: 100dvh;
    font: 17px/1.4 -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, sans-serif;
    -webkit-font-smoothing: antialiased;
    display: flex;
    flex-direction: column;
    padding: max(20px, env(safe-area-inset-top)) 20px max(24px, env(safe-area-inset-bottom));
  }
  header { display: flex; align-items: center; justify-content: space-between; max-width: 440px; width: 100%; margin: 0 auto; }
  .wordmark {
    font-family: Manrope, -apple-system, sans-serif;
    font-weight: 800;
    font-size: 24px;
    letter-spacing: -0.8px;
    color: var(--label);
    text-decoration: none;
  }
  main { flex: 1; display: flex; flex-direction: column; justify-content: center; max-width: 440px; width: 100%; margin: 0 auto; padding: 32px 0; }
  .card {
    position: relative;
    overflow: hidden;
    border-radius: 28px;
    background: var(--card);
    border: 1px solid rgba(255, 255, 255, 0.06);
  }
  .hero { position: relative; aspect-ratio: 1200 / 630; background: #050807; }
  .hero img { display: block; width: 100%; height: 100%; object-fit: cover; }
  .content { padding: 22px 22px 24px; }
  .eyebrow {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
    font-weight: 600;
    letter-spacing: 0.02em;
    color: var(--accent);
    background: var(--accent-soft);
    padding: 6px 12px;
    border-radius: 999px;
  }
  .eyebrow.inactive { color: var(--secondary); background: var(--raised); }
  h1 { margin: 14px 0 8px; font-size: 30px; line-height: 1.08; letter-spacing: -0.6px; font-weight: 700; overflow-wrap: anywhere; }
  .meta { display: flex; align-items: center; gap: 8px; color: var(--secondary); font-size: 15px; margin-bottom: 10px; }
  .meta svg { flex: none; }
  p { margin: 0; color: var(--secondary); font-size: 16px; }
  .actions { display: grid; gap: 10px; margin-top: 22px; }
  .button {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    min-height: 52px;
    border-radius: 16px;
    border: 0;
    font: inherit;
    font-weight: 600;
    text-decoration: none;
    cursor: pointer;
    transition: transform 120ms ease, opacity 120ms ease;
  }
  .button:active { transform: scale(0.98); opacity: 0.9; }
  .primary { background: var(--accent); color: var(--on-accent); }
  .secondary { background: var(--raised); color: var(--label); }
  .hint { margin-top: 18px; font-size: 13px; color: var(--secondary); text-align: center; line-height: 1.45; }
  footer { text-align: center; font-size: 12px; color: #5a5a60; }
  .toast {
    position: fixed; left: 50%; bottom: max(28px, env(safe-area-inset-bottom));
    transform: translate(-50%, 16px); opacity: 0;
    background: var(--raised); color: var(--label);
    padding: 10px 16px; border-radius: 999px; font-size: 14px; font-weight: 600;
    transition: opacity 180ms ease, transform 180ms ease; pointer-events: none;
  }
  .toast.show { opacity: 1; transform: translate(-50%, 0); }
  @media (prefers-reduced-motion: reduce) { .button, .toast { transition: none; } }
</style>
</head>
<body>
${isInactive ? `<header><a class="wordmark" href="${escapeHtml(env.GET_APP_URL)}">xplore</a></header>` : ""}
<main>
  <article class="card">
    ${isInactive ? "" : `<div class="hero"><img src="/og-invite.png" alt="" width="1200" height="630"></div>`}
    <div class="content">
      <span class="eyebrow${isInactive ? " inactive" : ""}">${escapeHtml(eyebrow)}</span>
      <h1>${escapeHtml(headline)}</h1>
      ${
        members
          ? `<div class="meta"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>${escapeHtml(members)}</div>`
          : ""
      }
      <p>${escapeHtml(body)}</p>
      ${
        isInactive
          ? `<div class="actions"><a class="button secondary" href="${escapeHtml(env.GET_APP_URL)}">Learn about Xplore</a></div>`
          : `<div class="actions">
        <a class="button primary" href="${escapeHtml(env.GET_APP_URL)}">Get Xplore</a>
        <button class="button secondary" type="button" id="copy">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
          Copy invite link
        </button>
      </div>
      <div class="hint">Already have Xplore? Copy the link, then tap <strong>Join a trip</strong> in the app.</div>`
      }
    </div>
  </article>
</main>
<footer>Xplore · Group travel, planned together</footer>
<div class="toast" id="toast" role="status" aria-live="polite">Link copied</div>
<script>
  (function () {
    var button = document.getElementById("copy");
    if (!button) return;
    var toast = document.getElementById("toast");
    button.addEventListener("click", function () {
      var link = location.href;
      var done = function () {
        toast.classList.add("show");
        setTimeout(function () { toast.classList.remove("show"); }, 1600);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(link).then(done, function () { window.prompt("Copy this link", link); });
      } else {
        window.prompt("Copy this link", link);
      }
    });
  })();
</script>
</body>
</html>`;
}

function memberLabel(count) {
  return count === 1 ? "1 traveler going" : `${count} travelers going`;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
