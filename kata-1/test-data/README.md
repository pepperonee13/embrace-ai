# Shared Test Data

This directory contains shared test data files that are used by both the C# and F# implementations to ensure consistent testing across both solutions.

## Structure

The test data is organized by category, with each category containing multiple test cases extracted from the [specification](../spec.md):

- **`basic-blocks.json`** - Tests for basic block functionality (empty text, plain text, headed blocks, nested blocks)
- **`dictionaries.json`** - Tests for dictionary parsing with different separators
- **`lists.json`** - Tests for list functionality (ordered, bulleted, nested lists)
- **`complex-scenarios.json`** - Tests for complex scenarios (mixed lists, lists with content)

## Test Data Format

Each test data file follows this JSON structure:

```json
{
  "category": "Category Name",
  "description": "Description of what this category tests",
  "testCases": [
    {
      "name": "Test case name",
      "description": "Description of what this test case validates",
      "input": "Document input text",
      "expected": {
        "kind": "block",
        "head": "Expected output structure"
      }
    }
  ]
}
```

## Usage

### C# Implementation

The C# tests use the `TestDataLoader` class to load shared test data:

```csharp
[Theory]
[MemberData(nameof(GetBasicBlockTestCases))]
public void BasicBlocks_ShouldParseCorrectly(TestCase testCase)
{
    var result = DocumentAI.ParseDocument(testCase.Input);
    var actualJson = JsonSerializer.Serialize(result, JsonOptions);
    // Assert against testCase.Expected
}

public static IEnumerable<object[]> GetBasicBlockTestCases()
{
    return TestDataLoader.GetTestCases("basic-blocks.json");
}
```

### F# Implementation

The F# tests use the `TestDataLoader` module:

```fsharp
[<Theory>]
[<MemberData(nameof(BasicBlocksTestData))>]
let ``Basic blocks should parse correctly`` (testCase: TestCase) =
    let result = parseDocument testCase.Input
    let actualJson = toJson result
    // Assert against testCase.Expected

static member BasicBlocksTestData() =
    let testCases = getTestCases "basic-blocks.json"
    testCases |> Array.map (fun tc -> [| tc |])
```

## Benefits

1. **Single Source of Truth**: Test cases are defined once and used by both implementations
2. **Specification Compliance**: All test cases are extracted directly from the specification
3. **Consistency**: Both implementations are tested against identical inputs and expected outputs
4. **Maintainability**: Changes to test cases only need to be made in one place
5. **Categorization**: Tests are organized by functionality for better organization

## Adding New Test Cases

To add new test cases:

1. Choose the appropriate category file (or create a new one)
2. Add the test case to the `testCases` array
3. Ensure the `input` and `expected` fields match the specification
4. Both C# and F# tests will automatically pick up the new test case

## Test Data Validation

The test data files should be validated against the specification to ensure:
- All examples from the specification are covered
- Input and expected output match exactly
- Test cases are properly categorized
- JSON structure is valid

## Path Resolution

The test data loader automatically resolves paths relative to the kata-1 root directory, so both implementations can access the same test data files regardless of their location in the repository structure.