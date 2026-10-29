# Epics

Orun-style work programs. Each epic is a folder carrying `epic.yaml` (the
declaration the platform reads: slug, key prefix, milestones with exit
criteria and task keys) beside its doc set. The pull request that adds the
folder is the adoption; the merge creates the epic in the workspace.

| Epic | Cluster | Status | What it is |
|------|---------|--------|------------|
| [`notion-waitlist/`](./notion-waitlist/) | **NW** | In progress (NW1: the site on Workers) | Vercel's Next.js Waitlist with Notion CMS — the Next.js waitlist with Notion as CMS — on Cloudflare Workers + Static Assets through OpenNext, with Cloudflare's rate-limit binding for Upstash, Notion's and Resend's keys as Orun secrets, and an Orun baseline that instantiates it (NW2) |

As-built ≠ intent: what shipped lives in each epic's `IMPLEMENTATION-STATUS.md`.
