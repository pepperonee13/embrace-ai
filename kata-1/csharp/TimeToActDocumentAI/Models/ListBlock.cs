using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace TimeToActDocumentAI.Models;

public record ListBlock : ContentNode
{
    public override string Kind => "list";
    
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public List<Block> Items { get; init; } = [];
}