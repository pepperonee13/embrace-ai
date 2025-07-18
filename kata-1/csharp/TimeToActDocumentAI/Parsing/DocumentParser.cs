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
                    var (dict, dictStream) = DictionaryParser.ParseDictionary(currentStream);
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
        var kindString = tagToken?.Attributes.GetValueOrDefault("kind", ".") ?? ".";
        var listKind = ListItemParser.ParseListKind(kindString);
        
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
                        var listItem = ListItemParser.TryParseListItem(line, listKind);
                        if (listItem != null)
                        {
                            var nestingDecision = ListNestingStrategy.ShouldNestItem(listItem, items, hasExplicitNestedLists);
                            if (nestingDecision.ShouldNest)
                            {
                                var (nestedList, updatedParent) = ListNestingStrategy.GetOrCreateNestedList(nestingDecision.ParentItem!);
                                nestedList.Items.Add(listItem);
                                items[nestingDecision.ParentIndex] = updatedParent;
                            }
                            else
                            {
                                items.Add(listItem);
                            }
                        }
                        else if (ContentAttachmentService.ShouldAttachAsContent(line, listKind) && items.Count > 0)
                        {
                            // This line is not a list item, so attach it as body content to the last item
                            items = ContentAttachmentService.AttachTextToLastItem(items, line);
                        }
                    }
                    break;
                    
                case TokenType.BlockStart:
                    currentStream = currentStream.Advance();
                    var (nestedBlock, blockStream) = ParseBlock(currentStream);
                    currentStream = blockStream;
                    if (items.Count > 0)
                    {
                        items = ContentAttachmentService.AttachContentToLastItem(items, nestedBlock);
                    }
                    break;
                    
                case TokenType.DictStart:
                    var (dict, dictStream) = DictionaryParser.ParseDictionary(currentStream);
                    currentStream = dictStream;
                    if (items.Count > 0)
                    {
                        items = ContentAttachmentService.AttachContentToLastItem(items, dict);
                    }
                    break;
                    
                case TokenType.ListStart:
                    var (nestedListBlock, nestedListStream) = ParseList(currentStream);
                    currentStream = nestedListStream;
                    if (items.Count > 0)
                    {
                        // For mixed lists, attach to the semantically appropriate parent
                        var targetItem = ListNestingStrategy.FindAppropriateParentForNestedList(items);
                        var targetIndex = items.IndexOf(targetItem);
                        items = ContentAttachmentService.AttachContentToItem(items, targetIndex, nestedListBlock);
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