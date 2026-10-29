# web — architecture

Built by the turbo pipeline from `apps/web` and deployed with wrangler.

|                     |                                                 |
| ------------------- | ----------------------------------------------- |
| Worker config       | `apps/web/wrangler.jsonc`                       |
| Entry               | `.open-next/worker.js`                          |
| Compatibility date  | `2026-10-01`                                    |
| Compatibility flags | `nodejs_compat`, `global_fetch_strictly_public` |

## Bindings

| Binding          | Kind          | Source                        |
| ---------------- | ------------- | ----------------------------- |
| `SIGNUP_LIMITER` | Rate limiter  | 2 requests / 60s per location |
| `ASSETS`         | Static assets | `.open-next/assets`           |

## Secrets resolved by the lane (names only)

- `NOTION_DB` (optional)
- `NOTION_SECRET` (optional)
- `RESEND_API_KEY` (optional)
- `RESEND_FROM` (optional)
