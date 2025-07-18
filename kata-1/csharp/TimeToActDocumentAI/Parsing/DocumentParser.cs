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
                    return block with { Head = head, Body = body.Count > 0 ? body : null };
                    
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
        
        return block with { Head = head, Body = body.Count > 0 ? body : null };
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
                            // Check if this is a nested item (like 2.1. under 2.)
                            if (ShouldNestUnderPreviousItem(listItem, items))
                            {
                                var lastItemIndex = items.Count - 1;
                                var lastItem = items[lastItemIndex];
                                var nestedList = GetOrCreateNestedList(lastItem, out var updatedParent);
                                nestedList.Items.Add(listItem);
                                items[lastItemIndex] = updatedParent;
                            }
                            else
                            {
                                items.Add(listItem);
                            }
                        }
                    }
                    break;
                    
                case TokenType.BlockStart:
                    Advance();
                    var nestedBlock = ParseBlock();
                    if (items.Count > 0)
                    {
                        var lastItem = items[^1];
                        var newBody = new List<ContentNode>(lastItem.Body ?? []) { nestedBlock };
                        items[^1] = lastItem with { Body = newBody };
                    }
                    break;
                    
                case TokenType.DictStart:
                    var dict = ParseDictionary();
                    if (items.Count > 0)
                    {
                        var lastItem = items[^1];
                        var newBody = new List<ContentNode>(lastItem.Body ?? []) { dict };
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
                    Head = string.IsNullOrEmpty(content) ? null : content
                };
            }
        }
        else if (kind == "*")
        {
            // Handle bullet lists
            if (trimmedLine.StartsWith("•") || trimmedLine.StartsWith("*") || trimmedLine.StartsWith("-") || trimmedLine.StartsWith("o"))
            {
                var bulletChar = trimmedLine[0].ToString();
                var content = trimmedLine.Substring(1).Trim();
                return new Block
                {
                    Number = bulletChar,
                    Head = string.IsNullOrEmpty(content) ? null : content
                };
            }
        }
        
        // If it doesn't match the expected format, treat as continuation of previous item
        return null;
    }

    private bool ShouldNestUnderPreviousItem(Block currentItem, List<Block> existingItems)
    {
        if (existingItems.Count == 0 || currentItem.Number == null)
            return false;

        var lastItem = existingItems[^1];
        if (lastItem.Number == null)
            return false;

        // For numbered lists, check if current number is a sub-number of the last item
        if (currentItem.Number.Contains('.') && lastItem.Number.Contains('.'))
        {
            var currentParts = currentItem.Number.TrimEnd('.').Split('.');
            var lastParts = lastItem.Number.TrimEnd('.').Split('.');
            
            // Check if current item is a sub-item (e.g., 2.1 under 2, or 2.1.3 under 2.1)
            if (currentParts.Length > lastParts.Length)
            {
                // Check if the prefix matches
                for (int i = 0; i < lastParts.Length; i++)
                {
                    if (currentParts[i] != lastParts[i])
                        return false;
                }
                return true;
            }
        }

        // For bullet lists, check if current bullet is different from last (indicating nesting)
        if (!currentItem.Number.Contains('.') && !lastItem.Number.Contains('.'))
        {
            return currentItem.Number != lastItem.Number;
        }

        return false;
    }

    private ListBlock GetOrCreateNestedList(Block parentItem, out Block updatedParent)
    {
        // Check if parent already has a nested list
        if (parentItem.Body?.LastOrDefault() is ListBlock existingList)
        {
            updatedParent = parentItem;
            return existingList;
        }

        // Create new nested list
        var nestedList = new ListBlock();
        var newBody = new List<ContentNode>(parentItem.Body ?? []) { nestedList };
        updatedParent = parentItem with { Body = newBody };
        
        return nestedList;
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