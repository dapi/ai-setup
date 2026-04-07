# media-lib

![CI](https://github.com/akoltun/media-lib/actions/workflows/ci.yml/badge.svg)

Персональный структурированный медиа-каталог в виде веб-приложения. Позволяет создавать и поддерживать древовидный каталог медиафайлов (фото, видео) с произвольными метаданными: названием, описанием и пользовательскими полями. Поддерживает совместный доступ к материалам.

## Installation

### Requirements

- [Bun](https://bun.sh/)

### Install dependencies

```bash
bun install
```

## Development

```bash
bun run dev
```

Запускает полный стек (BE + FE с hot reload).

## Build

```bash
bun run build
```

Собирает оптимизированные статические ресурсы в `dist/`.

## Production

```bash
bun run serve
```

Запускает production-сборку.

## Testing

```bash
bun run test
```

Запускает все unit-тесты.

```bash
bunx playwright test
```

Запускает e2e-тесты.

## Stack

| Layer                     | Technology                               |
| ------------------------- | ---------------------------------------- |
| Runtime / Package Manager | Bun                                      |
| Language                  | TypeScript 6                             |
| Frontend                  | React 19, MUI 7, MUI X 8, React Router 7 |
| Backend                   | Bun, Drizzle ORM, PostgreSQL             |
| Linter / Formatter        | Oxlint, Oxfmt                            |
| Tests                     | Bun Test Runner (unit), Playwright (e2e) |
| CI                        | GitHub Actions                           |
