using Microsoft.AspNetCore.JsonPatch;
using Microsoft.AspNetCore.JsonPatch.Operations;
using Xunit;

namespace Mapper.Tests;

public sealed class MapperTests
{
    [Fact]
    public void Map_Maps_Add_Replace_Remove_And_Test_For_Same_Named_Members()
    {
        var mapper = new global::Mapper.Mapper(new DefaultProfile());
        var patch = CreatePatch<SourceModel>(
            Operation<SourceModel>("add", "/Name", value: "Alice"),
            Operation<SourceModel>("replace", "/Age", value: 42),
            Operation<SourceModel>("remove", "/Name"),
            Operation<SourceModel>("test", "/Age", value: 42));

        var mapped = mapper.Map<SourceModel, TargetModel>(patch);

        Assert.Collection(
            mapped.Operations,
            operation =>
            {
                Assert.Equal("add", operation.op);
                Assert.Equal("/Name", operation.path);
                Assert.Equal("Alice", operation.value);
            },
            operation =>
            {
                Assert.Equal("replace", operation.op);
                Assert.Equal("/Age", operation.path);
                Assert.Equal(42L, operation.value);
            },
            operation =>
            {
                Assert.Equal("remove", operation.op);
                Assert.Equal("/Name", operation.path);
            },
            operation =>
            {
                Assert.Equal("test", operation.op);
                Assert.Equal("/Age", operation.path);
                Assert.Equal(42L, operation.value);
            });
    }

    [Fact]
    public void Map_Maps_To_Target_Member_With_Different_Name()
    {
        var mapper = new global::Mapper.Mapper(new RenameProfile());
        var patch = CreatePatch<SourceModel>(Operation<SourceModel>("replace", "/Name", value: "Bob"));

        var mapped = mapper.Map<SourceModel, RenamedTargetModel>(patch);

        var operation = Assert.Single(mapped.Operations);
        Assert.Equal("/DisplayName", operation.path);
        Assert.Equal("Bob", operation.value);
    }

    [Fact]
    public void Map_Converts_Value_When_Target_Type_Differs()
    {
        var mapper = new global::Mapper.Mapper(new ComputedProfile());
        var patch = CreatePatch<SourceStatusModel>(Operation<SourceStatusModel>("replace", "/Status", value: "Active"));

        var mapped = mapper.Map<SourceStatusModel, TargetStatusModel>(patch);

        var operation = Assert.Single(mapped.Operations);
        Assert.Equal("/Status", operation.path);
        Assert.Equal(TargetStatus.Active, operation.value);
    }

    [Fact]
    public void Map_Skips_Ignored_Target_Member()
    {
        var mapper = new global::Mapper.Mapper(new IgnoreProfile());
        var patch = CreatePatch<SourceModel>(Operation<SourceModel>("replace", "/Name", value: "Ignored"));

        var mapped = mapper.Map<SourceModel, TargetModel>(patch);

        Assert.Empty(mapped.Operations);
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

    private sealed class DefaultProfile : global::Mapper.MapProfile
    {
        public DefaultProfile()
        {
            CreateMap<SourceModel, TargetModel>();
        }
    }

    private sealed class RenameProfile : global::Mapper.MapProfile
    {
        public RenameProfile()
        {
            CreateMap<SourceModel, RenamedTargetModel>()
                .ForMember(target => target.DisplayName, options => options.MapFrom(source => source.Name));
        }
    }

    private sealed class ComputedProfile : global::Mapper.MapProfile
    {
        public ComputedProfile()
        {
            CreateMap<SourceStatusModel, TargetStatusModel>()
                .ForMember(
                    target => target.Status,
                    options => options.MapFrom<TargetStatus?>(source => string.IsNullOrWhiteSpace(source.Status)
                        ? null
                        : Enum.Parse<TargetStatus>(source.Status, true)));
        }
    }

    private sealed class IgnoreProfile : global::Mapper.MapProfile
    {
        public IgnoreProfile()
        {
            CreateMap<SourceModel, TargetModel>()
                .ForMember(target => target.Name, options => options.Ignore());
        }
    }

    private sealed class SourceModel
    {
        public string? Name { get; set; }

        public int Age { get; set; }
    }

    private sealed class TargetModel
    {
        public string? Name { get; set; }

        public long Age { get; set; }
    }

    private sealed class RenamedTargetModel
    {
        public string? DisplayName { get; set; }
    }

    private sealed class SourceStatusModel
    {
        public string? Status { get; set; }
    }

    private sealed class TargetStatusModel
    {
        public TargetStatus? Status { get; set; }
    }

    private enum TargetStatus
    {
        Unknown = 0,
        Active = 1
    }
}
