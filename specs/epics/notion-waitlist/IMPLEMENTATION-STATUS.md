# notion-waitlist — implementation status

| Milestone | State | Landed |
|---|---|---|
| NW0 — the spec | ✅ | the repository's first commit |
| NW1 — the waitlist on Workers | ✅ | NW-2 |
| NW2 — a baseline | planned | NW-3 |

## Departures from the upstream template

Everything not listed here is the template as it is upstream at `4798588`.

| # | What | Why |
|---|---|---|
| 1 | The app lives in `apps/web` of a pnpm workspace (the root lockfile, pnpm 10.12.1) instead of a Bun lockfile | One lockfile for the workspace, the composition's package manager |
| 2 | Next 16.3.8, React 19, `eslint-config-next` 16.3.8 (flat config, its `core-web-vitals` rules as upstream's `next/core-web-vitals`, the React Compiler's `react-hooks/immutability` off by name for the particles canvas); framer-motion 12, sonner 2, next-themes 0.4, `@radix-ui/react-slot` 1.2 — the versions that support React 19; Tailwind 3 kept | OpenNext 1.20 refuses Next 15.5 and every OpenNext starter here is proven on 16.3.8 (risk NW-D); the template's look is Tailwind 3's |
| 3 | `next build --webpack` | Turbopack's per-route server chunks put the Worker at 2.97 MiB gzipped, against Workers Free's 3 MiB; webpack's are 1.48 MiB |
| 4 | Upstash's `Ratelimit` → the Worker's `SIGNUP_LIMITER` Workers Rate Limiting binding (two per sixty seconds, a fixed window), keyed on the site's host, the route and `CF-Connecting-IP`, on BOTH `/api/mail` and `/api/notion` (upstream limited only the mail route) | The brief's mapping; the Notion route wrote to the owner's database for anyone who called it; `request.ip` is gone in Next 15+ (risk NW-C) |
| 5 | Notion's and Resend's keys read per request (`lib/waitlist.ts`); without them each route answers 503 naming the keys it lacks, and the page's toast says the waitlist is not connected yet; the Resend client is created per request | A site is born without them; upstream's module-level Resend client throws without a key |
| 6 | The email's sender is `RESEND_FROM` (a fourth Orun secret), its reply-to and its "reply to this email" mailto (the template author's address) are gone, and its logo is on the site's own origin | Mail from the owner's product must not come from, or reply to, the template's author; the logo was the template's vercel.app deployment |
| 7 | `/api/mail` answers 502 when Resend refuses (upstream answered 200 with Resend's error, and the page went on to write the row) | The page's "Failed to send email" toast was unreachable |
| 8 | The Notion client is given the Worker's fetch through a plain function | Its default is node-fetch, and it calls what it is given as a method of itself, which workerd refuses for its native fetch |
| 9 | Each React Email component from its own package (`@react-email/body`, …) instead of `@react-email/components`; `@react-email/render` 2 | The components package carries a Tailwind compiler the email does not use |
| 10 | Figtree self-hosted (`next/font/local` over `@fontsource-variable/figtree`, OFL-1.1) | `next/font/google` fetches Google Fonts at build and fails on GitHub's runners |
| 11 | `@vercel/analytics` dropped; the unused `@svgr/webpack`, `lucide-react`, `@radix-ui/react-label` and the `react-email` preview CLI dropped; `.prettierrc` and `.eslintrc.json` replaced by the workspace's lint | Vercel-only, or never imported; the preview server is a dev tool with its own Next |
| 12 | The "Upstash" and "Vercel" logos under "Powered by" dropped; the grid is two by two | The port uses neither |
| 13 | `opengraph-image.png` and `twitter-image.png` moved from `app/` to `public/` and named in `metadata` (with `og:site_name` and `og:url`), replacing the hand-written meta tags | As file conventions Next compiles each 1.3 MB image into the Worker; the hand-written `og:image` was relative and `og:url` the template's vercel.app |
| 14 | `app/site.ts` (`SITE_NAME`, `SOURCE_URL`, `SITE_URL`); the title, `og:site_name` and `metadataBase` read them; the description says Cloudflare instead of Upstash and Vercel | One rename seam; the origin per environment |
| 15 | "Use this template" links the site's own repository (`SOURCE_URL`), not a fork of upstream | The site deploys from its own repository |
| 16 | The email component is `WaitlistWelcomeEmail` (upstream: `NotionWaitlistEmail`); the email's apostrophes are HTML entities | The rename's sweep refuses the baseline's Pascal name anywhere; the lint's `react/no-unescaped-entities` (the rendered email is the same) |
| 17 | `/api/health`, `next.config.ts`, `open-next.config.ts`, `wrangler.jsonc`, `cloudflare-env.d.ts`, `component.yaml`, `tooling/wire/worker-secrets.mjs` | The Workers build, its deploy contract and the deploy's smoke |
| 18 | `tests/web` (vitest) | The template ships none |
