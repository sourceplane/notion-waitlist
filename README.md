# notion-waitlist

Lakshay Bhushan's [Next.js waitlist with Notion as CMS](https://github.com/lakshaybhushan/nextjs-notion-waitlist-template)
([lakshaybhushan/nextjs-notion-waitlist-template](https://github.com/lakshaybhushan/nextjs-notion-waitlist-template),
Vercel's "Next.js Waitlist with Notion CMS" template, demo at
https://nextjs-notion-waitlist.vercel.app) — an animated one-page waitlist
that saves each signup to a Notion database and sends a React Email welcome
through Resend, rate-limited per visitor — running on **Cloudflare Workers +
Static Assets** through [`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare),
and packaged as an **Orun baseline**: one command takes a new site from
nothing to live on stage and prod, in its own repository, under its own name.

The template's code is the code. What the port adds is the Workers build,
the monorepo wrapper, a test package and the deploy contract; what it
changes is what Workers and a fresh, unattended deployment force: Upstash's
rate limit is Cloudflare's own Workers Rate Limiting binding (and covers
both signup routes, not only the email), Notion's and Resend's keys are Orun
secrets the owner stores after the build, handed to the Worker as Worker
secrets, a signup is told the waitlist is not connected yet until they are,
the email is sent from the owner's own address (`RESEND_FROM`) rather than
the template author's, Figtree is self-hosted, and the "Use this template"
button is the site's own source link. What the baseline adds is everything
needed to make a copy of it somebody else's — built the way
[cirrus-baseline](https://github.com/sourceplane/cirrus-baseline) is. See
[`specs/epics/notion-waitlist`](specs/epics/notion-waitlist/README.md)
for the design, the milestones and the as-built status, including every
departure.

## Instantiating a site

```bash
git clone --depth 1 --branch <baseline-tag> https://github.com/sourceplane/notion-waitlist
cd notion-waitlist
orun new --blueprint repo-blueprint.yaml --out ~/sites/acme-notes --run-hooks --resume \
  --set reponame=acme-notes --set productname="Acme Notes" \
  --set githuborg=acme-inc --set subdomain=<workers-dev-subdomain>
```

Or, once the platform's registry lists it, from the Orun console (Baselines →
`notion-waitlist` → Build). Two phases — `01-product` (the repository
created, then the whole site in one pull request, deployed to stage and prod
and smoke-tested) and `03-docs` (the live deployment recorded) — each landing
one pull request in the new repository.
**[BOOTSTRAP.md](BOOTSTRAP.md)** is the operator guide;
[docs/phases/](docs/phases/README.md) has a page per phase.

The new repository receives the **site only** — the app, its tests, its CI,
its tooling, a README and an `AGENTS.md` of its own and its operating
contract — renamed throughout to the site's name, repository and Cloudflare
Worker. None of this repository's machinery ships. **Notion and Resend are
the owner's to connect afterwards** (the site's README, "Connect Notion and
Resend"): no platform brokers them, so the card asks for no key, and the
site goes live with its page up and a signup told the waitlist is not
connected yet.

| What makes it a baseline | Where |
|---|---|
| The console card (inputs, secrets, programme) | `blueprint.yaml` |
| The build document (modules, phases, hooks) | `repo-blueprint.yaml` |
| This tree's identity, and the bootstrap's task contracts | `.baseline/` |
| The rename engine (product-name seam: `apps/web/app/site.ts`) | `tooling/rebrand/rebrand.mjs` |
| The bootstrap's helpers (deferrals, redeploy marker, work-tree strip) | `tooling/bootstrap/` |
| The deployment-record renderer | `hooks/render-deployment-docs.sh` |
| The site's README, agent page and context pack | `.baseline/product/README.md`, `.baseline/product/AGENTS.md`, `ai/context/` |
| The baseline's tests: contract, leak, offline bootstrap, end to end | `testing/`, `.github/workflows/baseline.yml` |
| Cutting a `baseline-vN` tag | `.github/workflows/tag.yml` |

## What is here (the site)

| Surface | Where |
|---|---|
| The site's name, source link and origin | `apps/web/app/site.ts` |
| The waitlist page (the template's header, call to action, form, logos, footer and particles) | `apps/web/app/page.tsx`, `apps/web/components` |
| `/api/mail` (the welcome email), `/api/notion` (the row), `/api/health` (the deploy's smoke) | `apps/web/app/api` |
| Whether Notion and Resend are connected, and the rate limit both routes take | `apps/web/lib/waitlist.ts` |
| The welcome email (React Email) | `apps/web/emails/index.tsx` |
| The rate-limit binding (`SIGNUP_LIMITER`, two per sixty seconds) | `apps/web/wrangler.jsonc` |
| The Worker-secret push (Notion's and Resend's keys) | `tooling/wire/worker-secrets.mjs` |
| Workers build and deploy contract | `apps/web/next.config.ts`, `open-next.config.ts`, `wrangler.jsonc`, `component.yaml` |
| Tests | `tests/web` (vitest) |

## Getting started

```bash
pnpm install
pnpm typecheck
pnpm lint
pnpm test
pnpm build            # next build + opennextjs-cloudflare build → apps/web/.open-next
```

The build needs neither Notion nor Resend: their keys are read by the Worker
per request. With an integration's secret, a database id, a Resend key and a
sender in `apps/web/.env.local` (`apps/web/.env.example`),
`pnpm --filter @app/web dev` takes real signups; `pnpm --filter @app/web
preview` serves the built Worker with the same keys from `apps/web/.dev.vars`.

## How it maps to Vercel

| Vercel | Here |
|---|---|
| Next.js hosting on Vercel's runtime | One Cloudflare Worker (`.open-next/worker.js`) + Static Assets, built by `next build --webpack` (Turbopack's per-route server chunks put the Worker at 2.97 MiB gzipped, against Workers Free's 3 MiB; webpack's are 1.48 MiB) |
| Upstash Redis rate limit (`Ratelimit.slidingWindow(2, "1 m")`, keyed on `request.ip`) on the email route | Workers Rate Limiting (`SIGNUP_LIMITER`: two per sixty seconds, a fixed window), keyed on the site's host, the route and `CF-Connecting-IP`, on BOTH the email and the Notion route |
| `NOTION_SECRET`, `NOTION_DB`, `RESEND_API_KEY` as project env vars | Orun secrets per environment the owner stores (and `RESEND_FROM`), read by the build as optional refs and handed to the Worker as Worker secrets; no bundle holds one |
| Missing keys (the Resend client throws on import, every signup fails) | The not-connected site: the page renders, a signup gets a 503 naming the keys it lacks, and the page says the waitlist is not connected yet |
| The template author's sender (`hello@waitlist.lakshb.dev`), reply-to and logo URL in the email | `RESEND_FROM`, no reply-to (replies go to the sender), the logo from the site's own origin |
| `next/font/google` (Figtree) | Figtree self-hosted from `@fontsource-variable/figtree` (OFL-1.1) |
| `@vercel/analytics` | Dropped |
| The "Upstash" and "Vercel" tiles under "Powered by" | Dropped (the port uses neither); the grid is two by two |
| `app/opengraph-image.png`, `app/twitter-image.png` beside a hand-written `og:image` meta | The same images served from `public/` and named in `metadata` on `metadataBase` (as file conventions Next compiles each 1.3 MB image into the Worker) |
| Hard-coded `vercel.app` `og:url` | `NEXT_PUBLIC_SITE_URL`, set per environment by the deploy |
| "Use this template" (fork the template on GitHub) | The site's own source link; `orun new --blueprint repo-blueprint.yaml` is the clone — a new repository, branded, deployed |
| Deploy on push | Orun deploys `<repo>-web-{stage,prod}` on merge to `main` (`apps/web/component.yaml`), smoke-tested |

## Licence

The template carries no licence file and GitHub records none. Its README's
"License" section allows personal and commercial use and modification, and
asks commercial users to consider supporting its author; that section is
the only grant, and this repository keeps the template's credit (the
footer's "Brought to you by" and the links above).

## CI

| Workflow | What it runs | Ships to a site |
|---|---|---|
| `ci.yml` | the Orun pipeline, and the only workflow a site carries: `orun plan --changed`, then one job per lane. A pull request runs the verify lanes (the site built and dry-deployed per environment; the tests' `quick-check` lane installs and checks the package, it does not run them), except the bootstrap's own landings (`orun/BASE-*`), where `plan` alone is the check; a merge deploys stage → prod. It plans nothing while `intent.yaml` names the placeholder workspace `ws_CHANGE_ME`, as this repository does. A manual run (Orunbase's Deploy button, or Run workflow on `main`) plans the environment and components it names under the push-to-main trigger, so they deploy as a merge deploys them | yes |
| `baseline.yml` | the baseline's own tiers: contract tests, the blueprint read by the pinned orun, the leak gate, the offline bootstrap, the site built, dry-deployed and served — not connected, and with made-up Notion and Resend keys against a local stand-in of their APIs (no key in any file of the build, one signup as the template sends it, the third request a minute refused) | no |
| `tag.yml` | cuts a `baseline-vN` tag (manual) | no |
