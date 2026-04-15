using System.Reflection;

namespace Mapper.Demo.Services;

public static class DemoMetadata
{
    public static IReadOnlyList<string> Describe<T>() =>
        typeof(T)
            .GetProperties(BindingFlags.Public | BindingFlags.Instance)
            .Select(static property => $"{property.Name}: {FormatType(property.PropertyType)}")
            .ToArray();

    private static string FormatType(Type type)
    {
        if (type == typeof(string))
        {
            return "string";
        }

        if (type == typeof(int))
        {
            return "int";
        }

        if (type == typeof(long))
        {
            return "long";
        }

        if (type.IsGenericType && type.GetGenericTypeDefinition() == typeof(Nullable<>))
        {
            return $"{FormatType(Nullable.GetUnderlyingType(type)!)}?";
        }

        return type.Name;
    }
}
