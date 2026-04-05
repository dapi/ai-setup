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
- Bun Dev Server, Bun Bundler, Bun Package Manager
- Drizzle codebase first approach without creation of sql migration files
- Drizzle ORM connects to PostgreSQL DB via Bun SQL module
- No SSR
- React Router in Data mode
- Bun Test Runner for unit tests for BE
- Playwright e2e tests for FE and for the whole application
- Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.
- Prefer interfaces over types
- Prefer arrow function for React components
- kebab-case for file and folder names
- 2 spaces indention
- Each file has only one exported function or class, use named export. It can have additional exported type(s) and/or interface(s)
- Each React component has corresponding props interface. Example: 
```typescript
export interface ButtonProps {
  color: string
  children: React.ReactNode
}
export const Button = ({ color, children }) => <Btn color={color}>{children}</Btn>
```
- All api endpoints starts with `/api`
- Use Russian for all Brief (`Brief.md`), Spec (`Spec.md`) and Plan (`Plan.md`) documents

## Project Structure
- `src` - source code of the application
  - `index.ts` - server (BE) entrypoint
  - `index.html` - SPA html
  - `frontend.tsx` - client (FE SPA) endpoint
  - `app` - folder contains FE routes and BE API routes, and global error pages, like 404, etc
    - `api-routes.ts` - file imports all domains routes and exports them as `apiRoutes` object that satisfies `Serve.Routes` type from `bun`
  - `components` - folder contains business logic related React components used across different domains
  - `domains` - main folder that contains all business logic of the application grouped by domains, subdomains, etc.; there is no explicit limit on nesting levels, each domain/subdomain contains both FE and BE business logic files
    - `<simple-domain-name>` - folder that contains all domain related files, if domain is simple and has no subdomains
      - `api.ts` - file exports `<simpleDomainName>Api` object that describes all endpoints that belongs to this domain: `{ "/api/<simple-domain-name>": { GET(), POST(), etc.  }}`
      - `<simple-domain-name>.tsx` - React component that renders this domain page
      - `components`, `ui`, `utils` - if domain is not complex enough to have subdomains, but not simple enough to fit in one file, it can be split into components, ui and utils if necessary
    - `<complex-domain-name>` - folder that contains subdomains of a complex domain
      - `<subdomain-name>` - folder that contains all subdomain files (complex subdomains can be composed from sub-sub-domain; the level of nesting depends on the level of domain/subdomain complexity)
        - `api.ts` - file exports `<subdomainName>Api` object that describes all endpoints that belongs to this domain: `{ "/api/<complex-domain-name>/<subdomain-name>": { GET(), POST(), etc.  }}`
        - `<subdomain-name>.tsx` - React component that renders this subdomain page
        - `components`, `ui`, `utils` - if subdomain is not complex enough to have own subdomains, but not simple enough to fit in one file, it can be split into components, ui and utils if necessary
      - `components`, `ui`, `utils` - few subdomains can share common components, ui and utils if necessary
    - `components`, `ui`, `utils` - few domains can share common components, ui and utils if necessary
  - `state` - folder contains helper function related to application state, examples: functions to access database on BE, functions to access `sessionStorage` on FE
  - `tests` - folder contains e2e Playwright tests
  - `ui` - folder contains common UI React components
  - `utils` - small utils functions used across the whole app

If `components`, `ui` or `utils` has to be used by few subdomains they are placed on the lowest level of common subdomains. They can and should be moved up or down on the domain/subdomain trees according the necessary usage.

If `components`, `ui` or `utils` has to be used by few domains they are placed in the "root" corresponding folders: `src/components`, `src/ui`, `src/utils`.

### `components` vs `ui`
- `ui` - simple React components that either don't have state, or have only ui related state, ex. pressed/unpressed button
- `components` - React components that have business logic related state, ex. search component

- If `ui`, `components` or `utils` are not related to domain logic and, therefore, can be easily shared with other projects, or extracted to common library, they are placed in `src/{ui|components|utils}` folders.
- otherwise they are placed in the lowers common domain/subdomain folder.

## Constraints
No new dependencies without explicit request

## Requirements
The app supports latest version of Chrome. It is to be used in Playwright tests.