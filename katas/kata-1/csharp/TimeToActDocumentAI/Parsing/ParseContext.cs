using TimeToActDocumentAI.Models;

namespace TimeToActDocumentAI.Parsing;

/// <summary>
/// Represents the context and intent of a parsing operation.
/// Makes parsing behavior explicit and provides type-safe context information.
/// </summary>
public readonly struct ParseContext
{
    public ParseContextType Type { get; }
    public ListItemParser.ListKind? ListKind { get; }
    public string? DictionarySeparator { get; }
    public bool HasExplicitNestedLists { get; }

    private ParseContext(ParseContextType type, ListItemParser.ListKind? listKind = null, 
                        string? dictionarySeparator = null, bool hasExplicitNestedLists = false)
    {
        Type = type;
        ListKind = listKind;
        DictionarySeparator = dictionarySeparator;
        HasExplicitNestedLists = hasExplicitNestedLists;
    }

    /// <summary>
    /// Creates a context for parsing a root document block.
    /// </summary>
    public static ParseContext ForDocument() => new(ParseContextType.Document);

    /// <summary>
    /// Creates a context for parsing a nested block.
    /// </summary>
    public static ParseContext ForNestedBlock() => new(ParseContextType.NestedBlock);

    /// <summary>
    /// Creates a context for parsing a list with the specified kind.
    /// </summary>
    /// <param name="listKind">The type of list being parsed</param>
    /// <param name="hasExplicitNestedLists">Whether explicit nested list tags are present</param>
    public static ParseContext ForList(ListItemParser.ListKind listKind, bool hasExplicitNestedLists = false) =>
        new(ParseContextType.List, listKind, hasExplicitNestedLists: hasExplicitNestedLists);

    /// <summary>
    /// Creates a context for parsing a dictionary with the specified separator.
    /// </summary>
    /// <param name="separator">The separator used for key-value pairs</param>
    public static ParseContext ForDictionary(string separator) =>
        new(ParseContextType.Dictionary, dictionarySeparator: separator);

    /// <summary>
    /// Creates a context for parsing head content.
    /// </summary>
    public static ParseContext ForHead() => new(ParseContextType.Head);

    /// <summary>
    /// Determines if content should be attached to existing items in this context.
    /// </summary>
    public bool ShouldAttachContent => Type == ParseContextType.List;

    /// <summary>
    /// Determines if nesting rules should be applied in this context.
    /// </summary>
    public bool ShouldApplyNestingRules => Type == ParseContextType.List && !HasExplicitNestedLists;

    /// <summary>
    /// Gets a descriptive name for this parsing context.
    /// </summary>
    public string ContextName => Type switch
    {
        ParseContextType.Document => "Document",
        ParseContextType.NestedBlock => "Nested Block",
        ParseContextType.List => $"{ListKind} List",
        ParseContextType.Dictionary => $"Dictionary (sep: {DictionarySeparator})",
        ParseContextType.Head => "Head",
        _ => "Unknown"
    };
}

/// <summary>
/// Defines the types of parsing contexts available.
/// </summary>
public enum ParseContextType
{
    Document,
    NestedBlock,
    List,
    Dictionary,
    Head
}