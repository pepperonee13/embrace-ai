# TimeToAct DocumentAI - C# Implementation

A modern C# implementation of the TimeToAct DocumentAI specification for parsing structured business documents into JSON format suitable for AI assistants.

## Features

- **Modern C# (.NET 8)**: Built with the latest C# features including records, pattern matching, and nullable reference types
- **Structured Document Parsing**: Converts business documents (contracts, procedures, etc.) into structured JSON
- **Flexible Content Types**: Supports text, nested blocks, dictionaries, and lists
- **JSON Serialization**: Full round-trip JSON serialization support
- **Comprehensive Testing**: Unit tests covering all major functionality
- **Clean Architecture**: Separation of concerns with lexical analysis, parsing, and serialization layers

## Quick Start

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

### Document Structure

The parser supports these main content types:

#### 1. Plain Text
```
First paragraph.
Second paragraph.
```

#### 2. Headed Blocks
```
<head>Section Title</head>
Content goes here.
```

#### 3. Dictionaries
```
<dict sep=":">
Key1: Value1
Key2: Value2
</dict>
```

#### 4. Lists
```
<list kind=".">
1. First item
2. Second item
2.1. Sub-item
</list>
```

#### 5. Nested Blocks
```
<head>Main Section</head>
Introduction text
<block>
<head>Subsection</head>
Detailed content
</block>
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

## Testing

Run the unit tests:

```bash
dotnet test TimeToActDocumentAI.Tests
```

Run the example application:

```bash
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

## Requirements

- .NET 8.0 or later
- System.Text.Json (included in .NET 8)

## License

This implementation is provided as a reference implementation of the TimeToAct DocumentAI specification.