using Mapper.Demo.Models;

namespace Mapper.Demo.Mapping;

public sealed class DemoProfile : global::Mapper.MapProfile
{
    public DemoProfile()
    {
        CreateMap<Source, Target>()
            .ForMember(target => target.DisplayName, options => options.MapFrom(source => source.Name));
    }
}
