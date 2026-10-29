# notion-waitlist — where this repository stands

The entry page for anyone (or any agent) picking this repository up. It is
this repository's own state and does not ship to a site built from it; the
pages that do are [operations.md](operations.md) and
[deployment.md](deployment.md), with the site's `AGENTS.md`.

## What it is

The Next.js waitlist with Notion as CMS
(lakshaybhushan/nextjs-notion-waitlist-template, the template behind
Vercel's Next.js Waitlist with Notion CMS) — an animated one-page signup
that saves each visitor to a Notion database and sends a React Email welcome
through Resend, rate-limited per visitor by the Worker's own Workers Rate
Limiting binding — built by OpenNext into one Cloudflare Worker with Static
Assets, packaged as an Orun baseline: `orun new --blueprint
repo-blueprint.yaml` builds a new site in its own repository and takes it to
live on stage and prod in one landing (`01-product`), then records what went
live (`03-docs`). A site is born without Notion and Resend: its page serves
and a signup is told the waitlist is not connected yet until its owner
stores the four keys.

## Release

| | |
|---|---|
| Latest tag | `baseline-v1` — NW0 to NW2: the repository, the waitlist on Workers, and the baseline (blueprint, phases, tests) |
| Proven live | Not yet: proven offline in Baseline CI only (risk NW-A) |
| Registry | Unlisted: the template has no licence file (risk NW-E) |

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/notion-waitlist/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/notion-waitlist/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/notion-waitlist/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What the components are | `apps/web/docs/`, `tests/web/docs/` (generated; `python3 tooling/catalog/gen-component-docs.py`) |

## Next

1. Bootstrap one site from `baseline-v1` from the console and record its
   timings against the 5-minute estimate (closes NW-A).
2. On that site, store a Notion database's and a Resend domain's keys for
   stage, redeploy, and sign up once (closes NW-B).
3. The registry row goes public only once the template's licence question
   is settled (NW-E).
