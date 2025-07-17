# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains two implementations of the TimeToAct DocumentAI specification - a structured document parser that converts business documents into JSON format suitable for AI assistants. Both implementations follow the same specification defined in `spec.md`.

## Project Structure

The repository contains two separate implementations:

- **C# Implementation** (`csharp/`): Modern .NET 8 implementation with comprehensive testing
- **F# Implementation** (`fsharp/`): Functional programming approach with domain-driven design

### C# Implementation (`csharp/`)
- `TimeToActDocumentAI/` - Core library with Models, Parsing, and main DocumentAI class
- `TimeToActDocumentAI.Tests/` - XUnit test suite
- `TimeToActDocumentAI.Example/` - Example usage application

### F# Implementation (`fsharp/`)
- `TimeToActParser/` - Core library with Types, DocumentParser, JsonSerializer modules
- `TimeToActParser.Tests/` - XUnit test suite with spec-based tests

## Common Development Tasks

### Building and Testing

**C# Implementation:**
```bash
# Build the solution
dotnet build csharp/TimeToActDocumentAI.sln

# Run all tests
dotnet test csharp/TimeToActDocumentAI.Tests

# Run the example application
dotnet run --project csharp/TimeToActDocumentAI.Example
```

**F# Implementation:**
```bash
# Build the solution
dotnet build fsharp/TimeToActParser.sln

# Run all tests
dotnet test fsharp/TimeToActParser.Tests

# Run the main application
dotnet run --project fsharp/TimeToActParser
```

### Running Individual Tests

**C# Tests:**
```bash
# Run specific test method
dotnet test csharp/TimeToActDocumentAI.Tests --filter "TestMethodName"

# Run tests with verbose output
dotnet test csharp/TimeToActDocumentAI.Tests --verbosity normal
```

**F# Tests:**
```bash
# Run specific test
dotnet test fsharp/TimeToActParser.Tests --filter "TestMethodName"
```

## Architecture and Design

### C# Implementation Architecture
- **Models**: Records-based immutable data structures (Block, ListBlock, Dictionary, ContentNode)
- **Parsing**: Lexer tokenizes input, DocumentParser builds structure
- **Serialization**: Custom JsonConverter handles polymorphic ContentNode types
- **Design**: Modern C# features (records, nullable reference types, pattern matching)

### F# Implementation Architecture
- **Types**: Discriminated unions for ContentNode, domain-specific value objects
- **DocumentParser**: Functional parsing with active patterns
- **JsonSerializer**: JSON conversion respecting the specification format
- **Design**: Domain-driven design with functional programming principles

### Key Domain Types

Both implementations support the same core content types:
- **Block**: Main container with optional head, number, and body content
- **ListBlock**: Ordered (numbered) or bulleted lists
- **Dictionary**: Key-value pairs with configurable separators
- **Text**: Plain text content

### Document Format

The parser handles structured documents with these elements:
- `<head>Title</head>` - Document/section headers
- `<block>...</block>` - Nested content blocks
- `<list kind=".">` or `<list kind="*">` - Ordered or bulleted lists
- `<dict sep=":">` - Key-value dictionaries with custom separators

## Testing Strategy

Both implementations follow the specification in `spec.md` which serves as both documentation and test cases. The spec provides input/output pairs that define expected behavior.

### Test Structure
- **Specification Tests**: Direct implementation of examples from `spec.md`
- **Edge Cases**: Empty documents, nested structures, complex mixed content
- **JSON Serialization**: Round-trip testing for data integrity

## Technology Stack

- **.NET 8**: Both implementations target .NET 8.0
- **Testing**: XUnit framework for both C# and F# tests
- **JSON**: System.Text.Json for serialization in C#, custom implementation in F#
- **C# Features**: Records, nullable reference types, pattern matching, implicit usings
- **F# Features**: Discriminated unions, active patterns, type providers, functional composition

## Development Guidelines

### Code Quality
- Follow TDD principles as specified in global CLAUDE.md
- Maintain immutable data structures where possible
- Use appropriate language idioms (C# records, F# discriminated unions)
- Ensure comprehensive test coverage for all specification examples

### When Working with Tests
- Always run full test suite before making changes
- New features should include corresponding test cases
- Follow the specification examples in `spec.md` for expected behavior
- Use descriptive test names that reflect the specification being tested

## Specification Compliance

Both implementations must conform to the TimeToAct DocumentAI specification in `spec.md`. The specification includes:
- Input/output examples for all supported document formats
- JSON structure requirements
- Parsing rules for nested content
- Handling of edge cases and empty content

Any changes to parsing logic should be validated against the complete specification test suite.