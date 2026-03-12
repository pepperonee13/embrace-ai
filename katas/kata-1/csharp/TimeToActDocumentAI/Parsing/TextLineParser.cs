namespace TimeToActDocumentAI.Parsing;

/// <summary>
/// Utility parser for extracting text lines from token streams.
/// Provides consistent text parsing behavior across all parsers.
/// </summary>
public static class TextLineParser
{
    /// <summary>
    /// Parses consecutive text tokens into individual lines with consistent formatting.
    /// </summary>
    /// <param name="stream">The token stream positioned at text tokens</param>
    /// <returns>A tuple containing the parsed lines and updated stream</returns>
    public static (List<string> lines, TokenStream stream) ParseTextLines(TokenStream stream)
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

    /// <summary>
    /// Parses text lines and filters them based on a predicate.
    /// Useful for parsing scenarios where only certain lines are relevant.
    /// </summary>
    /// <param name="stream">The token stream positioned at text tokens</param>
    /// <param name="predicate">Function to determine which lines to include</param>
    /// <returns>A tuple containing the filtered lines and updated stream</returns>
    public static (List<string> lines, TokenStream stream) ParseTextLinesWhere(TokenStream stream, Func<string, bool> predicate)
    {
        var (allLines, newStream) = ParseTextLines(stream);
        var filteredLines = allLines.Where(predicate).ToList();
        return (filteredLines, newStream);
    }

    /// <summary>
    /// Parses text lines and transforms them using a selector function.
    /// Provides a functional approach to text line processing.
    /// </summary>
    /// <typeparam name="T">The type to transform lines into</typeparam>
    /// <param name="stream">The token stream positioned at text tokens</param>
    /// <param name="selector">Function to transform each line</param>
    /// <returns>A tuple containing the transformed items and updated stream</returns>
    public static (List<T> items, TokenStream stream) ParseTextLinesSelect<T>(TokenStream stream, Func<string, T> selector)
    {
        var (lines, newStream) = ParseTextLines(stream);
        var transformedItems = lines.Select(selector).ToList();
        return (transformedItems, newStream);
    }
}