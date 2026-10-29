# notion-waitlist — implementation plan

Three milestones, each one reviewed pull request (NW0 is the repository's
first commit), each green before it merges.

## NW0 — the spec (NW-1)

The repository is born: `intent.yaml` with the placeholder workspace
`ws_CHANGE_ME`, `ci.yml` (portfolio-starter-kit's, which plans nothing
until the workspace is set), the shared TypeScript and ESLint configuration,
the spec index, this doc set and the task contracts.

## NW1 — the waitlist on Workers (NW-2)

- The template's `app/`, `components/`, `lib/`, `emails/`, `public/` and
  Tailwind configuration in `apps/web`; its dependencies on Next 16.3.8 and
  React 19, with `@opennextjs/cloudflare` and `wrangler`; Figtree
  self-hosted; the unused and Vercel-only dependencies dropped.
- `next.config.ts` (`output: 'standalone'`, the workspace root, images
  unoptimized), `open-next.config.ts` with the static-assets incremental
  cache, `wrangler.jsonc` with the `SIGNUP_LIMITER` rate limit, and the
  build on webpack.
- `lib/waitlist.ts`: the Notion and Resend switch, the 503 that names what
  is missing, the rate-limit key and check; both routes read them;
  `/api/health`. The page's toast for a waitlist not connected yet.
- The email: each React Email component from its own package, the sender
  `RESEND_FROM`, no reply-to, the logo on the site's origin.
- `SITE_NAME`, `SOURCE_URL` and `SITE_URL` in `app/site.ts`; the metadata
  reads them. "Use this template" is the source link.
- `tooling/wire/worker-secrets.mjs`; `component.yaml`: the optional secret
  refs, the deploy contract (the origin per environment, the build without
  the keys, the secret push) and its smoke. `tests/web`: the identity, the
  switch, the rate-limit key, the email, the secret push.
- The README's "How it maps to Vercel".

## NW2 — a baseline (NW-3)

portfolio-starter-kit's machinery, renamed: `blueprint.yaml`,
`repo-blueprint.yaml`, `.baseline/` (identity, the product's README with
"Connect Notion and Resend" and "The rate limit", its `AGENTS.md`, task
contracts), `tooling/rebrand` (the template's repository and demo masked as
credit), `tooling/bootstrap`, `hooks/render-deployment-docs.sh` (probing
`/` and `/api/health`, naming the four keys), `docs/phases/`, the context
pack, `testing/` (the leak and placement gates on this tree's files, the
optional refs and the binding checked in the plan; the e2e tier building and
serving the site not connected, then with made-up keys against a local
stand-in of Notion's and Resend's APIs, then without its binding) and
`baseline.yml` / `tag.yml`.
