using TimeToActDocumentAI.Models;

namespace TimeToActDocumentAI.Parsing;

/// <summary>
/// Factory for creating ContentNode instances with explicit intent.
/// Centralizes content node creation and makes the purpose clear.
/// </summary>
public static class ContentNodeFactory
{
    /// <summary>
    /// Creates text content nodes from a collection of lines.
    /// </summary>
    /// <param name="lines">The text lines to convert to content nodes</param>
    /// <returns>A list of TextContent nodes</returns>
    public static List<ContentNode> CreateTextContentFromLines(IEnumerable<string> lines)
    {
        return lines.Select(line => new TextContent(line)).Cast<ContentNode>().ToList();
    }

    /// <summary>
    /// Creates a single text content node from a line.
    /// </summary>
    /// <param name="line">The text line to convert</param>
    /// <returns>A TextContent node</returns>
    public static ContentNode CreateTextContent(string line)
    {
        return new TextContent(line);
    }

    /// <summary>
    /// Creates content nodes from parsed text lines with filtering.
    /// Only creates content for non-empty, meaningful lines.
    /// </summary>
    /// <param name="lines">The text lines to process</param>
    /// <param name="predicate">Optional predicate to filter lines</param>
    /// <returns>A list of ContentNode instances</returns>
    public static List<ContentNode> CreateFilteredTextContent(IEnumerable<string> lines, Func<string, bool>? predicate = null)
    {
        var filteredLines = predicate != null ? lines.Where(predicate) : lines;
        return filteredLines
            .Where(line => !string.IsNullOrWhiteSpace(line))
            .Select(line => new TextContent(line))
            .Cast<ContentNode>()
            .ToList();
    }

    /// <summary>
    /// Creates a block content node.
    /// </summary>
    /// <param name="block">The block to wrap as content</param>
    /// <returns>The block as a ContentNode</returns>
    public static ContentNode CreateBlockContent(Block block)
    {
        return block;
    }

    /// <summary>
    /// Creates a list content node.
    /// </summary>
    /// <param name="listBlock">The list block to wrap as content</param>
    /// <returns>The list block as a ContentNode</returns>
    public static ContentNode CreateListContent(ListBlock listBlock)
    {
        return listBlock;
    }

    /// <summary>
    /// Creates a dictionary content node.
    /// </summary>
    /// <param name="dictionary">The dictionary to wrap as content</param>
    /// <returns>The dictionary as a ContentNode</returns>
    public static ContentNode CreateDictionaryContent(Models.Dictionary dictionary)
    {
        return dictionary;
    }

    /// <summary>
    /// Creates content nodes from mixed content types with explicit intent.
    /// </summary>
    /// <param name="contentItems">The content items to process</param>
    /// <returns>A list of properly typed ContentNode instances</returns>
    public static List<ContentNode> CreateMixedContent(params object[] contentItems)
    {
        var contentNodes = new List<ContentNode>();

        foreach (var item in contentItems)
        {
            var contentNode = item switch
            {
                string text => CreateTextContent(text),
                Block block => CreateBlockContent(block),
                ListBlock listBlock => CreateListContent(listBlock),
                Models.Dictionary dictionary => CreateDictionaryContent(dictionary),
                ContentNode node => node,
                _ => throw new ArgumentException($"Unsupported content type: {item.GetType()}")
            };

            contentNodes.Add(contentNode);
        }

        return contentNodes;
    }
}