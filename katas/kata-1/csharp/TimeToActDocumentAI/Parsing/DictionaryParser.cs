using TimeToActDocumentAI.Models;

namespace TimeToActDocumentAI.Parsing;

/// <summary>
/// Domain-specific parser for dictionary structures using DDD principles.
/// Encapsulates the business logic for parsing key-value pairs with configurable separators.
/// </summary>
public static class DictionaryParser
{
    /// <summary>
    /// Parses a dictionary from a token stream using functional patterns.
    /// </summary>
    /// <param name="stream">The token stream positioned at the dictionary start tag</param>
    /// <returns>A tuple containing the parsed dictionary and the updated stream</returns>
    public static (Models.Dictionary dictionary, TokenStream stream) ParseDictionary(TokenStream stream)
    {
        var separator = TagTokenExtractor.ExtractDictionarySeparator(stream.Current);
        var currentStream = stream.Advance(); // consume <dict>
        
        var items = new Dictionary<string, string>();
        
        while (!currentStream.IsAtEnd && currentStream.Current.Type != TokenType.DictEnd)
        {
            if (currentStream.Current.Type == TokenType.Text)
            {
                var (lines, textStream) = TextLineParser.ParseTextLines(currentStream);
                currentStream = textStream;
                
                foreach (var line in lines)
                {
                    var keyValuePair = ParseKeyValuePair(line, separator);
                    if (keyValuePair.HasValue)
                    {
                        items[keyValuePair.Value.Key] = keyValuePair.Value.Value;
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


    /// <summary>
    /// Parses a single line into a key-value pair using the specified separator.
    /// </summary>
    /// <param name="line">The line to parse</param>
    /// <param name="separator">The separator to split on</param>
    /// <returns>A key-value pair if parsing succeeds, null otherwise</returns>
    private static (string Key, string Value)? ParseKeyValuePair(string line, string separator)
    {
        if (string.IsNullOrWhiteSpace(line))
            return null;

        var separatorIndex = line.IndexOf(separator);
        if (separatorIndex >= 0)
        {
            var key = line.Substring(0, separatorIndex).Trim();
            var value = line.Substring(separatorIndex + separator.Length).Trim();
            return (key, value);
        }
        
        // Handle lines without separator as keys with empty values
        if (!string.IsNullOrWhiteSpace(line))
        {
            return (line.Trim(), string.Empty);
        }
        
        return null;
    }

}