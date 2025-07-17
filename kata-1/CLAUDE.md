# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TimeToActDocumentAI is a modern C# implementation of the TimeToAct DocumentAI specification for parsing structured business documents into JSON format suitable for AI assistants. It converts documents like contracts and procedures into structured JSON while preserving semantic meaning.

## Technology Stack

- **.NET 8** with latest C# language features
- **System.Text.Json** for high-performance JSON serialization
- **xUnit** for unit testing
- **Records** for immutable data structures
- **Nullable reference types** for better null safety

## Common Development Commands

```bash
# Build the solution
dotnet build TimeToActDocumentAI.sln

# Run unit tests
dotnet test TimeToActDocumentAI.Tests

# Run example application
dotnet run --project TimeToActDocumentAI.Example

# Build for release
dotnet build TimeToActDocumentAI.sln --configuration Release

# Run specific test
dotnet test TimeToActDocumentAI.Tests --filter "TestMethodName"
```

## Architecture Overview

### Core Components

1. **Models** (`TimeToActDocumentAI.Models/`):
   - `ContentNode`: Base record for all content types
   - `Block`: Main container for structured content with optional head and numbering
   - `ListBlock`: Ordered or unordered lists with hierarchical support
   - `Dictionary`: Key-value pairs with configurable separators
   - `TextContent`: Plain text content

2. **Parsing Pipeline** (`TimeToActDocumentAI.Parsing/`):
   - `Lexer`: Tokenizes input text into structured tokens
   - `DocumentParser`: Converts tokens into document structure
   - `Token`: Represents parsed elements with position information

3. **Serialization**:
   - `DocumentAI`: Main API class with parsing and JSON conversion
   - `ContentNodeJsonConverter`: Custom JSON converter for polymorphic content

### Key Design Patterns

- **Immutable Data Structures**: Uses records for thread-safe, immutable content
- **Polymorphic Serialization**: Proper JSON handling of different content types
- **Clean Architecture**: Clear separation between lexing, parsing, and serialization
- **Modern C# Features**: Pattern matching, nullable reference types, latest language features

## Document Format Support

The parser handles these content types:

### Plain Text
```
First paragraph.
Second paragraph.
```

### Headed Blocks
```
<head>Section Title</head>
Content goes here.
```

### Dictionaries
```
<dict sep=":">
Key1: Value1
Key2: Value2
</dict>
```

### Lists
```
<list kind=".">
1. First item
2. Second item
2.1. Sub-item
</list>
```

### Nested Blocks
```
<head>Main Section</head>
<block>
<head>Subsection</head>
Content
</block>
```

## Testing Strategy

### Unit Tests (`TimeToActDocumentAI.Tests/`)
- **Coverage**: All major parsing scenarios and edge cases
- **Structure**: Comprehensive test suite in `DocumentAITests.cs`
- **Validation**: Tests parsing, serialization, and round-trip JSON conversion

### Example Application (`TimeToActDocumentAI.Example/`)
- **Purpose**: Demonstrates real-world usage patterns
- **Content**: Contract and procedure document examples
- **Usage**: Run to see parsing results and JSON output

## Development Patterns

### C# Modern Features
- **Records**: Immutable data structures for reliability
- **Nullable Reference Types**: Explicit null handling
- **Pattern Matching**: Clean conditional logic
- **Latest C# Language Version**: Uses cutting-edge language features

### Error Handling
- Comprehensive validation during parsing
- Clear error messages with position information
- Graceful handling of malformed input

### Performance Considerations
- **System.Text.Json**: High-performance JSON serialization
- **Immutable Structures**: Thread-safe operations
- **Efficient Parsing**: Single-pass lexing and parsing

## JSON Output Format

Produces JSON conforming to TimeToAct DocumentAI specification:

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

## Usage Examples

### Basic Parsing
```csharp
var document = DocumentAI.ParseDocument(input);
var json = DocumentAI.ToJson(document);
```

### Contract Processing
```csharp
var contract = DocumentAI.ParseDocument(contractText);
// Process structured contract data
```

### Procedure Documentation
```csharp
var procedure = DocumentAI.ParseDocument(procedureText);
// Convert to JSON for AI processing
```