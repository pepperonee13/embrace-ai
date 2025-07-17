using System.Text;
using System.Text.RegularExpressions;

namespace TimeToActDocumentAI.Parsing;

public class Lexer
{
    private readonly string _input;
    private int _position;
    private readonly List<Token> _tokens = [];

    public Lexer(string input)
    {
        _input = input ?? string.Empty;
        _position = 0;
    }

    public IEnumerable<Token> Tokenize()
    {
        while (_position < _input.Length)
        {
            var token = ReadNextToken();
            if (token != null)
            {
                _tokens.Add(token);
                yield return token;
            }
        }
        
        yield return new Token(TokenType.EndOfFile, string.Empty, _position);
    }

    private Token? ReadNextToken()
    {
        SkipWhitespace();
        
        if (_position >= _input.Length)
            return null;

        // Check for XML-like tags
        if (PeekChar() == '<')
        {
            return ReadTag();
        }

        // Read text content
        return ReadText();
    }

    private Token ReadTag()
    {
        var startPos = _position;
        var tagBuilder = new StringBuilder();
        
        // Read opening '<'
        tagBuilder.Append(ReadChar());
        
        // Check for closing tag
        var isClosing = PeekChar() == '/';
        if (isClosing)
        {
            tagBuilder.Append(ReadChar());
        }
        
        // Read tag name
        var tagName = ReadIdentifier();
        tagBuilder.Append(tagName);
        
        // Read attributes for opening tags
        var attributes = new Dictionary<string, string>();
        if (!isClosing)
        {
            attributes = ReadAttributes();
        }
        
        // Read closing '>'
        SkipWhitespace();
        if (PeekChar() == '>')
        {
            tagBuilder.Append(ReadChar());
        }
        
        var tokenType = GetTokenType(tagName, isClosing);
        return new TagToken(tokenType, tagBuilder.ToString(), startPos, attributes);
    }

    private Dictionary<string, string> ReadAttributes()
    {
        var attributes = new Dictionary<string, string>();
        
        while (_position < _input.Length && PeekChar() != '>')
        {
            SkipWhitespace();
            
            if (PeekChar() == '>')
                break;
                
            var attrName = ReadIdentifier();
            if (string.IsNullOrEmpty(attrName))
                break;
                
            SkipWhitespace();
            
            if (PeekChar() == '=')
            {
                ReadChar(); // consume '='
                SkipWhitespace();
                
                var attrValue = ReadAttributeValue();
                attributes[attrName] = attrValue;
            }
            else
            {
                attributes[attrName] = string.Empty;
            }
        }
        
        return attributes;
    }

    private string ReadAttributeValue()
    {
        var quote = PeekChar();
        if (quote == '"' || quote == '\'')
        {
            ReadChar(); // consume opening quote
            var value = ReadUntil(quote);
            ReadChar(); // consume closing quote
            return value;
        }
        
        return ReadUntil(' ', '\t', '\n', '\r', '>');
    }

    private string ReadIdentifier()
    {
        var builder = new StringBuilder();
        
        while (_position < _input.Length && 
               (char.IsLetterOrDigit(PeekChar()) || PeekChar() == '_' || PeekChar() == '-'))
        {
            builder.Append(ReadChar());
        }
        
        return builder.ToString();
    }

    private Token? ReadText()
    {
        var startPos = _position;
        var textBuilder = new StringBuilder();
        
        while (_position < _input.Length && PeekChar() != '<')
        {
            textBuilder.Append(ReadChar());
        }
        
        var text = textBuilder.ToString().Trim();
        return text.Length > 0 ? new Token(TokenType.Text, text, startPos) : null;
    }

    private TokenType GetTokenType(string tagName, bool isClosing)
    {
        return (tagName.ToLower(), isClosing) switch
        {
            ("head", false) => TokenType.HeadStart,
            ("head", true) => TokenType.HeadEnd,
            ("block", false) => TokenType.BlockStart,
            ("block", true) => TokenType.BlockEnd,
            ("list", false) => TokenType.ListStart,
            ("list", true) => TokenType.ListEnd,
            ("dict", false) => TokenType.DictStart,
            ("dict", true) => TokenType.DictEnd,
            _ => TokenType.Text
        };
    }

    private char PeekChar()
    {
        return _position < _input.Length ? _input[_position] : '\0';
    }

    private char ReadChar()
    {
        return _position < _input.Length ? _input[_position++] : '\0';
    }

    private void SkipWhitespace()
    {
        while (_position < _input.Length && char.IsWhiteSpace(PeekChar()))
        {
            _position++;
        }
    }

    private string ReadUntil(params char[] terminators)
    {
        var builder = new StringBuilder();
        
        while (_position < _input.Length && !terminators.Contains(PeekChar()))
        {
            builder.Append(ReadChar());
        }
        
        return builder.ToString();
    }
}