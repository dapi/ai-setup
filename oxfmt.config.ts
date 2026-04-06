import { defineConfig } from "oxfmt";

export default defineConfig({
  printWidth: 120,
  tabWidth: 2,
  useTabs: false,
  singleQuote: false,
  trailingComma: "all",
  bracketSpacing: true,
  arrowParens: "avoid",
  organizeImports: true,
  sortPackageJson: true,
  ignorePatterns: [".*/**", "homeworks/**", "node_modules/**", "dist/**", "test-results/**", "playwright-report/**"],
});
