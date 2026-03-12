namespace TimeToActDocumentAI.Parsing;

public enum TokenType
{
    Text,
    HeadStart,
    HeadEnd,
    BlockStart,
    BlockEnd,
    ListStart,
    ListEnd,
    DictStart,
    DictEnd,
    EndOfFile
}

public record Token(TokenType Type, string Value, int Position);

public record TagToken(TokenType Type, string Value, int Position, Dictionary<string, string> Attributes) : Token(Type, Value, Position);