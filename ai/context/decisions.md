# notion-waitlist — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives. Superseded decisions stay listed, marked, so the history
reads in order.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | Next.js on Workers + Static Assets through `@opennextjs/cloudflare`, with the static-assets incremental cache | The page is pre-rendered and the two routes render per request; nothing revalidates, and the cache serves the page with no binding | `specs/epics/notion-waitlist/design.md` |
| 2 | Next 16.3.8 and React 19, not the template's Next 14.2.4 | OpenNext 1.20 refuses Next 15.5 at build; every OpenNext starter here is proven on 16.3.8 | risk NW-D |
| 3 | `next build --webpack` | Turbopack's per-route server chunks put the Worker at 2.97 MiB gzipped against Workers Free's 3 MiB; webpack's are 1.48 MiB | IMPLEMENTATION-STATUS (departures) |
| 4 | Upstash → the Worker's `SIGNUP_LIMITER` Workers Rate Limiting binding, two per sixty seconds, on both routes, keyed on host, route and `CF-Connecting-IP` | Nothing to provision; the Notion route was unlimited upstream; a namespace is the account's, so the host keeps sites apart | `apps/web/lib/waitlist.ts`, `apps/web/wrangler.jsonc` |
| 5 | The binding lives in the committed `wrangler.jsonc`, which the composition deploys as written; `/api/health` reports it and the smoke requires it | stack-tectonic has no rate-limit composition and needs none; the deploy's smoke catches a Worker that lost it | `apps/web/component.yaml` |
| 6 | Notion's and Resend's keys are read per request; without them a route answers 503 naming what is missing | A fresh site must deploy and serve before its owner has either; upstream's Resend client threw without a key | `apps/web/lib/waitlist.ts` |
| 7 | The keys are Orun secrets per environment, read as `optionalSecretEnv`; the build runs without them (`env -u`) and the deploy lane hands them to the Worker as Worker secrets | SaaS keys are Orun secrets; none may be in a bundle or the build cache | `apps/web/component.yaml`, `tooling/wire/worker-secrets.mjs` |
| 8 | `RESEND_FROM` is the owner's; the template's sender, reply-to and mailto go | The owner's waitlist must not send as, or reply to, the template's author | IMPLEMENTATION-STATUS (departures) |
| 9 | `/api/health` and a full-page render with its signup button are the deploy's smoke | A Worker without its binding refuses every signup; the smoke catches it at deploy | `apps/web/component.yaml` |
| 10 | "Use this template" is the site's own source link | The site deploys from its own repository; the button forked upstream | IMPLEMENTATION-STATUS (departures) |
| 11 | The site's name is one seam, `SITE_NAME` in `apps/web/app/site.ts`, for the title and `og:site_name`; `metadataBase` is `NEXT_PUBLIC_SITE_URL` | The rename rewrites one literal; the template hard-coded its Vercel origin | `apps/web/app/site.ts` |
| 12 | No custom-domain phase: a domain is the owner's step, and `SITE_URL` points the build at it | The brokered `workers-deploy` token has no zone scope | README, "Custom domain" |
| 13 | One landing (`01-product`) then the record (`03-docs`), each checked in the build box | A landing has a fixed cost; the convergence on main builds, deploys and smoke-tests the site for real | `docs/phases/README.md` |
| 14 | `ci.yml` plans nothing while `intent.yaml` names `ws_CHANGE_ME`; no Checks workflow | A bootstrap cannot set a repository variable; a push to main must start `ci.yml` alone | `.github/workflows/ci.yml` |
| 15 | stack-tectonic 0.19.0, not 0.20.0 | 0.20.0's lane-shared install links `node_modules` out of the job's tree | portfolio-starter-kit's risk PK-J |
| 16 | Component docs are generated from the manifests and checked in CI; orun is pinned only where it runs | A hand-written copy drifts silently | `tooling/catalog/gen-component-docs.py` |
| 17 | `subdomain` is read from the Cloudflare connection, never asked; the console asks for no domain and no Notion or Resend key | The first two belong to the account or the owner; no platform connection can mint the keys | `blueprint.yaml` |
