using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace TimeToActDocumentAI.Models;

public record Block : ContentNode
{
    public override string Kind => "block";
    
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Number { get; init; }
    
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Head { get; init; }
    
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public List<ContentNode>? Body { get; init; }
}