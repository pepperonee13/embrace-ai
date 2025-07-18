# TimeToAct DocumentAI - C# Implementation TODOs

## Current Status
- **54/56 tests passing** (96% success rate)
- Core functionality fully implemented and working
- Only 2 complex parsing scenarios remaining

---

## 🔴 High Priority Issues (Blocking 2 tests)

### 1. Mixed List Nesting Logic
**Test**: `ComplexScenariosTests.ComplexScenarios_ShouldParseCorrectly` - "Mixed lists with different types"

**Problem**: 
- According to `spec.md` (lines 342-374), in mixed lists, item "2.1. Subsection" should be at the top level
- Currently: Item 2.1 is nested under item 2 due to number hierarchy logic
- The bullet list should attach to item 2, but 2.1 should be a sibling of items 1, 2, 3

**Input**:
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

**Expected Structure**:
- Items: 1, 2, 2.1, 3 (all at top level)
- Bullet list nested under item 2 only

**Current Structure**:
- Items: 1, 2, 3 (top level)
- Item 2.1 nested under item 2 (in separate nested list)
- Bullet list also nested under item 2

**Fix Needed**: Context-aware nesting that detects mixed list scenarios and disables numbered nesting when explicit `<list>` tags are present.

**Files to Modify**:
- `TimeToActDocumentAI/Parsing/DocumentParser.cs` - `ShouldNestUnderPreviousItem()` method
- Add detection for mixed list context
- Implement different nesting rules for mixed vs. pure numbered lists

---

### 2. Text Content Attachment to List Items
**Test**: `ComplexScenariosTests.ComplexScenarios_ShouldParseCorrectly` - "Lists with content and dictionary"

**Problem**:
- According to `spec.md` (lines 378-419), text following list items should be attached as body content
- Currently: Text like "First body" and "Some more text" is not being parsed as list item body content
- Text should be serialized as plain strings in the body array (not wrapped in TextContent objects)

**Input**:
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

**Expected Structure**:
- Item 1: head="First", body=["First body"]
- Item 2: head="Second", body=["Some more text", {dict}]

**Current Structure**:
- Item 1: head="First", body=null
- Item 2: head="Second", body=null
- Text content is not being associated with list items

**Fix Needed**: Enhanced parsing to associate text content between list items with the appropriate list item.

**Files to Modify**:
- `TimeToActDocumentAI/Parsing/DocumentParser.cs` - `ParseList()` method
- Modify text parsing logic to accumulate content for current list item
- Handle text content that appears between list items
- Ensure text is serialized as plain strings (not TextContent objects)

---

## 🟡 Medium Priority Improvements

### 3. Error Handling Enhancement
- Add more robust error handling for malformed input
- Improve error messages for debugging
- Add validation for nested structures

### 4. Performance Optimization
- Profile and optimize parsing performance for large documents
- Consider streaming parsing for very large inputs
- Optimize memory usage for deeply nested structures

### 5. Code Quality
- Add more comprehensive unit tests for edge cases
- Improve code documentation and comments
- Consider extracting parsing strategies into separate classes

---

## 🟢 Completed Features ✅

- [x] Empty document parsing
- [x] Plain text parsing with paragraph separation
- [x] Head and nested block parsing
- [x] Dictionary parsing with various separators
- [x] Ordered list parsing (numbered items)
- [x] Bullet list parsing
- [x] Basic nested list support
- [x] JSON serialization with camelCase naming
- [x] Nullable Body property handling
- [x] Nested `<list>` tag support within lists
- [x] Parent-finding logic for nested list attachment
- [x] Round-trip JSON serialization/deserialization
- [x] Comprehensive test coverage for basic scenarios

---

## 🔧 Technical Debt

### Code Organization
- Consider splitting `DocumentParser.cs` into smaller, focused classes
- Extract list parsing logic into dedicated `ListParser` class
- Create separate strategies for different list types

### Testing
- Add property-based testing for edge cases
- Create performance benchmark tests
- Add integration tests for complex documents

### Documentation
- Add XML documentation to all public methods
- Create developer guide for extending the parser
- Document parsing algorithm and design decisions

---

## 📝 Developer Notes

### Key Files
- **`DocumentAI.cs`**: Main API entry point, JSON serialization
- **`DocumentParser.cs`**: Core parsing logic, handles all token processing
- **`Models/`**: Data structures (Block, ListBlock, Dictionary, ContentNode)
- **`Parsing/Lexer.cs`**: Tokenization of input text
- **Test files**: Comprehensive test suite with spec-based test cases

### Debugging Tips
- Use `DebugTest/` project for isolated testing of specific scenarios
- Check `test-data/*.json` files for expected behavior from specification
- Refer to `spec.md` as the source of truth for all parsing behavior
- The `FindAppropriateParentForNestedList()` method handles complex nested scenarios

### Contributing
- Follow TDD principles: Red → Green → Refactor
- Ensure all tests pass before committing
- Add tests for new functionality
- Keep commits small and focused
- Reference spec.md for expected behavior

---

## 🎯 Success Metrics

- **Current**: 54/56 tests passing (96%)
- **Target**: 56/56 tests passing (100%)
- **Performance**: Parse typical documents in <10ms
- **Maintainability**: Clean, well-documented code following SOLID principles