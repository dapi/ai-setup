using Microsoft.AspNetCore.JsonPatch;
using Microsoft.AspNetCore.JsonPatch.Operations;
using Xunit;

namespace Mapper.Tests;

public sealed class NestedMapperTests
{
    [Fact]
    public void Map_Maps_Nested_Same_Name_Path_And_From()
    {
        var mapper = new global::Mapper.Mapper(new NestedSameNameProfile());
        var patch = CreatePatch<SourceEnvelope>(
            Operation<SourceEnvelope>("replace", "/Person/Name", from: "/Person/Alias", value: "Alice"));

        var mapped = mapper.Map<SourceEnvelope, TargetEnvelope>(patch);

        var operation = Assert.Single(mapped.Operations);
        Assert.Equal("/Person/Name", operation.path);
        Assert.Equal("/Person/Alias", operation.from);
        Assert.Equal("Alice", operation.value);
    }

    [Fact]
    public void Map_Maps_Path_Deeper_Than_One_Level()
    {
        var mapper = new global::Mapper.Mapper(new DeepNestedProfile());
        var patch = CreatePatch<DeepSourceRoot>(Operation<DeepSourceRoot>("replace", "/Company/Department/Name", value: "Ops"));

        var mapped = mapper.Map<DeepSourceRoot, DeepTargetRoot>(patch);

        var operation = Assert.Single(mapped.Operations);
        Assert.Equal("/Company/Department/Name", operation.path);
        Assert.Equal("Ops", operation.value);
    }

    [Fact]
    public void Map_Uses_Explicit_MapFrom_For_Nested_Rename()
    {
        var mapper = new global::Mapper.Mapper(new NestedRenameProfile());
        var patch = CreatePatch<RenamedSourceEnvelope>(Operation<RenamedSourceEnvelope>("replace", "/Person/Name", value: "Bob"));

        var mapped = mapper.Map<RenamedSourceEnvelope, RenamedTargetEnvelope>(patch);

        var operation = Assert.Single(mapped.Operations);
        Assert.Equal("/Profile/DisplayName", operation.path);
        Assert.Equal("Bob", operation.value);
    }

    [Fact]
    public void Map_Skips_Operation_When_From_Path_Is_Ignored()
    {
        var mapper = new global::Mapper.Mapper(new IgnoreFromProfile());
        var patch = CreatePatch<SourceEnvelope>(
            Operation<SourceEnvelope>("replace", "/Person/Name", from: "/Person/Alias", value: "Alice"));

        var mapped = mapper.Map<SourceEnvelope, IgnoreFromTargetEnvelope>(patch);

        Assert.Empty(mapped.Operations);
    }

    [Fact]
    public void Map_Skips_Operation_When_Top_Level_Target_Field_Is_Ignored()
    {
        var mapper = new global::Mapper.Mapper(new IgnoreTopLevelProfile());
        var patch = CreatePatch<SourceEnvelope>(Operation<SourceEnvelope>("replace", "/Person/Name", value: "Alice"));

        var mapped = mapper.Map<SourceEnvelope, TargetEnvelope>(patch);

        Assert.Empty(mapped.Operations);
    }

    [Fact]
    public void Map_Skips_Operation_When_Nested_Target_Field_Is_Ignored()
    {
        var mapper = new global::Mapper.Mapper(new IgnoreNestedFieldProfile());
        var patch = CreatePatch<SourceEnvelope>(Operation<SourceEnvelope>("replace", "/Person/Name", value: "Alice"));

        var mapped = mapper.Map<SourceEnvelope, TargetEnvelope>(patch);

        Assert.Empty(mapped.Operations);
    }

    [Fact]
    public void Map_Converts_Nested_Value_When_Target_Type_Differs()
    {
        var mapper = new global::Mapper.Mapper(new NestedConversionProfile());
        var patch = CreatePatch<SourceEnvelope>(Operation<SourceEnvelope>("replace", "/Person/Age", value: 42));

        var mapped = mapper.Map<SourceEnvelope, ConversionTargetEnvelope>(patch);

        var operation = Assert.Single(mapped.Operations);
        Assert.Equal("/Person/Age", operation.path);
        Assert.Equal(42L, operation.value);
    }

    [Fact]
    public void Map_Uses_Computed_Value_From_One_Nested_Source_Field()
    {
        var mapper = new global::Mapper.Mapper(new NestedComputedProfile());
        var patch = CreatePatch<SourceEnvelope>(Operation<SourceEnvelope>("replace", "/Person/Age", value: 12));

        var mapped = mapper.Map<SourceEnvelope, ComputedTargetEnvelope>(patch);

        var operation = Assert.Single(mapped.Operations);
        Assert.Equal("/Profile/AgeLabel", operation.path);
        Assert.Equal("12 years", operation.value);
    }

    [Fact]
    public void Map_Prefers_Explicit_MapFrom_Over_Nested_Profile()
    {
        var mapper = new global::Mapper.Mapper(new ExplicitPriorityProfile());
        var patch = CreatePatch<SourceEnvelope>(Operation<SourceEnvelope>("replace", "/Person/Name", value: "Alice"));

        var mapped = mapper.Map<SourceEnvelope, PriorityTargetEnvelope>(patch);

        var operation = Assert.Single(mapped.Operations);
        Assert.Equal("/ContactName", operation.path);
        Assert.Equal("Alice", operation.value);
    }

    [Fact]
    public void Map_Uses_Explicit_Nested_MapFrom_Without_Intermediate_Profile()
    {
        var mapper = new global::Mapper.Mapper(new ExplicitLeafOnlyProfile());
        var patch = CreatePatch<SourceEnvelope>(Operation<SourceEnvelope>("replace", "/Person/Age", value: 7));

        var mapped = mapper.Map<SourceEnvelope, PriorityTargetEnvelope>(patch);

        var operation = Assert.Single(mapped.Operations);
        Assert.Equal("/AgeValue", operation.path);
        Assert.IsType<long>(operation.value);
        Assert.Equal(7L, (long)operation.value!);
    }

    [Fact]
    public void Map_Throws_When_Nested_Profile_Is_Missing()
    {
        var mapper = new global::Mapper.Mapper(new MissingNestedProfile());
        var patch = CreatePatch<SourceEnvelope>(Operation<SourceEnvelope>("replace", "/Person/Name", value: "Alice"));

        var exception = Assert.Throws<InvalidOperationException>(() => mapper.Map<SourceEnvelope, TargetEnvelope>(patch));

        Assert.Contains("/Person/Name", exception.Message);
        Assert.Contains(typeof(SourcePerson).FullName!, exception.Message);
        Assert.Contains(typeof(TargetPerson).FullName!, exception.Message);
    }

    [Fact]
    public void Map_Throws_When_Root_Segment_Does_Not_Match()
    {
        var mapper = new global::Mapper.Mapper(new NestedSameNameProfile());
        var patch = CreatePatch<SourceEnvelope>(Operation<SourceEnvelope>("replace", "/Unknown/Name", value: "Alice"));

        var exception = Assert.Throws<InvalidOperationException>(() => mapper.Map<SourceEnvelope, TargetEnvelope>(patch));

        Assert.Contains("/Unknown/Name", exception.Message);
        Assert.Contains(typeof(SourceEnvelope).FullName!, exception.Message);
        Assert.Contains(typeof(TargetEnvelope).FullName!, exception.Message);
    }

    [Fact]
    public void Map_Throws_When_Leaf_Segment_Does_Not_Match()
    {
        var mapper = new global::Mapper.Mapper(new MissingLeafProfile());
        var patch = CreatePatch<SourceEnvelope>(Operation<SourceEnvelope>("replace", "/Person/Name", value: "Alice"));

        var exception = Assert.Throws<InvalidOperationException>(() => mapper.Map<SourceEnvelope, MissingLeafTargetEnvelope>(patch));

        Assert.Contains("/Person/Name", exception.Message);
        Assert.Contains(typeof(SourcePerson).FullName!, exception.Message);
        Assert.Contains(typeof(MissingLeafTargetPerson).FullName!, exception.Message);
    }

    [Fact]
    public void Map_Throws_When_Remainder_Does_Not_Match()
    {
        var mapper = new global::Mapper.Mapper(new MissingRemainderProfile());
        var patch = CreatePatch<DeepSourceRoot>(Operation<DeepSourceRoot>("replace", "/Company/Department/Name", value: "Ops"));

        var exception = Assert.Throws<InvalidOperationException>(() => mapper.Map<DeepSourceRoot, MissingRemainderTargetRoot>(patch));

        Assert.Contains("/Company/Department/Name", exception.Message);
        Assert.Contains(typeof(DeepSourceCompany).FullName!, exception.Message);
        Assert.Contains(typeof(MissingRemainderTargetCompany).FullName!, exception.Message);
    }

    [Fact]
    public void Mapper_Throws_When_Two_MapFrom_Rules_Conflict_By_Source_Path()
    {
        var exception = Assert.Throws<InvalidOperationException>(() => new global::Mapper.Mapper(new ConflictingNestedMapFromProfile()));

        Assert.Contains("/Person/Name", exception.Message);
        Assert.Contains(typeof(SourceEnvelope).FullName!, exception.Message);
        Assert.Contains(typeof(PriorityTargetEnvelope).FullName!, exception.Message);
    }

    [Fact]
    public void Mapper_Throws_When_Two_Mappings_Exist_For_The_Same_Type_Pair()
    {
        var exception = Assert.Throws<InvalidOperationException>(() => new global::Mapper.Mapper(new DuplicateTypePairProfile()));

        Assert.Contains("Duplicate mapping", exception.Message);
        Assert.Contains(typeof(SourceEnvelope).FullName!, exception.Message);
        Assert.Contains(typeof(TargetEnvelope).FullName!, exception.Message);
    }

    [Fact]
    public void Mapper_Throws_For_Multi_Source_Nested_MapFrom()
    {
        var exception = Assert.Throws<NotSupportedException>(() => new global::Mapper.Mapper(new UnsupportedNestedExpressionProfile()));

        Assert.Contains("exactly one source member", exception.Message);
    }

    [Theory]
    [InlineData("")]
    [InlineData("Person/Name")]
    [InlineData("/Person/")]
    [InlineData("/Person//Name")]
    [InlineData("/Person/0/Name")]
    [InlineData("/Person/~0Name")]
    public void Map_Throws_For_Unsupported_Json_Pointer(string path)
    {
        var mapper = new global::Mapper.Mapper(new IgnoreTopLevelProfile());
        var patch = CreatePatch<SourceEnvelope>(Operation<SourceEnvelope>("replace", path, value: "Alice"));

        var exception = Assert.Throws<NotSupportedException>(() => mapper.Map<SourceEnvelope, TargetEnvelope>(patch));

        Assert.Contains(path, exception.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Map_Validates_From_Before_Ignore()
    {
        var mapper = new global::Mapper.Mapper(new IgnoreFromProfile());
        var patch = CreatePatch<SourceEnvelope>(
            Operation<SourceEnvelope>("replace", "/Person/Name", from: "/Person/0/Alias", value: "Alice"));

        var exception = Assert.Throws<NotSupportedException>(() => mapper.Map<SourceEnvelope, IgnoreFromTargetEnvelope>(patch));

        Assert.Contains("/Person/0/Alias", exception.Message);
    }

    [Fact]
    public void Map_Throws_When_Operation_Targets_Whole_Nested_Object()
    {
        var mapper = new global::Mapper.Mapper(new NestedSameNameProfile());
        var patch = CreatePatch<SourceEnvelope>(Operation<SourceEnvelope>("replace", "/Person", value: new { Name = "Alice" }));

        var exception = Assert.Throws<NotSupportedException>(() => mapper.Map<SourceEnvelope, TargetEnvelope>(patch));

        Assert.Contains("/Person", exception.Message);
        Assert.Contains(typeof(TargetPerson).FullName!, exception.Message);
    }

    [Fact]
    public void Map_Throws_Clear_Error_When_Path_Continues_After_Leaf_Member()
    {
        var mapper = new global::Mapper.Mapper(new NestedConversionProfile());
        var patch = CreatePatch<SourceEnvelope>(Operation<SourceEnvelope>("replace", "/Person/Age/Value", value: 42));

        var exception = Assert.Throws<InvalidOperationException>(() => mapper.Map<SourceEnvelope, ConversionTargetEnvelope>(patch));

        Assert.Contains("/Person/Age/Value", exception.Message);
        Assert.Contains("/Person/Age", exception.Message);
        Assert.Contains("continues after a leaf member", exception.Message);
    }

    private static JsonPatchDocument<TModel> CreatePatch<TModel>(params Operation<TModel>[] operations)
        where TModel : class
    {
        var patch = new JsonPatchDocument<TModel>();
        foreach (var operation in operations)
        {
            patch.Operations.Add(operation);
        }

        return patch;
    }

    private static Operation<TModel> Operation<TModel>(string op, string path, string? from = null, object? value = null)
        where TModel : class =>
        new()
        {
            op = op,
            path = path,
            from = from,
            value = value
        };

    private sealed class NestedSameNameProfile : global::Mapper.MapProfile
    {
        public NestedSameNameProfile()
        {
            CreateMap<SourceEnvelope, TargetEnvelope>();
            CreateMap<SourcePerson, TargetPerson>();
        }
    }

    private sealed class NestedRenameProfile : global::Mapper.MapProfile
    {
        public NestedRenameProfile()
        {
            CreateMap<RenamedSourceEnvelope, RenamedTargetEnvelope>()
                .ForMember(target => target.Profile, options => options.MapFrom(source => source.Person));

            CreateMap<SourcePerson, RenamedTargetPerson>()
                .ForMember(target => target.DisplayName, options => options.MapFrom(source => source.Name));
        }
    }

    private sealed class IgnoreFromProfile : global::Mapper.MapProfile
    {
        public IgnoreFromProfile()
        {
            CreateMap<SourceEnvelope, IgnoreFromTargetEnvelope>();
            CreateMap<SourcePerson, IgnoreFromTargetPerson>()
                .ForMember(target => target.Alias, options => options.Ignore());
        }
    }

    private sealed class IgnoreTopLevelProfile : global::Mapper.MapProfile
    {
        public IgnoreTopLevelProfile()
        {
            CreateMap<SourceEnvelope, TargetEnvelope>()
                .ForMember(target => target.Person, options => options.Ignore());

            CreateMap<SourcePerson, TargetPerson>();
        }
    }

    private sealed class IgnoreNestedFieldProfile : global::Mapper.MapProfile
    {
        public IgnoreNestedFieldProfile()
        {
            CreateMap<SourceEnvelope, TargetEnvelope>();
            CreateMap<SourcePerson, TargetPerson>()
                .ForMember(target => target.Name, options => options.Ignore());
        }
    }

    private sealed class NestedConversionProfile : global::Mapper.MapProfile
    {
        public NestedConversionProfile()
        {
            CreateMap<SourceEnvelope, ConversionTargetEnvelope>();
            CreateMap<SourcePerson, ConversionTargetPerson>();
        }
    }

    private sealed class NestedComputedProfile : global::Mapper.MapProfile
    {
        public NestedComputedProfile()
        {
            CreateMap<SourceEnvelope, ComputedTargetEnvelope>()
                .ForMember(target => target.Profile.AgeLabel, options => options.MapFrom(source => source.Person.Age + " years"));
        }
    }

    private sealed class ExplicitPriorityProfile : global::Mapper.MapProfile
    {
        public ExplicitPriorityProfile()
        {
            CreateMap<SourceEnvelope, PriorityTargetEnvelope>()
                .ForMember(target => target.ContactName, options => options.MapFrom(source => source.Person.Name));

            CreateMap<SourcePerson, TargetPerson>();
        }
    }

    private sealed class ExplicitLeafOnlyProfile : global::Mapper.MapProfile
    {
        public ExplicitLeafOnlyProfile()
        {
            CreateMap<SourceEnvelope, PriorityTargetEnvelope>()
                .ForMember(target => target.AgeValue, options => options.MapFrom(source => source.Person.Age));
        }
    }

    private sealed class MissingNestedProfile : global::Mapper.MapProfile
    {
        public MissingNestedProfile()
        {
            CreateMap<SourceEnvelope, TargetEnvelope>();
        }
    }

    private sealed class MissingLeafProfile : global::Mapper.MapProfile
    {
        public MissingLeafProfile()
        {
            CreateMap<SourceEnvelope, MissingLeafTargetEnvelope>();
            CreateMap<SourcePerson, MissingLeafTargetPerson>();
        }
    }

    private sealed class DeepNestedProfile : global::Mapper.MapProfile
    {
        public DeepNestedProfile()
        {
            CreateMap<DeepSourceRoot, DeepTargetRoot>();
            CreateMap<DeepSourceCompany, DeepTargetCompany>();
            CreateMap<DeepSourceDepartment, DeepTargetDepartment>();
        }
    }

    private sealed class MissingRemainderProfile : global::Mapper.MapProfile
    {
        public MissingRemainderProfile()
        {
            CreateMap<DeepSourceRoot, MissingRemainderTargetRoot>();
            CreateMap<DeepSourceCompany, MissingRemainderTargetCompany>();
        }
    }

    private sealed class ConflictingNestedMapFromProfile : global::Mapper.MapProfile
    {
        public ConflictingNestedMapFromProfile()
        {
            CreateMap<SourceEnvelope, PriorityTargetEnvelope>()
                .ForMember(target => target.ContactName, options => options.MapFrom(source => source.Person.Name))
                .ForMember(target => target.SecondaryName, options => options.MapFrom(source => source.Person.Name));
        }
    }

    private sealed class UnsupportedNestedExpressionProfile : global::Mapper.MapProfile
    {
        public UnsupportedNestedExpressionProfile()
        {
            CreateMap<SourceEnvelope, PriorityTargetEnvelope>()
                .ForMember(target => target.ContactName, options => options.MapFrom(source => source.Person.Name + source.Person.Alias));
        }
    }

    private sealed class DuplicateTypePairProfile : global::Mapper.MapProfile
    {
        public DuplicateTypePairProfile()
        {
            CreateMap<SourceEnvelope, TargetEnvelope>();
            CreateMap<SourceEnvelope, TargetEnvelope>();
        }
    }

    private sealed class SourceEnvelope
    {
        public SourcePerson Person { get; set; } = new();
    }

    private sealed class TargetEnvelope
    {
        public TargetPerson Person { get; set; } = new();
    }

    private sealed class IgnoreFromTargetEnvelope
    {
        public IgnoreFromTargetPerson Person { get; set; } = new();
    }

    private sealed class ConversionTargetEnvelope
    {
        public ConversionTargetPerson Person { get; set; } = new();
    }

    private sealed class ComputedTargetEnvelope
    {
        public ComputedTargetPerson Profile { get; set; } = new();
    }

    private sealed class PriorityTargetEnvelope
    {
        public string? ContactName { get; set; }

        public long AgeValue { get; set; }

        public string? SecondaryName { get; set; }
    }

    private sealed class RenamedSourceEnvelope
    {
        public SourcePerson Person { get; set; } = new();
    }

    private sealed class RenamedTargetEnvelope
    {
        public RenamedTargetPerson Profile { get; set; } = new();
    }

    private sealed class MissingLeafTargetEnvelope
    {
        public MissingLeafTargetPerson Person { get; set; } = new();
    }

    private sealed class SourcePerson
    {
        public string? Name { get; set; }

        public string? Alias { get; set; }

        public int Age { get; set; }
    }

    private sealed class TargetPerson
    {
        public string? Name { get; set; }

        public string? Alias { get; set; }
    }

    private sealed class IgnoreFromTargetPerson
    {
        public string? Name { get; set; }

        public string? Alias { get; set; }
    }

    private sealed class ConversionTargetPerson
    {
        public long Age { get; set; }
    }

    private sealed class ComputedTargetPerson
    {
        public string? AgeLabel { get; set; }
    }

    private sealed class RenamedTargetPerson
    {
        public string? DisplayName { get; set; }
    }

    private sealed class MissingLeafTargetPerson
    {
        public string? Alias { get; set; }
    }

    private sealed class DeepSourceRoot
    {
        public DeepSourceCompany Company { get; set; } = new();
    }

    private sealed class DeepTargetRoot
    {
        public DeepTargetCompany Company { get; set; } = new();
    }

    private sealed class MissingRemainderTargetRoot
    {
        public MissingRemainderTargetCompany Company { get; set; } = new();
    }

    private sealed class DeepSourceCompany
    {
        public DeepSourceDepartment Department { get; set; } = new();
    }

    private sealed class DeepTargetCompany
    {
        public DeepTargetDepartment Department { get; set; } = new();
    }

    private sealed class MissingRemainderTargetCompany
    {
        public MissingRemainderTargetDepartment Office { get; set; } = new();
    }

    private sealed class DeepSourceDepartment
    {
        public string? Name { get; set; }
    }

    private sealed class DeepTargetDepartment
    {
        public string? Name { get; set; }
    }

    private sealed class MissingRemainderTargetDepartment
    {
        public string? Name { get; set; }
    }
}
