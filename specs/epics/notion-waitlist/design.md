# notion-waitlist — design

## The template

[lakshaybhushan/nextjs-notion-waitlist-template](https://github.com/lakshaybhushan/nextjs-notion-waitlist-template)
(`4798588`, the template behind Vercel's "Next.js Waitlist with Notion CMS")
is one Next.js 14 page: a header (a link to a sample Notion database, "Use
this template"), a shimmering "Coming soon!" call to action, a name and
email form, a "Powered by" grid of logos, a footer credit and a canvas of
particles — framer-motion, shadcn/ui, Tailwind 3, sonner toasts. A signup
posts to two route handlers in turn: `/api/mail`, which rate-limits the
visitor's IP with Upstash Redis (two a minute, sliding) and sends a React
Email welcome through Resend, and then `/api/notion`, which adds a page
(`Name`, `Email`) to a Notion database through `@notionhq/client`.

## How each Vercel piece maps to Cloudflare

| Vercel | Cloudflare | Notes |
|---|---|---|
| Next.js on Vercel | `@opennextjs/cloudflare` → one Worker + Static Assets | Next 16.3.8, React 19; `next build --webpack` (Turbopack's per-route server chunks: 2.97 MiB gzipped against Workers Free's 3 MiB; webpack's 1.48 MiB) |
| Upstash Redis `Ratelimit` | Workers Rate Limiting (`SIGNUP_LIMITER` in `wrangler.jsonc`) | Two per sixty seconds per key, a fixed window; both routes; below |
| Project env vars | Orun secrets per environment → Worker secrets | Read per request; below |
| `request.ip` | `CF-Connecting-IP` | Next 15 dropped `request.ip` |
| `next/font/google` | `next/font/local` over `@fontsource-variable/figtree` | Google Fonts at build time fails on GitHub's runners |
| `@vercel/analytics` | — | Vercel-only |
| `app/opengraph-image.png` | the same image in `public/`, named in `metadata` | As a file convention Next compiles each 1.3 MB image into the Worker as a route |

## The rate limit

Upstream limits only `/api/mail`; `/api/notion` writes to the owner's
database for anyone who calls it. Here both routes take the same
`SIGNUP_LIMITER` binding, each with its own count — the key is
`<host>:<route>:<CF-Connecting-IP>` — so one signup (one of each) fits, a
second fits, and a third request to either in a minute is refused (429)
before it reaches Notion or Resend. The host is in the key because a
rate-limit namespace is the account's: two environments, or two products on
one account, never share a visitor's count.

The binding is declared in the committed `wrangler.jsonc`, which the
composition deploys as written (`wrangler deploy --config wrangler.jsonc`);
the lane's own dry run lists it, the end-to-end tier asserts it, and
`/api/health` reports it — so the deploy's smoke fails a Worker that lost it.
Workers Rate Limiting counts per Cloudflare location and is eventually
consistent: a brake on abuse, not an exact quota (risk NW-C).

## Before Notion and Resend are connected

No platform brokers Notion or Resend, so a site is born without them, and
the Resend client the template creates at module load throws without a key —
upstream, every signup would fail. Here each route reads its service's keys
per request (`lib/waitlist.ts`): without them it answers 503 with the names
of the keys it lacks (never a value), and the page's toast says the waitlist
is not connected yet. The page itself never needed them. `/api/health`
reports both, connected or not.

The four keys (`NOTION_SECRET`, `NOTION_DB`, `RESEND_API_KEY`, and
`RESEND_FROM` for the template's hard-coded sender) are optional Orun
secrets the component resolves as `optionalSecretEnv`. The build runs
without them (`env -u`), so no bundle and no build cache holds one, and
`tooling/wire/worker-secrets.mjs` hands those that are set to the Worker as
Worker secrets (`wrangler secret bulk`, the values over stdin) from the
deploy lane only.

The email keeps the template's design and words; what pointed at the
template's author — the sender, the reply-to, the "reply to this email"
mailto and the logo's vercel.app URL — becomes the owner's sender and the
site's own origin.

## The repository and the build

portfolio-starter-kit's shape: `apps/web` (the site), `tests/web` (vitest),
`tooling/` (TypeScript and ESLint configuration, the rename engine, the
bootstrap helpers, the wrangler renderer, the Worker-secret push), one
`intent.yaml` (dev verify-only, stage and prod deployed), `ci.yml` the only
workflow a site carries, and the baseline's own `blueprint.yaml`,
`repo-blueprint.yaml`, `.baseline/`, `testing/` and `baseline.yml`. The
site's name is one seam (`SITE_NAME` in `apps/web/app/site.ts`), its origin
`NEXT_PUBLIC_SITE_URL` per environment.

## Alternatives rejected

- **Keep Upstash Redis as a SaaS.** It would work, and cost a fourth
  account and two more secrets for something the Worker's own binding does;
  the brief maps it to Workers Rate Limiting.
- **A KV or D1 counter** (ai-emoji-generator's KV counter). Exact across
  locations, but a namespace or database to provision for a two-a-minute
  brake; the binding needs nothing provisioned.
- **One signup route.** Merging `/api/mail` and `/api/notion` would let one
  count cover a signup, but it changes the template's page and its two-step
  error messages; two counts keep both.
