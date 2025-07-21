using System.Text.RegularExpressions;
using TimeToActDocumentAI.Models;

namespace TimeToActDocumentAI.Parsing;

/// <summary>
/// Domain-specific parser for list items based on DDD principles.
/// Encapsulates the business logic for recognizing and parsing different list item formats.
/// </summary>
public static class ListItemParser
{
    /// <summary>
    /// Represents the kind of list that determines parsing rules.
    /// </summary>
    public enum ListKind
    {
        Numbered,  // "." - Ordered lists with numbers (1., 2.1., etc.)
        Bulleted   // "*" - Bullet lists with various bullet characters
    }

    /// <summary>
    /// Attempts to parse a text line as a list item according to the specified list kind.
    /// </summary>
    /// <param name="line">The text line to parse</param>
    /// <param name="listKind">The kind of list determining parsing rules</param>
    /// <returns>A Block representing the list item, or null if the line doesn't match the expected format</returns>
    public static Block? TryParseListItem(string line, ListKind listKind)
    {
        if (string.IsNullOrWhiteSpace(line))
            return null;

        var trimmedLine = line.Trim();

        return listKind switch
        {
            ListKind.Numbered => TryParseNumberedListItem(trimmedLine),
            ListKind.Bulleted => TryParseBulletedListItem(trimmedLine),
            _ => null
        };
    }

    /// <summary>
    /// Converts string list kind to enum.
    /// </summary>
    public static ListKind ParseListKind(string kind) => kind switch
    {
        "." => ListKind.Numbered,
        "*" => ListKind.Bulleted,
        _ => ListKind.Numbered // Default fallback
    };

    private static Block? TryParseNumberedListItem(string trimmedLine)
    {
        // Handle numbered lists (1., 2.1., etc.)
        // Regex pattern: one or more digits, followed by optional (.digit) groups, then a dot and space
        var match = Regex.Match(trimmedLine, @"^(\d+(?:\.\d+)*)\.\s*(.*)$");
        if (!match.Success)
            return null;

        var number = match.Groups[1].Value;
        var content = match.Groups[2].Value;

        return new Block
        {
            Number = number + ".",
            Head = string.IsNullOrEmpty(content) ? null : content
        };
    }

    private static Block? TryParseBulletedListItem(string trimmedLine)
    {
        // Handle bullet lists with various bullet characters
        if (!IsBulletCharacter(trimmedLine[0]))
            return null;

        var bulletChar = trimmedLine[0].ToString();
        var content = trimmedLine.Substring(1).Trim();

        return new Block
        {
            Number = bulletChar,
            Head = string.IsNullOrEmpty(content) ? null : content
        };
    }

    private static bool IsBulletCharacter(char character) =>
        character is '•' or '*' or '-' or 'o';
}