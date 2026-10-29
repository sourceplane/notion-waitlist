#!/usr/bin/env bash
# TIER 2 — the site a bootstrap produces builds, deploys (dry) and serves.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree.
# This proves it WORKS, by doing to it what its own pipelines will:
#
#   1. at the finished site, the landing's own checks — install with the
#      lockfile the site ships, render fixtures, typecheck, lint, test,
#      build. The bootstrap's own landings are checked in the box with
#      `orun validate` and `orun plan` alone (`checks: local`; their PR's CI
#      on an `orun/BASE-…` branch is `plan` alone, and the convergence on
#      main builds, deploys and smoke-tests the site), so THIS is where a
#      site those steps refuse is caught: before the tag, not after a build
#      has merged it. Every later pull request of the site runs ci.yml's
#      verify lanes;
#   2. the stage lane's own steps, rendered by `orun plan` in the site: on a
#      pull request (the verify profile) `build-app` — the component's
#      buildCommand, origin and all, the same step the deploy profile runs —
#      `verify-build-output` and `deploy-dry-run` (`wrangler deploy --dry-run
#      --name <reponame>-web-stage`). They run IN THE TREE THE RUNNER STAGES
#      for the job (testing/lib/stage-job.py), with the dependency layout the
#      pinned composition produces: if its install step is `scope: lane`, the
#      top-level node_modules is a symlink to the source checkout's; if not,
#      the job's own install step runs inside the staged tree. Run in a plain
#      checkout, this tier was green while the first live bootstrap's lanes
#      died in the lane layout (Turbopack: "Symlink … points out of the
#      filesystem root");
#   3. serve the built Worker with `wrangler dev` and run the component's OWN
#      `smokeCommand` against it, verbatim — the check the real deploy ends
#      with — and then read every route the site promises. A fresh site has
#      no Notion database or Resend domain, so this is the site as it is born:
#      the template's page, titled with the site's name and linking the
#      site's repository, its assets, /api/health ok with its rate limit
#      bound, and a signup told the waitlist is not connected yet (503,
#      naming the keys it lacks). The lane's deploy dry run lists the
#      SIGNUP_LIMITER rate-limit binding: the deploy keeps it;
#   4. the same stage lane's build-app again, now with Notion's and Resend's
#      four keys in its environment as the optional secret refs put them
#      there (made-up keys), and the result checked: no key in any file of
#      the build, the keys handed to the Worker only from a lane that can
#      deploy. Served with the keys as the deploy hands them over (wrangler's
#      .dev.vars) and Notion's and Resend's APIs a local stand-in
#      (lib/stand-in.py), one signup is the template's own: the welcome email
#      from RESEND_FROM to the visitor, the row in NOTION_DB, each read back
#      from what the stand-in was sent; a third email or row in a minute is
#      refused (429) before it reaches either. Served WITHOUT its rate-limit
#      binding, the deploy's smoke must fail: a Worker that lost it is caught
#      by the deploy, not by a visitor.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered Cloudflare token, deploy for real and probe workers.dev. That is a
# bootstrap against a workspace (BOOTSTRAP.md); everything short of it is here.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, and the network for
# `pnpm install` (or a warm store). A few minutes: two installs and three
# builds (the landing's checks over the site, and the stage lane's own in its
# staged tree, without Notion's and Resend's keys and with them).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git curl; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
dev_pid=""
# wrangler dev runs under pnpm, node and two workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So it is
# started as its own process group (setsid) and the whole group is stopped.
cleanup() {
  if [ -n "$dev_pid" ]; then
    kill -TERM -- "-$dev_pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$dev_pid" 2>/dev/null || break; sleep 0.5; done
    kill -KILL -- "-$dev_pid" 2>/dev/null || true
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
sub="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['subdomain'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false NEXT_TELEMETRY_DISABLED=1 TURBO_TELEMETRY_DISABLED=1

# The landing's own checks, step for step, run here at once on the whole
# tree. A pull request in the site builds and dry-deploys it through ci.yml's
# lanes; the lint and the tests run here, and by hand before a push.
LANDING_CHECKS=(
  "pnpm install --frozen-lockfile"
  "pnpm run wire:fixture"
  "pnpm typecheck"
  "pnpm lint"
  "pnpm test"
  "pnpm build"
)
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  for cmd in "${LANDING_CHECKS[@]}"; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
echo "   2 phases placed and landed"

# ── 1. the finished site ───────────────────────────────────────────────────
echo "── the finished site: install, the fixture render, typecheck, lint, test, build"
checks "$tree" "$scratch/checks-site.log"

# ── 2. the deploy lane's steps, for stage ──────────────────────────────────
echo "── the stage lane: build-app, verify-build-output, deploy-dry-run"
# The 01-product landing over the repository's empty first commit: every file
# of the site changed, as on its pull request.
s00="$(git -C "$tree" rev-parse HEAD~2)"; s01="$(git -C "$tree" rev-parse HEAD~1)"
(cd "$tree" && orun plan --intent intent.yaml --trigger github-pull-request --changed \
   --base "$s00" --head "$s01" --env stage --output "$scratch/plan.json") > "$scratch/plan.log" 2>&1 \
  || { echo "FAIL: orun plan" >&2; tail -15 "$scratch/plan.log" >&2; exit 1; }
python3 - "$scratch/plan.json" "$scratch/steps" <<'PY'
import json, pathlib, sys
plan = json.load(open(sys.argv[1]))
out = pathlib.Path(sys.argv[2]); out.mkdir()
job = next(j for j in plan["jobs"] if j["component"] == "web" and j["environment"] == "stage")
for s in job["steps"]:
    if s["id"] in ("build-app", "verify-build-output", "deploy-dry-run"):
        (out / f"{s['id']}.sh").write_text(s.get("run") or "")
    if s["id"] == "install-workspace-dependencies":
        (out / "install.sh").write_text(s.get("run") or "")
        (out / "install.wd").write_text(s.get("working-directory") or ".")
        (out / "install.scope").write_text(s.get("scope") or "job")
(out / "path").write_text(job.get("path") or "apps/web")
for k, v in (job.get("env") or {}).items():
    (out / "env").open("a").write(f"export {k}={json.dumps(v)}\n")
PY
# The job's private tree, staged as orun stages it. The source checkout
# carries no build output (a CI checkout has none, so the plain-tree build's is
# removed rather than copied in), and its dependencies are what the pinned
# composition says: a lane-scoped install ran once in the source tree (step 1
# ran the same command) and is linked in, or the job installs its own.
rm -rf "$tree/apps/web/.open-next" "$tree/apps/web/.wrangler"
work="$tree/.orun/runs/e2e/web.stage.verify-deploy/work"
[ -f "$scratch/steps/install.sh" ] || { echo "FAIL: the stage lane has no install step" >&2; exit 1; }
if [ "$(cat "$scratch/steps/install.scope")" = lane ]; then
  python3 "$here/lib/stage-job.py" "$tree" "$work" --shared-deps
  [ -L "$work/node_modules" ] || { echo "FAIL: the staged tree's node_modules is not the lane's symlink" >&2; exit 1; }
  echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: lane — node_modules → the source tree's"
else
  python3 "$here/lib/stage-job.py" "$tree" "$work"
  echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: job — installing inside it"
  echo "   ▸ install-workspace-dependencies"
  (cd "$work/$(cat "$scratch/steps/path")/$(cat "$scratch/steps/install.wd")" && bash -e "$scratch/steps/install.sh") \
    > "$scratch/install.log" 2>&1 || { echo "FAIL: the lane's install step" >&2; tail -30 "$scratch/install.log" >&2; exit 1; }
  [ -d "$work/node_modules" ] && [ ! -L "$work/node_modules" ] \
    || { echo "FAIL: the job's install did not land inside its own tree" >&2; exit 1; }
fi
for step in build-app verify-build-output deploy-dry-run; do
  [ -f "$scratch/steps/$step.sh" ] || { echo "FAIL: the stage verify lane has no $step step" >&2; exit 1; }
  echo "   ▸ $step"
  # The runner's per-job environment: the job's env (intent environment
  # `env:`) and ORUN_ENVIRONMENT; the step runs in the component's directory.
  if ! (cd "$work/$(cat "$scratch/steps/path")" && \
        { [ -f "$scratch/steps/env" ] && source "$scratch/steps/env"; true; } && \
        export ORUN_ENVIRONMENT=stage && bash -e "$scratch/steps/$step.sh") > "$scratch/$step.log" 2>&1; then
    echo "FAIL: the deploy lane's $step step" >&2; tail -40 "$scratch/$step.log" >&2; exit 1
  fi
done

# ── 3. serve it, and smoke it as the deploy does ───────────────────────────
# serve DIR LOG [DEV_VARS [CONFIG]] — wrangler dev over the built Worker in
# DIR, on a free port; sets $url. DEV_VARS, when given, is the Worker's
# secrets file; CONFIG another wrangler config in DIR.
serve() {
  local dir="$1" log="$2" vars="${3:-}" config="${4:-wrangler.jsonc}"
  stop_dev
  port=$(python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()")
  rm -f "$dir/.dev.vars"
  [ -n "$vars" ] && cp "$vars" "$dir/.dev.vars"
  (cd "$dir" && exec setsid pnpm exec wrangler dev --config "$config" --ip 127.0.0.1 --port "$port" \
     --name "$repo-web-stage" --show-interactive-dev-session=false) > "$log" 2>&1 < /dev/null &
  dev_pid=$!
  # By name, not by address: wrangler dev hands the Worker `localhost` as the
  # request's host whichever address it was reached on; on workers.dev the
  # two agree.
  url="http://localhost:$port"
  for _ in $(seq 1 90); do
    curl -s -o /dev/null "$url/" && return 0
    kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev exited" >&2; tail -30 "$log" >&2; exit 1; }
    sleep 1
  done
  curl -s -o /dev/null "$url/" || { echo "FAIL: wrangler dev never answered" >&2; tail -30 "$log" >&2; exit 1; }
}
stop_dev() {
  if [ -n "$dev_pid" ]; then
    kill -TERM -- "-$dev_pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$dev_pid" 2>/dev/null || break; sleep 0.5; done
    kill -KILL -- "-$dev_pid" 2>/dev/null || true
    dev_pid=""
  fi
}
smoke="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/web/component.yaml")"
app="$work/$(cat "$scratch/steps/path")"

echo "── wrangler dev over the built Worker: the site as it is born, Notion and Resend not connected"
serve "$app" "$scratch/dev.log"
echo "   ▸ the component's own smokeCommand, DEPLOYED_URL=$url"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the site" >&2; exit 1; }

echo "   ▸ every route the site promises"
# routes MODE [STAND_IN_LOG KEYS_JSON] — MODE not-connected | connected.
routes() {
python3 - "$url" "$values" "https://$repo-web-stage.$sub.workers.dev" "$@" <<'PY'
import html, json, re, sys, urllib.error, urllib.request
base, values, origin, mode = sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3], sys.argv[4]
log = sys.argv[5] if len(sys.argv) > 5 else None
keys = json.loads(sys.argv[6]) if len(sys.argv) > 6 else {}
name, repo, org = values["productname"], values["reponame"], values["githuborg"]
problems = []
def bad(m): problems.append(m)
def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(base + path, data=data, method=method,
                                 headers={"content-type": "application/json"} if data else {})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, r.read().decode(errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace")
def as_json(text):
    try:
        return json.loads(text)
    except ValueError:
        return None
def calls():
    if not log:
        return []
    try:
        return [json.loads(l) for l in open(log) if l.strip()]
    except FileNotFoundError:
        return []

status, page = call("GET", "/")
if status != 200 or "</html>" not in page:
    bad(f"/ answered {status}, or did not render to its end")
title = re.search(r"<title>(.*?)</title>", page, re.S)
if not title or html.unescape(title.group(1)) != name:
    bad(f"the home page's <title> is {title and title.group(1)!r}, not {name!r}")
if f'href="https://github.com/{org}/{repo}"' not in page:
    bad(f"the header's \"Use this template\" does not link the site's repository github.com/{org}/{repo}")
for prop, image in (("og:image", "opengraph-image.png"), ("twitter:image", "twitter-image.png")):
    m = re.search(rf'<meta (?:property|name)="{prop}" content="([^"]+)"', page)
    if not m or m.group(1) != f"{origin}/{image}":
        bad(f"the {prop} card is not the template's image, absolute on {origin}: {m and m.group(1)}")
site = re.search(r'<meta property="og:site_name" content="([^"]+)"', page)
if not site or html.unescape(site.group(1)) != name:
    bad(f"og:site_name is {site and site.group(1)!r}, not {name!r}")
text = html.unescape(page)
for want in ("A Simple Next.js Waitlist Template with Notion as CMS", "Join Waitlist!", "Brought to you by", "Powered by"):
    if want not in text:
        bad(f"the home page lost the template's {want!r}")
if "Next.js + Notion — Waitlist Template" in text or "notion-waitlist" in page:
    bad("the home page still carries the baseline's name")
for gone in ("upstash", "vercel.app", "vercel.com", "_vercel/insights"):
    if gone in page.lower():
        bad(f"the home page still carries {gone!r} — the port uses neither Upstash nor Vercel")
for asset in ("/logo.svg", "/notion.svg", "/resend.svg", "/opengraph-image.png", "/waitlist-logo.png"):
    s, _ = call("GET", asset)
    if s != 200:
        bad(f"{asset} answered {s}")

s, body = call("GET", "/api/health")
want = {"ok": True, "rateLimit": "bound", "notion": mode, "resend": mode}
if s != 200 or as_json(body) != want:
    bad(f"/api/health answered {s} {body[:160]!r}, want 200 {want}")
s, _ = call("GET", "/no-such-page")
if s != 404:
    bad(f"/no-such-page answered {s}, want 404")

visitor = "Ada O'Brien & Co"
email = "ada+waitlist@example.org"
if mode == "not-connected":
    s, body = call("POST", "/api/mail", {"firstname": visitor, "email": email})
    if s != 503 or as_json(body) != {"error": "Resend is not connected", "missing": ["RESEND_API_KEY", "RESEND_FROM"]}:
        bad(f"/api/mail answered {s} {body[:120]!r} without Resend — want 503 and what is missing")
    s, body = call("POST", "/api/notion", {"name": visitor, "email": email})
    if s != 503 or as_json(body) != {"error": "Notion is not connected", "missing": ["NOTION_SECRET", "NOTION_DB"]}:
        bad(f"/api/notion answered {s} {body[:120]!r} without Notion — want 503 and what is missing")
    chunks = re.findall(r'<script src="(/_next/static/chunks/[^"]+\.js)"', page)
    if not any("This waitlist is not connected yet" in call("GET", c)[1] for c in chunks):
        bad("no page script tells a visitor the waitlist is not connected yet")
else:
    # One signup, as the page makes it: the welcome email, then the row.
    s, body = call("POST", "/api/mail", {"firstname": visitor, "email": email})
    if s != 200 or as_json(body) != {"message": "Email sent successfully"}:
        bad(f"/api/mail answered {s} {body[:160]!r}, want 200 and the template's message")
    s, body = call("POST", "/api/notion", {"name": visitor, "email": email})
    if s != 200 or as_json(body) != {"success": True}:
        bad(f"/api/notion answered {s} {body[:160]!r}, want 200 success")
    got = calls()
    mails = [c for c in got if c["path"] == "/emails"]
    pages = [c for c in got if c["path"] == "/v1/pages"]
    if len(mails) != 1 or len(pages) != 1 or len(got) != 2:
        bad(f"one signup sent {[c['path'] for c in got]} — want one email and one page")
    if mails:
        m = mails[0]; b = m["body"]
        if m["authorization"] != f"Bearer {keys['RESEND_API_KEY']}":
            bad("Resend was not called with the RESEND_API_KEY the Worker holds")
        if b.get("from") != keys["RESEND_FROM"] or b.get("to") != [email]:
            bad(f"the email goes from {b.get('from')!r} to {b.get('to')!r} — want RESEND_FROM to the visitor")
        if b.get("subject") != "Thankyou for wailisting the Next.js + Notion CMS template!":
            bad(f"the email's subject is {b.get('subject')!r}, not the template's")
        if "reply_to" in b or "replyTo" in b:
            bad("the email still sets a reply-to (the template sent replies to its author)")
        body_text = html.unescape(re.sub(r"<!-- -->", "", b.get("html", "")))
        if f"Hi {visitor}," not in body_text or "Thanks for joining the waitlist" not in body_text:
            bad("the email is not the template's welcome, addressed to the visitor")
        if f'src="{origin}/waitlist-logo.png"' not in b.get("html", ""):
            bad(f"the email's logo is not on the site's own origin {origin}")
    if pages:
        pg = pages[0]; b = pg["body"]
        if pg["authorization"] != f"Bearer {keys['NOTION_SECRET']}" or pg["notion-version"] != "2022-06-28":
            bad(f"Notion was not called with NOTION_SECRET and the client's API version: {pg['notion-version']!r}")
        want_page = {
            "parent": {"database_id": keys["NOTION_DB"]},
            "properties": {
                "Email": {"type": "email", "email": email},
                "Name": {"type": "title", "title": [{"type": "text", "text": {"content": visitor}}]},
            },
        }
        if b != want_page:
            bad(f"the page Notion was asked to create is {json.dumps(b)[:240]}, not the template's row")
    # The rate limit: two of each route in a minute — the signup fits — and
    # the third is refused before it reaches Resend or Notion.
    s1, _ = call("POST", "/api/mail", {"firstname": visitor, "email": email})
    s2, body2 = call("POST", "/api/mail", {"firstname": visitor, "email": email})
    if s1 != 200 or s2 != 429 or as_json(body2) != {"error": "Too many requests!!"}:
        bad(f"a second and third email in a minute answered {s1}, {s2} {body2[:80]!r} — want 200, then 429")
    n1, _ = call("POST", "/api/notion", {"name": visitor, "email": email})
    n2, nbody2 = call("POST", "/api/notion", {"name": visitor, "email": email})
    if n1 != 200 or n2 != 429 or as_json(nbody2) != {"error": "Too many requests!!"}:
        bad(f"a second and third row in a minute answered {n1}, {n2} {nbody2[:80]!r} — want 200, then 429")
    got = calls()
    if len([c for c in got if c["path"] == "/emails"]) != 2 or len([c for c in got if c["path"] == "/v1/pages"]) != 2:
        bad(f"refused requests still reached the services: {[c['path'] for c in got]}")
    leaked = [k for k, v in keys.items() if v in page or v in body2 or v in nbody2]
    if leaked:
        bad(f"a response carries the value of {leaked}")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
extra = ("; one signup reaches Notion and Resend as the template sends it, and the third request a minute is refused"
         if mode == "connected" else "; a signup is told the waitlist is not connected yet")
print(f"   /, its assets, /api/health, /api/mail, /api/notion and a 404 — the site's own, Notion and Resend {mode}, on {origin}{extra}")
PY
}
routes not-connected

# The deploy deploys the Worker with its binding: the lane's own dry run
# (step 2, `wrangler deploy --dry-run --config wrangler.jsonc`) lists it.
grep -q "env.SIGNUP_LIMITER (2 requests/60s)" "$scratch/deploy-dry-run.log" \
  && grep -q "Rate Limit" "$scratch/deploy-dry-run.log" \
  || { echo "FAIL: the lane's deploy dry run does not carry the SIGNUP_LIMITER rate limit" >&2; tail -20 "$scratch/deploy-dry-run.log" >&2; exit 1; }
echo "   the lane's deploy dry run binds SIGNUP_LIMITER (2 requests/60s)"

# ── 4. the same lane, with Notion's and Resend's keys ──────────────────────
# Made-up keys in the shapes the services issue: nothing here reaches Notion
# or Resend — the Worker is pointed at a local stand-in (lib/stand-in.py).
echo "── the stage lane's build-app again, with Notion's and Resend's keys as the optional refs supply them"
rnd() { python3 -c "import secrets;print(secrets.token_hex(12))"; }
export E2E_NOTION_SECRET="ntn_e2e_$(rnd)" E2E_NOTION_DB="e2e$(rnd)" E2E_RESEND_API_KEY="re_e2e_$(rnd)" \
       E2E_RESEND_FROM="Waitlist E2E <hello-$(rnd)@waitlist.example.org>"
rm -rf "$app/.open-next" "$app/.next" "$app/.wrangler"
if ! (cd "$app" && { [ -f "$scratch/steps/env" ] && source "$scratch/steps/env"; true; } && \
      export ORUN_ENVIRONMENT=stage NOTION_SECRET="$E2E_NOTION_SECRET" NOTION_DB="$E2E_NOTION_DB" \
             RESEND_API_KEY="$E2E_RESEND_API_KEY" RESEND_FROM="$E2E_RESEND_FROM" && \
      unset CLOUDFLARE_API_TOKEN && bash -e "$scratch/steps/build-app.sh") > "$scratch/build-app-keys.log" 2>&1; then
  echo "FAIL: the deploy lane's build-app step, with the keys" >&2; tail -40 "$scratch/build-app-keys.log" >&2; exit 1
fi
grep -qF "worker-secrets: no Cloudflare credential in this job (a verify lane) — NOTION_SECRET, NOTION_DB, RESEND_API_KEY, RESEND_FROM reach $repo-web-stage from the deploy lane" \
  "$scratch/build-app-keys.log" || { echo "FAIL: the build did not hand the four keys to $repo-web-stage (or claimed to from a verify lane)" >&2; tail -10 "$scratch/build-app-keys.log" >&2; exit 1; }
for v in "$E2E_NOTION_SECRET" "$E2E_NOTION_DB" "$E2E_RESEND_API_KEY" "$E2E_RESEND_FROM"; do
  if grep -rlF -- "$v" "$app/.open-next" "$app/.next" "$scratch/build-app-keys.log" > "$scratch/leaks.txt" 2>/dev/null; then
    echo "FAIL: a key's value is in the build:" >&2; head -5 "$scratch/leaks.txt" >&2; exit 1
  fi
done
echo "   no key in any file of the build or its log; the keys pushed only by a deploy lane"
(cd "$app" && { [ -f "$scratch/steps/env" ] && source "$scratch/steps/env"; true; } && \
   export ORUN_ENVIRONMENT=stage && bash -e "$scratch/steps/verify-build-output.sh") > "$scratch/verify-keys.log" 2>&1 \
  || { echo "FAIL: verify-build-output, with the keys" >&2; tail -20 "$scratch/verify-keys.log" >&2; exit 1; }

echo "── wrangler dev over it, with the secrets the deploy hands the Worker, Notion and Resend a local stand-in"
python3 "$here/lib/stand-in.py" "$scratch/stand-in.port" "$scratch/stand-in.jsonl" &
stand_in_pid=$!
trap 'kill "$stand_in_pid" 2>/dev/null || true; cleanup' EXIT
for _ in $(seq 1 50); do [ -s "$scratch/stand-in.port" ] && break; sleep 0.1; done
[ -s "$scratch/stand-in.port" ] || { echo "FAIL: the stand-in never listened" >&2; exit 1; }
stand_in="http://127.0.0.1:$(cat "$scratch/stand-in.port")"
NOTION_SECRET="$E2E_NOTION_SECRET" NOTION_DB="$E2E_NOTION_DB" RESEND_API_KEY="$E2E_RESEND_API_KEY" RESEND_FROM="$E2E_RESEND_FROM" \
  node "$tree/tooling/wire/worker-secrets.mjs" --secret NOTION_SECRET --secret NOTION_DB --secret RESEND_API_KEY --secret RESEND_FROM \
  --dev-vars "$scratch/keys.dev.vars" > /dev/null
printf 'NOTION_API_BASE_URL="%s"\nRESEND_BASE_URL="%s"\n' "$stand_in" "$stand_in" >> "$scratch/keys.dev.vars"
serve "$app" "$scratch/dev-keys.log" "$scratch/keys.dev.vars"
echo "   ▸ the component's own smokeCommand, DEPLOYED_URL=$url"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the site with Notion and Resend connected" >&2; exit 1; }
echo "   ▸ every route the site promises, and one signup end to end"
routes connected "$scratch/stand-in.jsonl" \
  "$(python3 -c 'import json,os;print(json.dumps({k:os.environ["E2E_"+k] for k in ("NOTION_SECRET","NOTION_DB","RESEND_API_KEY","RESEND_FROM")}))')"

echo "── and without its rate limit: the deploy's smoke must refuse a Worker that lost its binding"
python3 -c '
import re, sys
text = open(sys.argv[1]).read()
out, n = re.subn(r"\n  // Workers Rate Limiting:.*?\n  \],", "", text, flags=re.S)
assert n == 1, "wrangler.jsonc has no ratelimits block"
open(sys.argv[2], "w").write(out)
' "$app/wrangler.jsonc" "$app/wrangler.nolimit.jsonc"
serve "$app" "$scratch/dev-nolimit.log" "" wrangler.nolimit.jsonc
if DEPLOYED_URL="$url" bash -c "$smoke" 2>/dev/null; then
  echo "FAIL: the smoke passed a Worker with no SIGNUP_LIMITER binding" >&2; exit 1
fi
echo "   refused"
stop_dev
rm -f "$app/wrangler.nolimit.jsonc"

echo "e2e.test.sh: ok"
