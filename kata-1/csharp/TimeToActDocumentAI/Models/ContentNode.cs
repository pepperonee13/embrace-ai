using System.Text.Json.Serialization;

namespace TimeToActDocumentAI.Models;

public abstract record ContentNode
{
    public abstract string Kind { get; }
}

public record TextContent(string Value) : ContentNode
{
    public override string Kind => "text";
}