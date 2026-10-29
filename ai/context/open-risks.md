# notion-waitlist — open risks

What is not yet proven or not yet decided. The full write-up of every risk,
including the accepted and resolved ones, is
`specs/epics/notion-waitlist/risks-and-open-questions.md`; this page lists
only what is still live, so it should be short.

| ID | Risk | State | What closes it |
|---|---|---|---|
| NW-A | `baseline-v1` is not yet proven live; it is proven offline in Baseline CI (the offline bootstrap, the stage lane's own steps, the site served and smoke-tested not connected and connected to a local stand-in) | OPEN | One console bootstrap from `baseline-v1` |
| NW-B | A signup against the real Notion and Resend has not run on the Worker: offline, a stand-in reads back what both clients send, and the first `wrangler secret bulk` on a Worker that does not exist yet has not run | OPEN | The four keys stored on a live site's stage, redeployed, one signup |
| NW-F | `@notionhq/client` 2 bundles node-fetch, handed the Worker's fetch instead | WATCH | Holds while every e2e signs up through it |

Accepted, and worth knowing before you change them: NW-C (the rate limit is
per location, eventually consistent), NW-D (Next 16.3.8, not 14.2.4), NW-E
(no licence file; the README's grant only), NW-G (the email's words are the
template author's).
