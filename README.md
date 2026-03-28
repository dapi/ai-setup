# media-lib

Personal structured media catalog web application. See [PROJECT.md](PROJECT.md) for full project description.

## Installation

This project was bootstrapped using `bun init` interactive installer (Bun v1.3.11).

### Setup choices

**Command run:**
```bash
bun init --react
```

**Interactive prompts and answers:**

| Prompt | Answer | Reason |
|--------|--------|--------|
| Package name | `media-lib` | Matches the project folder name |
| React variant | `--react` (base, no suffix) | React is in the stack; Tailwind and shadcn/ui are **not** in the stack, so `--react=tailwind` and `--react=shadcn` were skipped |

**What was generated:**
- `package.json` — project manifest with React 19 dependencies
- `tsconfig.json` — TypeScript configuration
- `bunfig.toml` — Bun runtime configuration
- `bun-env.d.ts` — Bun environment type declarations
- `src/index.ts` — Backend entry point (Bun HTTP server)
- `src/frontend.tsx` — Frontend entry point
- `src/App.tsx` — Root React component
- `src/index.html` — HTML shell
- `src/index.css` — Base styles
- `.cursor/rules/use-bun-instead-of-node-vite-npm-pnpm.mdc` — Cursor IDE rule enforcing Bun toolchain

**Dependencies installed:**
- `react@^19` + `react-dom@^19` — UI framework (from stack)
- `@types/react@^19` + `@types/react-dom@^19` + `@types/bun` — TypeScript types

### Install dependencies

```bash
bun install
```

## Development

```bash
bun run dev
```

Starts the full-stack dev server with hot reload.

## Build

```bash
bun run build
```

Builds optimized static assets to `dist/`.

## Production

```bash
bun run serve
```

Serves the production build.

## Stack

| Layer | Technology |
|-------|-----------|
| Runtime / Package Manager | Bun |
| Language | TypeScript 6 |
| Frontend | React 19, MUI 7, MUI X 8, React Router 7 |
| Backend | Bun, Drizzle ORM, PostgreSQL |
| Linter / Formatter | Oxlint, Oxfmt |
| Tests | Bun Test Runner (unit), Playwright (e2e) |
