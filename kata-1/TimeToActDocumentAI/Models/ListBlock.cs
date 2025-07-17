using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace TimeToActDocumentAI.Models;

public record ListBlock : ContentNode
{
    public override string Kind => "list";
    
    [JsonPropertyName("items")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public List<Block> Items { get; init; } = [];
}