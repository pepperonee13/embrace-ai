# TimeToAct DocumentAI Specification

## Overview

TimeToAct DocumentAI is a specification for parsing structured business documents (contracts, procedures, policies) into a standardized JSON format suitable for AI processing. It converts documents with markup syntax into a hierarchical structure that preserves semantic meaning.

## Core Concepts

### Document Structure

All documents are parsed into a root `Block` containing:
- **Head**: Optional document title
- **Body**: List of content elements (text, nested blocks, lists, dictionaries)
- **Number**: Optional numbering (for list items)

### Content Types

1. **Text Content**: Plain text paragraphs
2. **Block**: Container with optional head and body content
3. **List Block**: Ordered or unordered lists with items
4. **Dictionary**: Key-value pairs with configurable separators

### Markup Syntax

#### Headed Blocks
```
<head>Section Title</head>
Content goes here.
```

#### Nested Blocks
```
<block>
<head>Subsection</head>
Content
</block>
```

#### Dictionaries
```
<dict sep=":">
Key1: Value1
Key2: Value2
</dict>
```

#### Lists
```
<list kind=".">
1. First item
2. Second item
2.1. Sub-item
</list>

<list kind="*">
• Bullet item
• Another bullet
</list>
```

## JSON Output Format

### Root Document
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

### Content Node Types

#### Text Content
```json
"Simple text string"
```

#### Block
```json
{
  "kind": "block",
  "head": "Optional Title",
  "number": "Optional Number",
  "body": [/* content nodes */]
}
```

#### List Block
```json
{
  "kind": "list",
  "items": [
    {
      "kind": "block",
      "number": "1.",
      "body": ["Item content"]
    }
  ]
}
```

#### Dictionary
```json
{
  "kind": "dict",
  "items": {
    "key1": "value1",
    "key2": "value2"
  }
}
```

## Parsing Rules

### Text Processing
- Empty lines separate paragraphs
- Leading/trailing whitespace is trimmed
- Empty or whitespace-only input produces empty block

### Dictionary Parsing
- Default separator is ":"
- Custom separators specified in `sep` attribute
- Multi-character separators supported
- Only first occurrence of separator used for splitting
- Empty values allowed

### List Processing
- Ordered lists: `kind="."` with number patterns like "1.", "2.1.", "10."
- Unordered lists: `kind="*"` with bullet characters (•, *, -)
- List items are parsed as blocks with optional numbers
- Nested content within list items supported

### Block Nesting
- Blocks can contain any content type
- Unlimited nesting depth
- Head elements optional at any level

## Implementation Requirements

### Core API
```
ParseDocument(input: string) -> Block
ToJson(block: Block) -> string
FromJson(json: string) -> Block
```

### Data Models
- ContentNode: Abstract base for all content types
- Block: Main container with head, number, body
- ListBlock: Container for list items
- Dictionary: Key-value store with custom separators
- TextContent: Plain text wrapper

### Parsing Pipeline
1. **Lexical Analysis**: Tokenize input into structured tokens
2. **Parsing**: Build hierarchical document structure
3. **Serialization**: Convert to JSON with proper type handling

### Error Handling
- Invalid markup should be treated as text content
- Malformed structures should gracefully degrade
- Position information helpful for debugging

## Validation Rules

### Dictionary Validation
- Keys must be non-empty strings
- Values can be empty strings
- Separator must be present in each line
- Lines without separator treated as text

### List Validation
- Number format must match list kind
- Ordered lists: digits followed by periods
- Unordered lists: recognized bullet characters
- Mixed numbering patterns within same list allowed

### Block Validation
- Head tags must be properly closed
- Nested blocks must be properly structured
- Content outside blocks treated as root level

## Extensions and Customization

### Separator Support
- Single character: `:`, `-`, `=`, `|`
- Multi-character: `->`, `::`, `|||`, `##`
- Custom separators via `sep` attribute

### List Formatting
- Ordered: Support for multi-level numbering (1., 1.1., 1.1.1.)
- Unordered: Support for various bullet styles
- Mixed content within list items

### Content Nesting
- Dictionaries within lists
- Lists within blocks
- Blocks within lists
- Unlimited nesting combinations

## Round-trip Compatibility

The specification requires that:
1. `FromJson(ToJson(ParseDocument(input))) == ParseDocument(input)`
2. JSON serialization preserves all semantic information
3. Deserialization recreates identical object structure

## Character Encoding

- UTF-8 encoding for all text content
- Unicode characters supported in all content types
- Proper handling of special characters in separators

## Performance Considerations

- Single-pass parsing preferred
- Efficient tokenization without backtracking
- Minimal memory allocation during parsing
- Streaming support for large documents optional