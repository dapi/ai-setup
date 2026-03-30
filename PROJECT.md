# Назначение проекта
DotNet библиотека для мэппинга операций Json Patch из одной модели в другую

## Краткое описание
Метод Map принимает на вход объект JsonPatchDocument<TSource> и возвращает объект JsonPatchDocument<TTarget>,
в котором операции над моделью TSource преобразованы на операции над моделью TTarget.

Настройка преобразования производится инициализаций настроечного класса PatchMapProfile из библиотеки.

### Правила преобразований
- По умолчанию операции переносятся без изменений для одноименных полей
- Если поля имеют одинаковое имя но разный тип то производится попытка автоматического преобразовнаия типа
- Есть возможность задать индивидуальное преобразование для любого поля из модели TTarget:
  - Применить операцию от поля из TSource с отличающимся названием
  - Задать произвольное вычисление вида Func<TSourceField, TTargetField> от поля из TSource, указанного через Linq 

## Ссылки
Протокол Json Patch - https://datatracker.ietf.org/doc/html/rfc6902
Nuget package Microsoft.AspNetCore.JsonPatch.SystemTextJson - https://www.nuget.org/packages/Microsoft.AspNetCore.JsonPatch.SystemTextJson

## Реализация проекта
Библиотека на DotNet Standart 2.1 на языке C#.

Библиотека предоставляет:
1. Публичный класс Mapper - мэппер, использующися в прикладном коде
1. Публичный класс MapProfile - через него определяются настройки преобразований 

Все настройки находятся на этапе компиляции и с помощью кодогенерации создаются объекты для необходимых преобразований.
Цель - минимальные задержки в Run Time.

### Пример настройки преобразований 

```
    public class FromRequestMappingProfile : MapProfile
    {
        public MappingProfile()
        {
            CreateMap<GetEntityModel, AdminTransactionsGetEntityRequest>();

            CreateMap<GetEntitiesModel, GetEntitiesRequest>()
                .ForMember(m => m.UserId, opt => opt.Ignore())
                .ForMember(m => m.Status, opt => opt.MapFrom(v => string.IsNullOrEmpty(v.Status) ? null : (EntityStatus?)Enum.Parse<EntityStatus>(v.Status)));
        }
    }
```


## Тестирование
Отдельный проект с тестами на XUnit, проверяющий
### все виды операций, описаных в протоколе Json Patch
- create
- replace
- remove
- test

### варианты мэппинга
- патч поля из патча поля поля с тем же названием
- патч поля из патча поля с другим названием
- патч поля с вычислением из другого поля


