# .prompts

Каноническое место для prompt-шаблонов, используемых в workflow реализации фич.

## Соглашение использования
- Имя команды соответствует имени файла в `.prompts/`.
- Вызов выполняется в форме `prompt_name issue_number`.
- Во всех шаблонах используется единый плейсхолдер `issue_number`.

Пример:

```text
start_task 9
```

## Шаблоны
- `start_task` — читает GitHub issue и создаёт `brief.md`.
- `rw_brief` — ревьюит `brief.md`.
- `mk_spec` — строит `spec.md` из `brief.md`.
- `rw_spec` — ревьюит `spec.md`.
- `mk_plan` — строит `plan.md` из `spec.md`.
- `rw_plan` — проверяет `plan.md` на соответствие `spec.md`.
- `gnd_plan` — проверяет `plan.md` на соответствие кодовой базе.
- `implement` — реализует `plan.md`.

## Артефакты
Все шаблоны работают относительно директории:

```text
memory-bank/features/{issue_number}/
```

В зависимости от шага workflow там создаются или проверяются:
- `brief.md`
- `spec.md`
- `plan.md`
