# notion-waitlist

A launch waitlist — an animated one-page signup that saves each visitor to
a [Notion](https://www.notion.so) database and sends them a
[React Email](https://react.email) welcome through [Resend](https://resend.com),
rate-limited per visitor — as a Next.js app on **Cloudflare Workers + Static
Assets** through [`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare).

Working on it with a coding agent? [AGENTS.md](AGENTS.md) says what to read
first, how a change lands and what not to touch.

## Live deployment

<!-- 03-docs:begin -->
Not recorded yet. The bootstrap's last phase writes the live URLs, the
workspace and the secrets the site uses into
[ai/context/deployment.md](ai/context/deployment.md); how the site deploys
and how to operate it is in
[ai/context/operations.md](ai/context/operations.md).
<!-- 03-docs:end -->

## Connect Notion and Resend

The site deploys and serves before it has a Notion database or a Resend
domain: until its Worker holds their keys, the page renders, a signup is
told **the waitlist is not connected yet** (the routes answer 503, naming the
keys they lack), and `/api/health` reports `"notion":"not-connected"` and
`"resend":"not-connected"`. To start taking signups:

1. **Notion.** Create an internal integration
   ([Notion → Integrations](https://www.notion.so/profile/integrations)) and
   copy its secret. Create a database with a **Name** (title) property and an
   **Email** (email) property, share it with the integration (… → Connections),
   and copy its id from its URL (the 32 characters before `?v=`).
2. **Resend.** Verify a domain you own in [Resend](https://resend.com/domains)
   and create an API key that can send. Choose the address the welcome email
   comes from on that domain, e.g. `Your Name <hello@waitlist.your-domain.com>`;
   replies go to it.
3. **Give the site its keys**, once per deployed environment. They are this
   repository's Orun secrets, and stage and prod can each name their own
   database and sender:

   ```bash
   orun secrets set NOTION_SECRET  --env prod   # prompts for the value
   orun secrets set NOTION_DB      --env prod
   orun secrets set RESEND_API_KEY --env prod
   orun secrets set RESEND_FROM    --env prod
   ```

   The build never sees them: the deploy hands them to the Worker as Worker
   secrets (`wrangler secret bulk`), so they are in no bundle, no build cache
   and no log, and the Worker reads them per request.
4. **Redeploy the site**: the deploy is what hands the keys to the Worker,
   and setting a secret deploys nothing. Use **Deploy by hand** below, or
   change the stamp on the last line of `apps/web/component.yaml`
   (`# orun: redeploy …`) and merge. From that deploy on, a signup gets the
   welcome email and a row in your database, and `/api/health` reports both
   connected.

The welcome email's words are the template's (`apps/web/emails/index.tsx`) —
written in its author's voice, so rewrite them in yours before you launch.

To run it locally, copy `apps/web/.env.example` to `apps/web/.env.local` and
fill in the four keys; `wrangler dev` (`pnpm --filter @app/web preview`)
reads them from `apps/web/.dev.vars` instead. Neither file is ever committed.

## The rate limit

Each visitor may send two signup requests a minute to each of the two
routes — one signup is one of each — and a third is refused (429) before it
reaches Notion or Resend. It is Cloudflare's own
[Workers Rate Limiting](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/)
binding, `SIGNUP_LIMITER` in `apps/web/wrangler.jsonc` (deployed with the
Worker, nothing to store); change `limit` there to allow more. It counts
per Cloudflare location, so it is a brake on abuse, not an exact quota.

## What is here

| Surface | Where |
|---|---|
| The site's name and source link | `apps/web/app/site.ts` |
| The waitlist page | `apps/web/app/page.tsx`, `apps/web/components` |
| `/api/mail` (the welcome email), `/api/notion` (the row), `/api/health` (the deploy's smoke) | `apps/web/app/api` |
| Whether Notion and Resend are connected, and the rate limit | `apps/web/lib/waitlist.ts` |
| The welcome email | `apps/web/emails/index.tsx` |
| The Worker-secret push | `tooling/wire/worker-secrets.mjs` |
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

```bash
pnpm --filter @app/web dev        # http://localhost:3000
pnpm --filter @app/web preview    # wrangler dev over the built Worker
```

Variables (`apps/web/.env.example`):

| Variable | What it does |
|---|---|
| `NOTION_SECRET`, `NOTION_DB` | The Notion integration's secret and the database signups are written to (above). Read by the Worker per request. |
| `RESEND_API_KEY`, `RESEND_FROM` | The Resend API key and the address the welcome email is sent from (above). Read by the Worker per request. |
| `NEXT_PUBLIC_SITE_URL` | The site's public origin, for the Open Graph image's absolute URL and the email's logo. The deploy sets it per environment (see below). Defaults to `http://localhost:3000`. |

## How it deploys

Merges to `main` converge through [Orun](https://github.com/sourceplane/orun):
`.github/workflows/ci.yml` plans the changed components and runs each lane
against the workspace in `intent.yaml`. The site deploys to `stage`, then to
`prod` once stage has converged on the same commit; `dev` only verifies. The
Worker is `notion-waitlist-web-<env>` on your account's workers.dev
subdomain, and every deploy is smoke-tested over HTTP: the home page renders
to its end with its signup button, and `/api/health` answers ok — the Worker
has its rate-limit binding. A pull request runs the same pipeline's verify
lanes: the site built and dry-deployed for each environment, with nothing
deployed. They do not lint or run the tests, so run `pnpm typecheck`,
`pnpm lint` and `pnpm test` before you push. (A push to `main` builds,
deploys and smoke-tests.)

The pipeline holds one credential, GitHub's own `GITHUB_TOKEN`. The
Cloudflare token and account id are brokered per run from the workspace's
Cloudflare connection, and Notion's and Resend's keys are Orun secrets;
nothing provider-shaped is stored in the repository or in GitHub.

**Deploy by hand.** Orunbase's **Deploy** button on a component, or **Run
workflow** on the CI workflow in GitHub's Actions tab (on `main`), runs
`ci.yml` for the environment and components you pick, and each one deploys
exactly as a merge would deploy it. Leave the component blank to redeploy
every component in that environment, with nothing changed: after storing or
rotating the Notion and Resend keys, say. A component with nothing to run in
that environment (a test suite in `prod`) is left out with a notice.

## Custom domain

The site answers on workers.dev from its first deploy. To serve it on your
own domain:

1. Add the domain to the Cloudflare account the site deploys into, and attach
   it to the Worker (dashboard → Workers & Pages →
   `notion-waitlist-web-prod` → Settings → Domains & Routes → Add →
   Custom domain). Do the same for stage with a subdomain if you want one.
2. Set the environment's public origin in `intent.yaml`, so the Open Graph
   image's URL and the email's logo use it (until then they use the
   workers.dev URL):

   ```yaml
   environments:
     prod:
       env:
         SITE_URL: https://notion-waitlist.example.com
   ```

   The site was born with the reserved placeholder
   `notion-waitlist.example.com` where its domain goes: that example,
   and `BASE_DOMAIN` under each environment (dev, stage and prod) in
   `intent.yaml`. Replace it with your domain in the same change.
3. Merge. The next deploy of `apps/web` builds with the new origin. (A change
   to `intent.yaml` alone deploys nothing — touch `apps/web` in the same pull
   request, or let the next change to the site carry it.)

## Credits

The site is Lakshay Bhushan's Next.js waitlist with Notion as CMS
([lakshaybhushan/nextjs-notion-waitlist-template](https://github.com/lakshaybhushan/nextjs-notion-waitlist-template)),
the template behind Vercel's Next.js Waitlist with Notion CMS. It carries no
licence file; its README allows personal and commercial use and
modification, and asks commercial users to consider supporting its author.
