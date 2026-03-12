using TimeToActDocumentAI.Models;

namespace TimeToActDocumentAI.Parsing;

/// <summary>
/// Domain-specific parser for block structures using DDD principles.
/// Encapsulates the business logic for parsing document blocks and nested content.
/// </summary>
public static class BlockParser
{
    /// <summary>
    /// Parses a block from a token stream using functional patterns.
    /// </summary>
    /// <param name="stream">The token stream positioned at block content</param>
    /// <returns>A tuple containing the parsed block and the updated stream</returns>
    public static (Block block, TokenStream stream) ParseBlock(TokenStream stream)
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
                    (head, currentStream) = HeadParser.ParseHead(currentStream);
                    break;
                    
                case TokenType.BlockStart:
                    (body, currentStream) = ProcessNestedBlockInBlock(currentStream, body);
                    break;
                    
                case TokenType.BlockEnd:
                    currentStream = currentStream.Advance();
                    return (CreateFinalBlock(block, head, body), currentStream);
                    
                case TokenType.ListStart:
                    (body, currentStream) = ProcessListInBlock(currentStream, body);
                    break;
                    
                case TokenType.DictStart:
                    (body, currentStream) = ProcessDictionaryInBlock(currentStream, body);
                    break;
                    
                case TokenType.Text:
                    (body, currentStream) = ProcessTextInBlock(currentStream, body);
                    break;
                    
                default:
                    currentStream = currentStream.Advance();
                    break;
            }
        }
        
        return (CreateFinalBlock(block, head, body), currentStream);
    }

    private static (List<ContentNode> body, TokenStream stream) ProcessNestedBlockInBlock(TokenStream stream, List<ContentNode> body)
    {
        var currentStream = stream.Advance();
        var (nestedBlock, nextStream) = ParseBlock(currentStream);
        var updatedBody = new List<ContentNode>(body) { nestedBlock };
        return (updatedBody, nextStream);
    }

    private static (List<ContentNode> body, TokenStream stream) ProcessListInBlock(TokenStream stream, List<ContentNode> body)
    {
        var (listBlock, listStream) = ListParser.ParseList(stream);
        var updatedBody = new List<ContentNode>(body) { listBlock };
        return (updatedBody, listStream);
    }

    private static (List<ContentNode> body, TokenStream stream) ProcessDictionaryInBlock(TokenStream stream, List<ContentNode> body)
    {
        var (dict, dictStream) = DictionaryParser.ParseDictionary(stream);
        var updatedBody = new List<ContentNode>(body) { dict };
        return (updatedBody, dictStream);
    }

    private static (List<ContentNode> body, TokenStream stream) ProcessTextInBlock(TokenStream stream, List<ContentNode> body)
    {
        var (textLines, textStream) = TextLineParser.ParseTextLines(stream);
        var textContent = ContentNodeFactory.CreateTextContentFromLines(textLines);
        var updatedBody = new List<ContentNode>(body);
        updatedBody.AddRange(textContent);
        return (updatedBody, textStream);
    }

    private static Block CreateFinalBlock(Block block, string? head, List<ContentNode> body)
    {
        return block with 
        { 
            Head = head, 
            Body = body.Count > 0 ? body : null 
        };
    }

    /// <summary>
    /// Validates that a token stream is positioned at a valid block start token.
    /// </summary>
    /// <param name="stream">The token stream to validate</param>
    /// <returns>True if positioned at a block start token</returns>
    public static bool IsAtBlockStart(TokenStream stream)
    {
        return !stream.IsAtEnd && stream.Current.Type == TokenType.BlockStart;
    }

    /// <summary>
    /// Parses a document root block (entry point for parsing).
    /// </summary>
    /// <param name="stream">The token stream to parse</param>
    /// <returns>The parsed root block</returns>
    public static Block ParseDocument(TokenStream stream)
    {
        return ParseBlock(stream).block;
    }
}