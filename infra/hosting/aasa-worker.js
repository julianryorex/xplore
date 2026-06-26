// Cloudflare Worker that serves the Apple App Site Association (AASA) file for
// xplore.olympuslabs.ai, used by iOS universal links for trip invites
// (FEAT-003). Apple requires HTTPS, Content-Type: application/json, no redirect,
// and the path /.well-known/apple-app-site-association (no .json extension).
//
// Deploy: bind this Worker to a route for `xplore.olympuslabs.ai/*` (see
// infra/README.md "Trip invite deep links"). Keep the JSON below in sync with
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

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === "/.well-known/apple-app-site-association") {
      return new Response(JSON.stringify(AASA), {
        headers: {
          "Content-Type": "application/json",
          "Cache-Control": "max-age=3600",
        },
      });
    }

    // Invite links land here when the app is NOT installed. Send people to an
    // install/landing page instead of a blank 404. Adjust as desired.
    if (url.pathname.startsWith("/join")) {
      return Response.redirect("https://olympuslabs.ai", 302);
    }

    return new Response("Not found", { status: 404 });
  },
};
