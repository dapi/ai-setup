# Build

Каноническая структура репозитория:
- `src/Mapper.sln` — основное solution проекта;
- `src/Mapper` — библиотека;
- `src/Mapper.Tests` — отдельный тестовый проект.
- `src/Mapper.Demo` — демонстрационный Razor Pages проект для ручной проверки мэппинга.

Для обычной сборки достаточно стандартных CLI-команд `dotnet`. 
Отдельный build-скрипт для повседневной сборки в репозитории не нужен и не используется как основной путь.

Основные команды:
- `dotnet build src/Mapper.sln` - сборка проекта
- `dotnet test src/Mapper.sln` - запуск тестов

## Demo

`Mapper.Demo` подключается к `src/Mapper.sln`, поэтому его сборка входит в обычный `dotnet build src/Mapper.sln`.

Для локального запуска demo используйте:
- `dotnet run --project src/Mapper.Demo/Mapper.Demo.csproj`

Для запуска из редактора используйте:
- `.vscode/launch.json` -> `Launch Mapper.Demo`

Назначение demo-проекта:
- показать на одной странице demo-модели `Source` и `Target` в формате `name: type`;
- дать ввести или отредактировать Json Patch для `Source`;
- прогнать `JsonPatchDocument<Source>` через локальную библиотеку `Mapper`;
- отобразить сериализованный результат как `JsonPatchDocument<Target>`.

Ограниченный demo-сценарий:
- `Source`: `Name: string`, `Age: int`;
- `Target`: `DisplayName: string`, `Age: int`;
- демонстрируется same-name mapping `Age -> Age`;
- демонстрируется `MapFrom(...)`-переименование `Name -> DisplayName`.

Стартовое состояние страницы:
- при первой загрузке показываются поля `Source` и `Target` в формате `name: type`;
- поле ввода уже заполнено обязательным примером patch-а;
- результат остаётся на той же странице после нажатия `Map`.

Стартовый пример patch-а:
```json
[
  { "op": "replace", "path": "/Name", "value": "Alice" },
  { "op": "replace", "path": "/Age", "value": 42 }
]
```

Ожидаемый результат для этого примера:
```json
[
  { "op": "replace", "path": "/DisplayName", "value": "Alice" },
  { "op": "replace", "path": "/Age", "value": 42 }
]
```
