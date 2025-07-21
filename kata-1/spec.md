# Embrace AI: Kata 1 - Rinat Abdullin - Confluence

## Embrace AI: Kata 1

### TimeToAct DocumentAI Spec

Let's define a simple document format that could describe contract, procedure or any other business document in a structured way. It may be used to load this business data into AI Assistants like in ERC.

Weʼll work with the documents.

Our documents will consist from blocks. Block is a logical piece of text like pagragraph. It can optionally have a head, number and body. Block body could contain:

- another block
- text
- list
- dictionary

Blocks could contain heterogenous content - texts, other blocks, dictionaries.

List could contain only similar block items that also have number.

---

### Document Layout

The document below describes a simple text format that could be deterministically parsed into JSON objects. This document is also a test suite! Code admonitions always come in pairs: first `input` and then `json`.

When parser is implemented, parsed input should always produce output that is structurally similar to the expected `json`.

Headline before the code blocks is the name of the text.

Data structures to parse document into could look like this in python:

> AI in Coding helps a lot with high-level tasks like prototyping, reasoning and finding bugs.

Please use your favourite tools (no limitations) to implement as much of this spec as possible in a language of your choice. Imagine that your team will have to support this code for a few years, so you want to do a thorough job here.

```python
from typing import List, Optional, Union, Dict, Literal
from pydantic import BaseModel, Field

# This type alias helps with readability and forward references.
ContentNode = Union[str, "Block", "ListBlock", "Dictionary"]

class Dictionary(BaseModel):
    """
    A distinct dictionary structure for key-value pairs.
    """
    kind: Literal["dict"]
    items: Dict[str, str] = Field(default_factory=dict)

class Block(BaseModel):
    """
    A general-purpose container for a 'section' or item.

    - 'number' can store a section number (e.g., "5", "5.1") if applicable.
    - 'head' is an optional heading for the block.
    - 'body' can hold any mix of strings, sub-blocks, dictionaries, or lists.
    """
    kind: Literal["block"]
    number: Optional[str] = None
    head: Optional[str] = None
    body: List[ContentNode] = Field(default_factory=list)

class ListBlock(BaseModel):
    """
    A container for a list of items, each item being a 'Block'.
    """
    kind: Literal["list"]
    items: List[Block] = Field(default_factory=list)

# Important for forward references within union types
Block.model_rebuild()
```

---

### Specifications

#### Empty text

Empty text results in an empty document block

#### Body

Plain text goes into the block body straight away. Different paragraphs are separated by the new lines.

It will be parsed into:

> Note, that we strip and skip empty lines!

```json
{
  "kind": "block"
}
```

```
First paragraph.
Second paragraph.
```

```json
{
  "kind": "block",
  "body": [
    "First paragraph.",
    "Second paragraph."
  ]
}
```

```
First paragraph.
```

#### Head

Text marked with `<head>` goes directly into the head of the current block.

#### Blocks

You've seen that the document is parsed in a root block. But everything is a block and blocks can be nested explicitly

This is how things get extracted:

```
<head>Test Document</head>
Content
```

```json
{
  "kind": "block",
  "head": "Test Document",
  "body": [
    "Content"
  ]
}
```

```
<head>AI Coding Kata</head>
Let's get started with the kata
<block>
<head>Preface</head>
Here is a little story
</block>
```

```json
{
  "kind": "block",
  "head": "AI Coding Kata",
  "body": [
    "Let's get started with the kata",
    {
      "kind": "block",
      "head": "Preface",
      "body": [
        "Here is a little story"
      ]
    }
  ]
}
```

---

### Dictionaries

Dictionaries are used to capture key-value pairs, by default they are separated by `:`

This will be parsed into:

```
<dict sep=":">
Key One: Value One
Key Two: Value Two
Key Three: Value Three
</dict>
```

```json
{
  "kind": "block",
  "body": [
    {
      "kind": "dict",
      "items": {
        "Key One": "Value One",
        "Key Two": "Value Two",
        "Key Three": "Value Three"
      }
    }
  ]
}
```

```
<dict sep="-">
Title - AI Coding - for TAT
Kata Number - 
</dict>
```

```json
{
  "kind": "block",
  "body": [
    {
      "kind": "dict",
      "items": {
        "Title": "AI Coding - for TAT",
        "Kata Number": ""
      }
    }
  ]
}
```

---

### Lists

Lists are very important! By default, each non-empty line is a list item. They go inside the root block. There are multiple kinds:

- `.` for ordered lists that are dot-separated
- `*` for bulleted lists

Note, that list item goes to `head` and number goes to `number`.

```
<list kind=".">
1. First
2. Second
</list>
```

```json
{
  "kind": "block",
  "body": [
    {
      "kind": "list",
      "items": [
        { "kind": "block", "number": "1.", "head": "First" },
        { "kind": "block", "number": "2.", "head": "Second" }
      ]
    }
  ]
}
```

```
<list kind=".">
1. First
2. Second
2.1. Subitem 1
2.2. Subitem 2
</list>
```

```json
{
  "kind": "block",
  "body": [
    {
      "kind": "list",
      "items": [
        { "kind": "block", "number": "1.", "head": "First" },
        { "kind": "block", "number": "2.", "head": "Second", "body": [
          { "kind": "list", "items": [
            { "kind": "block", "number": "2.1.", "head": "Subitem 1" },
            { "kind": "block", "number": "2.2.", "head": "Subitem 2" }
          ]}
        ]}
      ]
    }
  ]
}
```

```
<list kind="*">
• First
• Second
• Third
</list>
```

```json
{
  "kind": "block",
  "body": [
    {
      "kind": "list",
      "items": [
        { "kind": "block", "number":"•", "head": "First" },
        { "kind": "block", "number":"•", "head": "Second" },
        { "kind": "block", "number":"•", "head": "Third" }
      ]
    }
  ]
}
```

```
<list kind="*">
• First
o Subitem
• Second
• Third
</list>
```

```json
{
  "kind": "block",
  "body": [
    {
      "kind": "list",
      "items": [
        { "kind": "block", "number":"•", "head": "First", "body": [
          { "kind": "list", "items": [
            { "kind": "block", "number":"o", "head": "Subitem" }
          ]}
        ]},
        { "kind": "block", "number":"•", "head": "Second" },
        { "kind": "block", "number":"•", "head": "Third" }
      ]}
  ]}
```

---

### Mixed Lists

We can mix lists, but would need to designate different types separately with tags.

```
<list kind=".">
1. Beginning
2. Main 
2.1. Subsection
<list kind="*">
* Bullet 1
* Bullet 2
</list>
3. Ending
</list>
```

```json
{
  "kind": "block",
  "body": [
    {
      "kind": "list",
      "items": [
        { "kind": "block", "number":"1.", "head": "Beginning" },
        { "kind": "block", "number":"2.", "head": "Main", "body": [
          { "kind": "list", "items": [
            { "kind": "block", "number":"*", "head": "Bullet 1" },
            { "kind": "block", "number":"*", "head": "Bullet 2" }
          ]}
        ]},
        { "kind": "block", "number":"2.1.", "head": "Subsection" },
        { "kind": "block", "number":"3.", "head": "Ending" }
      ]
    }
  ]
}
```

---

### Lists with Content

Obviously, lists can have additional content. If something in the current list doesn't match the prefix, then it is treated as block body:

```
<list kind=".">
1. First
First body
2. Second
Some more text
<dict sep=":">
Key: Value
Another Key: Another Value
</dict>
</list>
```

```json
{
  "kind": "block",
  "body": [
    {
      "kind": "list",
      "items": [
        { "kind": "block", "number":"1.", "head": "First", "body": [
          "First body"
        ] },
        { "kind": "block", "number":"2.", "head": "Second", "body": [
          "Some more text",
          {
            "kind": "dict",
            "items": {
              "Key": "Value",
              "Another Key": "Another Value"
            }
          }
        ] }
      ]
    }
  ]
}
```

