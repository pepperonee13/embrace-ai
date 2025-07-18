module TimeToActParser.Tests.DictionariesTests

open Xunit
open System.Text.Json
open System.Text.Json.Nodes
open TimeToActParser.DocumentParser
open TimeToActParser.JsonSerializer
open TimeToActParser.Tests.TestDataLoader

type DictionariesTests() =
    static member DictionariesTestData() =
        let testCases = getTestCases "dictionaries.json"
        testCases |> Array.map (fun tc -> [| tc |])

    [<Theory>]
    [<MemberData(nameof(DictionariesTests.DictionariesTestData))>]
    member _.``Dictionaries should parse correctly`` (testCase: TestCase) =
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