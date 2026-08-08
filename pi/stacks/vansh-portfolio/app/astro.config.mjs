import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  site: "http://100.64.0.1:8091",
  outDir: "./dist",
  vite: {
    plugins: [tailwindcss()],
  },
});
