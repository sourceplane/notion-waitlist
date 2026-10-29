import { spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { describe, expect, it } from "vitest";

// tooling/wire/worker-secrets.mjs: what hands Notion's and Resend's keys to the Worker
// on a deploy, and to wrangler dev locally. Run as the deploy runs it, with a
// made-up value, and never with a Cloudflare credential.
const SCRIPT = path.resolve(__dirname, "../../../tooling/wire/worker-secrets.mjs");
const SECRET = "secret_offline_fixture_not_a_key";

function run(args: string[], env: Record<string, string | undefined>) {
  const clean = { ...process.env };
  delete clean.CLOUDFLARE_API_TOKEN;
  for (const name of ["NOTION_SECRET", "NOTION_DB", "RESEND_API_KEY", "RESEND_FROM"]) delete clean[name];
  return spawnSync(process.execPath, [SCRIPT, ...args], { env: { ...clean, ...env }, encoding: "utf8" });
}

describe("worker-secrets.mjs", () => {
  it("skips an unset secret and succeeds: the build without it needs none", () => {
    const r = run(["--secret", "NOTION_SECRET", "--worker", "acme-web-stage"], {});
    expect(r.status).toBe(0);
    expect(r.stdout).toContain("not set, skipped: NOTION_SECRET");
    expect(r.stdout).toContain("nothing to set");
  });

  it("pushes nothing from a verify lane (no Cloudflare credential), and prints no value", () => {
    const r = run(["--secret", "NOTION_SECRET", "--worker", "acme-web-stage"], { NOTION_SECRET: SECRET });
    expect(r.status).toBe(0);
    expect(r.stdout).toContain("a verify lane");
    expect(r.stdout + r.stderr).not.toContain(SECRET);
  });

  it("writes .dev.vars for wrangler dev, readable by its owner only", () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "worker-secrets-"));
    const file = path.join(dir, ".dev.vars");
    const r = run(["--secret", "NOTION_SECRET", "--dev-vars", file], { NOTION_SECRET: SECRET });
    expect(r.status).toBe(0);
    expect(fs.readFileSync(file, "utf8")).toBe(`NOTION_SECRET="${SECRET}"\n`);
    expect(fs.statSync(file).mode & 0o777).toBe(0o600);
    expect(r.stdout + r.stderr).not.toContain(SECRET);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it("refuses a name that is not an environment variable", () => {
    const r = run(["--secret", "notion-secret", "--worker", "acme-web-stage"], {});
    expect(r.status).toBe(2);
  });
});
