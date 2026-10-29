import { describe, expect, it } from "vitest";
import {
  allowed,
  limitKey,
  missing,
  notConnected,
  notionConfig,
  resendConfig,
  tooManyRequests,
  type RateLimiter,
} from "lib/waitlist";

// apps/web/lib/waitlist.ts: what a signup needs at request time — Notion and
// Resend connected or not, and the per-visitor rate limit both routes take.
const NOTION = { NOTION_SECRET: "secret_fixture", NOTION_DB: "db-fixture" };
const RESEND = { RESEND_API_KEY: "re_fixture", RESEND_FROM: "Acme <hello@acme.test>" };

describe("the Notion and Resend switch", () => {
  it("is connected only with both of a service's keys", () => {
    expect(notionConfig({})).toBeNull();
    expect(notionConfig({ NOTION_SECRET: "x" })).toBeNull();
    expect(notionConfig({ NOTION_DB: "x" })).toBeNull();
    expect(notionConfig(NOTION)).toEqual({ secret: "secret_fixture", database: "db-fixture", baseUrl: undefined });
    expect(resendConfig({ RESEND_API_KEY: "x" })).toBeNull();
    expect(resendConfig({ RESEND_FROM: "x" })).toBeNull();
    expect(resendConfig(RESEND)).toEqual({ apiKey: "re_fixture", from: "Acme <hello@acme.test>" });
  });

  it("takes the Notion API's origin from NOTION_API_BASE_URL, else the client's default", () => {
    expect(notionConfig({ ...NOTION, NOTION_API_BASE_URL: "http://127.0.0.1:9" })?.baseUrl).toBe("http://127.0.0.1:9");
    expect(notionConfig({ ...NOTION, NOTION_API_BASE_URL: "" })?.baseUrl).toBeUndefined();
  });

  it("answers a signup it cannot take with a 503 naming what is missing, never a value", async () => {
    expect(missing({ NOTION_SECRET: "x" }, ["NOTION_SECRET", "NOTION_DB"])).toEqual(["NOTION_DB"]);
    const r = notConnected("Resend", { RESEND_API_KEY: "re_should_not_leak" });
    expect(r.status).toBe(503);
    const body = await r.text();
    expect(JSON.parse(body)).toEqual({ error: "Resend is not connected", missing: ["RESEND_FROM"] });
    expect(body).not.toContain("re_should_not_leak");
  });
});

describe("the rate limit", () => {
  const request = (url: string, ip?: string) =>
    new Request(url, { method: "POST", headers: ip ? { "cf-connecting-ip": ip } : {} });

  it("counts a visitor per route and per site", () => {
    expect(limitKey("mail", request("https://a.example/api/mail", "203.0.113.7"))).toBe("a.example:mail:203.0.113.7");
    expect(limitKey("notion", request("https://a.example/api/notion", "203.0.113.7"))).toBe("a.example:notion:203.0.113.7");
    expect(limitKey("mail", request("https://b.example/api/mail", "203.0.113.7"))).toBe("b.example:mail:203.0.113.7");
  });

  it("counts a request without CF-Connecting-IP as upstream did, as 127.0.0.1", () => {
    expect(limitKey("mail", request("http://localhost:8787/api/mail"))).toBe("localhost:8787:mail:127.0.0.1");
  });

  it("asks the binding, and refuses what it refuses", async () => {
    const seen: string[] = [];
    const counts = new Map<string, number>();
    const limiter: RateLimiter = {
      async limit({ key }) {
        seen.push(key);
        counts.set(key, (counts.get(key) ?? 0) + 1);
        return { success: (counts.get(key) ?? 0) <= 2 };
      },
    };
    const r = () => request("https://a.example/api/mail", "198.51.100.1");
    expect(await allowed(limiter, "mail", r())).toBe(true);
    expect(await allowed(limiter, "mail", r())).toBe(true);
    expect(await allowed(limiter, "mail", r())).toBe(false);
    expect(await allowed(limiter, "notion", r())).toBe(true);
    expect(seen).toEqual([
      "a.example:mail:198.51.100.1",
      "a.example:mail:198.51.100.1",
      "a.example:mail:198.51.100.1",
      "a.example:notion:198.51.100.1",
    ]);
    const refused = tooManyRequests();
    expect(refused.status).toBe(429);
    expect(await refused.json()).toEqual({ error: "Too many requests!!" });
  });

  it("fails loudly without its binding rather than letting every request through", async () => {
    await expect(allowed(undefined, "mail", request("https://a.example/"))).rejects.toThrow(/SIGNUP_LIMITER/);
  });
});
