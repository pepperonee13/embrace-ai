using TimeToActDocumentAI.Models;

namespace TimeToActDocumentAI.Parsing;

public class DocumentParser
{
    private readonly TokenStream _initialStream;

    public DocumentParser(IEnumerable<Token> tokens)
    {
        _initialStream = new TokenStream(tokens);
    }

    public Block Parse()
    {
        return BlockParser.ParseDocument(_initialStream);
    }






}