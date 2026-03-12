using System.Text.Json;
using TimeToActDocumentAI.Models;
using Xunit;

namespace TimeToActDocumentAI.Tests;

public class DocumentAITests
{
    [Fact]
    public void ParseEmptyDocument_ReturnsEmptyBlock()
    {
        var result = DocumentAI.ParseDocument("");
        
        Assert.Equal("block", result.Kind);
        Assert.Null(result.Head);
        Assert.Null(result.Number);
        Assert.True(result.Body == null || result.Body.Count == 0);
    }

    [Fact]
    public void ParsePlainText_ReturnsBlockWithTextContent()
    {
        var input = "First paragraph.\nSecond paragraph.";
        var result = DocumentAI.ParseDocument(input);
        
        Assert.Equal("block", result.Kind);
        Assert.NotNull(result.Body);
        Assert.Equal(2, result.Body.Count);
        Assert.All(result.Body, item => Assert.IsType<TextContent>(item));
        
        var textContents = result.Body.Cast<TextContent>().ToList();
        Assert.Equal("First paragraph.", textContents[0].Value);
        Assert.Equal("Second paragraph.", textContents[1].Value);
    }

    [Fact]
    public void ParseWithHead_ReturnsBlockWithHeadAndBody()
    {
        var input = "<head>Contract Title</head>\nThis is the contract content.";
        var result = DocumentAI.ParseDocument(input);
        
        Assert.Equal("block", result.Kind);
        Assert.Equal("Contract Title", result.Head);
        Assert.Single(result.Body);
        
        var textContent = Assert.IsType<TextContent>(result.Body[0]);
        Assert.Equal("This is the contract content.", textContent.Value);
    }

    [Fact]
    public void ParseNestedBlock_ReturnsBlockWithNestedStructure()
    {
        var input = """
            <head>Master Agreement</head>
            Introduction text
            <block>
            <head>Terms and Conditions</head>
            Detailed terms here
            </block>
            """;
        
        var result = DocumentAI.ParseDocument(input);
        
        Assert.Equal("Master Agreement", result.Head);
        Assert.NotNull(result.Body);
        Assert.Equal(2, result.Body.Count);
        
        var textContent = Assert.IsType<TextContent>(result.Body[0]);
        Assert.Equal("Introduction text", textContent.Value);
        
        var nestedBlock = Assert.IsType<Block>(result.Body[1]);
        Assert.Equal("Terms and Conditions", nestedBlock.Head);
        Assert.Single(nestedBlock.Body);
        
        var nestedTextContent = Assert.IsType<TextContent>(nestedBlock.Body[0]);
        Assert.Equal("Detailed terms here", nestedTextContent.Value);
    }

    [Theory]
    [InlineData(":", "Party A: Acme Corporation", "Party A", "Acme Corporation")]
    [InlineData("-", "Party A - Acme Corporation", "Party A", "Acme Corporation")]
    [InlineData("=", "Party A = Acme Corporation", "Party A", "Acme Corporation")]
    [InlineData("|", "Party A | Acme Corporation", "Party A", "Acme Corporation")]
    [InlineData("->", "Party A -> Acme Corporation", "Party A", "Acme Corporation")]
    [InlineData(":", "Key: Value with: colon", "Key", "Value with: colon")]
    [InlineData("-", "Key- Value with - dash", "Key", "Value with - dash")]
    public void ParseDictionary_WithDifferentSeparators_ParsesCorrectly(string separator, string line, string expectedKey, string expectedValue)
    {
        var input = $"""
            <dict sep="{separator}">
            {line}
            </dict>
            """;
        
        var result = DocumentAI.ParseDocument(input);
        
        Assert.Single(result.Body);
        var dict = Assert.IsType<Models.Dictionary>(result.Body[0]);
        Assert.Equal("dict", dict.Kind);
        Assert.Single(dict.Items);
        Assert.Equal(expectedValue, dict.Items[expectedKey]);
    }

    [Fact]
    public void ParseDictionary_WithMultipleItems_ReturnsCorrectDictionary()
    {
        var input = """
            <dict sep=":">
            Party A: Acme Corporation
            Party B: Beta Industries
            Effective Date: 2024-01-01
            </dict>
            """;
        
        var result = DocumentAI.ParseDocument(input);
        
        Assert.Single(result.Body);
        var dict = Assert.IsType<Models.Dictionary>(result.Body[0]);
        Assert.Equal("dict", dict.Kind);
        Assert.Equal(3, dict.Items.Count);
        Assert.Equal("Acme Corporation", dict.Items["Party A"]);
        Assert.Equal("Beta Industries", dict.Items["Party B"]);
        Assert.Equal("2024-01-01", dict.Items["Effective Date"]);
    }

    [Theory]
    [InlineData(".", "1.", "1.")]
    [InlineData(".", "2.1.", "2.1.")]
    [InlineData(".", "10.", "10.")]
    [InlineData(".", "1.2.3.", "1.2.3.")]
    [InlineData(".", "100.1.", "100.1.")]
    public void ParseOrderedList_WithDifferentNumberFormats_ParsesCorrectly(string kind, string numberFormat, string expectedNumber)
    {
        var input = $"""
            <list kind="{kind}">
            {numberFormat} Test Item
            </list>
            """;
        
        var result = DocumentAI.ParseDocument(input);
        
        Assert.NotNull(result.Body);
        Assert.Single(result.Body);
        var list = Assert.IsType<ListBlock>(result.Body[0]);
        Assert.Single(list.Items);
        Assert.Equal(expectedNumber, list.Items[0].Number);
        Assert.Equal("Test Item", list.Items[0].Head);
    }

    [Fact]
    public void ParseOrderedList_WithMultipleItems_ReturnsCorrectStructure()
    {
        var input = """
            <list kind=".">
            1. Payment Terms
            2. Delivery Schedule
            2.1. Initial Delivery
            2.2. Final Delivery
            3. Warranties
            </list>
            """;
        
        var result = DocumentAI.ParseDocument(input);
        
        Assert.Single(result.Body);
        var list = Assert.IsType<ListBlock>(result.Body[0]);
        Assert.Equal("list", list.Kind);
        Assert.Equal(3, list.Items.Count);  // Top-level items: 1, 2, 3
        
        Assert.Equal("1.", list.Items[0].Number);
        Assert.Equal("Payment Terms", list.Items[0].Head);
        
        Assert.Equal("2.", list.Items[1].Number);
        Assert.Equal("Delivery Schedule", list.Items[1].Head);
        
        // Check nested structure under item 2
        Assert.NotNull(list.Items[1].Body);
        Assert.Single(list.Items[1].Body);
        var nestedList = Assert.IsType<ListBlock>(list.Items[1].Body[0]);
        Assert.Equal(2, nestedList.Items.Count);
        
        Assert.Equal("2.1.", nestedList.Items[0].Number);
        Assert.Equal("Initial Delivery", nestedList.Items[0].Head);
        
        Assert.Equal("2.2.", nestedList.Items[1].Number);
        Assert.Equal("Final Delivery", nestedList.Items[1].Head);
        
        Assert.Equal("3.", list.Items[2].Number);
        Assert.Equal("Warranties", list.Items[2].Head);
    }

    [Theory]
    [InlineData("*", "•", "Bullet item")]
    [InlineData("*", "*", "Asterisk item")]
    [InlineData("*", "-", "Dash item")]
    public void ParseBulletList_WithDifferentBulletTypes_ParsesCorrectly(string kind, string bulletChar, string itemText)
    {
        var input = $"""
            <list kind="{kind}">
            {bulletChar} {itemText}
            </list>
            """;
        
        var result = DocumentAI.ParseDocument(input);
        
        Assert.NotNull(result.Body);
        Assert.Single(result.Body);
        var list = Assert.IsType<ListBlock>(result.Body[0]);
        Assert.Single(list.Items);
        Assert.Equal(bulletChar, list.Items[0].Number);
        Assert.Equal(itemText, list.Items[0].Head);
    }

    [Fact]
    public void ParseBulletList_WithMultipleItems_ReturnsCorrectStructure()
    {
        var input = """
            <list kind="*">
            • Confidentiality Agreement
            • Non-Compete Clause
            • Intellectual Property Rights
            </list>
            """;
        
        var result = DocumentAI.ParseDocument(input);
        
        Assert.NotNull(result.Body);
        Assert.Single(result.Body);
        var list = Assert.IsType<ListBlock>(result.Body[0]);
        Assert.Equal(3, list.Items.Count);
        
        Assert.Equal("•", list.Items[0].Number);
        Assert.Equal("Confidentiality Agreement", list.Items[0].Head);
    }

    [Fact]
    public void ToJson_SerializesCorrectly()
    {
        var block = new Block
        {
            Head = "Test Document",
            Body = new List<ContentNode>
            {
                new TextContent("Some text"),
                new Models.Dictionary
                {
                    Items = new Dictionary<string, string>
                    {
                        ["Key1"] = "Value1",
                        ["Key2"] = "Value2"
                    }
                }
            }
        };
        
        var json = DocumentAI.ToJson(block);
        
        Assert.Contains("\"head\": \"Test Document\"", json);
        Assert.Contains("\"kind\": \"block\"", json);
        Assert.Contains("\"kind\": \"dict\"", json);
        Assert.Contains("Some text", json);
    }

    [Fact]
    public void RoundTrip_PreservesData()
    {
        var input = """
            <head>Software License Agreement</head>
            This agreement is entered into on the date last signed below.
            
            <dict sep=":">
            Licensor: TechCorp Inc.
            Licensee: ClientCo Ltd.
            </dict>
            """;
        
        var parsed = DocumentAI.ParseDocument(input);
        var json = DocumentAI.ToJson(parsed);
        var deserialized = DocumentAI.FromJson(json);
        
        Assert.Equal(parsed.Head, deserialized.Head);
        Assert.Equal(parsed.Body?.Count ?? 0, deserialized.Body?.Count ?? 0);
        Assert.Equal(parsed.Kind, deserialized.Kind);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("\n\n")]
    [InlineData("\t\t")]
    public void ParseDocument_WithEmptyOrWhitespaceInput_ReturnsEmptyBlock(string input)
    {
        var result = DocumentAI.ParseDocument(input);
        
        Assert.Equal("block", result.Kind);
        Assert.Null(result.Head);
        Assert.Null(result.Number);
        Assert.True(result.Body == null || result.Body.Count == 0);
    }

    [Theory]
    [InlineData("<dict>Key:Value</dict>", "Key", "Value")]
    [InlineData("<dict sep=\":\">\nKey:Value\n</dict>", "Key", "Value")]
    [InlineData("<dict sep=\"-\">Key - Value</dict>", "Key", "Value")]
    [InlineData("<dict sep=\"=\">Key=Value</dict>", "Key", "Value")]
    public void ParseDictionary_WithDifferentFormats_ParsesCorrectly(string input, string expectedKey, string expectedValue)
    {
        var result = DocumentAI.ParseDocument(input);
        
        Assert.Single(result.Body);
        var dict = Assert.IsType<Models.Dictionary>(result.Body[0]);
        Assert.Single(dict.Items);
        Assert.Equal(expectedValue, dict.Items[expectedKey]);
    }

    [Fact]
    public void ParseDictionary_WithEmptyValues_HandlesCorrectly()
    {
        var input = """
            <dict sep=":">
            Key1: Value1
            Key2: 
            Key3: Value3
            EmptyKey:
            </dict>
            """;
        
        var result = DocumentAI.ParseDocument(input);
        
        Assert.Single(result.Body);
        var dict = Assert.IsType<Models.Dictionary>(result.Body[0]);
        Assert.Equal(4, dict.Items.Count);
        Assert.Equal("Value1", dict.Items["Key1"]);
        Assert.Equal("", dict.Items["Key2"]);
        Assert.Equal("Value3", dict.Items["Key3"]);
        Assert.Equal("", dict.Items["EmptyKey"]);
    }

    [Theory]
    [MemberData(nameof(ComplexDocumentTestData))]
    public void ParseDocument_WithComplexStructures_ParsesCorrectly(string input, int expectedBodyCount, string expectedHeadText)
    {
        var result = DocumentAI.ParseDocument(input);
        
        Assert.Equal("block", result.Kind);
        Assert.Equal(expectedHeadText, result.Head);
        Assert.Equal(expectedBodyCount, result.Body?.Count ?? 0);
    }

    public static IEnumerable<object[]> ComplexDocumentTestData()
    {
        yield return new object[]
        {
            """
            <head>Simple Document</head>
            Just text content.
            """,
            1,
            "Simple Document"
        };

        yield return new object[]
        {
            """
            <head>Document with Dictionary</head>
            Introduction text.
            <dict sep=":">
            Key1: Value1
            Key2: Value2
            </dict>
            """,
            2,
            "Document with Dictionary"
        };

        yield return new object[]
        {
            """
            <head>Document with List</head>
            Introduction text.
            <list kind=".">
            1. First item
            2. Second item
            </list>
            Conclusion text.
            """,
            3,
            "Document with List"
        };

        yield return new object[]
        {
            """
            <head>Document with Nested Blocks</head>
            Introduction.
            <block>
            <head>Section 1</head>
            Section content.
            </block>
            <block>
            <head>Section 2</head>
            More content.
            </block>
            """,
            3,
            "Document with Nested Blocks"
        };
    }

    [Theory]
    [InlineData("<dict sep=\"::\">\nKey :: Value\n</dict>", "Key", "Value")]
    [InlineData("<dict sep=\"-->\">Key --> Value</dict>", "Key", "Value")]
    [InlineData("<dict sep=\"|||\">\nKey ||| Value\n</dict>", "Key", "Value")]
    [InlineData("<dict sep=\"##\">\nKey ## Value\n</dict>", "Key", "Value")]
    public void ParseDictionary_WithMultiCharacterSeparators_ParsesCorrectly(string input, string expectedKey, string expectedValue)
    {
        var result = DocumentAI.ParseDocument(input);
        
        Assert.Single(result.Body);
        var dict = Assert.IsType<Models.Dictionary>(result.Body[0]);
        Assert.Single(dict.Items);
        Assert.Equal(expectedValue, dict.Items[expectedKey]);
    }

    [Fact]
    public void ParseMixedContent_WithListContainingDictionary_ParsesCorrectly()
    {
        var input = """
            <list kind=".">
            1. First item
            Some description text.
            <dict sep=":">
            Subelement: Value
            Another: Data
            </dict>
            2. Second item
            More text here.
            </list>
            """;
        
        var result = DocumentAI.ParseDocument(input);
        
        Assert.Single(result.Body);
        var list = Assert.IsType<ListBlock>(result.Body[0]);
        Assert.Equal(2, list.Items.Count);
        
        // Check first item with text content and dictionary
        var firstItem = list.Items[0];
        Assert.Equal("1.", firstItem.Number);
        Assert.Equal("First item", firstItem.Head);
        Assert.NotNull(firstItem.Body);
        Assert.Equal(2, firstItem.Body.Count); // Text content + dictionary
        
        // Check text content
        var textContent = Assert.IsType<TextContent>(firstItem.Body[0]);
        Assert.Equal("Some description text.", textContent.Value);
        
        // Check dictionary
        var dict = Assert.IsType<Models.Dictionary>(firstItem.Body[1]);
        Assert.Equal(2, dict.Items.Count);
        Assert.Equal("Value", dict.Items["Subelement"]);
        Assert.Equal("Data", dict.Items["Another"]);
        
        // Check second item with text content
        var secondItem = list.Items[1];
        Assert.Equal("2.", secondItem.Number);
        Assert.Equal("Second item", secondItem.Head);
        Assert.NotNull(secondItem.Body);
        Assert.Single(secondItem.Body);
        
        var secondTextContent = Assert.IsType<TextContent>(secondItem.Body[0]);
        Assert.Equal("More text here.", secondTextContent.Value);
    }

    [Fact]
    public void ParseDocument_WithComplexNestedStructure_ParsesCorrectly()
    {
        var input = """
            <head>Complex Document</head>
            Introduction paragraph.
            
            <block>
            <head>Section 1</head>
            Section content with nested elements.
            <dict sep=":">
            Key1: Value1
            Key2: Value2
            </dict>
            </block>
            
            <list kind=".">
            1. First item
            2. Second item
            </list>
            
            Conclusion paragraph.
            """;
        
        var result = DocumentAI.ParseDocument(input);
        
        Assert.Equal("Complex Document", result.Head);
        Assert.Equal(4, result.Body.Count); // Introduction, block, list, conclusion
        
        // Check introduction
        var intro = Assert.IsType<TextContent>(result.Body[0]);
        Assert.Equal("Introduction paragraph.", intro.Value);
        
        // Check nested block
        var block = Assert.IsType<Block>(result.Body[1]);
        Assert.Equal("Section 1", block.Head);
        Assert.Equal(2, block.Body.Count); // Text and dictionary
        
        // Check list
        var list = Assert.IsType<ListBlock>(result.Body[2]);
        Assert.Equal(2, list.Items.Count);
        
        // Check conclusion
        var conclusion = Assert.IsType<TextContent>(result.Body[3]);
        Assert.Equal("Conclusion paragraph.", conclusion.Value);
    }
}