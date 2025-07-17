# TimeToAct DocumentAI - C# Implementation

A modern C# implementation of the TimeToAct DocumentAI specification for parsing structured business documents into JSON format suitable for AI assistants.

## Features

- **Modern C# (.NET 8)**: Built with the latest C# features including records, pattern matching, and nullable reference types
- **Immutable Data Structures**: Uses records for better reliability and thread safety
- **System.Text.Json**: Modern, high-performance JSON serialization
- **Polymorphic Serialization**: Proper handling of different content types in JSON
- **Comprehensive Testing**: Unit tests covering all specification examples

## Quick Start

### Installation

```bash
# Build the solution
dotnet build TimeToActDocumentAI.sln

# Run tests
dotnet test TimeToActDocumentAI.Tests

# Run example
dotnet run --project TimeToActDocumentAI.Example
```

### Basic Usage

```csharp
using TimeToActDocumentAI;

// Parse a document
var input = """
    <head>Software License Agreement</head>
    This agreement is entered into on the date last signed below.
    
    <dict sep=":">
    Licensor: TechCorp Inc.
    Licensee: ClientCo Ltd.
    </dict>
    """;

var document = DocumentAI.ParseDocument(input);
var json = DocumentAI.ToJson(document);
Console.WriteLine(json);
```

## Architecture

### Core Components

1. **Models** (`TimeToActDocumentAI.Models`):
   - `ContentNode`: Base class for all content types
   - `Block`: Container for structured content with optional head and numbering
   - `ListBlock`: Ordered or unordered lists
   - `Dictionary`: Key-value pairs with configurable separators
   - `TextContent`: Plain text content

2. **Parsing** (`TimeToActDocumentAI.Parsing`):
   - `Lexer`: Tokenizes input text into structured tokens
   - `DocumentParser`: Converts tokens into document structure
   - `Token`: Represents parsed elements with position information

3. **Serialization**:
   - `DocumentAI`: Main API class with parsing and JSON conversion
   - `ContentNodeJsonConverter`: Custom JSON converter for polymorphic content

### Key Design Decisions

- **Records over Classes**: Immutable data structures for better reliability
- **Nullable Reference Types**: Explicit handling of null values
- **System.Text.Json**: Modern, high-performance JSON serialization
- **Polymorphic Serialization**: Proper handling of different content types in JSON

## Examples

### Contract Document
```csharp
var contract = """
    <head>Service Agreement</head>
    This agreement defines the terms of service.
    
    <dict sep=":">
    Client: Acme Corp
    Provider: Tech Solutions Inc.
    Effective Date: 2024-01-01
    </dict>
    
    <list kind=".">
    1. Service Scope
    The provider will deliver the following services:
    <list kind="*">
    • Web development
    • System maintenance
    • Technical support
    </list>
    
    2. Payment Terms
    Payment is due within 30 days of invoice.
    </list>
    """;

var result = DocumentAI.ParseDocument(contract);
```

### Procedure Document
```csharp
var procedure = """
    <head>Incident Response Procedure</head>
    Follow these steps when an incident occurs:
    
    <list kind=".">
    1. Immediate Response
    <dict sep="-">
    Timeline - Within 15 minutes
    Responsible - On-call engineer
    </dict>
    
    2. Assessment Phase
    Evaluate the severity and impact.
    
    3. Resolution
    Implement fixes and monitor results.
    </list>
    """;

var result = DocumentAI.ParseDocument(procedure);
```

## Development

### Building

```bash
# Build the entire solution
dotnet build TimeToActDocumentAI.sln

# Build specific project
dotnet build TimeToActDocumentAI/TimeToActDocumentAI.csproj
```

### Testing

```bash
# Run all tests
dotnet test TimeToActDocumentAI.Tests

# Run tests with verbose output
dotnet test TimeToActDocumentAI.Tests --verbosity normal

# Run specific test method
dotnet test TimeToActDocumentAI.Tests --filter "TestMethodName"
```

### Running Examples

```bash
# Run the example application
dotnet run --project TimeToActDocumentAI.Example
```

## Project Structure

```
TimeToActDocumentAI/
├── Models/
│   ├── ContentNode.cs      # Base content type
│   ├── Block.cs           # Main document container
│   ├── ListBlock.cs       # List structures
│   └── Dictionary.cs      # Key-value pairs
├── Parsing/
│   ├── Token.cs           # Token definitions
│   ├── Lexer.cs           # Lexical analyzer
│   └── DocumentParser.cs  # Document parser
└── DocumentAI.cs          # Main API class

TimeToActDocumentAI.Tests/
└── DocumentAITests.cs     # Comprehensive unit tests

TimeToActDocumentAI.Example/
└── Program.cs             # Example usage
```

## JSON Output Format

The parser produces JSON that matches the TimeToAct DocumentAI specification:

```json
{
  "kind": "block",
  "head": "Document Title",
  "body": [
    "Plain text content",
    {
      "kind": "dict",
      "items": {
        "key1": "value1",
        "key2": "value2"
      }
    },
    {
      "kind": "list",
      "items": [
        {
          "kind": "block",
          "number": "1.",
          "body": ["List item content"]
        }
      ]
    }
  ]
}
```

## Specification Compliance

This implementation follows the complete TimeToAct DocumentAI specification defined in [../spec.md](../spec.md). All examples in the specification are implemented as unit tests to ensure compliance.

## Requirements

- .NET 8.0 or later
- System.Text.Json (included in .NET 8)

## License

This implementation is provided as a reference implementation of the TimeToAct DocumentAI specification.