using System.Text.Json;
using System.Text.Json.Nodes;
using Xunit;

namespace TimeToActDocumentAI.Tests;

public class ComplexScenariosTests
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    [Theory]
    [MemberData(nameof(GetComplexScenarioTestCases))]
    public void ComplexScenarios_ShouldParseCorrectly(TestCase testCase)
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

    public static IEnumerable<object[]> GetComplexScenarioTestCases()
    {
        return TestDataLoader.GetTestCases("complex-scenarios.json");
    }

    private static void AssertJsonEquals(JsonNode? expected, JsonNode? actual, string testName)
    {
        if (expected == null && actual == null) return;
        
        Assert.True(expected != null && actual != null, $"Null mismatch in test: {testName}");
        
        var expectedStr = expected.ToJsonString();
        var actualStr = actual.ToJsonString();
        
        Assert.Equal(expectedStr, actualStr);
    }
}