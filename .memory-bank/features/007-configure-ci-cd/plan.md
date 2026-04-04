# Implementation Plan: 007 — Configure CI / CD

**Статус:** Draft  
**Версия:** 1.1  
**Спецификация:** [spec.md](./spec.md)  
**Бриф:** [brief.md](./brief.md)

---

## Grounding Summary (текущее состояние)

| Артефакт | Статус | Путь |
|---|---|---|
| GitHub Actions CI workflow | Есть, но только meta-lint + smoke bootstrap, **без** Rails-проверок | `.github/workflows/ci.yml` |
| `bin/ci` (Rails) | Есть: RuboCop, Bundler Audit, Brakeman, **без** RSpec | `video_chat_and_translator/bin/ci` + `config/ci.rb` |
| Docker dev compose | Есть, рабочий | `docker/docker-compose.yml` |
| Docker dev Dockerfile | Есть | `docker/Dockerfile` |
| Docker prod Dockerfile (Kamal) | Есть, multi-stage | `video_chat_and_translator/Dockerfile` |
| Kamal deploy.yml | Есть, **плейсхолдеры** (`localhost:5555`, `192.168.0.1`) | `video_chat_and_translator/config/deploy.yml` |
| `.kamal/secrets` | Есть, шаблон 1Password | `video_chat_and_translator/.kamal/secrets` |
| `spec/` (RSpec) | **Не существует**, rspec-rails не в Gemfile | — |
| `docs/ci-checks.md` | **Не существует** | — |
| `docs/ci-parity.md` | **Не существует** | — |
| `docs/ci-troubleshooting.md` | **Не существует** | — |
| `docs/cd-triggers.md` | **Не существует** | — |
| CD workflow | **Не существует** | — |
| `scripts/ci-app.sh` | **Не существует** | — |
| `production.rb` SSL | `assume_ssl` и `force_ssl` **закомментированы** | `video_chat_and_translator/config/environments/production.rb` |

---

## Эпик 1 — CI: единая точка правды по качеству

> **Порядок шагов 1.1.x:** нумерация совпадает с порядком выполнения (сначала `docker-compose.ci.yml`, затем `ci-app.sh`, затем workflow). Для шагов 1.2.x и 1.3.x дополнительно смотри граф в конце документа.

### Шаг 1.1.1 — Создать `/docs/ci-checks.md`

**Файл:** `video_chat_and_translator/docs/ci-checks.md` (новый)

**Содержание:**
- Перечень обязательных проверок: `bin/rubocop`, `bin/bundler-audit`, `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`
- Явная запись: «RSpec: не подключён — пропуск» с датой
- Ссылка на `bin/ci` как каноническую точку входа
- **Лог сборки Docker в CI (спека §8):** зафиксировать, что при сбое job загружается артефакт, включающий файл **`docker-build-log.txt`** (полный stdout/stderr шага `docker compose build`), а не только лог шага в UI Actions — см. шаг 1.1.4 и раздел «Артефакты» после шага 1.2.2

**Зависимости:** нет  
**Проверка:** файл существует, перечислены 3 проверки, зафиксирован статус RSpec и политика лога сборки

---

### Шаг 1.1.2 — Создать `docker/docker-compose.ci.yml`

**Файл:** `docker/docker-compose.ci.yml` (новый)

**Суть:** CI-override для docker-compose, чтобы не трогать рабочий dev-compose. Отличия от dev:
- `RAILS_ENV=test`
- `DATABASE_URL` указывает на тестовую БД
- `volumes: []` — без host mount (в CI код внутри образа через COPY)

**Merge compose и `environment`:** в базовом `docker-compose.yml` у `web` поле `environment` — список строк. При объединении файлов Docker Compose **заменяет список целиком**, не объединяет по ключам. В CI у `web` остаются только переменные из override (`DATABASE_URL`, `RAILS_ENV`). Переменные dev (`VITE_RUBY_HOST`, `PORT`, `BINDING`) в CI **отсутствуют** — это осознанно; для `bin/ci` (RuboCop, Brakeman, bundler-audit, `bin/setup --skip-server`) они не требуются. Явно задокументировать в `ci-parity.md` (шаг 1.2.1).

```yaml
services:
  web:
    build:
      context: ../video_chat_and_translator
      dockerfile: ../docker/Dockerfile
    environment:
      - DATABASE_URL=postgres://postgres:postgres@db:5432/video_chat_and_translator_test
      - RAILS_ENV=test
    depends_on:
      db:
        condition: service_healthy
    volumes: []

  db:
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: video_chat_and_translator_test
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
```

**Зависимости:** нет  
**Конфликты:** `docker/docker-compose.yml` **не изменяется**, нет конфликтов с dev-окружением  
**Проверка:** `docker compose -f docker/docker-compose.yml -f docker/docker-compose.ci.yml config` — валидный YAML без ошибок

---

### Шаг 1.1.3 — Создать `scripts/ci-app.sh`

**Файл:** `scripts/ci-app.sh` (новый)

**Суть:** единый входной скрипт для локального воспроизведения CI-проверок в Docker, **с паритетом** с job в `.github/workflows/ci.yml`: те же два compose-файла, те же команды, **teardown** в конце (или при ошибке).

**Требования к скрипту (lint в репозитории):**
- Шебанг `#!/usr/bin/env bash`
- `set -euo pipefail` в начале
- Проходит **shfmt** и **shellcheck** (job `Lint` проверяет `scripts/*.sh`)
- **Teardown:** после успеха или ошибки выполнять `docker compose -f docker/docker-compose.yml -f docker/docker-compose.ci.yml down -v` — удобно через `trap '...' EXIT` (или эквивалент), чтобы не оставлять контейнеры и volumes после локального запуска

**Минимальный каркас логики:**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE=(docker compose -f "${ROOT_DIR}/docker/docker-compose.yml" -f "${ROOT_DIR}/docker/docker-compose.ci.yml")

cleanup() {
  "${COMPOSE[@]}" down -v
}
trap cleanup EXIT

mkdir -p "${ROOT_DIR}/tmp/ci-artifacts"
"${COMPOSE[@]}" build web 2>&1 | tee "${ROOT_DIR}/tmp/ci-artifacts/docker-build-log.txt"
"${COMPOSE[@]}" run --rm web bin/setup --skip-server
"${COMPOSE[@]}" run --rm web bin/ci
```

(Путь `tmp/ci-artifacts` для локального `docker-build-log.txt` можно заменить на согласованный с командой; важно: локально тоже сохранять лог сборки для отладки.)

**Зависимости:** шаг 1.1.2 (`docker-compose.ci.yml`)  
**Конфликты:** нет — скрипт новый  
**Проверка:** `./scripts/ci-app.sh` локально воспроизводит проверки; `shfmt -d scripts/ci-app.sh` и `shellcheck scripts/ci-app.sh` без замечаний; после завершения нет «висящих» compose-сервисов от этого прогона

---

### Шаг 1.1.4 — Добавить job `app` в `.github/workflows/ci.yml`

**Файл:** `.github/workflows/ci.yml` (изменение)

**Суть:** добавить новый job `app` параллельно с `lint` и `smoke-bootstrap`.

**Лог сборки образа (спека §8, сценарий «Сборка Docker-образа в CI завершилась с ошибкой»):** вывод шага `docker compose build` писать в файл **`docker-build-log.txt`** (например через `tee`), чтобы при падении **на этапе build** в артефакте был полный лог сборки; логи `docker compose logs` при этом могут быть пустыми или неинформативными.

**Пиннинг actions:** как в существующем `ci.yml`, указывать **SHA коммита**, не тег (`@v4`). Для `actions/upload-artifact` использовать тот же подход, что для `actions/checkout` (проверка actionlint).

Пример фрагмента (SHA `upload-artifact` перепроверить на момент реализации по [релизам actions/upload-artifact](https://github.com/actions/upload-artifact/releases); в плане зафиксирован ориентир для ветки `v4`):

```yaml
  app:
    name: App checks (Docker)
    runs-on: ubuntu-latest
    timeout-minutes: 45

    steps:
      - name: Checkout
        uses: actions/checkout@93cb6efe18208431cddfb8368fd83d5badbf9bfd # v5.0.1

      - name: Prepare artifact directory
        run: mkdir -p /tmp/ci-artifacts

      - name: Build Docker image
        run: docker compose -f docker/docker-compose.yml -f docker/docker-compose.ci.yml build web 2>&1 | tee /tmp/ci-artifacts/docker-build-log.txt

      - name: Setup database
        run: docker compose -f docker/docker-compose.yml -f docker/docker-compose.ci.yml run --rm web bin/setup --skip-server

      - name: Run CI checks
        run: docker compose -f docker/docker-compose.yml -f docker/docker-compose.ci.yml run --rm web bin/ci

      - name: Collect logs on failure
        if: failure()
        run: |
          docker compose -f docker/docker-compose.yml -f docker/docker-compose.ci.yml logs > /tmp/ci-artifacts/docker-compose-runtime-logs.txt 2>&1 || true
          docker compose -f docker/docker-compose.yml -f docker/docker-compose.ci.yml cp web:/app/log/test.log /tmp/ci-artifacts/test.log || true

      - name: Upload failure artifacts
        if: failure()
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4.x (SHA на ref v4; перепроверить при merge)
        with:
          name: ci-failure-logs
          path: /tmp/ci-artifacts/

      - name: Teardown
        if: always()
        run: docker compose -f docker/docker-compose.yml -f docker/docker-compose.ci.yml down -v
```

**Затрагиваемые участки:** новый job в конец файла, не трогает `lint` и `smoke-bootstrap`.  
**Зависимости:** шаг 1.1.2 (`docker-compose.ci.yml`)  
**Конфликты:** существующий `concurrency` group `ci-${{ github.workflow }}-${{ github.ref }}` сохраняется — новый job входит в тот же workflow.  
**Проверка:** PR → GitHub Actions → job `App checks (Docker)` запускается и проходит; при искусственном падении на `build` в артефакте есть `docker-build-log.txt`

---

### Шаг 1.2.1 — Создать `docs/ci-parity.md`

**Файл:** `video_chat_and_translator/docs/ci-parity.md` (новый)

**Содержание:**
- Таблица отличий CI от локального dev compose:
  - `RAILS_ENV=test` (vs `development`)
  - `volumes: []` (no host mount)
  - Тестовая БД `video_chat_and_translator_test` (vs `_development`)
- **Явный абзац про merge `environment`:** при объединении compose-файлов список `environment` у `web` **заменяется** override целиком; в CI **нет** `VITE_RUBY_HOST`, `PORT`, `BINDING` — для статических проверок и `bin/setup --skip-server` это не требуется; при появлении шага, зависящего от них, добавить переменные в `docker-compose.ci.yml` и обновить этот документ
- Ссылка на `docker/docker-compose.ci.yml`
- Обоснование отличий (инвариант §2 п.2 спецификации)

**Зависимости:** шаг 1.1.2, 1.1.4  
**Проверка:** документ полный, в том числе про замену `environment`

---

### Шаг 1.2.2 — Документировать артефакты падений

**Файл:** `video_chat_and_translator/docs/ci-checks.md` (обновление после 1.1.1)

**Суть:** раздел «Артефакты и диагностика»:
- Путь в GitHub Actions UI для скачивания артефакта `ci-failure-logs`
- Состав: **`docker-build-log.txt`** (всегда создаётся на шаге build через `tee`), при падении после старта контейнеров — **`docker-compose-runtime-logs.txt`**, **`test.log`** (если файл существует)
- Строка: «JUnit XML: не подключён — без вкладки Tests в GitHub. Подключение — после добавления RSpec и настройки `--format RspecJunitFormatter`»

**Зависимости:** шаг 1.1.1, 1.1.4  
**Проверка:** искусственный сбой на build и после build → артефакт содержит ожидаемые файлы; документация совпадает с workflow

---

### Шаг 1.2.3 — Troubleshooting CI (спека §8)

**Файл:** `video_chat_and_translator/docs/ci-troubleshooting.md` (новый)

**Суть:** выполнить требование спеки (сценарий «Недоступен registry при pull базовых образов»): отдельный короткий документ или, по решению команды, раздел в `ci-checks.md` со ссылкой из оглавления. В плане зафиксирован **отдельный файл** для ясности.

**Содержание (минимум):**
- При сетевых сбоях / недоступности registry: **повторить** workflow run в Actions
- Проверить статус Docker Hub / зеркал / корпоративного mirror
- Куда смотреть: лог шага build (`docker-build-log.txt` в артефакте при failure)

**Зависимости:** шаг 1.1.4 (чтобы имена артефактов совпадали)  
**Проверка:** документ есть; из `ci-checks.md` или `ci-parity.md` — одна ссылка «Troubleshooting»

---

### Шаг 1.3.1 — Документация branch protection

**Файл:** `video_chat_and_translator/docs/ci-branch-protection.md` (новый)

**Содержание:**
- Точные имена required status checks (из `name:` полей jobs в `ci.yml`):
  - `App checks (Docker)`
  - `Lint`
  - `Smoke (ubuntu-latest)`
  - `Smoke (macos-latest)`
- Пошаговая инструкция: Settings → Branches → Add rule → `main` → Require status checks → вписать имена
- Рекомендация: «Require branches to be up to date before merging»

**Зависимости:** шаг 1.1.4 (имя job финальное)  
**Проверка:** имена checks совпадают с именами job в workflow

---

## Эпик 2 — CD: документированный путь к staging и production

### Шаг 2.0.1 — Согласование с владельцем (BLOCKER)

> **Перед началом эпика 2 необходимо согласовать с владельцем репозитория:**

1. **Триггеры CD:** staging = push в `main` / manual dispatch? Production = approval / annotated tag?
2. **Registry:** GHCR (`ghcr.io`) или другой?
3. **Реальные хосты:** staging и production (заменить `192.168.0.1`)
4. **SSL:** proxy в Kamal или внешний LB?
5. **Разделение окружений:** `deploy.staging.yml` / `deploy.production.yml` или Kamal destinations?

**Результат согласования** записывается в `docs/cd-triggers.md`.

---

### Шаг 2.1.1 — Создать `docs/cd-triggers.md`

**Файл:** `video_chat_and_translator/docs/cd-triggers.md` (новый)

**Содержание** (заполняется после согласования шага 2.0.1):
- Staging trigger: конкретный вариант
- Production trigger: конкретный вариант
- Concurrency policy: `deploy-staging` / `deploy-production`, `cancel-in-progress: false`
- Без формулировок «при необходимости» / «по согласованию»

**Зависимости:** шаг 2.0.1  
**Проверка:** документ полный, однозначные формулировки

---

### Шаг 2.1.2 — Создать Runbook `docs/cd-runbook.md`

**Файл:** `video_chat_and_translator/docs/cd-runbook.md` (новый)

**Содержание:**
- **Предпосылки:** registry, SSH-доступ, `.kamal/secrets`
- **Staging:** команда деплоя, smoke URL, критерий успеха
- **Production:** команда деплоя, approval gate, smoke URL
- **Откат:** `kamal rollback` + критерий успешного отката (smoke URL отвечает, предыдущая ревизия на хосте)
- **Логи:** `kamal app logs`, `kamal audit`
- **Политика секретов:** 1Password, ссылка на `.kamal/secrets`
- **Чеклист нового мейнтейнера** (7 пунктов из спеки §7 фича 2.1):
  1. Доступ к registry и pull образа
  2. SSH на целевые хосты
  3. Заполнение секретов из хранилища команды
  4. Выполнение dry-run или `kamal config` без ошибок
  5. Деплой в согласованное непродакшен окружение
  6. Smoke по URL из runbook
  7. Выполнение учебного отката или tabletop с владельцем репо

**Зависимости:** шаг 2.0.1, 2.1.1  
**Проверка:** все 7 пунктов чеклиста присутствуют, откат описан с командами и ожидаемым результатом

---

### Шаг 2.2.1 — Создать `.github/workflows/deploy.yml`

**Файл:** `.github/workflows/deploy.yml` (новый)

**Суть:** CD workflow с jobs для staging и production.

**Пиннинг `actions/checkout`:** не использовать `@v4` по тегу — указать **тот же SHA**, что в `.github/workflows/ci.yml` (на момент реализации: `actions/checkout@93cb6efe18208431cddfb8368fd83d5badbf9bfd # v5.0.1`), либо другой закреплённый SHA после явной проверки совместимости.

```yaml
name: Deploy

on:
  push:
    branches: [main]       # staging (если согласовано)
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [staging, production]

concurrency:
  group: deploy-${{ github.event.inputs.environment || 'staging' }}
  cancel-in-progress: false

jobs:
  deploy-staging:
    # условие для staging
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@93cb6efe18208431cddfb8368fd83d5badbf9bfd # v5.0.1 — как в ci.yml
      - # Install Kamal
      - # kamal deploy (staging destination)

  deploy-production:
    # условие для production (tag / manual + approval)
    runs-on: ubuntu-latest
    environment: production  # GitHub Environment с required reviewers
    steps:
      - uses: actions/checkout@93cb6efe18208431cddfb8368fd83d5badbf9bfd # v5.0.1 — как в ci.yml
      - # Install Kamal
      - # kamal deploy (production destination)
```

**Точное содержание зависит от решений шага 2.0.1.**

**Зависимости:** шаг 2.0.1, 2.1.1  
**Конфликты:** новый файл, не трогает `ci.yml`  
**Проверка:** workflow запускается, деплой в staging проходит, в run видны идентификатор образа/digest и ref коммита

---

### Шаг 2.3.1 — Обновить `config/deploy.yml`

**Файл:** `video_chat_and_translator/config/deploy.yml` (изменение)

**Суть:**
- Заменить `registry: server: localhost:5555` на реальный (после согласования)
- Заменить `servers: web: - 192.168.0.1` на реальные хосты (или destinations для staging/production)
- Решить `proxy`/SSL: раскомментировать блок proxy **или** добавить явную строку «SSL termination: внешний LB / без proxy»
- Согласовать с `production.rb`

**Зависимости:** шаг 2.0.1  
**Конфликты:** напрямую затрагивает `deploy.yml` — согласовать с владельцем  
**Проверка:** `kamal config` — exit code 0

---

### Шаг 2.3.2 — Согласовать SSL в `production.rb`

**Файл:** `video_chat_and_translator/config/environments/production.rb` (изменение)

**Суть:** если proxy SSL включён в deploy.yml — раскомментировать:
- `config.assume_ssl = true`
- `config.force_ssl = true`

Если внешний LB — оставить закомментированным, добавить комментарий с обоснованием.

**Зависимости:** шаг 2.3.1  
**Проверка:** совпадение с решением по proxy в deploy.yml

---

## Порядок выполнения (граф зависимостей)

```
Эпик 1 (можно начинать сразу):

  1.1.1 (docs/ci-checks.md — черновик + политика лога сборки)
    │
  1.1.2 (docker-compose.ci.yml)
    │
  1.1.3 (scripts/ci-app.sh: двойной compose, shellcheck/shfmt, trap teardown)
    │
  1.1.4 (job app: build tee → docker-build-log.txt, upload-artifact по SHA, артефакты)
    │
    ├── 1.2.1 (docs/ci-parity.md — в т.ч. merge environment)
    ├── 1.2.2 (дополнить ci-checks.md: артефакты, JUnit)
    ├── 1.2.3 (docs/ci-troubleshooting.md + ссылка)
    └── 1.3.1 (docs/ci-branch-protection.md)

Эпик 2 (BLOCKER: согласование 2.0.1):

  2.0.1 (согласование с владельцем)
    │
    ├── 2.1.1 (docs/cd-triggers.md)
    │     └── 2.1.2 (docs/cd-runbook.md)
    │
    ├── 2.2.1 (.github/workflows/deploy.yml — checkout по SHA как в ci.yml)
    │
    └── 2.3.1 (config/deploy.yml)
          └── 2.3.2 (production.rb SSL)
```

---

## Затрагиваемые файлы (сводка)

| Файл | Действие |
|---|---|
| `.github/workflows/ci.yml` | Изменение (добавить job `app`) |
| `.github/workflows/deploy.yml` | **Новый** |
| `docker/docker-compose.ci.yml` | **Новый** |
| `scripts/ci-app.sh` | **Новый** |
| `video_chat_and_translator/docs/ci-checks.md` | **Новый** (+ правки по артефактам) |
| `video_chat_and_translator/docs/ci-parity.md` | **Новый** |
| `video_chat_and_translator/docs/ci-troubleshooting.md` | **Новый** |
| `video_chat_and_translator/docs/ci-branch-protection.md` | **Новый** |
| `video_chat_and_translator/docs/cd-triggers.md` | **Новый** |
| `video_chat_and_translator/docs/cd-runbook.md` | **Новый** |
| `video_chat_and_translator/config/deploy.yml` | Изменение (после согласования) |
| `video_chat_and_translator/config/environments/production.rb` | Изменение (условно, после согласования SSL) |

---

## Блокеры и решения перед стартом

| Блокер | Что нужно | Влияет на |
|---|---|---|
| Эпик 1 — нет блокеров | Можно начинать немедленно | Шаги 1.x |
| Эпик 2 — согласование (шаг 2.0.1) | Registry, хосты, триггеры CD, SSL | Все шаги 2.x |

---

## Changelog плана (ревью v1.1)

| Замечание | Изменение |
|---|---|
| 1 — дублирование 1.1.2 / 1.1.5 | Шаг 1.1.5 удалён; один шаг **1.1.3** создаёт `ci-app.sh` сразу с двойным compose и teardown |
| 2 — порядок 1.1.2 vs 1.1.3 | Перенумерация: **1.1.2** = `docker-compose.ci.yml`, **1.1.3** = `ci-app.sh`, **1.1.4** = workflow; примечание в начале эпика 1 |
| 3 — лог сборки Docker | Build через `tee` → `docker-build-log.txt`; артефакт; явная политика в `ci-checks.md` |
| 4 — troubleshooting | Новый шаг **1.2.3**, файл `docs/ci-troubleshooting.md` |
| 5 — пиннинг upload-artifact | `actions/upload-artifact@<SHA>`; в deploy — `checkout` по SHA как в `ci.yml` |
| 6 — merge environment | Описано в 1.1.2 и в **1.2.1** (`ci-parity.md`) |
| 7 — shellcheck/shfmt | В **1.1.3** — шебанг, `set -euo pipefail`, каркас скрипта |
| 8 — teardown в скрипте | В **1.1.3** — `trap` + `down -v`; локальный `tee` лога сборки в `tmp/ci-artifacts` |
