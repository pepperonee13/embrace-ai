using System.Text.RegularExpressions;
using TimeToActDocumentAI.Models;

namespace TimeToActDocumentAI.Parsing;

public class DocumentParser
{
    private readonly TokenStream _initialStream;

    public DocumentParser(IEnumerable<Token> tokens)
    {
        _initialStream = new TokenStream(tokens);
    }

    public Block Parse()
    {
        return ParseBlock(_initialStream).block;
    }

    private (Block block, TokenStream stream) ParseBlock(TokenStream stream)
    {
        var block = new Block();
        var body = new List<ContentNode>();
        string? head = null;
        var currentStream = stream;
        
        while (!currentStream.IsAtEnd)
        {
            var token = currentStream.Current;
            
            switch (token.Type)
            {
                case TokenType.HeadStart:
                    (head, currentStream) = ParseHead(currentStream);
                    break;
                    
                case TokenType.BlockStart:
                    currentStream = currentStream.Advance();
                    var (nestedBlock, nextStream) = ParseBlock(currentStream);
                    body.Add(nestedBlock);
                    currentStream = nextStream;
                    break;
                    
                case TokenType.BlockEnd:
                    currentStream = currentStream.Advance();
                    return (block with { Head = head, Body = body.Count > 0 ? body : null }, currentStream);
                    
                case TokenType.ListStart:
                    var (listBlock, listStream) = ParseList(currentStream);
                    body.Add(listBlock);
                    currentStream = listStream;
                    break;
                    
                case TokenType.DictStart:
                    var (dict, dictStream) = ParseDictionary(currentStream);
                    body.Add(dict);
                    currentStream = dictStream;
                    break;
                    
                case TokenType.Text:
                    var (textLines, textStream) = ParseTextLines(currentStream);
                    body.AddRange(textLines.Select(line => new TextContent(line)));
                    currentStream = textStream;
                    break;
                    
                default:
                    currentStream = currentStream.Advance();
                    break;
            }
        }
        
        return (block with { Head = head, Body = body.Count > 0 ? body : null }, currentStream);
    }

    private (string head, TokenStream stream) ParseHead(TokenStream stream)
    {
        var currentStream = stream.Advance(); // consume <head>
        
        var headContent = new List<string>();
        while (!currentStream.IsAtEnd && currentStream.Current.Type != TokenType.HeadEnd)
        {
            if (currentStream.Current.Type == TokenType.Text)
            {
                headContent.Add(currentStream.Current.Value);
            }
            currentStream = currentStream.Advance();
        }
        
        if (currentStream.Current.Type == TokenType.HeadEnd)
        {
            currentStream = currentStream.Advance(); // consume </head>
        }
        
        return (string.Join(" ", headContent), currentStream);
    }

    private (ListBlock listBlock, TokenStream stream) ParseList(TokenStream stream)
    {
        var tagToken = stream.Current as TagToken;
        var kind = tagToken?.Attributes.GetValueOrDefault("kind", ".") ?? ".";
        
        var currentStream = stream.Advance(); // consume <list>
        
        var items = new List<Block>();
        var currentContent = new List<string>();
        var hasExplicitNestedLists = currentStream.HasTokenAhead(TokenType.ListStart, TokenType.ListEnd); // Look ahead for explicit nested lists
        
        while (!currentStream.IsAtEnd && currentStream.Current.Type != TokenType.ListEnd)
        {
            var token = currentStream.Current;
            
            switch (token.Type)
            {
                case TokenType.Text:
                    var (lines, textStream) = ParseTextLines(currentStream);
                    currentStream = textStream;
                    foreach (var line in lines)
                    {
                        var listItem = ParseListItem(line, kind);
                        if (listItem != null)
                        {
                            // In mixed list context, disable numbered nesting to keep items flat
                            // Check if this is a nested item (like 2.1. under 2.)
                            if (!hasExplicitNestedLists && ShouldNestUnderPreviousItem(listItem, items))
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
                        else if (!string.IsNullOrWhiteSpace(line) && items.Count > 0)
                        {
                            // This line is not a list item, so attach it as body content to the last item
                            var lastItemIndex = items.Count - 1;
                            var lastItem = items[lastItemIndex];
                            var newBody = new List<ContentNode>(lastItem.Body ?? []) { new TextContent(line) };
                            items[lastItemIndex] = lastItem with { Body = newBody };
                        }
                    }
                    break;
                    
                case TokenType.BlockStart:
                    currentStream = currentStream.Advance();
                    var (nestedBlock, blockStream) = ParseBlock(currentStream);
                    currentStream = blockStream;
                    if (items.Count > 0)
                    {
                        var lastItem = items[^1];
                        var newBody = new List<ContentNode>(lastItem.Body ?? []) { nestedBlock };
                        items[^1] = lastItem with { Body = newBody };
                    }
                    break;
                    
                case TokenType.DictStart:
                    var (dict, dictStream) = ParseDictionary(currentStream);
                    currentStream = dictStream;
                    if (items.Count > 0)
                    {
                        var lastItem = items[^1];
                        var newBody = new List<ContentNode>(lastItem.Body ?? []) { dict };
                        items[^1] = lastItem with { Body = newBody };
                    }
                    break;
                    
                case TokenType.ListStart:
                    var (nestedListBlock, nestedListStream) = ParseList(currentStream);
                    currentStream = nestedListStream;
                    if (items.Count > 0)
                    {
                        // For mixed lists, attach to the semantically appropriate parent
                        var targetItem = FindAppropriateParentForNestedList(items);
                        var targetIndex = items.IndexOf(targetItem);
                        var newBody = new List<ContentNode>(targetItem.Body ?? []) { nestedListBlock };
                        items[targetIndex] = targetItem with { Body = newBody };
                    }
                    break;
                    
                default:
                    currentStream = currentStream.Advance();
                    break;
            }
        }
        
        if (currentStream.Current.Type == TokenType.ListEnd)
        {
            currentStream = currentStream.Advance(); // consume </list>
        }
        
        return (new ListBlock { Items = items }, currentStream);
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

    private Block FindAppropriateParentForNestedList(List<Block> items)
    {
        if (items.Count == 0)
            return items[^1];

        var lastItem = items[^1];
        
        // If the last item is a numbered sub-item (like 2.1.), 
        // look for its logical parent (like 2.)
        if (lastItem.Number != null && lastItem.Number.Contains('.'))
        {
            var lastParts = lastItem.Number.TrimEnd('.').Split('.');
            if (lastParts.Length > 1)
            {
                // Look for a parent item (e.g., "2." for "2.1.")
                var parentNumber = lastParts[0] + ".";
                for (int i = items.Count - 2; i >= 0; i--)
                {
                    if (items[i].Number == parentNumber)
                    {
                        return items[i];
                    }
                }
            }
        }
        
        // Default to last item if no appropriate parent found
        return lastItem;
    }


    private (Models.Dictionary dictionary, TokenStream stream) ParseDictionary(TokenStream stream)
    {
        var tagToken = stream.Current as TagToken;
        var separator = tagToken?.Attributes.GetValueOrDefault("sep", ":") ?? ":";
        
        var currentStream = stream.Advance(); // consume <dict>
        
        var items = new Dictionary<string, string>();
        
        while (!currentStream.IsAtEnd && currentStream.Current.Type != TokenType.DictEnd)
        {
            if (currentStream.Current.Type == TokenType.Text)
            {
                var (lines, textStream) = ParseTextLines(currentStream);
                currentStream = textStream;
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
                currentStream = currentStream.Advance();
            }
        }
        
        if (currentStream.Current.Type == TokenType.DictEnd)
        {
            currentStream = currentStream.Advance(); // consume </dict>
        }
        
        return (new Models.Dictionary { Items = items }, currentStream);
    }

    private (List<string> lines, TokenStream stream) ParseTextLines(TokenStream stream)
    {
        var lines = new List<string>();
        var currentStream = stream;
        
        while (!currentStream.IsAtEnd && currentStream.Current.Type == TokenType.Text)
        {
            var textLines = currentStream.Current.Value.Split('\n', StringSplitOptions.RemoveEmptyEntries);
            lines.AddRange(textLines.Select(line => line.Trim()).Where(line => !string.IsNullOrEmpty(line)));
            currentStream = currentStream.Advance();
        }
        
        return (lines, currentStream);
    }

}