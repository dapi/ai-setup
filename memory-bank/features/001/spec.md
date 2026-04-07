# Feature Spec: Add Linter & Formatter

**Feature:** 001
**Brief:** `memory-bank/features/001/brief.md`
**Issue:** akoltun/media-lib#1
**Status:** Active
**Date:** 2026-04-05

---

## Контекст

Проект использует Bun как пакетный менеджер и среду выполнения. В `package.json` уже определены скрипты (`dev`, `build`, `compile`, `serve`), но отсутствует скрипт `lint`. Инструменты стека: **Oxlint** (линтер) и **Oxfmt** (форматтер).

---

## Решение

### 1. Установка зависимостей

Добавить `oxlint`, `oxfmt` и `oxlint-tsgolint` в `devDependencies`:

```bash
bun add -d oxlint oxfmt oxlint-tsgolint
```

- `oxlint-tsgolint` — обязательный пакет для работы type-aware линтера; без него линтер будет падать при запуске
- Плагины `import`, `promise`, `typescript`, `react` и `vitest` встроены в `oxlint` и не требуют отдельной установки

### 2. Конфигурация Oxlint

Создать файл `oxlint.config.ts` в корне проекта:

```typescript
import { defineConfig } from "oxlint";

export default defineConfig({
  options: {
    typeAware: true,
  },
  categories: {
    correctness: "error",
    perf: "error",
    style: "error",
    suspicious: "warn",
  },
  env: {
    browser: true,
    node: true,
  },
  globals: {},
  plugins: ["import", "promise", "typescript"],
  rules: {
    "eslint/sort-imports": "off",
    "import/no-named-export": "off",
    "import/prefer-default-export": "off",
    "no-duplicate-imports": ["error", { allowSeparateTypeImports: true }],
    "typescript/no-floating-promises": "error",
    "typescript/no-misused-promises": "error",
    "typescript/await-thenable": "error",
    "typescript/no-unsafe-argument": "error",
    "typescript/no-unsafe-assignment": "error",
    "typescript/no-unsafe-call": "error",
    "typescript/no-unsafe-return": "error",
    "typescript/no-unsafe-member-access": "error",
    "typescript/no-unnecessary-type-assertion": "warn",
    "typescript/no-unnecessary-condition": "warn",
    "typescript/prefer-nullish-coalescing": "warn",
    "typescript/prefer-optional-chain": "warn",
    "typescript/switch-exhaustiveness-check": "error",
  },
  ignorePatterns: ["**", "!src/**", "!tests/**"],
  overrides: [
    {
      files: ["src/**/*.tsx", "src/**/*.jsx"],
      plugins: ["react"],
      rules: {
        "react/react-in-jsx-scope": "off",
      },
    },
    {
      files: ["src/**/*.test.ts", "src/**/*.test.tsx", "src/**/*.spec.ts", "src/**/*.spec.tsx"],
      plugins: ["vitest"],
    },
  ],
});
```

- Охватываемые расширения: `.js`, `.mjs`, `.cjs`, `.ts`, `.mts`, `.cts`, `.jsx`, `.tsx`
- Oxlint обнаруживает эти файлы автоматически; явное перечисление расширений не требуется
- `options.typeAware: true` — включает type-aware режим: Oxlint читает `tsconfig.json` и использует информацию о типах TypeScript при анализе; требует установленного пакета `oxlint-tsgolint`
- Плагины `import`, `promise` и `typescript` применяются глобально
- Плагин `react` применяется только к TSX/JSX файлам фронтенда (`src/**/*.tsx`, `src/**/*.jsx`)
- Плагин `vitest` применяется только к тестовым файлам внутри `src/` (`*.test.ts`, `*.test.tsx`, `*.spec.ts`, `*.spec.tsx`) — Oxlint-плагин `vitest` распознаёт паттерны Bun Test Runner (`describe`/`it`/`expect`); установка пакета `vitest` не требуется
- Type-aware правила в секции `rules` проверяют корректность работы с асинхронным кодом, небезопасными операциями и излишними конструкциями, требующими знания типов
- eslint/sort-imports не применяется, поскольку сортировка импортов осуществляется форматтером

### 3. Конфигурация Oxfmt

Создать файл `oxfmt.config.ts` в корне проекта:

```typescript
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
  ignorePatterns: [".*/**", "homeworks/**", "node_modules/**", "dist/**"],
});
```

- Охватываемые расширения: `.js`, `.jsx`, `.ts`, `.tsx`, `.json`, `.jsonc`, `.json5`, `.yaml`, `.toml`, `.html`, `.css`, `.scss`, `.less`, `.md`, `.mdx`
- `printWidth: 120` — максимальная длина строки 120 символов
- `organizeImports: true` — автоматическая сортировка и группировка импортов
- `sortPackageJson: true` — сортировка ключей в `package.json` согласно стандартному порядку

### 4. Скрипт `lint` в `package.json`

Добавить в секцию `scripts`:

```json
"lint": "oxlint --fix && oxfmt --write"
```

- `oxlint --fix` — применяет только безопасные автоисправления
- `oxfmt --write` — форматирует файлы на месте
- `&&` — `oxfmt` запускается только при успешном завершении `oxlint`

### 5. Исправление нарушений Oxlint

a. Запустить `bun run lint` и получить список нарушений, неисправленных в автоматическом режиме.
b. Для каждого нарушения : исправить файл напрямую, не меняя бизнес-логику.
c. Повторять шаги a–b до тех пор, пока `bun run lint` не завершится с кодом `0`, или до ситуации из «Сценариев ошибок».

---

## Изменяемые файлы

| Файл               | Действие                                                                                   |
| ------------------ | ------------------------------------------------------------------------------------------ |
| `package.json`     | Добавить скрипт `lint`, добавить `oxlint`, `oxfmt` и `oxlint-tsgolint` в `devDependencies` |
| `oxlint.config.ts` | Создать — конфигурация Oxlint                                                              |
| `oxfmt.config.ts`  | Создать — конфигурация Oxfmt                                                               |

---

## Критерии приёмки (проверка)

0. `bun add -d oxlint oxfmt oxlint-tsgolint` завершается с кодом выхода `0` и все три пакета присутствуют в `devDependencies` в `package.json`
1. `bun run lint` завершается с кодом выхода `0` на файлах проекта
2. После выполнения `bun run lint` команда `oxfmt --check` завершается с кодом выхода `0` (нет файлов с несоответствиями форматированию)
3. Файлы `oxlint.config.ts` и `oxfmt.config.ts` существуют в корне проекта и содержат конфигурацию из спеки
4. `bunx oxlint src/` (без `--fix`) завершается с кодом выхода `0`

---

## Сценарии ошибок

- Если `bun add -d oxlint oxfmt oxlint-tsgolint` завершается с ненулевым кодом — остановить выполнение, сообщить об ошибке. Дальнейшие шаги не выполнять.
- Если `oxlint --fix` завершается с ненулевым кодом — это ожидаемое поведение при наличии неисправимых нарушений. Перейти к шагу 5 (редактирование исходных файлов), не останавливая выполнение.
- Если `oxfmt --write` завершается с ненулевым кодом — вывести список файлов с ошибками форматирования, остановить выполнение. Не продолжать.
- Если после всех допустимых исправлений в `src/` и `tests/` (см. шаг 5) `oxlint` всё ещё завершается с ненулевым кодом — остановить выполнение, вывести список неисправленных нарушений. Не продолжать и не изменять бизнес-логику.

---

## Инварианты

- `oxfmt` запускается только при успешном завершении `oxlint` (обеспечивается `&&`)
- `oxlint --fix` применяет **только** безопасные исправления (не `--fix-dangerously`)
- Oxlint проверяет только файлы в `src/` и `tests/`; все остальные файлы линтером не затрагиваются
- Oxfmt не затрагивает файлы в `node_modules/`, `dist/`, `.*/**`, `homeworks/`
- Если `oxlint.config.ts` или `oxfmt.config.ts` уже существуют — файлы перезаписываются содержимым из спеки без сохранения предыдущего содержимого

---

## Ограничения на реализацию

- Добавляются ровно три зависимости: `oxlint`, `oxfmt` и `oxlint-tsgolint`
- `tsconfig.json` не изменяется; Oxlint находит его автоматически
- `package.json` изменяется только в части `devDependencies` и `scripts`
- Изменения в `src/` и `tests/` файлах ограничены исправлением нарушений Oxlint (шаг 5)
- Другие файлы не меняются

---

## In scope

- Установка `oxlint`, `oxfmt` и `oxlint-tsgolint` как `devDependencies`
- Создание `oxlint.config.ts` с конфигурацией из спеки
- Создание `oxfmt.config.ts` с конфигурацией из спеки
- Добавление скрипта `lint` в `package.json`
- Исправление существующих нарушений `oxlint` до зелёного состояния

## Out of scope

- CI/CD интеграция
- Pre-commit хуки
- Конфигурация плагинов редактора
