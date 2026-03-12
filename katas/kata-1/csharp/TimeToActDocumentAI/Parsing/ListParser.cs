using TimeToActDocumentAI.Models;

namespace TimeToActDocumentAI.Parsing;

/// <summary>
/// Domain-specific parser for list structures using DDD principles.
/// Encapsulates the complex business logic for parsing various list types and nesting scenarios.
/// </summary>
public static class ListParser
{
    /// <summary>
    /// Parses a list from a token stream using functional patterns.
    /// </summary>
    /// <param name="stream">The token stream positioned at the list start tag</param>
    /// <returns>A tuple containing the parsed list block and the updated stream</returns>
    public static (ListBlock listBlock, TokenStream stream) ParseList(TokenStream stream)
    {
        var kindString = TagTokenExtractor.ExtractListKind(stream.Current);
        var listKind = ListItemParser.ParseListKind(kindString);
        
        var currentStream = stream.Advance(); // consume <list>
        
        var items = new List<Block>();
        var hasExplicitNestedLists = currentStream.HasTokenAhead(TokenType.ListStart, TokenType.ListEnd);
        
        while (!currentStream.IsAtEnd && currentStream.Current.Type != TokenType.ListEnd)
        {
            var token = currentStream.Current;
            
            switch (token.Type)
            {
                case TokenType.Text:
                    (items, currentStream) = ProcessTextInList(currentStream, items, listKind, hasExplicitNestedLists);
                    break;
                    
                case TokenType.BlockStart:
                    (items, currentStream) = ProcessNestedBlockInList(currentStream, items);
                    break;
                    
                case TokenType.DictStart:
                    (items, currentStream) = ProcessDictionaryInList(currentStream, items);
                    break;
                    
                case TokenType.ListStart:
                    (items, currentStream) = ProcessNestedListInList(currentStream, items);
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

    private static (List<Block> items, TokenStream stream) ProcessTextInList(
        TokenStream stream, List<Block> items, ListItemParser.ListKind listKind, bool hasExplicitNestedLists)
    {
        var (lines, textStream) = TextLineParser.ParseTextLines(stream);
        var currentStream = textStream;
        var updatedItems = new List<Block>(items);
        
        foreach (var line in lines)
        {
            var listItem = ListItemParser.TryParseListItem(line, listKind);
            if (listItem != null)
            {
                var nestingDecision = ListNestingStrategy.ShouldNestItem(listItem, updatedItems, hasExplicitNestedLists);
                if (nestingDecision.ShouldNest)
                {
                    var (nestedList, updatedParent) = ListNestingStrategy.GetOrCreateNestedList(nestingDecision.ParentItem!);
                    nestedList.Items.Add(listItem);
                    updatedItems[nestingDecision.ParentIndex] = updatedParent;
                }
                else
                {
                    updatedItems.Add(listItem);
                }
            }
            else if (ContentAttachmentService.ShouldAttachAsContent(line, listKind) && updatedItems.Count > 0)
            {
                updatedItems = ContentAttachmentService.AttachTextToLastItem(updatedItems, line);
            }
        }
        
        return (updatedItems, currentStream);
    }

    private static (List<Block> items, TokenStream stream) ProcessNestedBlockInList(TokenStream stream, List<Block> items)
    {
        var currentStream = stream.Advance();
        var (nestedBlock, blockStream) = BlockParser.ParseBlock(currentStream);
        currentStream = blockStream;
        
        var updatedItems = items.Count > 0 
            ? ContentAttachmentService.AttachContentToLastItem(items, nestedBlock)
            : items;
            
        return (updatedItems, currentStream);
    }

    private static (List<Block> items, TokenStream stream) ProcessDictionaryInList(TokenStream stream, List<Block> items)
    {
        var (dict, dictStream) = DictionaryParser.ParseDictionary(stream);
        var currentStream = dictStream;
        
        var updatedItems = items.Count > 0 
            ? ContentAttachmentService.AttachContentToLastItem(items, dict)
            : items;
            
        return (updatedItems, currentStream);
    }

    private static (List<Block> items, TokenStream stream) ProcessNestedListInList(TokenStream stream, List<Block> items)
    {
        var (nestedListBlock, nestedListStream) = ParseList(stream);
        var currentStream = nestedListStream;
        
        var updatedItems = items;
        if (items.Count > 0)
        {
            // For mixed lists, attach to the semantically appropriate parent
            var targetItem = ListNestingStrategy.FindAppropriateParentForNestedList(items);
            var targetIndex = items.IndexOf(targetItem);
            updatedItems = ContentAttachmentService.AttachContentToItem(items, targetIndex, nestedListBlock);
        }
        
        return (updatedItems, currentStream);
    }

    /// <summary>
    /// Validates that a token stream is positioned at a valid list start token.
    /// </summary>
    /// <param name="stream">The token stream to validate</param>
    /// <returns>True if positioned at a list start token</returns>
    public static bool IsAtListStart(TokenStream stream)
    {
        return !stream.IsAtEnd && stream.Current.Type == TokenType.ListStart;
    }
}