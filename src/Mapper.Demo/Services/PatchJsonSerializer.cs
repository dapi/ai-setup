using Microsoft.AspNetCore.JsonPatch;
using Microsoft.AspNetCore.JsonPatch.Operations;
using Newtonsoft.Json;

namespace Mapper.Demo.Services;

public static class PatchJsonSerializer
{
    private static readonly JsonSerializerSettings SerializerSettings = new()
    {
        Formatting = Formatting.Indented
    };

    public static JsonPatchDocument<TModel> Deserialize<TModel>(string json)
        where TModel : class
    {
        var operations = JsonConvert.DeserializeObject<List<Operation<TModel>>>(json, SerializerSettings);
        if (operations is null)
        {
            throw new JsonSerializationException("JSON Patch payload cannot be empty.");
        }

        var patch = new JsonPatchDocument<TModel>();
        foreach (var operation in operations)
        {
            patch.Operations.Add(operation);
        }

        return patch;
    }

    public static string Serialize<TModel>(JsonPatchDocument<TModel> patch)
        where TModel : class =>
        JsonConvert.SerializeObject(patch.Operations, SerializerSettings);
}
