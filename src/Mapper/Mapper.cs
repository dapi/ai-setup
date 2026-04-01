using System.Collections.Concurrent;
using System.Globalization;
using System.Linq.Expressions;
using System.Reflection;
using Microsoft.AspNetCore.JsonPatch;
using Microsoft.AspNetCore.JsonPatch.Operations;

namespace Mapper;

public sealed class Mapper
{
    private readonly ConcurrentDictionary<TypePair, ICompiledMap> _compiledMaps;

    public Mapper(params MapProfile[] profiles)
    {
        if (profiles is null)
        {
            throw new ArgumentNullException(nameof(profiles));
        }

        _compiledMaps = new ConcurrentDictionary<TypePair, ICompiledMap>(
            profiles
                .SelectMany(static profile => profile.Definitions)
                .Select(static definition => new KeyValuePair<TypePair, ICompiledMap>(
                    new TypePair(definition.SourceType, definition.TargetType),
                    definition.Compile())));
    }

    public JsonPatchDocument<TTarget> Map<TSource, TTarget>(JsonPatchDocument<TSource> sourcePatch)
        where TSource : class
        where TTarget : class
    {
        if (sourcePatch is null)
        {
            throw new ArgumentNullException(nameof(sourcePatch));
        }

        if (!_compiledMaps.TryGetValue(new TypePair(typeof(TSource), typeof(TTarget)), out var compiledMap))
        {
            throw new InvalidOperationException(
                $"Mapping from {typeof(TSource).FullName} to {typeof(TTarget).FullName} is not configured.");
        }

        var targetPatch = new JsonPatchDocument<TTarget>();

        foreach (var operation in sourcePatch.Operations)
        {
            var mappedOperation = compiledMap.MapOperation(operation);
            if (mappedOperation is Operation<TTarget> typedOperation)
            {
                targetPatch.Operations.Add(typedOperation);
            }
            else if (mappedOperation is not null)
            {
                throw new InvalidOperationException("Compiled mapping returned an operation of unexpected type.");
            }
        }

        return targetPatch;
    }
}

internal interface ICompiledMap
{
    object? MapOperation(Operation operation);
}

internal sealed class CompiledMap<TSource, TTarget> : ICompiledMap
    where TSource : class
    where TTarget : class
{
    private readonly Dictionary<string, MemberRule> _rules;

    public CompiledMap(Dictionary<string, MemberRule> rules)
    {
        _rules = rules;
    }

    public object? MapOperation(Operation operation)
    {
        if (operation is null)
        {
            throw new ArgumentNullException(nameof(operation));
        }

        var pathRule = ResolveRule(operation.path);
        if (pathRule?.Ignored == true)
        {
            return null;
        }

        var fromRule = string.IsNullOrWhiteSpace(operation.from) ? null : ResolveRule(operation.from);
        if (fromRule?.Ignored == true)
        {
            return null;
        }

        var mapped = new Operation<TTarget>
        {
            op = operation.op,
            path = pathRule?.TargetPath ?? operation.path,
            from = fromRule?.TargetPath ?? operation.from,
            value = ConvertValueIfNeeded(operation.op, operation.value, pathRule)
        };

        return mapped;
    }

    private MemberRule? ResolveRule(string? path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return null;
        }

        return _rules.TryGetValue(path, out var directRule) ? directRule : null;
    }

    private static object? ConvertValueIfNeeded(string op, object? value, MemberRule? rule)
    {
        if (value is null)
        {
            return null;
        }

        if (!OperationRequiresValue(op))
        {
            return value;
        }

        return rule?.Convert is null ? value : rule.Convert(value);
    }

    private static bool OperationRequiresValue(string op) =>
        string.Equals(op, "add", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(op, "replace", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(op, "test", StringComparison.OrdinalIgnoreCase);
}

internal sealed class MemberRule
{
    public string SourcePath { get; set; } = string.Empty;
    public string TargetPath { get; set; } = string.Empty;
    public bool Ignored { get; set; }
    public Func<object?, object?>? Convert { get; set; }
}

internal static class PatchMapCompiler
{
    public static ICompiledMap Compile<TSource, TTarget>(IReadOnlyDictionary<string, MemberConfiguration> memberConfigurations)
        where TSource : class
        where TTarget : class
    {
        var rules = BuildDefaultRules<TSource, TTarget>();

        foreach (var configuration in memberConfigurations.Values)
        {
            ApplyConfiguration<TSource, TTarget>(rules, configuration);
        }

        return new CompiledMap<TSource, TTarget>(rules);
    }

    private static Dictionary<string, MemberRule> BuildDefaultRules<TSource, TTarget>()
        where TSource : class
        where TTarget : class
    {
        var targetProperties = typeof(TTarget)
            .GetProperties(BindingFlags.Instance | BindingFlags.Public)
            .Where(static property => property.CanWrite)
            .ToDictionary(static property => property.Name, StringComparer.OrdinalIgnoreCase);

        var rules = new Dictionary<string, MemberRule>(StringComparer.OrdinalIgnoreCase);

        foreach (var sourceProperty in typeof(TSource).GetProperties(BindingFlags.Instance | BindingFlags.Public))
        {
            if (!sourceProperty.CanRead || !targetProperties.TryGetValue(sourceProperty.Name, out var targetProperty))
            {
                continue;
            }

            var path = "/" + sourceProperty.Name;
            rules[path] = new MemberRule
            {
                SourcePath = path,
                TargetPath = "/" + targetProperty.Name,
                Ignored = false,
                Convert = BuildValueConverter(sourceProperty.PropertyType, targetProperty.PropertyType)
            };
        }

        return rules;
    }

    private static void ApplyConfiguration<TSource, TTarget>(
        IDictionary<string, MemberRule> rules,
        MemberConfiguration configuration)
        where TSource : class
        where TTarget : class
    {
        if (configuration.Ignored)
        {
            var targetPath = configuration.TargetPath;
            var existing = rules.Values.FirstOrDefault(rule => string.Equals(rule.TargetPath, targetPath, StringComparison.OrdinalIgnoreCase));
            if (existing is not null)
            {
                rules[existing.SourcePath] = new MemberRule
                {
                    SourcePath = existing.SourcePath,
                    TargetPath = existing.TargetPath,
                    Ignored = true,
                    Convert = existing.Convert
                };
            }

            return;
        }

        if (configuration.SourceExpression is null)
        {
            return;
        }

        var sourceDescriptor = SourceMemberDescriptor.Create<TSource>(configuration.SourceExpression);
        rules[sourceDescriptor.Path] = new MemberRule
        {
            SourcePath = sourceDescriptor.Path,
            TargetPath = configuration.TargetPath,
            Ignored = false,
            Convert = sourceDescriptor.ValueConverter
        };
    }

    private static Func<object?, object?> BuildValueConverter(Type sourceType, Type targetType)
    {
        return value => ValueConversion.Convert(value, sourceType, targetType);
    }
}

internal sealed class SourceMemberDescriptor
{
    private SourceMemberDescriptor(string path, Func<object?, object?> valueConverter)
    {
        Path = path;
        ValueConverter = valueConverter;
    }

    public string Path { get; }

    public Func<object?, object?> ValueConverter { get; }

    public static SourceMemberDescriptor Create<TSource>(LambdaExpression expression)
    {
        var memberAccess = SingleMemberAccessVisitor.Find(expression.Body, expression.Parameters[0]);
        if (memberAccess is null)
        {
            throw new NotSupportedException("MapFrom expression must depend on exactly one source member.");
        }

        var sourcePath = "/" + string.Join("/", memberAccess.PathSegments);
        var valueParameter = Expression.Parameter(typeof(object), "value");
        var replacement = ReplaceExpressionVisitor.Replace(
            expression.Body,
            memberAccess.Expression,
            Expression.Convert(valueParameter, memberAccess.MemberType));

        var lambda = Expression.Lambda<Func<object?, object?>>(
            Expression.Convert(replacement, typeof(object)),
            valueParameter);

        var compiled = lambda.Compile();
        return new SourceMemberDescriptor(sourcePath, compiled);
    }
}

internal sealed class SingleMemberAccessVisitor : ExpressionVisitor
{
    private readonly ParameterExpression _rootParameter;
    private MemberAccessMatch? _match;
    private bool _multipleMatches;

    private SingleMemberAccessVisitor(ParameterExpression rootParameter)
    {
        _rootParameter = rootParameter;
    }

    public static MemberAccessMatch? Find(Expression expression, ParameterExpression rootParameter)
    {
        var visitor = new SingleMemberAccessVisitor(rootParameter);
        visitor.Visit(expression);
        return visitor._multipleMatches ? null : visitor._match;
    }

    protected override Expression VisitMember(MemberExpression node)
    {
        var unwrapped = ExpressionPath.UnwrapConvert(node.Expression);
        if (DependsOnRoot(unwrapped))
        {
            var pathSegments = ExpressionPath.GetMemberSegments(node);
            var match = new MemberAccessMatch(node, pathSegments, node.Type);
            if (_match is null)
            {
                _match = match;
            }
            else if (!string.Equals(_match.Path, match.Path, StringComparison.Ordinal))
            {
                _multipleMatches = true;
            }
        }

        return base.VisitMember(node);
    }

    private bool DependsOnRoot(Expression expression)
    {
        while (expression is MemberExpression memberExpression)
        {
            expression = ExpressionPath.UnwrapConvert(memberExpression.Expression);
        }

        return expression == _rootParameter;
    }
}

internal sealed class MemberAccessMatch
{
    public MemberAccessMatch(Expression expression, IReadOnlyList<string> pathSegments, Type memberType)
    {
        Expression = expression;
        PathSegments = pathSegments;
        MemberType = memberType;
        Path = "/" + string.Join("/", pathSegments);
    }

    public Expression Expression { get; }

    public IReadOnlyList<string> PathSegments { get; }

    public Type MemberType { get; }

    public string Path { get; }
}

internal sealed class ReplaceExpressionVisitor : ExpressionVisitor
{
    private readonly Expression _from;
    private readonly Expression _to;
    private readonly string? _fromMemberPath;

    private ReplaceExpressionVisitor(Expression from, Expression to)
    {
        _from = from;
        _to = to;
        _fromMemberPath = from is MemberExpression memberExpression
            ? "/" + string.Join("/", ExpressionPath.GetMemberSegments(memberExpression))
            : null;
    }

    public static Expression Replace(Expression root, Expression from, Expression to) =>
        new ReplaceExpressionVisitor(from, to).Visit(root)!;

    public override Expression? Visit(Expression? node)
    {
        if (node == _from)
        {
            return _to;
        }

        if (_fromMemberPath is not null &&
            node is MemberExpression memberExpression &&
            string.Equals(
                "/" + string.Join("/", ExpressionPath.GetMemberSegments(memberExpression)),
                _fromMemberPath,
                StringComparison.Ordinal))
        {
            return _to;
        }

        return base.Visit(node);
    }
}

internal static class ValueConversion
{
    public static object? Convert(object? value, Type sourceType, Type targetType)
    {
        if (value is null)
        {
            return null;
        }

        var sourceValue = UnwrapJsonElement(value);
        var nonNullableTargetType = Nullable.GetUnderlyingType(targetType) ?? targetType;

        if (nonNullableTargetType.IsInstanceOfType(sourceValue))
        {
            return sourceValue;
        }

        if (nonNullableTargetType.IsEnum)
        {
            if (sourceValue is string enumName)
            {
                return Enum.Parse(nonNullableTargetType, enumName, true);
            }

            var enumValue = System.Convert.ChangeType(sourceValue, Enum.GetUnderlyingType(nonNullableTargetType), CultureInfo.InvariantCulture);
            return Enum.ToObject(nonNullableTargetType, enumValue!);
        }

        if (nonNullableTargetType == typeof(Guid))
        {
            return sourceValue switch
            {
                Guid guid => guid,
                string guidString => Guid.Parse(guidString),
                _ => throw new InvalidCastException($"Cannot convert {sourceValue.GetType().FullName} to Guid.")
            };
        }

        if (nonNullableTargetType == typeof(string))
        {
            return System.Convert.ToString(sourceValue, CultureInfo.InvariantCulture);
        }

        return System.Convert.ChangeType(sourceValue, nonNullableTargetType, CultureInfo.InvariantCulture);
    }

    private static object UnwrapJsonElement(object value)
    {
        var typeName = value.GetType().FullName;
        if (!string.Equals(typeName, "System.Text.Json.JsonElement", StringComparison.Ordinal))
        {
            return value;
        }

        var rawText = (string)value.GetType().GetMethod("GetRawText")!.Invoke(value, Array.Empty<object>())!;
        var valueKind = value.GetType().GetProperty("ValueKind")!.GetValue(value)?.ToString();

        return valueKind switch
        {
            "String" => (string)value.GetType().GetMethod("GetString")!.Invoke(value, Array.Empty<object>())!,
            "Number" => ParseJsonNumber(rawText),
            "True" => true,
            "False" => false,
            "Null" => null!,
            _ => value
        };
    }

    private static object ParseJsonNumber(string rawText)
    {
        if (long.TryParse(rawText, NumberStyles.Integer, CultureInfo.InvariantCulture, out var int64Value))
        {
            return int64Value;
        }

        if (decimal.TryParse(rawText, NumberStyles.Float, CultureInfo.InvariantCulture, out var decimalValue))
        {
            return decimalValue;
        }

        return double.Parse(rawText, CultureInfo.InvariantCulture);
    }
}

internal readonly struct TypePair : IEquatable<TypePair>
{
    public TypePair(Type source, Type target)
    {
        Source = source;
        Target = target;
    }

    public Type Source { get; }

    public Type Target { get; }

    public bool Equals(TypePair other) => Source == other.Source && Target == other.Target;

    public override bool Equals(object? obj) => obj is TypePair other && Equals(other);

    public override int GetHashCode()
    {
        unchecked
        {
            return ((Source?.GetHashCode() ?? 0) * 397) ^ (Target?.GetHashCode() ?? 0);
        }
    }
}
