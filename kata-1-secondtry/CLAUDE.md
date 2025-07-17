# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a coding kata for implementing a TimeToAct DocumentAI parser. The goal is to create a parser that can convert a structured text format into JSON objects according to the specification defined in `spec.md`.

## Architecture

The project is currently empty and needs to be implemented from scratch. The task is to:

1. Implement a parser for the TimeToAct document format
2. Support parsing of blocks, lists, dictionaries, and mixed content
3. Convert the parsed content into JSON objects with the specified structure

## Document Format Specification

The parser must handle:
- **Blocks**: Basic containers with optional head, number, and body
- **Lists**: Ordered (`.`) and bulleted (`*`) lists with nested support
- **Dictionaries**: Key-value pairs with customizable separators
- **Mixed Content**: Complex documents combining all element types

Key data structures (based on Python spec in `spec.md`):
- `Block`: General container with `kind`, `number`, `head`, and `body` fields
- `ListBlock`: Container for list items with `kind` and `items` fields
- `Dictionary`: Key-value pairs with `kind` and `items` fields

## Implementation Requirements

- Parse text format deterministically into JSON
- Handle nested structures and mixed content
- Support hierarchical lists with proper numbering
- Process dictionary separators (`:` default, customizable)
- Strip and skip empty lines
- Maintain structural integrity as defined in test cases

## Test Cases

The `spec.md` file contains comprehensive test cases with input/output pairs. Each test shows:
- Input text format
- Expected JSON output structure
- Specific parsing rules and edge cases

Use these test cases to validate implementation correctness.

## F# Implementation

Located in `fsharp/` folder:

### Build Commands
```bash
dotnet build
dotnet test
dotnet run --project TimeToActParser
```

### Project Structure
- `TimeToActParser/` - Main parser implementation
  - `Types.fs` - Data type definitions
  - `TddParser.fs` - Complete TDD-built parser implementation
  - `JsonSerializer.fs` - JSON serialization
  - `Program.fs` - Console application
- `TimeToActParser.Tests/` - xUnit test project
  - `SpecTests.fs` - Comprehensive test suite based on spec.md

### Current Status
- ✅ Full spec compliance achieved using TDD principles
- ✅ All data types implemented: Block, ListBlock, Dictionary, ContentNode
- ✅ All parsing features working: head tags, nested blocks, dictionaries with custom separators, ordered/bulleted lists, mixed content
- ✅ Complex nested structures supported: lists with content and embedded dictionaries
- ✅ Comprehensive test suite: 13 tests covering all spec.md test cases
- ✅ JSON serialization working correctly
- ✅ Built using Test-Driven Development (RED-GREEN-REFACTOR cycle)

### Implementation Approach
The parser was built incrementally using TDD:
1. **RED**: Write failing tests for each feature
2. **GREEN**: Implement minimum code to pass tests  
3. **REFACTOR**: Improve code structure while keeping tests green

### Parser Features
- **Text parsing**: Handles plain text with paragraph separation
- **Head extraction**: `<head>Title</head>` tags
- **Nested blocks**: `<block>...</block>` structures
- **Dictionaries**: `<dict sep="separator">key: value</dict>` with custom separators
- **Ordered lists**: `<list kind=".">1. Item</list>` with numbered items
- **Bulleted lists**: `<list kind="*">• Item</list>` with bullet points
- **Mixed content**: Lists can contain text and nested structures
- **Complex nesting**: All structures can be nested within each other