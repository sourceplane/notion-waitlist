import type { NextConfig } from "next";
import path from "node:path";

// Notion's and Resend's keys are NOT the build's: they are the Worker's
// secrets, read per request (lib/waitlist.ts), so the same build serves a
// connected waitlist and one whose owner has not connected it yet. A deploy
// builds without them (component.yaml's buildCommand) and hands them to the
// Worker afterwards; no bundle ever contains one.
const nextConfig: NextConfig = {
  turbopack: {
    // The workspace root: Next resolves `next` and the app's dependencies
    // from the monorepo's node_modules.
    root: path.join(__dirname, "../.."),
  },
  // The logos are local SVGs, served as they are: Workers has no image
  // optimizer behind next/image.
  images: { unoptimized: true },
  // Required by @opennextjs/cloudflare, which bundles `.next/standalone/**`
  // into the Worker. Trace from the monorepo root so workspace dependencies
  // resolve from the root node_modules.
  output: "standalone",
  outputFileTracingRoot: path.join(__dirname, "../.."),
  experimental: {
    // Dev server only: behind orun.work's live Preview the browser's Origin
    // is the preview's host while `next dev` sees a local Host, and Next.js
    // refuses a Server Action from an origin it is not told about. `next
    // build` runs with NODE_ENV=production, so production keeps its
    // same-origin check.
    ...(process.env.NODE_ENV === "development"
      ? { serverActions: { allowedOrigins: ["*.orun-preview.app", "preview-gateway-stage.oruncloud.workers.dev"] } }
      : {}),
  },
  // Dev server only (`next build` ignores it): orun.work's live Preview tab
  // loads `next dev` from the preview's own host, and Next.js refuses the
  // hot reload and other /_next/* dev requests from an origin it is not told
  // about. These are the preview's hosts, prod's and stage's.
  allowedDevOrigins: ["*.orun-preview.app", "preview-gateway-stage.oruncloud.workers.dev"],
};

export default nextConfig;
