using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Mapper.Demo.Models;
using Mapper.Demo.Services;
using Newtonsoft.Json;
using PatchMapper = Mapper.Mapper;

namespace MapperDemo.Pages;

public sealed class IndexModel : PageModel
{
    private const string DefaultPatch = """
        [
          { "op": "replace", "path": "/Name", "value": "Alice" },
          { "op": "replace", "path": "/Age", "value": 42 }
        ]
        """;

    private readonly PatchMapper _mapper;

    public IndexModel(PatchMapper mapper)
    {
        _mapper = mapper;
    }

    [BindProperty]
    public string PatchInput { get; set; } = DefaultPatch;

    public string? ResultJson { get; private set; }

    public string? ErrorMessage { get; private set; }

    public IReadOnlyList<string> SourceFields => DemoMetadata.Describe<Source>();

    public IReadOnlyList<string> TargetFields => DemoMetadata.Describe<Target>();

    public void OnGet()
    {
    }

    public void OnPost()
    {
        PatchInput ??= string.Empty;

        if (string.IsNullOrWhiteSpace(PatchInput))
        {
            ErrorMessage = "Json Patch is required.";
            return;
        }

        try
        {
            var sourcePatch = PatchJsonSerializer.Deserialize<Source>(PatchInput);
            var targetPatch = _mapper.Map<Source, Target>(sourcePatch);
            ResultJson = PatchJsonSerializer.Serialize(targetPatch);
        }
        catch (JsonException exception)
        {
            ErrorMessage = $"Invalid JSON Patch: {exception.Message}";
        }
        catch (InvalidOperationException exception)
        {
            ErrorMessage = $"Mapping failed: {exception.Message}";
        }
    }
}
