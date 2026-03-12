namespace TimeToActDocumentAI.Parsing;

/// <summary>
/// Utility for extracting information from tag tokens with consistent behavior.
/// Provides type-safe access to tag attributes and default values.
/// </summary>
public static class TagTokenExtractor
{
    /// <summary>
    /// Extracts an attribute value from a tag token with a default fallback.
    /// </summary>
    /// <param name="token">The token to extract from</param>
    /// <param name="attributeName">The name of the attribute to extract</param>
    /// <param name="defaultValue">The default value if attribute is not found</param>
    /// <returns>The attribute value or default</returns>
    public static string ExtractAttribute(Token token, string attributeName, string defaultValue)
    {
        if (token is TagToken tagToken)
        {
            return tagToken.Attributes.GetValueOrDefault(attributeName, defaultValue) ?? defaultValue;
        }
        return defaultValue;
    }

    /// <summary>
    /// Extracts the separator attribute from a dictionary tag token.
    /// </summary>
    /// <param name="token">The dictionary tag token</param>
    /// <returns>The separator string to use for parsing</returns>
    public static string ExtractDictionarySeparator(Token token)
    {
        return ExtractAttribute(token, "sep", ":");
    }

    /// <summary>
    /// Extracts the kind attribute from a list tag token.
    /// </summary>
    /// <param name="token">The list tag token</param>
    /// <returns>The list kind string</returns>
    public static string ExtractListKind(Token token)
    {
        return ExtractAttribute(token, "kind", ".");
    }

    /// <summary>
    /// Determines if a token is a tag token with the specified type.
    /// </summary>
    /// <param name="token">The token to check</param>
    /// <param name="expectedType">The expected token type</param>
    /// <returns>True if the token is a tag token of the expected type</returns>
    public static bool IsTagTokenOfType(Token token, TokenType expectedType)
    {
        return token is TagToken && token.Type == expectedType;
    }

    /// <summary>
    /// Safely casts a token to a TagToken if it matches the expected type.
    /// </summary>
    /// <param name="token">The token to cast</param>
    /// <param name="expectedType">The expected token type</param>
    /// <returns>The TagToken if successful, null otherwise</returns>
    public static TagToken? AsTagToken(Token token, TokenType expectedType)
    {
        return IsTagTokenOfType(token, expectedType) ? (TagToken)token : null;
    }

    /// <summary>
    /// Extracts all attributes from a tag token as a dictionary.
    /// </summary>
    /// <param name="token">The tag token to extract from</param>
    /// <returns>A dictionary of all attributes, or empty if not a tag token</returns>
    public static Dictionary<string, string> ExtractAllAttributes(Token token)
    {
        if (token is TagToken tagToken)
        {
            return new Dictionary<string, string>(tagToken.Attributes);
        }
        return new Dictionary<string, string>();
    }
}