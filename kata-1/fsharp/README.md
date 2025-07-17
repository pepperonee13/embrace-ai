# TimeToAct DocumentAI - F# Implementation

A functional F# implementation of the TimeToAct DocumentAI specification for parsing structured business documents into JSON format suitable for AI assistants.

## Features

- **Functional Programming**: Immutable data structures and pure functions
- **Domain-Driven Design**: Explicit domain modeling with discriminated unions and value objects
- **Type Safety**: Leverages F#'s strong type system for correctness
- **Active Patterns**: Uses F# active patterns for elegant parsing logic
- **Comprehensive Testing**: Unit tests covering all specification examples

## Quick Start

### Installation

```bash
# Build the solution
dotnet build TimeToActParser.sln

# Run tests
dotnet test TimeToActParser.Tests

# Run example
dotnet run --project TimeToActParser
```

### Basic Usage

```fsharp
open TimeToActParser.DocumentParser
open TimeToActParser.JsonSerializer

let input = """<head>Software License Agreement</head>
This agreement is entered into on the date last signed below.

<dict sep=":">
Licensor: TechCorp Inc.
Licensee: ClientCo Ltd.
</dict>"""

let document = parseDocument input
let json = toJson document
printfn "%s" json
```

## Architecture

### Core Components

1. **Types** (`TimeToActParser.Types`):
   - `ContentNode`: Discriminated union for all content types
   - `Block`: Record type for structured content containers
   - `ListBlock`: Record type for ordered/unordered lists
   - `Dictionary`: Record type for key-value pairs
   - Domain-specific value objects (`DocumentHead`, `Separator`, `ListMarker`)

2. **DocumentParser** (`TimeToActParser.DocumentParser`):
   - Functional parsing with active patterns
   - Recursive descent parser for nested structures
   - Domain-specific parsing operations

3. **JsonSerializer** (`TimeToActParser.JsonSerializer`):
   - Custom JSON serialization respecting the specification
   - Recursive serialization for nested structures

### Key Design Decisions

- **Discriminated Unions**: Type-safe representation of different content types
- **Value Objects**: Domain-specific types for better modeling
- **Immutable Data**: All data structures are immutable
- **Active Patterns**: Elegant pattern matching for parsing logic
- **Functional Composition**: Pure functions composed together

## Domain Model

### Core Types

```fsharp
// Discriminated union for content
type ContentNode = 
    | Text of string
    | Block of Block
    | ListBlock of ListBlock
    | Dictionary of Dictionary

// Record types for structured data
type Block = {
    Number: ListMarker option
    Head: DocumentHead option
    Body: ContentNode list
}

type ListBlock = {
    Kind: ListKind
    Items: Block list
}

type Dictionary = {
    Separator: Separator
    Items: Map<string, string>
}
```

### Value Objects

```fsharp
// Domain-specific value objects
type DocumentHead = DocumentHead of string
type Separator = Separator of string
type ListMarker = 
    | OrderedList of string
    | BulletedList of string
```

## Examples

### Contract Document
```fsharp
let contract = """<head>Service Agreement</head>
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
</list>"""

let result = parseDocument contract
```

### Procedure Document
```fsharp
let procedure = """<head>Incident Response Procedure</head>
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
</list>"""

let result = parseDocument procedure
```

## Development

### Building

```bash
# Build the entire solution
dotnet build TimeToActParser.sln

# Build specific project
dotnet build TimeToActParser/TimeToActParser.fsproj
```

### Testing

```bash
# Run all tests
dotnet test TimeToActParser.Tests

# Run tests with verbose output
dotnet test TimeToActParser.Tests --verbosity normal

# Run specific test method
dotnet test TimeToActParser.Tests --filter "TestMethodName"
```

### Running Examples

```bash
# Run the main application
dotnet run --project TimeToActParser
```

## Project Structure

```
TimeToActParser/
├── Types.fs               # Domain types and value objects
├── DocumentParser.fs      # Functional parsing logic
├── JsonSerializer.fs      # Custom JSON serialization
└── Program.fs            # Main entry point

TimeToActParser.Tests/
├── SpecTests.fs          # Specification-based tests
└── Program.fs            # Test runner
```

## Functional Programming Approach

This implementation showcases functional programming principles:

### Immutability
All data structures are immutable, preventing accidental mutations and making the code more predictable.

### Pure Functions
Parsing functions are pure - they take input and return output without side effects.

### Type Safety
The F# type system prevents many runtime errors through compile-time checks.

### Pattern Matching
Discriminated unions and pattern matching provide elegant handling of different content types.

### Composition
Complex parsing operations are built by composing simpler functions.

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
- F# runtime (included with .NET 8)

## License

This implementation is provided as a reference implementation of the TimeToAct DocumentAI specification.