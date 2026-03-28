See PROJECT.md for project description.

## Stack
- TypeScript 6
- FE: React 19, MUI 7, MUI X 8, ReactRouter 7
- BE: Bun, Drizzle, PostgreSQL
- Linter & Formatter: Oxlint, Oxfmt
- Tests: Playwright 

## Key commands
- `bun run build` - build a production binary
- `bun run compile` - compile a project with TypeScript (without emitting JS code)
- `bun run db:console` - run psql console
- `bun run db:create` - create database
- `bun run db:drop` - drop database (except production environment)
- `bun run db:push` - push db schema changes to database
- `bun run dev` - run dev server
- `bun run lint` - run linter (in safe fixing mode) and formatter
- `bun run serve` - run production server
- `bun run test` - run tests

## Conventions
Bun Dev Server, Bun Bundler, Bun Package Manager
Drizzle codebase first approach without creation of sql migration files
Drizzle ORM connects to PostgreSQL DB via Bun SQL module
No SSR
React Router in Data mode
Bun Test Runner for unit tests for BE
Playwright e2e tests for FE and for the whole application
Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.

## Constraints
No new dependencies without explicit request

## Requirements
The app supports latest version of Chrome. It is to be used in Playwright tests.