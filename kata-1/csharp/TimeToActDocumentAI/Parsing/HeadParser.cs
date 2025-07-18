namespace TimeToActDocumentAI.Parsing;

/// <summary>
/// Domain-specific parser for head content using DDD principles.
/// Encapsulates the business logic for parsing head sections within documents.
/// </summary>
public static class HeadParser
{
    /// <summary>
    /// Parses a head section from a token stream using functional patterns.
    /// </summary>
    /// <param name="stream">The token stream positioned at the head start tag</param>
    /// <returns>A tuple containing the parsed head content and the updated stream</returns>
    public static (string head, TokenStream stream) ParseHead(TokenStream stream)
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

    /// <summary>
    /// Parses head content with additional processing options.
    /// </summary>
    /// <param name="stream">The token stream positioned at the head start tag</param>
    /// <param name="trimWhitespace">Whether to trim whitespace from the final result</param>
    /// <param name="collapseWhitespace">Whether to collapse multiple spaces into single spaces</param>
    /// <returns>A tuple containing the processed head content and the updated stream</returns>
    public static (string head, TokenStream stream) ParseHeadWithOptions(TokenStream stream, bool trimWhitespace = true, bool collapseWhitespace = true)
    {
        var (rawHead, newStream) = ParseHead(stream);
        
        var processedHead = rawHead;
        if (collapseWhitespace)
        {
            // Replace multiple whitespace characters with single spaces
            processedHead = System.Text.RegularExpressions.Regex.Replace(processedHead, @"\s+", " ");
        }
        
        if (trimWhitespace)
        {
            processedHead = processedHead.Trim();
        }
        
        return (processedHead, newStream);
    }

    /// <summary>
    /// Validates that a token stream is positioned at a valid head start token.
    /// </summary>
    /// <param name="stream">The token stream to validate</param>
    /// <returns>True if positioned at a head start token</returns>
    public static bool IsAtHeadStart(TokenStream stream)
    {
        return !stream.IsAtEnd && stream.Current.Type == TokenType.HeadStart;
    }
}