# План реализации: Добавить тесты

**Feature:** 002
**Spec:** `memory-bank/features/002/spec.md`
**Issue:** akoltun/media-lib#2
**Дата:** 2026-04-06

---

## Шаги реализации

### Шаг 1. Установка зависимостей

1. Выполнить `bun add -d @playwright/test` (изменение `package.json` разрешено спекой — см. разделы 1, 2)
2. Если команда завершилась с ошибкой — остановиться, сообщить об ошибке
3. Выполнить `bunx playwright install chromium`
4. Если команда завершилась с ошибкой — остановиться, сообщить об ошибке

**Проверка:** `@playwright/test` присутствует в `devDependencies` в `package.json`

---

### Шаг 2. Добавить скрипты в `package.json`

Добавить в секцию `scripts`:

```json
"test": "bun run build && bun test && bunx playwright test",
"test:api": "NODE_ENV=development bun test",
"test:e2e": "NODE_ENV=development bunx playwright test"
```

**Изменяемый файл:** `package.json` (только секция `scripts`; изменение разрешено спекой — см. раздел 2)

**Проверка:** скрипты `test`, `test:api`, `test:e2e` присутствуют в `package.json`

---

### Шаг 3. Создать конфигурацию Playwright

Создать файл `playwright.config.ts` в корне проекта с содержимым из спеки:

- `testDir: "./tests"`
- `workers: process.env.CI ? 1 : undefined`
- `retries: process.env.CI ? 2 : 0`
- Единственный проект — `chromium`
- `port = process.env.PORT || "3000"` — порт читается из переменной окружения, по умолчанию `3000`
- `baseURL` и `webServer.url` строятся из `port`
- `webServer.command` зависит от `NODE_ENV` (production → `bun run serve`, development → `bun run dev`)
- `reuseExistingServer: !process.env.CI`

**Создаваемый файл:** `playwright.config.ts`

**Проверка:** файл существует, содержимое соответствует спеке

---

### Шаг 4. Модифицировать `src/index.ts`

Заменить `const server` на `export const server` для именного экспорта экземпляра сервера.

**Изменяемый файл:** `src/index.ts`

**Проверка:** `export const server` присутствует в файле

---

### Шаг 5. Создать API-тест

Создать файл `src/domains/home/api.test.ts` с содержимым из спеки:

- `beforeAll` — динамический импорт `../../index` и получение `server`
- `afterAll` — остановка сервера
- Три теста для `GET /api/appeal`:
  - Статус 200
  - Content-Type содержит `application/json`
  - Тело ответа `{ appeal: "World" }`

**Создаваемый файл:** `src/domains/home/api.test.ts`

**Проверка:** `bun run test:api` завершается с кодом 0

---

### Шаг 6. Создать E2E-тест

Создать директорию `tests/` и файл `tests/home.spec.ts` с содержимым из спеки:

- Один тест: загрузка главной страницы и проверка заголовка `Hello, World!`
- Используется семантический локатор `page.getByRole("heading", { name: "Hello, World!" })`

**Создаваемый файл:** `tests/home.spec.ts`

**Проверка:** `bun run test:e2e` завершается с кодом 0

---

### Шаг 7. Обновить `.gitignore` и `oxfmt.config.ts`

Добавить записи в `.gitignore`:

```
dist/
/test-results/
/playwright-report/
```

- `dist/` — артефакты сборки (`bun run build`), создаются в том числе при запуске `bun run test`

Добавить `test-results/**` и `playwright-report/**` в `ignorePatterns` в `oxfmt.config.ts` (изменение `oxfmt.config.ts` разрешено спекой — см. раздел 6).

**Изменяемые файлы:** `.gitignore`, `oxfmt.config.ts`

**Проверка:** записи присутствуют в обоих файлах

---

### Шаг 8. Запуск линтера

Выполнить `bun run lint` и исправить замечания, если есть.

**Проверка:** `bun run lint` завершается с кодом 0

---

### Шаг 9. Финальная проверка

1. Запустить `bun run test:api` — убедиться, что API-тесты проходят
2. Запустить `bun run test:e2e` — убедиться, что E2E-тесты проходят
3. Запустить `bun run test` — убедиться, что полный цикл (build → API → E2E) проходит
4. Повторно запустить `bun run test` — убедиться в стабильности результата

**Проверка:** все 4 команды завершаются с кодом 0

---

## Сводка изменяемых файлов

| Файл                           | Действие                                                           |
| ------------------------------ | ------------------------------------------------------------------ |
| `package.json`                 | Изменить                                                           |
| `playwright.config.ts`         | Создать                                                            |
| `src/index.ts`                 | Изменить                                                           |
| `src/domains/home/api.test.ts` | Создать                                                            |
| `tests/home.spec.ts`           | Создать                                                            |
| `.gitignore`                   | Изменить (добавить `dist/`, `test-results/`, `playwright-report/`) |
| `oxfmt.config.ts`              | Изменить                                                           |

## Порядок выполнения

```
Шаг 1 (зависимости)
  → Шаг 2 (скрипты) + Шаг 3 (playwright config) + Шаг 4 (export server) + Шаг 7 (.gitignore + oxfmt)  [параллельно]
    → Шаг 5 (API-тест)
      → Шаг 6 (E2E-тест)
        → Шаг 8 (линтер)
          → Шаг 9 (финальная проверка)
```

Шаги 2, 3, 4, 7 не зависят друг от друга и могут выполняться параллельно после установки зависимостей. Шаг 5 зависит от шагов 2 и 4. Шаг 6 зависит от шагов 2 и 3.
