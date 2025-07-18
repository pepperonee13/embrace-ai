using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace TimeToActDocumentAI.Models;

public record Dictionary : ContentNode
{
    public override string Kind => "dict";
    
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public Dictionary<string, string> Items { get; init; } = [];
}