using TimeToActDocumentAI.Models;

namespace TimeToActDocumentAI.Parsing;

/// <summary>
/// Domain service for managing content attachment to list items using immutable patterns.
/// Encapsulates the business logic for attaching various content types to list item bodies.
/// </summary>
public static class ContentAttachmentService
{
    /// <summary>
    /// Attaches text content to the last item in a list using immutable update patterns.
    /// </summary>
    /// <param name="items">The list of items to update</param>
    /// <param name="textLine">The text to attach</param>
    /// <returns>A new list with the text attached to the last item</returns>
    public static List<Block> AttachTextToLastItem(List<Block> items, string textLine)
    {
        if (items.Count == 0 || string.IsNullOrWhiteSpace(textLine))
            return items;

        var newItems = new List<Block>(items);
        var lastItemIndex = items.Count - 1;
        var lastItem = items[lastItemIndex];
        var textContent = ContentNodeFactory.CreateTextContent(textLine);
        var newBody = new List<ContentNode>(lastItem.Body ?? []) { textContent };
        
        newItems[lastItemIndex] = lastItem with { Body = newBody };
        return newItems;
    }

    /// <summary>
    /// Attaches a content node (block, dictionary, etc.) to the last item in a list.
    /// </summary>
    /// <param name="items">The list of items to update</param>
    /// <param name="content">The content node to attach</param>
    /// <returns>A new list with the content attached to the last item</returns>
    public static List<Block> AttachContentToLastItem(List<Block> items, ContentNode content)
    {
        if (items.Count == 0)
            return items;

        var newItems = new List<Block>(items);
        var lastItemIndex = items.Count - 1;
        var lastItem = items[lastItemIndex];
        var newBody = new List<ContentNode>(lastItem.Body ?? []) { content };
        
        newItems[lastItemIndex] = lastItem with { Body = newBody };
        return newItems;
    }

    /// <summary>
    /// Attaches content to a specific item in the list by index.
    /// </summary>
    /// <param name="items">The list of items to update</param>
    /// <param name="targetIndex">The index of the target item</param>
    /// <param name="content">The content node to attach</param>
    /// <returns>A new list with the content attached to the specified item</returns>
    public static List<Block> AttachContentToItem(List<Block> items, int targetIndex, ContentNode content)
    {
        if (targetIndex < 0 || targetIndex >= items.Count)
            return items;

        var newItems = new List<Block>(items);
        var targetItem = items[targetIndex];
        var newBody = new List<ContentNode>(targetItem.Body ?? []) { content };
        
        newItems[targetIndex] = targetItem with { Body = newBody };
        return newItems;
    }

    /// <summary>
    /// Determines if a text line should be treated as content attachment rather than a new item.
    /// </summary>
    /// <param name="line">The text line to evaluate</param>
    /// <param name="listKind">The kind of list being processed</param>
    /// <returns>True if the line should be attached as content, false if it should be a new item</returns>
    public static bool ShouldAttachAsContent(string line, ListItemParser.ListKind listKind)
    {
        if (string.IsNullOrWhiteSpace(line))
            return false;

        // If the line doesn't parse as a list item, it should be attached as content
        return ListItemParser.TryParseListItem(line, listKind) == null;
    }
}