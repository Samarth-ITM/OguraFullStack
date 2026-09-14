// @lovable.dev/vite-tanstack-config already includes the following — do NOT add them manually
// or the app will break with duplicate plugins:
//   - TanStack devtools (dev-only, first), tanstackStart, viteReact, tailwindcss, tsConfigPaths,
//     nitro (build-only using cloudflare as a default target), VITE_* env injection, @ path alias,
//     React/TanStack dedupe, error logger plugins, and sandbox detection (port/host/strictPort).
// You can pass additional config via defineConfig({ vite: { ... }, etc... }) if needed.
import { defineConfig } from "@lovable.dev/vite-tanstack-config";
import type { Plugin } from "vite";

function devCssUrlShim(): Plugin {
  const VIRTUAL_PREFIX = "\0ogura-dev-css-url:";
  const VIRTUAL_SUFFIX = ".shim.js";
  return {
    name: "ogura-dev-css-url-shim",
    apply: "serve",
    enforce: "pre",
    async resolveId(id, importer) {
      if (!id.endsWith(".css?url")) return null;
      const resolved = await this.resolve(id.slice(0, -4), importer, { skipSelf: true });
      if (!resolved) return null;
      return VIRTUAL_PREFIX + resolved.id + VIRTUAL_SUFFIX;
    },
    load(id) {
      if (!id.startsWith(VIRTUAL_PREFIX) || !id.endsWith(VIRTUAL_SUFFIX)) return null;
      const file = id.slice(VIRTUAL_PREFIX.length, -VIRTUAL_SUFFIX.length);
      const inlineSpecifier = file.includes("?") ? `${file}&inline` : `${file}?inline`;
      return [
        `import css from ${JSON.stringify(inlineSpecifier)};`,
        `const b64 = typeof Buffer !== "undefined" ? Buffer.from(css, "utf8").toString("base64") : btoa(unescape(encodeURIComponent(css)));`,
        `export default "data:text/css;base64," + b64;`,
      ].join("\n");
    },
  };
}

export default defineConfig({
  vite: {
    plugins: [devCssUrlShim()],
  },
  tanstackStart: {
    // Redirect TanStack Start's bundled server entry to src/server.ts (our SSR error wrapper).
    // nitro/vite builds from this
    server: { entry: "server" },
  },
});
