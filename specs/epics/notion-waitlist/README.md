# notion-waitlist — Vercel's Next.js Waitlist with Notion CMS on Cloudflare Workers

**The Next.js waitlist with Notion as CMS built by OpenNext into one
Cloudflare Worker, deployed by Orun to stage and prod on every merge — a
signup saved to a Notion database and welcomed through Resend, rate-limited
per visitor by the Worker's own binding, and a site that serves before its
owner has connected either — and the baseline that makes a copy of it
somebody else's in one landing.**

| | |
|---|---|
| Status | ✅ Shipped (`baseline-v1`) — proven offline in Baseline CI; not yet live (risk NW-A) |
| Upstream | [lakshaybhushan/nextjs-notion-waitlist-template](https://github.com/lakshaybhushan/nextjs-notion-waitlist-template), at `4798588` (2025-06-25) |
| Reference | [portfolio-starter-kit](https://github.com/sourceplane/portfolio-starter-kit) — the same scaffolding, tests and bootstrap; [clerk-auth-starter](https://github.com/sourceplane/clerk-auth-starter) — a SaaS's keys as optional Orun secrets, handed to the Worker by the deploy, and a site that serves before they exist |
| Key | `NW` |

## Read in this order

1. [design.md](design.md) — the template, how each Vercel piece maps to
   Cloudflare, the rate limit, the site before Notion and Resend are
   connected, the repository and the build, and the alternatives rejected.
2. [implementation-plan.md](implementation-plan.md) — the milestones and
   what each one lands.
3. [risks-and-open-questions.md](risks-and-open-questions.md) — what is not
   proven, and what was accepted.
4. [IMPLEMENTATION-STATUS.md](IMPLEMENTATION-STATUS.md) — what shipped, and
   every departure from the upstream template.

## Milestones

| Milestone | What it lands | Task |
|---|---|---|
| NW0 — the spec | the repository, its intent, CI, tooling and spec index; this doc set | NW-1 |
| NW1 — the waitlist on Workers | the template in `apps/web`, built by OpenNext into one Worker; the rate-limit binding; the Notion and Resend switch; the Worker-secret push; `tests/web` | NW-2 |
| NW2 — a baseline | the console card, the build document, the context pack and the baseline's tests | NW-3 |
