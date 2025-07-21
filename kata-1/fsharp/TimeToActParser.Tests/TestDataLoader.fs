module TimeToActParser.Tests.TestDataLoader

open System
open System.IO
open System.Text.Json
open System.Text.Json.Nodes

[<CLIMutable>]
type TestCase = {
    Name: string
    Description: string
    Input: string
    Expected: JsonNode
}

[<CLIMutable>]
type TestData = {
    Category: string
    Description: string
    TestCases: TestCase[]
}

let private options = JsonSerializerOptions()
options.PropertyNameCaseInsensitive <- true

let loadTestData (fileName: string) : TestData =
    let testDataPath = Path.Combine(
        Directory.GetCurrentDirectory(),
        "..", "..", "..", "..", "..", // Navigate up to kata-1 root
        "test-data",
        fileName
    )

    if not (File.Exists testDataPath) then
        failwith $"Test data file not found: {testDataPath}"

    let jsonContent = File.ReadAllText testDataPath
    let testData = JsonSerializer.Deserialize<TestData>(jsonContent, options)
    
    if obj.ReferenceEquals(testData, null) then
        failwith $"Failed to deserialize test data from {fileName}"
    else
        testData

let getTestCases (fileName: string) : TestCase[] =
    let testData = loadTestData fileName
    testData.TestCases