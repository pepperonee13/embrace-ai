using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace TimeToActDocumentAI.Models;

public record Block : ContentNode
{
    public override string Kind => "block";
    
    [JsonPropertyName("number")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Number { get; init; }
    
    [JsonPropertyName("head")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Head { get; init; }
    
    [JsonPropertyName("body")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public List<ContentNode> Body { get; init; } = [];
}