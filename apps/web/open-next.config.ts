// OpenNext Cloudflare adapter config.
//
// The waitlist page is pre-rendered at build (a client page with nothing to
// read per request) and its two API routes render per request; nothing
// revalidates. The static-assets incremental cache serves the pre-rendered
// page from the Worker's static assets (read only, no R2/KV/D1 to
// provision). A change that caches renders (ISR, `revalidateTag`,
// "use cache") swaps this for the R2 incremental cache plus a tag cache.
import { defineCloudflareConfig } from "@opennextjs/cloudflare/config";
import staticAssetsIncrementalCache from "@opennextjs/cloudflare/overrides/incremental-cache/static-assets-incremental-cache";

export default defineCloudflareConfig({
  incrementalCache: staticAssetsIncrementalCache,
});
