# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains three complete implementations of the TimeToAct DocumentAI specification - a structured document parsing system that converts business documents into JSON format suitable for AI assistants. The implementations are:

- **C# (.NET 8)**: Object-oriented implementation with comprehensive parsing and immutable data structures
- **F# (.NET 8)**: Functional programming approach with discriminated unions and domain-driven design  
- **JavaScript**: Vanilla JavaScript implementation for simple parsing scenarios

All implementations follow the same specification in `spec.md` and produce identical JSON output.

## Development Commands

### C# Implementation (`csharp/` directory)

```bash
# Build the solution
dotnet build TimeToActDocumentAI.sln

# Run all tests
dotnet test TimeToActDocumentAI.Tests

# Run tests with verbose output
dotnet test TimeToActDocumentAI.Tests --verbosity normal

# Run specific test method
dotnet test TimeToActDocumentAI.Tests --filter "TestMethodName"

# Run example application
dotnet run --project TimeToActDocumentAI.Example

# Build specific project
dotnet build TimeToActDocumentAI/TimeToActDocumentAI.csproj
```

### F# Implementation (`fsharp/` directory)

```bash
# Build the solution
dotnet build TimeToActParser.sln

# Run all tests
dotnet test TimeToActParser.Tests

# Run tests with verbose output
dotnet test TimeToActParser.Tests --verbosity normal

# Run specific test method
dotnet test TimeToActParser.Tests --filter "TestMethodName"

# Run main application
dotnet run --project TimeToActParser

# Build specific project
dotnet build TimeToActParser/TimeToActParser.fsproj
```

### JavaScript Implementation (`js/` directory)

```bash
# Run basic unit tests
node documentai.test.js

# Run tests against official test data
node run-tests.js
```

## Architecture Overview

### C# Implementation Architecture

The C# implementation uses modern object-oriented design with:

- **Models** (`TimeToActDocumentAI.Models/`): Immutable record types for all content structures
  - `ContentNode`: Base class for all content types
  - `Block`: Primary container with optional head, number, and body  
  - `ListBlock`: Ordered/unordered list structures
  - `Dictionary`: Key-value pairs with configurable separators
- **Parsing** (`TimeToActDocumentAI.Parsing/`): Comprehensive parsing pipeline
  - `DocumentParser`: Core parsing logic with context-aware nesting
  - `Lexer`: Tokenization of structured text
  - `ParseContext`, `ContentNodeFactory`: Advanced parsing support
- **API** (`DocumentAI.cs`): Main entry point with JSON serialization

### F# Implementation Architecture

The F# implementation uses functional programming patterns with:

- **Types** (`Types.fs`): Discriminated unions and value objects for domain modeling
- **DocumentParser** (`DocumentParser.fs`): Pure functional parsing with active patterns
- **JsonSerializer** (`JsonSerializer.fs`): Custom JSON serialization respecting the specification

### JavaScript Implementation Architecture

The JavaScript implementation uses a simple recursive descent parser:

- Single-file implementation with `parse()` as main entry point
- Recursive parsing functions for each document element type
- String-based parsing with smart nesting logic

## Key Design Patterns

### Domain-Driven Design
Both .NET implementations follow DDD principles with explicit domain modeling, value objects, and clear boundaries between parsing, domain logic, and serialization.

### Immutability
All data structures are immutable (C# records, F# types, JavaScript objects), ensuring thread safety and preventing accidental mutations.

### Specification Compliance
All implementations strictly follow the parsing rules defined in `spec.md`, with comprehensive test coverage using the official test data in `test-data/`.

## Test Data and Validation

The repository includes comprehensive test data in `test-data/`:
- `basic-blocks.json`: Simple document structures
- `dictionaries.json`: Key-value pair parsing
- `lists.json`: List structures and nesting
- `complex-scenarios.json`: Mixed content and advanced parsing

When making changes, ensure all tests pass and new functionality includes corresponding test cases.

## Implementation Status

### C# Implementation
- **Status**: Complete - 56/56 tests passing (100%)
- **Key Features**: Advanced parsing with lookahead, context-aware nesting, sophisticated mixed list handling
- **Architecture**: Clean separation of concerns with comprehensive domain modeling

### F# Implementation  
- **Status**: Complete - Full specification compliance
- **Key Features**: Functional parsing with active patterns, type-safe domain modeling
- **Architecture**: Pure functional approach with discriminated unions

### JavaScript Implementation
- **Status**: Complete - All test suites passing
- **Key Features**: Simple recursive descent parser, mixed content support
- **Architecture**: Single-file implementation focused on simplicity

## Requirements

- .NET 8.0 or later (for C# and F# implementations)
- Node.js (for JavaScript implementation)
- All implementations use standard runtime libraries

## Project Structure Notes

- Each implementation has its own README with specific details
- The `csharp/todos.md` file tracks implementation progress and technical decisions
- All implementations produce identical JSON output as verified by the test suites
- The specification in `spec.md` is the authoritative source for parsing behavior