# Feature Spec: Добавить тесты

**Feature:** 002
**Brief:** `memory-bank/features/002/brief.md`
**Issue:** akoltun/ai-setup#2
**Status:** Active
**Date:** 2026-04-06

---

## Контекст

Проект использует Bun как среду выполнения и пакетный менеджер. Согласно `CLAUDE.md`, для тестирования используются:

- **Bun Test Runner** — unit/API-тесты (файлы `*.test.ts` внутри `src/`)
- **Playwright** — E2E-тесты (файлы `*.spec.ts` внутри `tests/`)

В проекте существует один API-эндпоинт `GET /api/appeal` (возвращает `{ appeal: "World" }`) и один React-компонент `Home`, который запрашивает этот эндпоинт и отображает `Hello, World!`. Тестовая инфраструктура отсутствует полностью: нет зависимостей, конфигураций и тестовых файлов.

Сервер запускается через `bun serve()` на порту по умолчанию (`3000`). Приложение должно поддерживать только последнюю версию Chrome.

---

## Решение

### 1. Установка зависимостей

Добавить `@playwright/test` в `devDependencies`:

```bash
bun add -d @playwright/test
```

После установки пакета загрузить браузер Chromium для Playwright:

```bash
bunx playwright install chromium
```

- Устанавливается только Chromium, так как приложение поддерживает только Chrome
- Остальные браузеры (Firefox, WebKit) не устанавливаются

### 2. Скрипты в `package.json`

Добавить в секцию `scripts`:

```json
"test": "bun run build && bun test && bunx playwright test",
"test:api": "NODE_ENV=development bun test",
"test:e2e": "NODE_ENV=development bunx playwright test"
```

- `test` — **production-режим**: сначала выполняет `bun run build`, затем запускает API-тесты и E2E-тесты. API-тесты при этом поднимают сервер в production-режиме (без `NODE_ENV=development`). E2E-тесты используют `bun run serve` (production-сервер). Build выполняется первым, чтобы убедиться, что приложение собирается без ошибок перед запуском тестов.
- `test:api` — **development-режим**: устанавливает `NODE_ENV=development` и запускает только API-тесты. Bun Test Runner автоматически находит файлы `*.test.ts` в проекте. Тесты поднимают сервер через импорт `src/index.ts` — сервер запустится в development-режиме благодаря установленной переменной окружения.
- `test:e2e` — **development-режим**: устанавливает `NODE_ENV=development` и запускает только E2E-тесты из директории `tests/`. Playwright config читает `NODE_ENV` и выбирает `bun run dev` для запуска сервера.
- В `test` используется `&&` — каждый следующий шаг запускается только при успехе предыдущего

### 3. Конфигурация Playwright

Создать файл `playwright.config.ts` в корне проекта:

```typescript
import { defineConfig, devices } from "@playwright/test";

const isProduction = !process.env.NODE_ENV || process.env.NODE_ENV === "production";
const port = process.env.PORT || "3000";
const baseURL = `http://localhost:${port}`;

export default defineConfig({
  testDir: "./tests",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "list",
  use: {
    baseURL,
    trace: "on-first-retry",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: {
    command: isProduction ? "bun run serve" : "bun run dev",
    url: baseURL,
    reuseExistingServer: !process.env.CI,
  },
});
```

- `testDir: "./tests"` — Playwright ищет тесты только в директории `tests/`
- `port` — читается из `process.env.PORT`, по умолчанию `"3000"`. `baseURL` и `webServer.url` строятся из этого значения, что позволяет менять порт через переменную окружения без изменения конфига
- `workers: process.env.CI ? 1 : undefined` — в CI один воркер для стабильности; локально Playwright использует количество по умолчанию (половина CPU)
- `retries: process.env.CI ? 2 : 0` — в CI до 2 повторных запусков для устойчивости к flaky-тестам; локально повторы отключены
- Единственный проект — `chromium` (приложение поддерживает только Chrome)
- `webServer.command` — зависит от `NODE_ENV`:
  - `bun run test` (production): `NODE_ENV` не установлен → `isProduction = true` → Playwright запускает `bun run serve` (production-сервер, обслуживает собранный бандл из `dist/`)
  - `bun run test:e2e` (development): `NODE_ENV=development` → `isProduction = false` → Playwright запускает `bun run dev` (dev-сервер с HMR)
- `reuseExistingServer` позволяет переиспользовать уже запущенный сервер при локальной разработке
- `reporter: "list"` — простой текстовый вывод результатов

### 4. API-тест

Создать файл `src/domains/home/api.test.ts`:

```typescript
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import type { Server } from "bun";

let server: Server;

beforeAll(async () => {
  server = (await import("../../index")).server;
});

afterAll(() => {
  server.stop();
});

describe("GET /api/appeal", () => {
  test("returns status 200", async () => {
    const res = await fetch(`${server.url}api/appeal`);
    expect(res.status).toBe(200);
  });

  test("returns Content-Type application/json", async () => {
    const res = await fetch(`${server.url}api/appeal`);
    expect(res.headers.get("content-type")).toContain("application/json");
  });

  test("returns body with appeal field", async () => {
    const res = await fetch(`${server.url}api/appeal`);
    const body = await res.json();
    expect(body).toEqual({ appeal: "World" });
  });
});
```

- Тест импортирует серверный модуль `src/index.ts` и получает именованный экспорт `server`
- `server.url` возвращает URL с trailing slash (например, `http://localhost:3000/`), поэтому путь указывается без начального `/`
- `beforeAll` / `afterAll` — сервер запускается один раз на всю группу тестов и останавливается после
- Три теста проверяют: статус ответа, заголовок `Content-Type` и структуру тела ответа

**Необходимое изменение `src/index.ts`:** текущий файл не экспортирует объект `server`. Необходимо добавить именной экспорт `server`, чтобы тесты могли импортировать и использовать экземпляр сервера:

Текущий код:

```typescript
const server = serve({
```

Изменить на:

```typescript
export const server = serve({
```

### 5. E2E-тест

Создать файл `tests/home.spec.ts`:

```typescript
import { expect, test } from "@playwright/test";

test("home page displays greeting", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Hello, World!" })).toBeVisible();
});
```

- Один тест проверяет: страница загружается и отображает заголовок `Hello, World!`
- Используется `page.getByRole("heading")` — семантический локатор, устойчивый к изменениям разметки
- `toBeVisible()` — Playwright автоматически ожидает появления элемента (auto-wait)

### 6. Добавить в `.gitignore` и `oxfmt.config.ts`

Добавить следующие записи в `.gitignore`, если они отсутствуют:

```
dist/
/test-results/
/playwright-report/
```

- `dist/` — артефакты сборки (`bun run build`), создаются в том числе при запуске `bun run test`
- `test-results/` — артефакты Playwright (скриншоты, трейсы)
- `playwright-report/` — HTML-отчёт Playwright

Добавить эти же папки в `ignorePatterns` в `oxfmt.config.ts`:

```typescript
ignorePatterns: [".*/**", "homeworks/**", "node_modules/**", "dist/**", "test-results/**", "playwright-report/**"],
```

- `oxlint.config.ts` уже исключает эти папки, поэтому его изменять не нужно

### 7. Запуск и проверка

a. Запустить `bun run test` и убедиться, что все тесты проходят.
b. Запустить `bun run test:api` и убедиться, что API-тесты проходят отдельно.
c. Запустить `bun run test:e2e` и убедиться, что E2E-тесты проходят отдельно.
d. Повторно запустить `bun run test` и убедиться, что результат идентичен первому запуску.

---

## Изменяемые файлы

| Файл                           | Действие                                                                                         |
| ------------------------------ | ------------------------------------------------------------------------------------------------ |
| `package.json`                 | Добавить `@playwright/test` в `devDependencies`; добавить скрипты `test`, `test:api`, `test:e2e` |
| `playwright.config.ts`         | Создать — конфигурация Playwright                                                                |
| `src/index.ts`                 | Заменить `const server` на `export const server` для именного экспорта                           |
| `src/domains/home/api.test.ts` | Создать — API-тесты для `GET /api/appeal`                                                        |
| `tests/home.spec.ts`           | Создать — E2E-тест главной страницы                                                              |
| `.gitignore`                   | Добавить `dist/`, `test-results/` и `playwright-report/`                                         |
| `oxfmt.config.ts`              | Добавить `test-results/**` и `playwright-report/**` в `ignorePatterns`                           |

---

## Критерии приёмки (проверка)

1. `bun run test` запускает API-тесты и E2E-тесты и завершается с кодом выхода `0`
2. `bun run test:api` запускает только API-тесты и завершается с кодом выхода `0`
3. `bun run test:e2e` запускает только E2E-тесты и завершается с кодом выхода `0`
4. API-тесты проверяют статус `200`, заголовок `Content-Type: application/json` и тело `{ appeal: "World" }` для `GET /api/appeal`
5. E2E-тест проверяет загрузку главной страницы и отображение заголовка `Hello, World!`
6. Повторный запуск `bun run test` без изменений в коде даёт тот же результат
7. Файлы `playwright.config.ts`, `src/domains/home/api.test.ts`, `tests/home.spec.ts` зафиксированы в репозитории

---

## Сценарии ошибок

- Если `bun add -d @playwright/test` завершается с ненулевым кодом — остановить выполнение, сообщить об ошибке. Дальнейшие шаги не выполнять.
- Если `bunx playwright install chromium` завершается с ненулевым кодом — остановить выполнение, сообщить об ошибке. Без браузера E2E-тесты невозможны.
- Если API-тесты падают — проверить, что `src/index.ts` экспортирует именованный `server` и что сервер запускается на свободном порту. Не переходить к E2E-тестам.
- Если `bun run build` падает при выполнении `bun run test` — остановить выполнение, исправить ошибку сборки. Тесты не запускаются без успешного билда.
- Если E2E-тесты падают — проверить, что dev-сервер запускается командой `bun run dev` и доступен по `http://localhost:3000`. Проверить, что Chromium установлен.

---

## Инварианты

- `bun test` запускает только файлы `*.test.ts` внутри `src/` — E2E-тесты (`.spec.ts` в `tests/`) не затрагиваются
- Playwright запускает только файлы из `tests/` — API-тесты внутри `src/` не затрагиваются
- API-тесты запускают собственный экземпляр сервера и останавливают его после выполнения — не зависят от внешнего процесса
- E2E-тесты используют `webServer` конфигурацию Playwright для автоматического запуска сервера (dev или production в зависимости от `NODE_ENV`)
- Два вида тестов полностью изолированы и не влияют друг на друга

---

## Ограничения на реализацию

- Добавляется ровно одна зависимость: `@playwright/test`
- `tsconfig.json` не изменяется
- `CLAUDE.md`, `oxlint.config.ts`, `PROJECT.md` не изменяются
- `oxfmt.config.ts` изменяется только в части `ignorePatterns`
- `package.json` изменяется только в части `devDependencies` и `scripts`
- Изменения в `src/index.ts` ограничены заменой `const server` на `export const server`
- Бизнес-логика существующих файлов не изменяется
- Устанавливается только браузер Chromium

---

## In scope

- Установка `@playwright/test` как `devDependency`
- Загрузка браузера Chromium для Playwright
- Создание `playwright.config.ts` с конфигурацией из спеки
- Добавление скриптов `test`, `test:api`, `test:e2e` в `package.json`
- Создание API-теста `src/domains/home/api.test.ts`
- Создание E2E-теста `tests/home.spec.ts`
- Модификация `src/index.ts` для именного экспорта экземпляра сервера
- Обновление `.gitignore`
- Обновление `ignorePatterns` в `oxfmt.config.ts`

## Out of scope

- CI/CD интеграция
- Тестирование производительности и нагрузочное тестирование
- Тестирование с реальной базой данных
- Code coverage метрики
- Визуальное регрессионное тестирование
- Тесты для Firefox и WebKit
