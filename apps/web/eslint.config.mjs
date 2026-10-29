import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";

// The template's own lint: Next's core-web-vitals rules (upstream's
// `next/core-web-vitals`), without the TypeScript preset it never ran.
const eslintConfig = defineConfig([
  ...nextVitals,
  {
    rules: {
      // eslint-plugin-react-hooks 7's React Compiler rule, newer than the
      // template: its particles canvas declares its callbacks after the hooks
      // that call them, as the template wrote it.
      "react-hooks/immutability": "off",
    },
  },
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
    // The Workers build's output and wrangler's local state.
    ".open-next/**",
    ".wrangler/**",
  ]),
]);

export default eslintConfig;
