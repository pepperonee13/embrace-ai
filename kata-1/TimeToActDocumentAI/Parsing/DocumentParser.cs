using System.Text.RegularExpressions;
using TimeToActDocumentAI.Models;

namespace TimeToActDocumentAI.Parsing;

public class DocumentParser
{
    private readonly List<Token> _tokens;
    private int _position;

    public DocumentParser(IEnumerable<Token> tokens)
    {
        _tokens = tokens.ToList();
        _position = 0;
    }

    public Block Parse()
    {
        return ParseBlock();
    }

    private Block ParseBlock()
    {
        var block = new Block();
        var body = new List<ContentNode>();
        string? head = null;
        
        while (_position < _tokens.Count && CurrentToken.Type != TokenType.EndOfFile)
        {
            var token = CurrentToken;
            
            switch (token.Type)
            {
                case TokenType.HeadStart:
                    head = ParseHead();
                    break;
                    
                case TokenType.BlockStart:
                    Advance();
                    var nestedBlock = ParseBlock();
                    body.Add(nestedBlock);
                    break;
                    
                case TokenType.BlockEnd:
                    Advance();
                    return block with { Head = head, Body = body };
                    
                case TokenType.ListStart:
                    var listBlock = ParseList();
                    body.Add(listBlock);
                    break;
                    
                case TokenType.DictStart:
                    var dict = ParseDictionary();
                    body.Add(dict);
                    break;
                    
                case TokenType.Text:
                    var textLines = ParseTextLines();
                    body.AddRange(textLines.Select(line => new TextContent(line)));
                    break;
                    
                default:
                    Advance();
                    break;
            }
        }
        
        return block with { Head = head, Body = body };
    }

    private string ParseHead()
    {
        Advance(); // consume <head>
        
        var headContent = new List<string>();
        while (_position < _tokens.Count && CurrentToken.Type != TokenType.HeadEnd)
        {
            if (CurrentToken.Type == TokenType.Text)
            {
                headContent.Add(CurrentToken.Value);
            }
            Advance();
        }
        
        if (CurrentToken.Type == TokenType.HeadEnd)
        {
            Advance(); // consume </head>
        }
        
        return string.Join(" ", headContent);
    }

    private ListBlock ParseList()
    {
        var tagToken = CurrentToken as TagToken;
        var kind = tagToken?.Attributes.GetValueOrDefault("kind", ".") ?? ".";
        
        Advance(); // consume <list>
        
        var items = new List<Block>();
        var currentContent = new List<string>();
        
        while (_position < _tokens.Count && CurrentToken.Type != TokenType.ListEnd)
        {
            var token = CurrentToken;
            
            switch (token.Type)
            {
                case TokenType.Text:
                    var lines = ParseTextLines();
                    foreach (var line in lines)
                    {
                        var listItem = ParseListItem(line, kind);
                        if (listItem != null)
                        {
                            items.Add(listItem);
                        }
                    }
                    break;
                    
                case TokenType.BlockStart:
                    Advance();
                    var nestedBlock = ParseBlock();
                    if (items.Count > 0)
                    {
                        var lastItem = items[^1];
                        var newBody = new List<ContentNode>(lastItem.Body) { nestedBlock };
                        items[^1] = lastItem with { Body = newBody };
                    }
                    break;
                    
                case TokenType.DictStart:
                    var dict = ParseDictionary();
                    if (items.Count > 0)
                    {
                        var lastItem = items[^1];
                        var newBody = new List<ContentNode>(lastItem.Body) { dict };
                        items[^1] = lastItem with { Body = newBody };
                    }
                    break;
                    
                default:
                    Advance();
                    break;
            }
        }
        
        if (CurrentToken.Type == TokenType.ListEnd)
        {
            Advance(); // consume </list>
        }
        
        return new ListBlock { Items = items };
    }

    private Block? ParseListItem(string line, string kind)
    {
        if (string.IsNullOrWhiteSpace(line))
            return null;
            
        var trimmedLine = line.Trim();
        
        if (kind == ".")
        {
            // Handle numbered lists (1., 2.1., etc.)
            var match = Regex.Match(trimmedLine, @"^(\d+(?:\.\d+)*)\.\s*(.*)$");
            if (match.Success)
            {
                var number = match.Groups[1].Value;
                var content = match.Groups[2].Value;
                
                return new Block
                {
                    Number = number + ".",
                    Body = string.IsNullOrEmpty(content) ? [] : [new TextContent(content)]
                };
            }
        }
        else if (kind == "*")
        {
            // Handle bullet lists
            if (trimmedLine.StartsWith("•") || trimmedLine.StartsWith("*") || trimmedLine.StartsWith("-"))
            {
                var content = trimmedLine.Substring(1).Trim();
                return new Block
                {
                    Body = string.IsNullOrEmpty(content) ? [] : [new TextContent(content)]
                };
            }
        }
        
        // If it doesn't match the expected format, treat as continuation of previous item
        return null;
    }

    private Models.Dictionary ParseDictionary()
    {
        var tagToken = CurrentToken as TagToken;
        var separator = tagToken?.Attributes.GetValueOrDefault("sep", ":") ?? ":";
        
        Advance(); // consume <dict>
        
        var items = new Dictionary<string, string>();
        
        while (_position < _tokens.Count && CurrentToken.Type != TokenType.DictEnd)
        {
            if (CurrentToken.Type == TokenType.Text)
            {
                var lines = ParseTextLines();
                foreach (var line in lines)
                {
                    var separatorIndex = line.IndexOf(separator);
                    if (separatorIndex >= 0)
                    {
                        var key = line.Substring(0, separatorIndex).Trim();
                        var value = line.Substring(separatorIndex + separator.Length).Trim();
                        items[key] = value;
                    }
                    else if (!string.IsNullOrWhiteSpace(line))
                    {
                        items[line.Trim()] = string.Empty;
                    }
                }
            }
            else
            {
                Advance();
            }
        }
        
        if (CurrentToken.Type == TokenType.DictEnd)
        {
            Advance(); // consume </dict>
        }
        
        return new Models.Dictionary { Items = items };
    }

    private List<string> ParseTextLines()
    {
        var lines = new List<string>();
        
        while (_position < _tokens.Count && CurrentToken.Type == TokenType.Text)
        {
            var textLines = CurrentToken.Value.Split('\n', StringSplitOptions.RemoveEmptyEntries);
            lines.AddRange(textLines.Select(line => line.Trim()).Where(line => !string.IsNullOrEmpty(line)));
            Advance();
        }
        
        return lines;
    }

    private Token CurrentToken => _position < _tokens.Count ? _tokens[_position] : new Token(TokenType.EndOfFile, string.Empty, -1);

    private void Advance()
    {
        if (_position < _tokens.Count)
        {
            _position++;
        }
    }
}