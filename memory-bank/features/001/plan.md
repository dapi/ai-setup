# Plan: Add Linter & Formatter

**Feature:** 001
**Spec:** `memory-bank/features/001/spec.md`
**Status:** Active
**Date:** 2026-04-05

---

## Шаги реализации

### Шаг 1 — Установка зависимостей

Выполнить:

```bash
bun add -d oxlint oxfmt
```

**Проверка:** команда завершается с кодом `0`, `oxlint` и `oxfmt` появляются в `devDependencies` в `package.json`.
**Стоп-условие:** если код выхода ненулевой — остановить выполнение, сообщить об ошибке.

---

### Шаг 2 — Создать `oxlint.config.ts`

Создать файл `oxlint.config.ts` в корне проекта с содержимым из спеки:

- `options.typeAware: true`
- `categories`: correctness/perf/style — error; suspicious — warn
- `env`: browser + node
- `plugins` глобально: `import`, `promise`, `typescript`
- `rules`: type-aware правила для async, unsafe, unnecessary конструкций
- `ignorePatterns`: проверять только `src/**` и `tests/**`
- `overrides`: плагин `react` для tsx/jsx, плагин `vitest` для тестовых файлов

**Проверка:** `bunx oxlint --print-config src/index.ts` завершается с кодом `0` и выводит применённую конфигурацию.
**Стоп-условие:** ненулевой код выхода или ошибка парсинга конфига — остановить выполнение, проверить содержимое файла.

---

### Шаг 3 — Создать `oxfmt.config.ts`

Создать файл `oxfmt.config.ts` в корне проекта с содержимым из спеки:

- `printWidth: 120`, `tabWidth: 2`, `useTabs: false`
- `singleQuote: false`, `trailingComma: "all"`, `bracketSpacing: true`, `arrowParens: "avoid"`
- `organizeImports: true`, `sortPackageJson: true`
- `ignorePatterns`: `.*/**`, `homeworks/**`, `node_modules/**`, `dist/**`

**Проверка:** `bunx oxfmt --check src/index.ts` завершается с кодом `0`.
**Стоп-условие:** ненулевой код выхода или ошибка парсинга конфига — остановить выполнение, проверить содержимое файла.

---

### Шаг 4 — Добавить скрипт `lint` в `package.json`

Добавить в секцию `scripts`:

```json
"lint": "oxlint --fix && oxfmt --write"
```

Изменять только `scripts` и `devDependencies` (уже обновлены на шаге 1).

**Примечание:** `oxlint --fix` запускается без явного указания пути и полагается на `ignorePatterns` из `oxlint.config.ts` (`["**", "!src/**", "!tests/**"]`). 

**Проверка:** `cat package.json` содержит `"lint": "oxlint --fix && oxfmt --write"` в секции `scripts`.

---

### Шаг 5 — Исправить нарушения Oxlint вручную

a. Запустить `bun run lint`.
b. Если `oxlint --fix` завершился с ненулевым кодом — это ожидаемо (есть нарушения без автоисправления). Прочитать вывод, найти оставшиеся нарушения.
c. Для каждого нарушения отредактировать файл в `src/` напрямую, не меняя бизнес-логику.
d. Повторить a–c до тех пор, пока `bun run lint` не завершится с кодом `0`.

**Стоп-условие:** если после всех допустимых правок `oxlint` всё ещё ненулевой — остановить, вывести список неисправленных нарушений, не менять бизнес-логику.
**Стоп-условие:** если `oxfmt --write` завершается с ненулевым кодом — вывести список файлов с ошибками, остановить выполнение.

---

## Проверка критериев приёмки

После завершения шагов 1–5 убедиться:

| # | Проверка | Команда |
|---|----------|---------|
| 0 | `oxlint` и `oxfmt` в `devDependencies` | просмотр `package.json` |
| 1 | `bun run lint` завершается с кодом `0` | `bun run lint` |
| 2 | `oxfmt --check` завершается с кодом `0` | `bunx oxfmt --check` |
| 3 | Конфиги существуют в корне с нужным содержимым | просмотр файлов |
| 4 | `bunx oxlint src/` (без `--fix`) завершается с кодом `0` | `bunx oxlint src/` |

---

## Затрагиваемые файлы

| Файл | Действие |
|------|----------|
| `package.json` | Добавить скрипт `lint`; `devDependencies` обновляются через `bun add` |
| `oxlint.config.ts` | Создать |
| `oxfmt.config.ts` | Создать |
| `src/**` | Исправить нарушения Oxlint (шаг 5) без изменения бизнес-логики |

---

## Инварианты

- Добавляются ровно две зависимости: `oxlint` и `oxfmt`
- `tsconfig.json` не изменяется
- Oxlint проверяет только `src/` и `tests/`; Oxfmt игнорирует `node_modules/`, `dist/`, `.*/**`, `homeworks/`
- `oxlint --fix` использует только безопасные исправления (не `--fix-dangerously`)
- `oxfmt` запускается только при успешном завершении `oxlint` (обеспечивается `&&`)
- Папка `tests/` на момент реализации отсутствует — Oxlint просто не найдёт там файлов, ошибки не будет. Паттерн `!tests/**` в `ignorePatterns` оставляется для будущих тестов
