namespace TimeToActDocumentAI.Parsing;

/// <summary>
/// Immutable token stream abstraction for parsing operations.
/// Encapsulates token navigation and lookahead capabilities.
/// </summary>
public readonly struct TokenStream
{
    private readonly List<Token> _tokens;
    private readonly int _position;

    public TokenStream(IEnumerable<Token> tokens, int position = 0)
    {
        _tokens = tokens.ToList();
        _position = position;
    }

    public Token Current => _position < _tokens.Count 
        ? _tokens[_position] 
        : new Token(TokenType.EndOfFile, string.Empty, -1);

    public bool IsAtEnd => _position >= _tokens.Count || Current.Type == TokenType.EndOfFile;

    public TokenStream Advance() => new(_tokens, _position + 1);

    public TokenStream AdvanceTo(int newPosition) => new(_tokens, Math.Min(newPosition, _tokens.Count));

    /// <summary>
    /// Looks ahead to check if there are any tokens of the specified type before encountering an end token.
    /// </summary>
    public bool HasTokenAhead(TokenType targetType, TokenType endType)
    {
        var lookaheadPos = _position;
        var depth = 1; // We're already inside the current context

        while (lookaheadPos < _tokens.Count)
        {
            var token = _tokens[lookaheadPos];

            if (token.Type == targetType)
                return true;
            
            if (token.Type == endType)
            {
                depth--;
                if (depth == 0)
                    break;
            }

            lookaheadPos++;
        }

        return false;
    }

    /// <summary>
    /// Consumes tokens while they match the predicate, returning the new stream position.
    /// </summary>
    public (TokenStream stream, List<Token> consumed) ConsumeWhile(Func<Token, bool> predicate)
    {
        var consumed = new List<Token>();
        var currentPos = _position;

        while (currentPos < _tokens.Count && predicate(_tokens[currentPos]))
        {
            consumed.Add(_tokens[currentPos]);
            currentPos++;
        }

        return (new TokenStream(_tokens, currentPos), consumed);
    }
}