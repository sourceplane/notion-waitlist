# apps/web — the site

The Next.js waitlist with Notion as CMS
([lakshaybhushan/nextjs-notion-waitlist-template](https://github.com/lakshaybhushan/nextjs-notion-waitlist-template)),
running on Cloudflare Workers + Static Assets:

- One animated page: the header, the call to action, the name and email
  form, the "Powered by" logos, the footer and the particles
  (`app/page.tsx`, `components/`)
- `/api/mail` sends the React Email welcome (`emails/index.tsx`) through
  Resend; `/api/notion` adds the signup to a Notion database
- Both routes take the Worker's `SIGNUP_LIMITER` rate limit, two a minute
  per visitor (`wrangler.jsonc`, `lib/waitlist.ts`)
- Tailwind 3, shadcn/ui, framer-motion, Figtree self-hosted

Notion and Resend are connected when the Worker holds their keys
(`lib/waitlist.ts`); until then a signup is told the waitlist is not
connected yet. The site's name and the repository its header links to are
in `app/site.ts`.

```bash
cp .env.example .env.local   # and fill in the four keys
pnpm dev        # next dev on http://localhost:3000
pnpm build      # next build --webpack + opennextjs-cloudflare build → .open-next/
pnpm preview    # wrangler dev over the built Worker (the keys from .dev.vars)
```

How it is deployed — per environment, on merge to `main` — is the
repository's README and `component.yaml` beside this file.
