module TimeToActParser.Tests.BasicBlocksTests

open Xunit
open System.Text.Json
open System.Text.Json.Nodes
open TimeToActParser.DocumentParser
open TimeToActParser.JsonSerializer
open TimeToActParser.Tests.TestDataLoader

type BasicBlocksTests() =
    static member BasicBlocksTestData() =
        let testCases = getTestCases "basic-blocks.json"
        testCases |> Array.map (fun tc -> [| tc |])

    [<Theory>]
    [<MemberData(nameof(BasicBlocksTests.BasicBlocksTestData))>]
    member _.``Basic blocks should parse correctly`` (testCase: TestCase) =
        // Arrange
        let input = testCase.Input
        let expectedJson = testCase.Expected

        // Act
        let result = parseDocument input
        let actualJson = toJson result
        let actualNode = JsonNode.Parse(actualJson)

        // Assert
        let expectedStr = expectedJson.ToJsonString()
        let actualStr = actualNode.ToJsonString()
        Assert.Equal(expectedStr, actualStr)