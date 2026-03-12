using System.Text.Json;
using System.Text.Json.Nodes;

namespace TimeToActDocumentAI.Tests;

public record TestCase(
    string Name,
    string Description,
    string Input,
    JsonNode Expected
);

public record TestData(
    string Category,
    string Description,
    TestCase[] TestCases
);

public static class TestDataLoader
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public static TestData LoadTestData(string fileName)
    {
        var testDataPath = Path.Combine(
            Directory.GetCurrentDirectory(),
            "..", "..", "..", "..", "..", // Navigate up to kata-1 root
            "test-data",
            fileName
        );

        if (!File.Exists(testDataPath))
        {
            throw new FileNotFoundException($"Test data file not found: {testDataPath}");
        }

        var jsonContent = File.ReadAllText(testDataPath);
        var testData = JsonSerializer.Deserialize<TestData>(jsonContent, Options);
        
        if (testData == null)
        {
            throw new InvalidOperationException($"Failed to deserialize test data from {fileName}");
        }

        return testData;
    }

    public static IEnumerable<object[]> GetTestCases(string fileName)
    {
        var testData = LoadTestData(fileName);
        return testData.TestCases.Select(tc => new object[] { tc });
    }
}