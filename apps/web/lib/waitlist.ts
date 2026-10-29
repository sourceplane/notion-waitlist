// What a signup needs at request time: whether Notion and Resend are
// connected, and the per-visitor rate limit.
//
// Notion's and Resend's keys are the Worker's secrets (Orun secrets the
// deploy hands over, README → Connect Notion and Resend), read per request:
// a deploy without them still serves the page, and a signup is told the
// waitlist is not connected yet (503), never a 500. Names only ever leave
// this module, never a value.

export type Connection = "connected" | "not-connected";

export interface NotionConfig {
  secret: string;
  database: string;
  // The Notion API's origin. Unset in a deployment (the client's default,
  // https://api.notion.com); the end-to-end tier points it at a stand-in.
  baseUrl?: string;
}

export interface ResendConfig {
  apiKey: string;
  from: string;
}

type Env = Record<string, string | undefined>;

export function notionConfig(env: Env = process.env): NotionConfig | null {
  const secret = env.NOTION_SECRET;
  const database = env.NOTION_DB;
  if (!secret || !database) return null;
  return { secret, database, baseUrl: env.NOTION_API_BASE_URL || undefined };
}

export function resendConfig(env: Env = process.env): ResendConfig | null {
  const apiKey = env.RESEND_API_KEY;
  const from = env.RESEND_FROM;
  if (!apiKey || !from) return null;
  return { apiKey, from };
}

// The names a service still needs, for the 503 a signup gets.
export function missing(env: Env, names: string[]): string[] {
  return names.filter((name) => !env[name]);
}

export const NOTION_KEYS = ["NOTION_SECRET", "NOTION_DB"];
export const RESEND_KEYS = ["RESEND_API_KEY", "RESEND_FROM"];

export function notConnected(service: "Notion" | "Resend", env: Env = process.env): Response {
  return Response.json(
    {
      error: `${service} is not connected`,
      missing: missing(env, service === "Notion" ? NOTION_KEYS : RESEND_KEYS),
    },
    { status: 503 },
  );
}

// ── The rate limit ────────────────────────────────────────────────────────
//
// Upstream limited the mail route with Upstash Redis — two requests per
// minute per IP address. Here it is Cloudflare's Workers Rate Limiting
// binding (wrangler.jsonc: SIGNUP_LIMITER, two per sixty seconds), and it
// covers BOTH routes that do work — the mail route and the Notion route —
// each with its own count, so a signup (one of each) fits and a third
// request to either in a minute is refused.
//
// The key carries the site's host: a rate-limit namespace is the account's,
// so two sites — this one's environments, or two products on one account —
// never share a visitor's count. The visitor is Cloudflare's
// CF-Connecting-IP (Next 15 dropped `request.ip`); a request without one is
// counted as upstream counted it, as 127.0.0.1.

export interface RateLimiter {
  limit(options: { key: string }): Promise<{ success: boolean }>;
}

export function limitKey(route: "mail" | "notion", request: Request): string {
  const host = new URL(request.url).host;
  const ip = request.headers.get("cf-connecting-ip") ?? "127.0.0.1";
  return `${host}:${route}:${ip}`;
}

export async function allowed(
  limiter: RateLimiter | undefined,
  route: "mail" | "notion",
  request: Request,
): Promise<boolean> {
  if (!limiter) throw new Error("the SIGNUP_LIMITER rate-limit binding is missing");
  const { success } = await limiter.limit({ key: limitKey(route, request) });
  return success;
}

export function tooManyRequests(): Response {
  return Response.json({ error: "Too many requests!!" }, { status: 429 });
}
