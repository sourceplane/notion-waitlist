import { getCloudflareContext } from "@opennextjs/cloudflare";
import { NextResponse } from "next/server";
import { notionConfig, resendConfig } from "@/lib/waitlist";

// What every deploy's smoke test reads: whether the Worker has what a signup
// needs of its own — the SIGNUP_LIMITER rate-limit binding wrangler.jsonc
// declares — and whether Notion and Resend are connected (their keys are the
// owner's to store, so either answer is ok). Names only — never a value.
export const dynamic = "force-dynamic";

export function GET() {
  const limiter = Boolean(getCloudflareContext().env.SIGNUP_LIMITER);
  return NextResponse.json(
    {
      ok: limiter,
      rateLimit: limiter ? "bound" : "missing",
      notion: notionConfig() ? "connected" : "not-connected",
      resend: resendConfig() ? "connected" : "not-connected",
    },
    { status: limiter ? 200 : 503 },
  );
}
