# TimeToAct DocumentAI Implementation Guide

## Overview

The TimeToAct DocumentAI Spec defines a structured text format for business documents (contracts, procedures, etc.) that can be parsed into JSON for use with AI Assistants. This guide will help you implement a parser for this format.

## Core Concepts

### Document Structure

Documents consist of **blocks** - logical pieces of text that can contain:
- **Head**: Optional title/heading
- **Number**: Optional numbering (e.g., "1.", "2.1")
- **Body**: Mixed content including:
  - Plain text
  - Nested blocks
  - Lists
  - Dictionaries

### Data Models

```python
from typing import List, Optional, Union, Dict, Literal
from pydantic import BaseModel, Field

ContentNode = Union[str, "Block", "ListBlock", "Dictionary"]

class Dictionary(BaseModel):
    kind: Literal["dict"]
    items: Dict[str, str] = Field(default_factory=dict)

class Block(BaseModel):
    kind: Literal["block"]
    number: Optional[str] = None
    head: Optional[str] = None
    body: List[ContentNode] = Field(default_factory=list)

class ListBlock(BaseModel):
    kind: Literal["list"]
    items: List[Block] = Field(default_factory=list)
```

## Implementation Steps

### 1. Basic Text Parsing

**Empty Document:**
```
(empty input)
```
→
```json
{
  "kind": "block"
}
```

**Plain Text:**
```
First paragraph.
Second paragraph.
```
→
```json
{
  "kind": "block",
  "body": [
    "First paragraph.",
    "Second paragraph."
  ]
}
```

### 2. Headers and Blocks

**Using `<head>` tags:**
```
<head>Contract Title</head>
This is the contract content.
```
→
```json
{
  "kind": "block",
  "head": "Contract Title",
  "body": ["This is the contract content."]
}
```

**Nested blocks:**
```
<head>Master Agreement</head>
Introduction text
<block>
<head>Terms and Conditions</head>
Detailed terms here
</block>
```

### 3. Dictionaries

**Default separator (:):**
```
<dict sep=":">
Party A: Acme Corporation
Party B: Beta Industries
Effective Date: 2024-01-01
</dict>
```

**Custom separator:**
```
<dict sep="-">
Contract ID - AGR-2024-001
Status - Active
Value -
</dict>
```

### 4. Lists

**Ordered lists (dot notation):**
```
<list kind=".">
1. Payment Terms
2. Delivery Schedule
2.1. Initial Delivery
2.2. Final Delivery
3. Warranties
</list>
```

**Bulleted lists:**
```
<list kind="*">
• Confidentiality Agreement
• Non-Compete Clause
• Intellectual Property Rights
</list>
```

### 5. Mixed Content

**Lists with body content:**
```
<list kind=".">
1. Definitions
For the purpose of this agreement:
<dict sep=":">
Supplier: The party providing goods
Buyer: The party purchasing goods
</dict>
2. Obligations
Both parties agree to...
</list>
```

## Real-World Examples

### Contract Document

```
<head>Software License Agreement</head>
This agreement is entered into on the date last signed below.

<dict sep=":">
Licensor: TechCorp Inc.
Licensee: ClientCo Ltd.
Effective Date: January 1, 2024
License Type: Enterprise
</dict>

<block>
<head>Grant of License</head>
Subject to the terms and conditions of this Agreement, Licensor grants Licensee a non-exclusive, non-transferable license.
</block>

<list kind=".">
1. Permitted Uses
Licensee may use the software for internal business purposes only.
2. Restrictions
Licensee shall not:
<list kind="*">
• Reverse engineer the software
• Sublicense to
