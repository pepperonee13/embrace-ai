using System.Text.Json;
using System.Text.Json.Serialization;
using TimeToActDocumentAI.Models;
using TimeToActDocumentAI.Parsing;

namespace TimeToActDocumentAI;

public class DocumentAI
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        Converters = { new ContentNodeJsonConverter() }
    };

    public static Block ParseDocument(string input)
    {
        var lexer = new Lexer(input);
        var tokens = lexer.Tokenize();
        var parser = new DocumentParser(tokens);
        return parser.Parse();
    }

    public static string ToJson(Block document)
    {
        return JsonSerializer.Serialize(document, JsonOptions);
    }

    public static Block FromJson(string json)
    {
        return JsonSerializer.Deserialize<Block>(json, JsonOptions) ?? new Block();
    }
}

public class ContentNodeJsonConverter : JsonConverter<ContentNode>
{
    public override ContentNode Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        using var document = JsonDocument.ParseValue(ref reader);
        var root = document.RootElement;

        if (root.ValueKind == JsonValueKind.String)
        {
            return new TextContent(root.GetString() ?? string.Empty);
        }

        if (root.ValueKind == JsonValueKind.Object && root.TryGetProperty("kind", out var kindProperty))
        {
            var kind = kindProperty.GetString();
            return kind switch
            {
                "block" => JsonSerializer.Deserialize<Block>(root.GetRawText(), options) ?? new Block(),
                "list" => JsonSerializer.Deserialize<ListBlock>(root.GetRawText(), options) ?? new ListBlock(),
                "dict" => JsonSerializer.Deserialize<Models.Dictionary>(root.GetRawText(), options) ?? new Models.Dictionary(),
                _ => new TextContent(root.GetRawText())
            };
        }

        return new TextContent(root.GetRawText());
    }

    public override void Write(Utf8JsonWriter writer, ContentNode value, JsonSerializerOptions options)
    {
        switch (value)
        {
            case TextContent textContent:
                writer.WriteStringValue(textContent.Value);
                break;
            case Block block:
                JsonSerializer.Serialize(writer, block, options);
                break;
            case ListBlock listBlock:
                JsonSerializer.Serialize(writer, listBlock, options);
                break;
            case Models.Dictionary dict:
                JsonSerializer.Serialize(writer, dict, options);
                break;
            default:
                writer.WriteStringValue(value.ToString());
                break;
        }
    }
}