import { defineConfig } from "vitest/config";
import * as path from "node:path";

export default defineConfig({
  resolve: {
    alias: [
      { find: /^app\//, replacement: path.resolve(__dirname, "../../apps/web/app") + "/" },
      { find: /^lib\//, replacement: path.resolve(__dirname, "../../apps/web/lib") + "/" },
      { find: /^emails$/, replacement: path.resolve(__dirname, "../../apps/web/emails/index.tsx") },
    ],
  },
  test: {
    include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
    environment: "node",
  },
});
