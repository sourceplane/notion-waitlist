# notion-waitlist — operating contract (for humans and agents)

This is the standing guide to how this site is deployed and operated.
Instance facts (live URLs, workspace, the secrets it uses) live in
[deployment.md](deployment.md), rendered from probed reality by the
bootstrap's `03-docs` phase; this file is the contract that stays true
between deployments. It is written to give an agent with repository read
access enough context to reason about and operate the site without any
other source.

## What this system is

A launch waitlist on Cloudflare (the Next.js waitlist with Notion as CMS),
expressed as an Orun component-native desired-state repo. Notion and Resend
are SaaS the site calls, not components here: its owner creates the Notion
integration and database and the Resend domain, and stores their keys.

- **`apps/web`** — the site: Next.js built by `@opennextjs/cloudflare`
  (`next build --webpack`) into one Worker plus Static Assets. The page is
  pre-rendered; a signup calls `/api/mail` (the React Email welcome, sent
  through Resend) and then `/api/notion` (a row in the Notion database), and
  `/api/health` is what the deploy's smoke reads. There is no database of
  its own.
- **The Notion and Resend switch** — `apps/web/lib/waitlist.ts`. Each route
  reads its service's keys per request: without them it answers 503 naming
  the keys it lacks, and the page tells the visitor the waitlist is not
  connected yet.
- **The rate limit** — the Worker's `SIGNUP_LIMITER` Workers Rate Limiting
  binding (`apps/web/wrangler.jsonc`: two requests per sixty seconds per
  key), taken by both routes, keyed on the site's host, the route and the
  visitor's `CF-Connecting-IP`. A third request in a minute is refused (429)
  before it reaches Notion or Resend.
- **`tests/web`** — the site's identity, the Notion and Resend switch, the
  rate-limit key, the welcome email and the Worker-secret push (vitest),
  verified on the `dev` rung.
- **`tooling/*`** — shared TypeScript and ESLint configuration, the
  deploy-time wrangler renderer, and `wire/worker-secrets.mjs`, which hands
  Notion's and Resend's keys to the Worker.

Environments: **`stage`** and **`prod`** are deployed; **`dev` is
verify-only by design** — lanes build and test, nothing deploys.

## Identity and tenancy

Every remote operation runs against ONE Orun workspace, declared in
`intent.yaml` under `execution.state.workspace` — committed, enforced, and
what CI uses. Do not remove it; headless credentials depend on it. If it
reads `ws_SET_ME`, the bootstrap had no workspace to write: set the real one
before anything else.

## How deployment works

1. Merge (or push) to `main`.
2. CI (`.github/workflows/ci.yml`) runs `orun plan --changed` — only
   components whose files changed are planned — then runs each planned lane
   with `orun run --remote-state`, authenticated by GitHub OIDC (the
   exchange resolves this repository's linked workspace server-side).
3. `apps/web` builds once per environment, with `NEXT_PUBLIC_SITE_URL` set to
   that environment's `SITE_URL` (intent.yaml) or its workers.dev URL, and
   without Notion's and Resend's keys; the deploy lane then sets the keys
   the environment has on `notion-waitlist-web-<env>` as Worker secrets
   (`wrangler secret bulk`), `wrangler deploy` ships it with its
   `SIGNUP_LIMITER` binding, and a smoke test fetches `/` (rendered to its
   end, with its signup button) and `/api/health` (ok: the Worker has its
   rate-limit binding).
4. `prod` deploys after `stage` has converged on the same commit
   (`environments.prod.promotion` in intent.yaml).
5. **The convergence run is the deployment.** A green run means every
   planned lane applied. Failed lanes are retried with
   `gh run rerun --failed`, which resumes the same execution.

Caveats that matter:

- A push that touches no component files plans zero lanes — that run is
  green and deployed nothing. Never treat "latest run green" as "site
  converged"; probe the URLs instead.
- A change to `intent.yaml`'s `environments` (a new `SITE_URL`, say) maps to
  no component and redeploys nothing on its own. Land it with a change under
  `apps/web`.
- Storing or rotating a Notion or Resend key deploys nothing either: the
  deploy is what hands the keys to the Worker. Redeploy by hand after
  setting them.
- Workers Rate Limiting counts per Cloudflare location and is eventually
  consistent: it is a brake on abuse, not an exact quota.

## Secrets model

- **Brokered provider secrets**: `CLOUDFLARE_API_TOKEN` (Workers deploy
  scope) and `CLOUDFLARE_ACCOUNT_ID` — pointers minted per run from the
  workspace's Cloudflare connection. No long-lived values at rest; nothing
  to rotate by hand.
- **The owner's Notion and Resend keys**, per environment, OPTIONAL:
  `NOTION_SECRET` (the integration's secret), `NOTION_DB` (the database
  signups are written to), `RESEND_API_KEY` and `RESEND_FROM` (the address
  the welcome email is sent from). The build runs without them (`env -u`),
  so no bundle or build cache holds one; the deploy lane hands them to the
  Worker as Worker secrets, the values over stdin, and the Worker reads them
  per request. `apps/web/component.yaml` reads all four as
  `optionalSecretEnv`: a key nobody stored is skipped, and the site deploys
  not connected. Rotate one at Notion or Resend, store the new value
  (`orun secrets set … --env <env>`), redeploy.
- Inspect by NAME only: `orun secrets list --org <ws> --project` and
  `--env stage|prod`. No tooling in this repository prints a secret value,
  and no document in `ai/context/` may contain one. `/api/health` reports
  whether Notion and Resend are connected, never a value.

## Verifying the system

```bash
# the site on each environment (also recorded, probed, in deployment.md)
curl -s -o /dev/null -w '%{http_code}\n' https://notion-waitlist-web-stage.your-workers-subdomain.workers.dev/
curl -s https://notion-waitlist-web-prod.your-workers-subdomain.workers.dev/api/health   # {"ok":true,"rateLimit":"bound","notion":…,"resend":…}

# workspace readiness (integrations + repository link)
orun integrations list --org <ws> --json && orun cloud check --org <ws>
```

## Common operations

| task | how |
|---|---|
| connect Notion and Resend | a Notion integration and a database shared with it, a verified Resend domain and key; `orun secrets set NOTION_SECRET --env <env>` (and `NOTION_DB`, `RESEND_API_KEY`, `RESEND_FROM`), deploy by hand (README, "Connect Notion and Resend") |
| change the rate limit | `limit` (and `period`, 10 or 60) of `SIGNUP_LIMITER` in `apps/web/wrangler.jsonc`; merge |
| change the site's code | `apps/web/app/` and `apps/web/components/`, the email `apps/web/emails/index.tsx`, its name `apps/web/app/site.ts`; merge |
| deploy a change | merge to `main`; watch the run; failed lanes → `gh run rerun --failed` |
| deploy by hand | Orunbase's Deploy button, or `gh workflow run ci.yml --ref main -f environment=<env> [-f component=<a,b>]` — the named components (blank: every one) run in that environment as a merge runs them; started off `main` it is refused |
| redeploy without a change | edit the last line of `apps/web/component.yaml` (`# orun: redeploy <reason> <stamp>`) and merge — it is a deploy trigger, nothing reads it |
| serve a custom domain | attach it to the Worker in Cloudflare, set `SITE_URL` for the environment in `intent.yaml`, and replace the placeholder `notion-waitlist.example.com` in `intent.yaml`'s `BASE_DOMAIN` (dev, stage and prod) with it (README, "Custom domain") |
| add a runtime secret | `orun secrets set <KEY> --org <ws> --env <env>`, then an `optionalSecretEnv` entry in `apps/web/component.yaml` and a `--secret <KEY>` on its `worker-secrets.mjs` call |
| headless credentials | `ORUN_TOKEN` (workspace-scoped) + `GITHUB_TOKEN` |

The deployment record is the bootstrap's `03-docs` phase. Re-running it (the
Orun console's Retry on that phase, or `orun new … --phase 03-docs`)
re-probes the URLs and re-renders [deployment.md](deployment.md); it is
idempotent.

## Evolution

Notion holds the signups; a feature that needs data of the site's own (a
referral count, say) adds a data store. Structural
changes (a second Worker, an API, a data store) follow the same
contract that deployed the site: add a component under `apps/`, `infra/` or
`packages/` with a `component.yaml`, land it as a pull request, and the
convergence run applies it.
