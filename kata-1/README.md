# TimeToAct DocumentAI

Two reference implementations of the TimeToAct DocumentAI specification for parsing structured business documents into JSON format suitable for AI assistants.

## Overview

This repository contains two complete implementations of the same specification:

- **[C# Implementation](csharp/)**: Modern .NET 8 implementation with comprehensive object-oriented design
- **[F# Implementation](fsharp/)**: Functional programming approach with domain-driven design

Both implementations follow the same [DocumentAI specification](spec.md) and produce identical JSON output.

## What is TimeToAct DocumentAI?

TimeToAct DocumentAI provides a simple, structured document format for describing business documents like contracts, procedures, or any structured content. It converts human-readable structured text into JSON format that can be easily consumed by AI assistants.

## Key Features

- **Structured Document Parsing**: Converts business documents into structured JSON
- **Flexible Content Types**: Supports text, nested blocks, dictionaries, and lists  
- **Two Language Implementations**: Choose between C# (OOP) or F# (functional) approaches
- **Comprehensive Testing**: Both implementations include full test suites
- **Specification-Driven**: Development follows the detailed specification in [spec.md](spec.md)

## Quick Start

Choose your preferred implementation:

- **[C# Implementation](csharp/)** - Object-oriented approach with modern C# features
- **[F# Implementation](fsharp/)** - Functional programming with domain-driven design

### Example Input

```
<head>Software License Agreement</head>
This agreement is entered into on the date last signed below.

<dict sep=":">
Licensor: TechCorp Inc.
Licensee: ClientCo Ltd.
</dict>

<list kind=".">
1. Grant of License
2. Restrictions
3. Termination
</list>
```

### Expected JSON Output

```json
{
  "kind": "block",
  "head": "Software License Agreement",
  "body": [
    "This agreement is entered into on the date last signed below.",
    {
      "kind": "dict",
      "items": {
        "Licensor": "TechCorp Inc.",
        "Licensee": "ClientCo Ltd."
      }
    },
    {
      "kind": "list",
      "items": [
        { "kind": "block", "number": "1.", "head": "Grant of License" },
        { "kind": "block", "number": "2.", "head": "Restrictions" },
        { "kind": "block", "number": "3.", "head": "Termination" }
      ]
    }
  ]
}
```

## Supported Document Elements

Both implementations support the complete specification defined in [spec.md](spec.md):

- **Plain Text**: Simple paragraphs and content
- **Headed Blocks**: `<head>Title</head>` for section headers
- **Nested Blocks**: `<block>...</block>` for hierarchical content
- **Dictionaries**: `<dict sep=":">` for key-value pairs with configurable separators
- **Lists**: `<list kind=".">` for ordered lists, `<list kind="*">` for bulleted lists
- **Mixed Content**: Complex documents with nested structures

## Getting Started

1. **Read the specification**: Start with [spec.md](spec.md) to understand the document format
2. **Choose your implementation**: 
   - For C#: See [csharp/README.md](csharp/README.md)
   - For F#: See [fsharp/README.md](fsharp/README.md)
3. **Run the examples**: Both implementations include working examples
4. **Run the tests**: Both implementations have comprehensive test suites based on the specification

## Implementation Details

Each implementation follows the same specification but uses different programming paradigms:

- **C# Implementation**: Object-oriented design with modern C# features (records, nullable reference types)
- **F# Implementation**: Functional programming with discriminated unions and domain-driven design

Both produce identical JSON output and pass the same specification-based test suite.

## Requirements

- .NET 8.0 or later
- Both implementations use standard .NET libraries

## Contributing

When making changes to either implementation:

1. Follow the [specification](spec.md) exactly
2. Ensure all tests pass
3. Both implementations should produce identical output
4. Add tests for new features using examples from the specification

## License

These implementations are provided as reference implementations of the TimeToAct DocumentAI specification.