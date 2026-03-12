# DocumentAI JavaScript Implementation

A simple vanilla JavaScript implementation of the TimeToAct DocumentAI specification.

## Features

- ✅ Empty document parsing
- ✅ Plain text parsing (single and multiple paragraphs)
- ✅ Head parsing (`<head>Title</head>`)
- ✅ Nested blocks (`<block>...</block>`)
- ✅ Dictionaries (`<dict sep="...">...</dict>`)
- ✅ Simple lists (`<list kind="...">...</list>`)
- ✅ Nested lists (full support)
- ✅ Complex mixed content scenarios (full support)

## Usage

```javascript
const { parse } = require('./documentai.js');

// Parse a simple document
const result = parse('<head>Title</head>\nContent');
console.log(result);
// { kind: "block", head: "Title", body: ["Content"] }
```

## Running Tests

```bash
# Run basic unit tests
node documentai.test.js

# Run tests against official test data
node run-tests.js
```

## Architecture

The implementation follows a simple recursive descent parser pattern:

- `parse()` - Main entry point
- `parseBlock()` - Handles block-level parsing
- `parseDict()` - Handles dictionary parsing
- `parseList()` - Handles list parsing
- `extractBlock()` / `extractTag()` - Extract content between tags

## Test Results

Current test status against official test data:
- ✅ Basic Blocks: 5/5 tests passing
- ✅ Dictionaries: 2/2 tests passing  
- ✅ Lists: 4/4 tests passing (all list types fully supported)
- ✅ Complex Scenarios: 2/2 tests passing (mixed content fully supported)

## Implementation Notes

This is a complete implementation of the DocumentAI specification focusing on simplicity and readability. It successfully handles all document structures including complex nested scenarios and mixed content. The parser uses string matching and recursive content processing with smart nesting logic for different list types.

Key features:
- Recursive parsing for nested structures
- Mixed content support (text, dictionaries, lists within lists)
- Smart nesting logic that handles both pure nested lists and mixed content scenarios
- Proper handling of different list types (ordered with dots, bulleted with various markers)