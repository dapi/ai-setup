# План реализации: Настройка CI/CD

**Feature:** 003
**Spec:** `memory-bank/features/003/spec.md`
**Issue:** akoltun/ai-setup#3
**Дата:** 2026-04-06

---

## Шаги реализации

### Шаг 1. Добавить скрипт `lint:ci` в `package.json`

Добавить в секцию `scripts`:

```json
"lint:ci": "oxlint && oxfmt --check"
```

Отличие от `lint`: без `--fix` и `--write` — в CI файлы не должны изменяться.

**Изменяемый файл:** `package.json` (только секция `scripts`)

**Проверка:** `bun run lint:ci` завершается с кодом 0

---

### Шаг 2. Настроить coverage в `bunfig.toml`

Добавить секцию `[test]` в существующий `bunfig.toml`:

```toml
[test]
coverage = true
coverageThreshold = 0.8
```

**Изменяемый файл:** `bunfig.toml`

**Проверка:** `bun test --coverage` завершается. Если покрытие ниже 80%, снизить `coverageThreshold` до фактического значения и зафиксировать как baseline.

---

### Шаг 3. Создать CI-пайплайн `.github/workflows/ci.yml`

Заменить существующий файл новым пайплайном со следующей структурой:

**Триггеры:** `push` в любую ветку, `pull_request`, `workflow_dispatch`

**Concurrency:** `cancel-in-progress: true` по группе `ci-${{ github.workflow }}-${{ github.ref }}`

**Джоб `setup`:**

1. `actions/checkout`
2. `oven-sh/setup-bun` — установить Bun
3. `bun install --frozen-lockfile`
4. `actions/upload-artifact` — `node_modules` как артефакт `node-modules`, retention 1 день

**Общие шаги для `lint`, `compile`, `build`, `test`** (зависят от `setup`):

1. `actions/checkout`
2. `oven-sh/setup-bun`
3. `actions/download-artifact` — скачать `node-modules` в `./node_modules`

**Джоб `lint`:** `bun run lint:ci`

**Джоб `compile`:** `bun run compile`

**Джоб `build`:** `bun run build`

**Джоб `test`** (timeout 30 мин, `NODE_ENV=production`):

1. `bun run build` — сборка для Playwright web-сервера
2. `bunx playwright install --with-deps chromium`
3. `bun test --coverage` — unit-тесты с coverage
4. `bunx playwright test` — e2e-тесты

**Создаваемый файл:** `.github/workflows/ci.yml` (замена существующего)

**Проверка:** YAML валиден, структура соответствует спеке

---

### Шаг 4. Актуализировать `README.md`

#### 4.1. CI-бейдж

После заголовка `# media-lib` добавить:

```markdown
![CI](https://github.com/akoltun/ai-setup/actions/workflows/ci.yml/badge.svg)
```

#### 4.2. Описание проекта

Заменить текущий первый абзац на:

> Персональный структурированный медиа-каталог в виде веб-приложения. Позволяет создавать и поддерживать древовидный каталог медиафайлов (фото, видео) с произвольными метаданными: названием, описанием и пользовательскими полями. Поддерживает совместный доступ к материалам.

#### 4.3. Раздел Installation

Убрать устаревшие детали о `bun init` (промпты, интерактивные ответы, сгенерированные файлы, установленные зависимости). Оставить:

- Требования: Bun
- Команда установки: `bun install`

БД (PostgreSQL, Drizzle) ещё не добавлена — шаги по настройке БД не включать.

#### 4.4. Раздел Development

Актуализировать: запускается полный стек (BE + FE с hot reload).

#### 4.5. Раздел Testing

Добавить раздел с командами:

- `bun run test` — запуск всех unit-тестов
- `bunx playwright test` — запуск e2e-тестов

#### 4.6. Прочие разделы

Проверить разделы Build, Production, Stack — обновить при необходимости. Удалить устаревшие разделы без аналога в текущем проекте.

**Изменяемый файл:** `README.md`

**Проверка:** README содержит актуальную информацию, бейдж присутствует

---

### Шаг 5. Запуск линтера

Выполнить `bun run lint` и исправить замечания, если есть.

**Проверка:** `bun run lint` завершается с кодом 0

---

### Шаг 6. Скорректировать порог покрытия (если необходимо)

Запустить `bun test --coverage` и проверить фактическое покрытие. Если покрытие ниже 80%:

1. Снизить `coverageThreshold` в `bunfig.toml` до фактического значения покрытия
2. Повторно запустить `bun test --coverage` — убедиться, что проходит

**Изменяемый файл:** `bunfig.toml` (при необходимости)

**Проверка:** `bun test --coverage` завершается с кодом 0

---

### Шаг 7. Финальная проверка

1. `bun run lint:ci` — линтер в CI-режиме проходит
2. `bun run compile` — компиляция TypeScript проходит
3. `bun run build` — сборка проходит
4. `bun test --coverage` — unit-тесты с coverage проходят
5. `bunx playwright test` — e2e-тесты проходят

**Проверка:** все 5 команд завершаются с кодом 0

---

### Шаг 8. Вывести инструкцию по ручной настройке

После завершения всех шагов вывести на экран пошаговую инструкцию по настройке Branch Protection Rules:

1. Смержить PR в `main`, дождаться первого прохождения CI
2. Перейти в Settings → Branches → Add rule для ветки `main`
3. Включить **Require status checks to pass before merging**
4. Добавить статус-чеки: `setup`, `lint`, `compile`, `build`, `test`
5. Включить **Do not allow bypassing the above settings** (рекомендуется)

---

## Сводка изменяемых файлов

| Файл                       | Действие                                     |
| -------------------------- | -------------------------------------------- |
| `package.json`             | Изменить (добавить скрипт `lint:ci`)         |
| `bunfig.toml`              | Изменить (добавить секцию `[test]`)          |
| `.github/workflows/ci.yml` | Заменить (новый CI-пайплайн)                 |
| `README.md`                | Изменить (актуализация всех разделов, бейдж) |

## Порядок выполнения

```
Шаг 1 (lint:ci) + Шаг 2 (bunfig.toml) + Шаг 3 (ci.yml) + Шаг 4 (README)  [параллельно]
  → Шаг 5 (линтер)
    → Шаг 6 (корректировка порога покрытия)
      → Шаг 7 (финальная проверка)
        → Шаг 8 (инструкция по ручной настройке)
```

Шаги 1, 2, 3, 4 не зависят друг от друга и могут выполняться параллельно. Шаг 5 зависит от шагов 1 и 4. Шаг 6 зависит от шага 2. Шаг 7 зависит от шагов 5 и 6. Шаг 8 выполняется после всех предыдущих шагов.
