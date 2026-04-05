# Feature #001. Add Linter & Formatter - https://github.com/akoltun/ai-setup/issues/1

## Brief
### Prompt #1
Read the issue 1 from the repository of the project.
Generate the Brief in accord with SDD best practices
Save it to `memory-bank/features/001/brief.md`

### Prompt #2
Read the Breif from `memory-bank/features/001/brief.md`
Pay attention on Open Questions at the end.
Adjust the Brief in accord with the following answers for those questions:
1. Check the documentation: https://oxc.rs/docs/guide/usage/formatter.html#oxfmt. Find and install plugin if needed.
2. Yes, include `.json` and `.md`
3. No

### Prompt #3 - повторялся в новой сессии многократно
Ты — ревьюер бизнес-задач. Проверь Brief в `memory-bank/features/001/brief.md` на полноту и однозначность.

Критерии:
1. Понятен контекст: откуда задача, почему важна сейчас
2. Brief НЕ содержит решения — только проблему и желаемый результат
3. Нет двусмысленных формулировок («быстро», «удобно», «при необходимости»)

Для каждого найденного замечания укажи:
- Что именно не так (цитата из документа)
- Почему это проблема
- Как исправить (конкретное предложение)

Если замечаний нет — напиши «0 замечаний, Brief готов к работе».

### Prompt #4 (в сессии Prompt-а #3)
Исправь замечания в соостветствие с предложенным.

В отношение замечания 2. Необходимо утолчнить, что после первого запуска линтера могут появиться ошибки, требующие ручного исправления. Для завершения задачи, все ошибки должны быть исправлены, и итоговый запуск линтера не должен находить ошибок.

### Prompt #5 (в сессии Prompt-а #3)
Примени исправления. Касательно второго замечания - это стандартное поведение 

### Prompt #6 (в сессии Prompt-а #3)
примени исправления, не создавай Spec.md

### Prompt #7 (в сессии Prompt-а #3)
примени исправления, не создавай Spec.md

### Prompt #8 (в сессии Prompt-а #3)
примени исправления, не создавай Spec.md

### Prompt #9 (в сессии Prompt-а #3)
Исправь замечания: убери Constraints, явно перечисли поддерживаемые линтером и форматтером типы файлов. Поддерживаемые типы файлов, определи из документации                             
  https://oxc.rs/docs/guide/usage/formatter.html#oxfmt и https://oxc.rs/docs/guide/usage/linter.html#oxlint  

### Prompt #10 (в сессии Prompt-а #3)
примени предложенные исправления, warnings не допустимы