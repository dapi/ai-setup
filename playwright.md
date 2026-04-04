# Playwright Setup

По умолчанию `make` ставит:

- `@playwright/cli`
- skill `playwright-cli` для `codex` и `claude-code`

## Когда нужен `playwright-skill`

`playwright-cli` лучше подходит как основной вариант:

- для обычной браузерной автоматизации через готовые команды;
- для предсказуемых agent workflows;
- для сценариев, где важны snapshots, refs и sessions;
- для одинакового поведения в `codex` и `claude-code`.

`playwright-skill` имеет смысл ставить отдельно, если нужен более свободный Playwright-режим именно в Claude Code:

- для `localhost` и локальной разработки;
- для нестандартных multi-step сценариев;
- для ad hoc проверок, где агенту проще написать свой JS-скрипт;
- для сценариев, где полезен видимый браузер по умолчанию.
