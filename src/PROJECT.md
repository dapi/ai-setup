# Назначение проекта
DotNet библиотека для мэппинга операций Json Patch из одной модели в другую

## Краткое описание
Метод Map принимает на вход объект JsonPatchDocument<TSource> и возвращает объект JsonPatchDocument<TTarget>,
в котором операции над моделью TSource преобразованы на операции над моделью TTarget.

Настройка преобразования производится инициализаций настроечного класса PatchMapProfile из библиотеки.
По умолчанию операции переносятся без изменений для одноименных полей. 
Если поля имеют одинаковое имя но разный тип то производится попытка автоматического преобразовнаия типа.
Есть возможность задать индивидуальное поведение для любого поля из модели TTarget. 

## Ссылки
Протокол Json Patch - https://datatracker.ietf.org/doc/html/rfc6902
Nuget package Microsoft.AspNetCore.JsonPatch.SystemTextJson - https://www.nuget.org/packages/Microsoft.AspNetCore.JsonPatch.SystemTextJson

## Реализация проекта
Библиотека на DotNet Standart 2.1 на языке C# с использованием кодогенерации для первоначальной настройки мэппинга.
