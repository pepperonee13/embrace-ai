using System.Text.Json;
using System.Text.Json.Nodes;
using Xunit;

namespace TimeToActDocumentAI.Tests;

public class BasicBlocksTests
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    [Theory]
    [MemberData(nameof(GetBasicBlockTestCases))]
    public void BasicBlocks_ShouldParseCorrectly(TestCase testCase)
    {
        // Arrange
        var input = testCase.Input;
        var expectedJson = testCase.Expected.ToJsonString();

        // Act
        var result = DocumentAI.ParseDocument(input);
        var actualJson = DocumentAI.ToJson(result);

        // Assert - Compare the JSON structures
        var expectedNode = JsonNode.Parse(expectedJson);
        var actualNode = JsonNode.Parse(actualJson);
        
        AssertJsonEquals(expectedNode, actualNode, testCase.Name);
    }

    public static IEnumerable<object[]> GetBasicBlockTestCases()
    {
        return TestDataLoader.GetTestCases("basic-blocks.json");
    }

    private static void AssertJsonEquals(JsonNode? expected, JsonNode? actual, string testName)
    {
        if (expected == null && actual == null) return;
        
        Assert.True(expected != null && actual != null, $"Null mismatch in test: {testName}");
        
        var expectedStr = expected.ToJsonString();
        var actualStr = actual.ToJsonString();
        
        // For detailed comparison, we can parse and compare structure
        Assert.Equal(expectedStr, actualStr);
    }
}