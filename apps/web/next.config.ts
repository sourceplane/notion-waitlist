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
};

export default nextConfig;
