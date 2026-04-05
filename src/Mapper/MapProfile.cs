using System.Linq.Expressions;
using System.Reflection;

namespace Mapper;

public abstract class MapProfile
{
    private readonly List<IMapDefinition> _definitions = new();

    internal IReadOnlyList<IMapDefinition> Definitions => _definitions;

    protected MapBuilder<TSource, TTarget> CreateMap<TSource, TTarget>()
        where TSource : class
        where TTarget : class
    {
        var definition = new MapDefinition<TSource, TTarget>();
        _definitions.Add(definition);
        return new MapBuilder<TSource, TTarget>(definition);
    }
}

public sealed class MapBuilder<TSource, TTarget>
    where TSource : class
    where TTarget : class
{
    private readonly MapDefinition<TSource, TTarget> _definition;

    internal MapBuilder(MapDefinition<TSource, TTarget> definition)
    {
        _definition = definition;
    }

    public MapBuilder<TSource, TTarget> ForMember<TMember>(
        Expression<Func<TTarget, TMember>> targetMember,
        Action<MemberOptionsBuilder<TSource, TTarget, TMember>> configure)
    {
        if (targetMember is null)
        {
            throw new ArgumentNullException(nameof(targetMember));
        }

        if (configure is null)
        {
            throw new ArgumentNullException(nameof(configure));
        }

        var targetPath = ExpressionPath.GetPath(targetMember);
        var optionsBuilder = new MemberOptionsBuilder<TSource, TTarget, TMember>(targetPath);
        configure(optionsBuilder);
        _definition.MemberConfigurations[targetPath] = optionsBuilder.Build();

        return this;
    }
}

public sealed class MemberOptionsBuilder<TSource, TTarget, TMember>
{
    private readonly string _targetPath;
    private readonly Type _targetMemberType;
    private MemberConfiguration? _configuration;

    internal MemberOptionsBuilder(string targetPath)
    {
        _targetPath = targetPath;
        _targetMemberType = typeof(TMember);
    }

    public void Ignore()
    {
        _configuration = MemberConfiguration.CreateIgnored(_targetPath, _targetMemberType);
    }

    public void MapFrom<TSourceMember>(Expression<Func<TSource, TSourceMember>> sourceMember)
    {
        if (sourceMember is null)
        {
            throw new ArgumentNullException(nameof(sourceMember));
        }

        _configuration = MemberConfiguration.ForMapFrom(_targetPath, _targetMemberType, sourceMember);
    }

    internal MemberConfiguration Build() => _configuration ?? MemberConfiguration.Direct(_targetPath, _targetMemberType);
}

internal interface IMapDefinition
{
    Type SourceType { get; }
    Type TargetType { get; }
    ICompiledMap Compile(Func<TypePair, ICompiledMap?> compiledMapProvider);
}

internal sealed class MapDefinition<TSource, TTarget> : IMapDefinition
    where TSource : class
    where TTarget : class
{
    public Dictionary<string, MemberConfiguration> MemberConfigurations { get; } = new(StringComparer.OrdinalIgnoreCase);

    public Type SourceType => typeof(TSource);

    public Type TargetType => typeof(TTarget);

    public ICompiledMap Compile(Func<TypePair, ICompiledMap?> compiledMapProvider) =>
        PatchMapCompiler.Compile<TSource, TTarget>(MemberConfigurations, compiledMapProvider);
}

internal sealed class MemberConfiguration
{
    private MemberConfiguration(string targetPath, Type targetMemberType, bool ignored, LambdaExpression? sourceExpression)
    {
        TargetPath = targetPath;
        TargetMemberType = targetMemberType;
        Ignored = ignored;
        SourceExpression = sourceExpression;
    }

    public string TargetPath { get; }

    public Type TargetMemberType { get; }

    public bool Ignored { get; }

    public LambdaExpression? SourceExpression { get; }

    public static MemberConfiguration Direct(string targetPath, Type targetMemberType) =>
        new(targetPath, targetMemberType, false, null);

    public static MemberConfiguration CreateIgnored(string targetPath, Type targetMemberType) =>
        new(targetPath, targetMemberType, true, null);

    public static MemberConfiguration ForMapFrom(string targetPath, Type targetMemberType, LambdaExpression sourceExpression) =>
        new(targetPath, targetMemberType, false, sourceExpression);
}

internal static class ExpressionPath
{
    public static string GetPath(LambdaExpression expression)
    {
        var segments = GetMemberSegments(expression.Body);
        return "/" + string.Join("/", segments);
    }

    public static IReadOnlyList<string> GetMemberSegments(Expression expression)
    {
        var segments = new Stack<string>();
        var current = UnwrapConvert(expression);

        while (current is MemberExpression memberExpression)
        {
            if (memberExpression.Member is not PropertyInfo)
            {
                throw new NotSupportedException("Only property access expressions are supported.");
            }

            segments.Push(memberExpression.Member.Name);
            current = UnwrapConvert(memberExpression.Expression);
        }

        if (current is not ParameterExpression)
        {
            throw new NotSupportedException("Only direct property access expressions are supported.");
        }

        return segments.ToArray();
    }

    public static Expression UnwrapConvert(Expression? expression)
    {
        while (expression is UnaryExpression unaryExpression &&
               (unaryExpression.NodeType == ExpressionType.Convert ||
                unaryExpression.NodeType == ExpressionType.ConvertChecked))
        {
            expression = unaryExpression.Operand;
        }

        return expression ?? throw new ArgumentNullException(nameof(expression));
    }
}
