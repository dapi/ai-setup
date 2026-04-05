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

        _compiledMaps = new ConcurrentDictionary<TypePair, ICompiledMap>();
        foreach (var definition in profiles.SelectMany(static profile => profile.Definitions))
        {
            var typePair = new TypePair(definition.SourceType, definition.TargetType);
            var compiledMap = definition.Compile(ResolveCompiledMap);
            if (!_compiledMaps.TryAdd(typePair, compiledMap))
            {
                throw new InvalidOperationException(
                    $"Duplicate mapping for {definition.SourceType.FullName} -> {definition.TargetType.FullName}.");
            }
        }
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

    private ICompiledMap? ResolveCompiledMap(TypePair typePair) =>
        _compiledMaps.TryGetValue(typePair, out var compiledMap) ? compiledMap : null;
}

internal interface ICompiledMap
{
    object? MapOperation(Operation operation);

    PathResolution ResolvePath(string path, string originalPath);
}

internal sealed class CompiledMap<TSource, TTarget> : ICompiledMap
    where TSource : class
    where TTarget : class
{
    private readonly IReadOnlyDictionary<string, MemberRule> _explicitRules;
    private readonly IReadOnlyDictionary<string, PropertyMap> _defaultPropertyMaps;
    private readonly IReadOnlyCollection<string> _ignoredTargetPaths;
    private readonly Func<TypePair, ICompiledMap?> _compiledMapProvider;
    private readonly TypePair _typePair;

    public CompiledMap(
        IReadOnlyDictionary<string, MemberRule> explicitRules,
        IReadOnlyDictionary<string, PropertyMap> defaultPropertyMaps,
        IReadOnlyCollection<string> ignoredTargetPaths,
        Func<TypePair, ICompiledMap?> compiledMapProvider)
    {
        _explicitRules = explicitRules;
        _defaultPropertyMaps = defaultPropertyMaps;
        _ignoredTargetPaths = ignoredTargetPaths;
        _compiledMapProvider = compiledMapProvider;
        _typePair = new TypePair(typeof(TSource), typeof(TTarget));
    }

    public object? MapOperation(Operation operation)
    {
        if (operation is null)
        {
            throw new ArgumentNullException(nameof(operation));
        }

        var pathResolution = ResolvePath(operation.path, operation.path);
        if (pathResolution.Ignored)
        {
            return null;
        }

        var fromResolution = string.IsNullOrWhiteSpace(operation.from) ? null : ResolvePath(operation.from, operation.from);
        if (fromResolution?.Ignored == true)
        {
            return null;
        }

        return new Operation<TTarget>
        {
            op = operation.op,
            path = pathResolution.TargetPath,
            from = fromResolution?.TargetPath ?? operation.from,
            value = ConvertValueIfNeeded(operation.op, operation.value, pathResolution)
        };
    }

    public PathResolution ResolvePath(string path, string originalPath)
    {
        var segments = JsonPointer.ValidateAndSplit(path);
        return ResolveSegments(segments, path, originalPath);
    }

    private PathResolution ResolveSegments(IReadOnlyList<string> segments, string relativePath, string originalPath)
    {
        if (TryResolveExplicitRule(segments, out var explicitRule, out var consumedSegments))
        {
            if (IsIgnored(explicitRule.TargetPath))
            {
                return PathResolution.CreateIgnored(originalPath, explicitRule.TargetPath, explicitRule.SourceType, explicitRule.TargetType);
            }

            if (consumedSegments == segments.Count)
            {
                EnsureLeafSupported(explicitRule.TargetType, originalPath);
                return PathResolution.Resolved(
                    originalPath,
                    explicitRule.TargetPath,
                    explicitRule.Convert,
                    explicitRule.SourceType,
                    explicitRule.TargetType);
            }

            EnsurePathCanContinue(
                explicitRule.SourcePath,
                explicitRule.TargetPath,
                explicitRule.SourceType,
                explicitRule.TargetType,
                originalPath);

            return ResolveNested(
                explicitRule.TargetPath,
                explicitRule.SourceType,
                explicitRule.TargetType,
                segments.Skip(consumedSegments).ToArray(),
                originalPath);
        }

        var segment = segments[0];
        if (!_defaultPropertyMaps.TryGetValue(segment, out var propertyMap))
        {
            throw CreatePathResolutionException(originalPath, $"Source path '{originalPath}' could not be resolved.");
        }

        if (IsIgnored(propertyMap.TargetPath))
        {
            return PathResolution.CreateIgnored(originalPath, propertyMap.TargetPath, propertyMap.SourceType, propertyMap.TargetType);
        }

        if (segments.Count == 1)
        {
            EnsureLeafSupported(propertyMap.TargetType, originalPath);
            return PathResolution.Resolved(
                originalPath,
                propertyMap.TargetPath,
                propertyMap.Convert,
                propertyMap.SourceType,
                propertyMap.TargetType);
        }

        EnsurePathCanContinue(
            propertyMap.SourcePath,
            propertyMap.TargetPath,
            propertyMap.SourceType,
            propertyMap.TargetType,
            originalPath);

        return ResolveNested(
            propertyMap.TargetPath,
            propertyMap.SourceType,
            propertyMap.TargetType,
            segments.Skip(1).ToArray(),
            originalPath);
    }

    private PathResolution ResolveNested(
        string resolvedTargetPrefix,
        Type sourceType,
        Type targetType,
        IReadOnlyList<string> remainderSegments,
        string originalPath)
    {
        var nestedTypePair = new TypePair(sourceType, targetType);
        var nestedMap = _compiledMapProvider(nestedTypePair);
        if (nestedMap is null)
        {
            throw new InvalidOperationException(
                $"Mapping from {sourceType.FullName} to {targetType.FullName} is not configured while resolving path '{originalPath}'.");
        }

        var remainderPath = JsonPointer.Combine(remainderSegments);
        var nestedResolution = nestedMap.ResolvePath(remainderPath, originalPath);
        if (nestedResolution.Ignored)
        {
            return nestedResolution;
        }

        return PathResolution.Resolved(
            originalPath,
            JsonPointer.Combine(resolvedTargetPrefix, nestedResolution.TargetPath),
            nestedResolution.ValueConverter,
            nestedResolution.SourceType,
            nestedResolution.TargetType);
    }

    private bool TryResolveExplicitRule(
        IReadOnlyList<string> segments,
        out MemberRule rule,
        out int consumedSegments)
    {
        for (var length = segments.Count; length >= 1; length--)
        {
            var candidatePath = JsonPointer.Combine(segments.Take(length));
            if (_explicitRules.TryGetValue(candidatePath, out rule!))
            {
                consumedSegments = length;
                return true;
            }
        }

        rule = null!;
        consumedSegments = 0;
        return false;
    }

    private bool IsIgnored(string targetPath)
    {
        foreach (var ignoredTargetPath in _ignoredTargetPaths)
        {
            if (string.Equals(targetPath, ignoredTargetPath, StringComparison.OrdinalIgnoreCase) ||
                targetPath.StartsWith(ignoredTargetPath + "/", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }

    private void EnsureLeafSupported(Type targetType, string originalPath)
    {
        if (PathLeafTypes.IsSupported(targetType))
        {
            return;
        }

        throw new NotSupportedException(
            $"Path '{originalPath}' resolves to non-leaf target type {targetType.FullName} for mapping {_typePair.Source.FullName} -> {_typePair.Target.FullName}.");
    }

    private void EnsurePathCanContinue(
        string sourcePath,
        string targetPath,
        Type sourceType,
        Type targetType,
        string originalPath)
    {
        if (!PathLeafTypes.IsSupported(sourceType) && !PathLeafTypes.IsSupported(targetType))
        {
            return;
        }

        throw CreatePathResolutionException(
            originalPath,
            $"Source path '{originalPath}' cannot be resolved because '{sourcePath}' maps to '{targetPath}', and the path continues after a leaf member.");
    }

    private InvalidOperationException CreatePathResolutionException(string originalPath, string message) =>
        new($"{message} Mapping pair: {_typePair.Source.FullName} -> {_typePair.Target.FullName}.");

    private static object? ConvertValueIfNeeded(string op, object? value, PathResolution resolution)
    {
        if (value is null)
        {
            return null;
        }

        if (!OperationRequiresValue(op))
        {
            return value;
        }

        return resolution.ValueConverter is null ? value : resolution.ValueConverter(value);
    }

    private static bool OperationRequiresValue(string op) =>
        string.Equals(op, "add", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(op, "replace", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(op, "test", StringComparison.OrdinalIgnoreCase);
}

internal sealed class PropertyMap
{
    public string SourcePath { get; set; } = string.Empty;
    public string TargetPath { get; set; } = string.Empty;
    public Type SourceType { get; set; } = typeof(object);
    public Type TargetType { get; set; } = typeof(object);
    public Func<object?, object?> Convert { get; set; } = static value => value;
}

internal sealed class MemberRule
{
    public string SourcePath { get; set; } = string.Empty;
    public string TargetPath { get; set; } = string.Empty;
    public Type SourceType { get; set; } = typeof(object);
    public Type TargetType { get; set; } = typeof(object);
    public Func<object?, object?>? Convert { get; set; }
}

internal sealed class PathResolution
{
    private PathResolution(
        bool ignored,
        string sourcePath,
        string targetPath,
        Func<object?, object?>? valueConverter,
        Type sourceType,
        Type targetType)
    {
        Ignored = ignored;
        SourcePath = sourcePath;
        TargetPath = targetPath;
        ValueConverter = valueConverter;
        SourceType = sourceType;
        TargetType = targetType;
    }

    public bool Ignored { get; }

    public string SourcePath { get; }

    public string TargetPath { get; }

    public Func<object?, object?>? ValueConverter { get; }

    public Type SourceType { get; }

    public Type TargetType { get; }

    public static PathResolution Resolved(
        string sourcePath,
        string targetPath,
        Func<object?, object?>? valueConverter,
        Type sourceType,
        Type targetType) =>
        new(false, sourcePath, targetPath, valueConverter, sourceType, targetType);

    public static PathResolution CreateIgnored(string sourcePath, string targetPath, Type sourceType, Type targetType) =>
        new(true, sourcePath, targetPath, null, sourceType, targetType);
}

internal static class PatchMapCompiler
{
    public static ICompiledMap Compile<TSource, TTarget>(
        IReadOnlyDictionary<string, MemberConfiguration> memberConfigurations,
        Func<TypePair, ICompiledMap?> compiledMapProvider)
        where TSource : class
        where TTarget : class
    {
        var explicitRules = new Dictionary<string, MemberRule>(StringComparer.OrdinalIgnoreCase);
        var ignoredTargetPaths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var configuration in memberConfigurations.Values)
        {
            ApplyConfiguration<TSource, TTarget>(explicitRules, ignoredTargetPaths, configuration);
        }

        return new CompiledMap<TSource, TTarget>(
            explicitRules,
            BuildDefaultRules<TSource, TTarget>(),
            ignoredTargetPaths,
            compiledMapProvider);
    }

    private static Dictionary<string, PropertyMap> BuildDefaultRules<TSource, TTarget>()
        where TSource : class
        where TTarget : class
    {
        var targetProperties = typeof(TTarget)
            .GetProperties(BindingFlags.Instance | BindingFlags.Public)
            .Where(static property => property.CanWrite)
            .ToDictionary(static property => property.Name, StringComparer.OrdinalIgnoreCase);

        var rules = new Dictionary<string, PropertyMap>(StringComparer.OrdinalIgnoreCase);

        foreach (var sourceProperty in typeof(TSource).GetProperties(BindingFlags.Instance | BindingFlags.Public))
        {
            if (!sourceProperty.CanRead || !targetProperties.TryGetValue(sourceProperty.Name, out var targetProperty))
            {
                continue;
            }

            rules[sourceProperty.Name] = new PropertyMap
            {
                SourcePath = "/" + sourceProperty.Name,
                TargetPath = "/" + targetProperty.Name,
                SourceType = sourceProperty.PropertyType,
                TargetType = targetProperty.PropertyType,
                Convert = BuildValueConverter(sourceProperty.PropertyType, targetProperty.PropertyType)
            };
        }

        return rules;
    }

    private static void ApplyConfiguration<TSource, TTarget>(
        IDictionary<string, MemberRule> rules,
        ISet<string> ignoredTargetPaths,
        MemberConfiguration configuration)
        where TSource : class
        where TTarget : class
    {
        if (configuration.Ignored)
        {
            ignoredTargetPaths.Add(configuration.TargetPath);
            return;
        }

        if (configuration.SourceExpression is null)
        {
            return;
        }

        var sourceDescriptor = SourceMemberDescriptor.Create<TSource>(configuration.SourceExpression, configuration.TargetMemberType);
        if (rules.TryGetValue(sourceDescriptor.Path, out var existingRule) &&
            !string.Equals(existingRule.TargetPath, configuration.TargetPath, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                $"Conflicting MapFrom configuration for source path '{sourceDescriptor.Path}' in mapping {typeof(TSource).FullName} -> {typeof(TTarget).FullName}.");
        }

        rules[sourceDescriptor.Path] = new MemberRule
        {
            SourcePath = sourceDescriptor.Path,
            TargetPath = configuration.TargetPath,
            SourceType = sourceDescriptor.MemberType,
            TargetType = sourceDescriptor.TargetMemberType,
            Convert = sourceDescriptor.ValueConverter
        };
    }

    private static Func<object?, object?> BuildValueConverter(Type sourceType, Type targetType) =>
        value => ValueConversion.Convert(value, sourceType, targetType);
}

internal sealed class SourceMemberDescriptor
{
    private SourceMemberDescriptor(
        string path,
        Func<object?, object?> valueConverter,
        Type memberType,
        Type targetMemberType)
    {
        Path = path;
        ValueConverter = valueConverter;
        MemberType = memberType;
        TargetMemberType = targetMemberType;
    }

    public string Path { get; }

    public Func<object?, object?> ValueConverter { get; }

    public Type MemberType { get; }

    public Type TargetMemberType { get; }

    public static SourceMemberDescriptor Create<TSource>(LambdaExpression expression, Type targetMemberType)
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
        Func<object?, object?> converter = value => ValueConversion.Convert(compiled(value), expression.ReturnType, targetMemberType);
        return new SourceMemberDescriptor(sourcePath, converter, memberAccess.MemberType, targetMemberType);
    }
}

internal sealed class SingleMemberAccessVisitor : ExpressionVisitor
{
    private readonly ParameterExpression _rootParameter;
    private readonly Dictionary<string, MemberAccessMatch> _matches = new(StringComparer.Ordinal);

    private SingleMemberAccessVisitor(ParameterExpression rootParameter)
    {
        _rootParameter = rootParameter;
    }

    public static MemberAccessMatch? Find(Expression expression, ParameterExpression rootParameter)
    {
        var visitor = new SingleMemberAccessVisitor(rootParameter);
        visitor.Visit(expression);
        return visitor.GetSingleMatch();
    }

    protected override Expression VisitMember(MemberExpression node)
    {
        var unwrapped = ExpressionPath.UnwrapConvert(node.Expression);
        if (DependsOnRoot(unwrapped) && !PathLeafTypes.IsSupported(unwrapped.Type))
        {
            var pathSegments = ExpressionPath.GetMemberSegments(node);
            var match = new MemberAccessMatch(node, pathSegments, node.Type);
            _matches[match.Path] = match;
        }

        return base.VisitMember(node);
    }

    private MemberAccessMatch? GetSingleMatch()
    {
        if (_matches.Count == 0)
        {
            return null;
        }

        var maximalMatches = _matches.Values
            .Where(candidate => !_matches.Keys.Any(other =>
                !string.Equals(other, candidate.Path, StringComparison.Ordinal) &&
                other.StartsWith(candidate.Path + "/", StringComparison.Ordinal)))
            .ToArray();

        return maximalMatches.Length == 1 ? maximalMatches[0] : null;
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

internal static class JsonPointer
{
    public static string[] ValidateAndSplit(string? path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            throw new NotSupportedException("Json Pointer path must not be empty.");
        }

        if (!path.StartsWith("/", StringComparison.Ordinal))
        {
            throw new NotSupportedException($"Json Pointer path '{path}' must start with '/'.");
        }

        var segments = path.Substring(1).Split('/');
        if (segments.Length == 0 || segments.Any(static segment => segment.Length == 0))
        {
            throw new NotSupportedException($"Json Pointer path '{path}' contains empty segments.");
        }

        foreach (var segment in segments)
        {
            if (segment.Contains('~'))
            {
                throw new NotSupportedException($"Json Pointer path '{path}' contains unsupported escape sequences.");
            }

            if (segment == "-" || segment.All(char.IsDigit))
            {
                throw new NotSupportedException($"Json Pointer path '{path}' contains unsupported array segments.");
            }
        }

        return segments;
    }

    public static string Combine(IEnumerable<string> segments) => "/" + string.Join("/", segments);

    public static string Combine(string prefix, string suffix) => prefix + suffix;
}

internal static class PathLeafTypes
{
    public static bool IsSupported(Type type)
    {
        var effectiveType = Nullable.GetUnderlyingType(type) ?? type;
        if (effectiveType == typeof(bool) ||
            effectiveType == typeof(string) ||
            effectiveType == typeof(Guid) ||
            effectiveType == typeof(DateTime) ||
            effectiveType == typeof(DateTimeOffset) ||
            effectiveType == typeof(TimeSpan) ||
            effectiveType.IsEnum)
        {
            return true;
        }

        return Type.GetTypeCode(effectiveType) switch
        {
            TypeCode.Byte => true,
            TypeCode.SByte => true,
            TypeCode.Int16 => true,
            TypeCode.UInt16 => true,
            TypeCode.Int32 => true,
            TypeCode.UInt32 => true,
            TypeCode.Int64 => true,
            TypeCode.UInt64 => true,
            TypeCode.Single => true,
            TypeCode.Double => true,
            TypeCode.Decimal => true,
            _ => false
        };
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
