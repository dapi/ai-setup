# Mapper

Библиотека на C# для преобразования `JsonPatchDocument<TSource>` в `JsonPatchDocument<TTarget>`.

## Что реализовано

- мэппинг одноимённых полей по умолчанию;
- автоматическая конвертация значения при различии типов;
- явное переименование целевого поля через `ForMember(...).MapFrom(...)`;
- игнорирование поля через `ForMember(...).Ignore()`;
- вычисляемое преобразование значения из одного исходного поля.

## Структура

- [src/Mapper.sln](/home/me/projects/mapper/src/Mapper.sln) — solution в папке исходников;
- [src/Mapper](/home/me/projects/mapper/src/Mapper) — библиотека;
- [src/Mapper.Tests](/home/me/projects/mapper/src/Mapper.Tests) — тесты `xUnit`.

## Использование

```csharp
public sealed class RequestProfile : MapProfile
{
    public RequestProfile()
    {
        CreateMap<SourceModel, TargetModel>()
            .ForMember(target => target.DisplayName, options => options.MapFrom(source => source.Name));
    }
}

var mapper = new Mapper(new RequestProfile());
var targetPatch = mapper.Map<SourceModel, TargetModel>(sourcePatch);
```

## Тесты

Из корня репозитория:

```bash
dotnet test
```
