import {createCommunityPreview} from './community-preview.mjs';
import {readCatalogFilters} from '../../server/catalog_query.mjs';
// Recovered from the existing Development Worker on 2026-10-15.
// Existing public catalog and its dated source attributions are preserved.
var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// server/event_categories.mjs
var eventCategories = Object.freeze([
  "party",
  "sport",
  "student",
  "concert",
  "dance",
  "workshop",
  "culture",
  "meetup"
]);
function matchesEventCategory(event2, category) {
  return !category || eventCategories.includes(category) && Array.isArray(event2.event_content?.categories) && event2.event_content.categories.includes(category);
}
__name(matchesEventCategory, "matchesEventCategory");

// server/development-event-media.mjs
var developmentEventMedia = {
  "soft-machine": {
    "flyer_data": "/event-media/3535d2dfdc907585d9f2.webp",
    "flyer_preview_data": "/event-media/08fa5efd61641e571360.webp",
    "flyer_aspect_ratio": 0.8036175710594315,
    "flyer_alt": "Offizieller Flyer: Soft Machine",
    "flyer_caption": "Eventflyer \xB7 Quelle: Musikbunker Aachen / Instagram",
    "flyer_source_url": "https://www.instagram.com/musikbunker_aachen/p/DeHnbfLofl6/"
  },
  "nude-ug2": {
    "flyer_data": "/event-media/2b616653145b9376ceaf.webp",
    "flyer_preview_data": "/event-media/e45db883216ed96e84f6.webp",
    "flyer_aspect_ratio": 0.8037109375,
    "flyer_alt": "Offizieller Flyer: NUDE \xD7 UG2 KOLLEKTIV",
    "flyer_caption": "Eventflyer \xB7 Quelle: Musikbunker Aachen / Instagram",
    "flyer_source_url": "https://www.instagram.com/musikbunker_aachen/p/DeHmAW3I7ZR/"
  },
  "guitar-trio": {
    "flyer_data": "/event-media/b9ed5c0bcb91fd3cc6d4.webp",
    "flyer_preview_data": "/event-media/77530dc5d985d95a3d9a.webp",
    "flyer_aspect_ratio": 1.7777777777777777,
    "flyer_alt": "Transatlantic Guitar Trio: offizielles Konzertfoto",
    "flyer_caption": "Konzertfoto \xB7 Quelle: Musikbunker Aachen",
    "flyer_source_url": "https://mubu.ac/event/joscho-stephans-transatlantic-guitar-trio-2/"
  },
  "sensual-tuesday": {
    "flyer_data": "/event-media/3a90b73f85ce70ff12b9.webp",
    "flyer_preview_data": "/event-media/d670491a5d30e9044da1.webp",
    "flyer_aspect_ratio": 2,
    "flyer_alt": "Offizieller Flyer: Sensual Tuesday \xB7 80er-Edition",
    "flyer_caption": "Eventflyer \xB7 Quelle: Apollo Aachen",
    "flyer_source_url": "https://apollo-aachen.de/"
  },
  "salsa-afterwork": {
    "flyer_data": "/event-media/7cad382481cc7f970148.webp",
    "flyer_preview_data": "/event-media/1709af07f7a81d9e7a4b.webp",
    "flyer_aspect_ratio": 1.910828025477707,
    "flyer_alt": "Salsa Afterwork im Apollo: offizielles Serienmotiv",
    "flyer_caption": "Serienmotiv \xB7 Quelle: Apollo Aachen",
    "flyer_source_url": "https://apollo-aachen.de/"
  },
  "2000er-party": {
    "flyer_data": "/event-media/3890166696ee24196ffe.webp",
    "flyer_preview_data": "/event-media/1cd30547ae209e5a7f65.webp",
    "flyer_aspect_ratio": 1.7777777777777777,
    "flyer_alt": "Offizieller Flyer: 2000er Party",
    "flyer_caption": "Eventflyer \xB7 Quelle: Apollo Aachen",
    "flyer_source_url": "https://apollo-aachen.de/"
  },
  "shut-up-dance": {
    "flyer_data": "/event-media/24ce27a33405f0b423c6.webp",
    "flyer_preview_data": "/event-media/3174553789f03614ce70.webp",
    "flyer_aspect_ratio": 1.7777777777777777,
    "flyer_alt": "Offizieller Flyer: Shut Up & Dance",
    "flyer_caption": "Eventflyer \xB7 Quelle: Apollo Aachen",
    "flyer_source_url": "https://apollo-aachen.de/club/events/"
  }
};

// server/development-events.mjs
var instagram = /* @__PURE__ */ __name((url) => ({ label: "Instagram-Ank\xFCndigung", url }), "instagram");
var official = /* @__PURE__ */ __name((url) => ({ label: "Veranstalter-Website", url }), "official");
var apolloPost = "https://www.instagram.com/club.apollo.aachen/p/Dd3mbpQOxp2/";
var apolloSite = "https://apollo-aachen.de/";
function event(id, title, startsAt, venue, organizer, description, sources, content = {}, accessDetails = {}) {
  const mediaKey = id.slice("external-".length, -"-20261013".length);
  return {
    id,
    title,
    starts_at: startsAt,
    status: "published",
    is_public: true,
    access_mode: "public",
    external: true,
    communities: [],
    signed_in: false,
    community: {
      "Apollo Aachen": "Apollo",
      "Dance Fusion Aachen": "Dance Fusion",
      "Musikbunker Aachen": "Musikbunker",
      "NUDE \xD7 UG2 KOLLEKTIV": "NUDE \xD7 UG2"
    }[organizer],
    organizer,
    organizer_id: null,
    location: `${venue}, Aachen`,
    verified_on: "06.10.2026",
    sources,
    access_details: accessDetails,
    event_content: {
      categories: {
        "sensual-tuesday": ["dance", "workshop"],
        "joscho-stephan": ["concert"],
        "salsa-afterwork": ["dance", "workshop"],
        "nude-ug2": ["party"],
        "2000er-party": ["party"],
        "soft-machine": ["concert"],
        "shut-up-dance": ["party"]
      }[mediaKey] ?? [],
      venue_name: venue,
      description,
      line_up: [],
      genres: [],
      flyer_data: "",
      admission: "",
      ...content,
      ...developmentEventMedia[mediaKey === "joscho-stephan" ? "guitar-trio" : mediaKey]
    }
  };
}
__name(event, "event");
var developmentEvents = [
  event(
    "external-sensual-tuesday-20261013",
    "Sensual Tuesday \xB7 80er-Edition",
    "2026-10-13T18:30:00+02:00",
    "Apollo",
    "Dance Fusion Aachen",
    "Tanzabend im Apollo. Das aktuelle Webprogramm nennt 18:30 Uhr, das Instagram-Monatsplakat 19:00 Uhr. Bitte die Startzeit beim Veranstalter pr\xFCfen.",
    [instagram(apolloPost), official(apolloSite)]
  ),
  event(
    "external-joscho-stephan-20261013",
    "Joscho Stephan\u2019s Transatlantic Guitar Trio",
    "2026-10-13T20:00:00+02:00",
    "Musikbunker",
    "Musikbunker Aachen",
    "Gitarrenkonzert mit Joscho Stephan, Richard Smith und Rory Hoffman: Jazz, Swing und eigene Kompositionen.",
    [
      instagram("https://www.instagram.com/musikbunker_aachen/p/Dd8wKOHoFdq/"),
      official("https://mubu.ac/event/joscho-stephans-transatlantic-guitar-trio-2/")
    ],
    {
      genres: ["Jazz", "Swing"],
      line_up: ["Joscho Stephan", "Richard Smith", "Rory Hoffman"],
      ticket_price_label_de: "25 € zzgl. Gebühren · VVK / 30 € · Abendkasse",
      ticket_price_label_en: "€25 plus fees · advance / €30 · door",
      admission: "Einlass 19:00 Uhr. Vorverkauf 25 \u20AC zzgl. Geb\xFChren; Abendkasse 30 \u20AC."
    }
  ),
  event(
    "external-salsa-afterwork-20261014",
    "Salsa Afterwork",
    "2026-10-14T19:00:00+02:00",
    "Apollo",
    "Apollo Aachen",
    "Salsa-Abend mit Tanzkurs ab 19:00 Uhr. Das Oktober-Webprogramm k\xFCndigt Ulf an.",
    [instagram(apolloPost), official(apolloSite)],
    { genres: ["Salsa"], line_up: ["Ulf"] }
  ),
  event(
    "external-nude-ug2-20261016",
    "NUDE \xD7 UG2 KOLLEKTIV",
    "2026-10-16T23:00:00+02:00",
    "Musikbunker",
    "NUDE \xD7 UG2 KOLLEKTIV",
    "Gemeinsame Clubnacht von NUDE und UG2 KOLLEKTIV im Musikbunker.",
    [
      instagram("https://www.instagram.com/musikbunker_aachen/p/DeHmAW3I7ZR/"),
      { label: "Instagram \xB7 NUDE", url: "https://www.instagram.com/nudeunderground/reel/DeFH1LtNFuq/" }
    ],
    { minimum_age: 18, ticket_price_label_de: "ab 10 € · Vorverkauf laut Ankündigung", ticket_price_label_en: "from €10 · advance, as announced", admission: "Einlass ab 23:00 Uhr. Vorverkauf ab 10 \u20AC laut Ank\xFCndigung." }
  ),
  event(
    "external-2000er-party-20261016",
    "2000er Party",
    "2026-10-16T23:00:00+02:00",
    "Apollo",
    "Apollo Aachen",
    "Party mit Musik aus den 2000ern. Das aktuelle Oktober-Webprogramm nennt Benedetto als DJ.",
    [instagram(apolloPost), official(apolloSite)],
    { line_up: ["Benedetto"] }
  ),
  event(
    "external-soft-machine-20261017",
    "Soft Machine",
    "2026-10-17T20:00:00+02:00",
    "Musikbunker",
    "Musikbunker Aachen",
    "Jazzrock-Konzert mit John Etheridge, Theo Travis, Fred Baker und Asaf Sirkis. Das Konzert ist bestuhlt.",
    [
      instagram("https://www.instagram.com/musikbunker_aachen/p/DeHnbfLofl6/"),
      official("https://mubu.ac/event/soft-machine/")
    ],
    {
      genres: ["Jazzrock"],
      line_up: ["John Etheridge", "Theo Travis", "Fred Baker", "Asaf Sirkis"],
      ticket_price_label_de: "25 € zzgl. Gebühren · Vorverkauf",
      ticket_price_label_en: "€25 plus fees · advance",
      admission: "Einlass 19:00 Uhr. Vorverkauf 25 \u20AC zzgl. Geb\xFChren."
    },
    { seating: "yes" }
  ),
  event(
    "external-shut-up-dance-20261017",
    "Shut Up & Dance",
    "2026-10-17T23:00:00+02:00",
    "Apollo",
    "Apollo Aachen",
    "Clubabend im Apollo, angek\xFCndigt im Instagram-Programm f\xFCr Oktober 2026.",
    [instagram(apolloPost), official("https://apollo-aachen.de/club/events/")],
    { line_up: ["Nion"] }
  )
].sort((a, b) => Date.parse(a.starts_at) - Date.parse(b.starts_at));
function upcomingDevelopmentEvents(now = Date.now()) {
  return [...developmentEvents,...createCommunityPreview(now).events].filter((item) => Date.parse(item.starts_at) >= now).sort((a,b)=>Date.parse(a.starts_at)-Date.parse(b.starts_at));
}
__name(upcomingDevelopmentEvents, "upcomingDevelopmentEvents");

// server/development-worker.mjs
var previewMessage = "Development-Vorschau: Anmeldung und Datenbank sind noch nicht verbunden.";
function secure(response) {
  const result = new Response(response.body, response);
  result.headers.set("X-Robots-Tag", "noindex, nofollow, noarchive");
  result.headers.set("X-Content-Type-Options", "nosniff");
  result.headers.set("Referrer-Policy", "no-referrer");
  result.headers.set("Cross-Origin-Opener-Policy", "same-origin");
  result.headers.set("Cross-Origin-Embedder-Policy", "credentialless");
  return result;
}
__name(secure, "secure");
function json(data, status = 200) {
  return secure(Response.json(data, { status, headers: { "Cache-Control": "no-store" } }));
}
__name(json, "json");
var development_worker_default = {
  async fetch(request, env) {
    const { pathname, searchParams } = new URL(request.url);
    const read = request.method === "GET" || request.method === "HEAD";
    if (pathname === "/__development/health" && read) {
      return json({ status: "ok", environment: "development", mode: "frontend-preview", backendConnected: false, gitCommit: env.GIT_COMMIT || null });
    }
    if (pathname === "/api/directory/home" && read) {
      const events = upcomingDevelopmentEvents();
      return json({
        preview: true,
        external_catalog: true,
        signed_in: false,
        catalog_label: "Aachen \xB7 12.\u201318. Oktober 2026",
        events,
        hero: events.slice(0, 3),
        communities: createCommunityPreview().communities
      });
    }
    if (pathname === "/api/directory/events" && read) {
      const q = (searchParams.get("q") || "").trim().toLocaleLowerCase("de");
      const category = searchParams.get("category") || "";
      let filters;
      try {filters=readCatalogFilters(searchParams);}catch {return json({code:'INVALID_QUERY',message:'Ungültiger Community- oder Zeitraumfilter.'},422);}
      const {community}=filters;
      const from = Date.parse(filters.from || "");
      const before = Date.parse(filters.before || "");
      const page = Math.max(1, Number.parseInt(searchParams.get("page") || "1", 10) || 1);
      const events = upcomingDevelopmentEvents().filter((item) => (!Number.isFinite(from) || Date.parse(item.starts_at) >= from) && (!Number.isFinite(before) || Date.parse(item.starts_at) < before) && (!community || item.communities.some(c=>c.id===community)) && matchesEventCategory(item, category) && [
        item.title,
        ...item.communities.map(c=>c.name),
        item.organizer,
        item.location,
        item.event_content.description,
        ...item.event_content.genres,
        ...item.event_content.line_up
      ].join(" ").toLocaleLowerCase("de").includes(q));
      return json({
        preview: true,
        signed_in: false,
        events: events.slice((page - 1) * 20, page * 20),
        series: [],
        communities: createCommunityPreview().communities,
        page,
        has_more: events.length > page * 20
      });
    }
    if (/^\/api\/directory\/events\/[^/]+$/.test(pathname) && read) {
      const id = pathname.split("/").at(-1);
      const event2 = upcomingDevelopmentEvents().find((item) => item.id === id);
      return event2 ? json(event2) : json({ code: "NOT_FOUND", message: "Veranstaltung nicht gefunden." }, 404);
    }
    if (pathname === "/api/directory/communities" && read) {
      return json({ preview: true, signed_in: false, items: createCommunityPreview().communities });
    }
    if (["/api/directory/organizers", "/api/directory/venues"].includes(pathname) && read) {
      return json({ preview: true, organizers: [], venues: [], items: [], communities: [], page: 1, has_more: false });
    }
    if (pathname.startsWith("/api/") || pathname.startsWith("/testing/")) {
      return json({ code: "DEVELOPMENT_PREVIEW_ONLY", message: previewMessage }, 503);
    }
    if (!read) return json({ code: "METHOD_NOT_ALLOWED" }, 405);
    if (/(^|\/)\.[^/]/.test(pathname)) return json({ code: "NOT_FOUND" }, 404);
    if (!env.ASSETS) {
      return secure(new Response("Development-Version wird eingerichtet.", { status: 503, headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" } }));
    }
    const response = secure(await env.ASSETS.fetch(request));
    if ((/^\/builds\/[a-f0-9]{20}\//.test(pathname) || /^\/event-media\/[a-f0-9]{20}\.webp$/.test(pathname)) && response.status === 200 && !response.headers.get("Content-Type")?.includes("text/html")) {
      response.headers.set("Cache-Control", "public, max-age=31536000, immutable");
    }
    if (!/^\/event-media\/[a-f0-9]{20}\.webp$/.test(pathname)) response.headers.set("Cache-Control", "no-cache");
    return response;
  }
};
export {
  development_worker_default as default
};
