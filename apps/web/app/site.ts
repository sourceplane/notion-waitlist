// The site's identity, written once. The page title, the Open Graph card and
// the welcome email's sign-off read SITE_NAME; the header's "Use this
// template" link is SOURCE_URL. A product built from this baseline gets both
// rewritten to its own name and repository at instantiation, so keep them
// literal and on one line each.
export const SITE_NAME = "Next.js + Notion — Waitlist Template";
export const SOURCE_URL = "https://github.com/sourceplane/notion-waitlist";

// The site's public origin: metadataBase (the Open Graph image's absolute
// URL), og:url and the welcome email's logo. The Orun build sets
// NEXT_PUBLIC_SITE_URL per environment: its SITE_URL from intent.yaml, else
// its workers.dev URL.
export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";
