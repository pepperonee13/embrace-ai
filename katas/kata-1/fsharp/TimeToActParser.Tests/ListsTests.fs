module TimeToActParser.Tests.ListsTests

open Xunit
open System.Text.Json
open System.Text.Json.Nodes
open TimeToActParser.DocumentParser
open TimeToActParser.JsonSerializer
open TimeToActParser.Tests.TestDataLoader

type ListsTests() =
    static member ListsTestData() =
        let testCases = getTestCases "lists.json"
        testCases |> Array.map (fun tc -> [| tc |])

    [<Theory>]
    [<MemberData(nameof(ListsTests.ListsTestData))>]
    member _.``Lists should parse correctly`` (testCase: TestCase) =
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