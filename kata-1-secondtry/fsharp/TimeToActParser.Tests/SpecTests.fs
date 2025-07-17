module TimeToActParser.Tests.SpecTests

open Xunit
open TimeToActParser.DocumentParser
open TimeToActParser.Types
open TimeToActParser.Types.TestHelpers
open TimeToActParser.JsonSerializer

// Test cases from spec.md following TDD principles

[<Fact>]
let ``Empty text results in empty document block`` () =
    let input = ""
    let result = parseDocument input
    
    Assert.Equal("block", getBlockKind result)
    Assert.Equal(None, numberToString result.Number)
    Assert.Equal(None, headToString result.Head)
    Assert.Equal(0, result.Body.Length)

[<Fact>]
let ``Plain text goes into block body - two paragraphs`` () =
    let input = "First paragraph.\nSecond paragraph."
    let result = parseDocument input
    
    Assert.Equal("block", getBlockKind result)
    Assert.Equal(2, result.Body.Length)
    
    match result.Body.[0] with
    | Text text -> Assert.Equal("First paragraph.", text)
    | _ -> Assert.True(false, "Expected text")
    
    match result.Body.[1] with
    | Text text -> Assert.Equal("Second paragraph.", text)
    | _ -> Assert.True(false, "Expected text")

[<Fact>]
let ``Head tag goes into block head`` () =
    let input = "<head>Test Document</head>\nContent"
    let result = parseDocument input
    
    Assert.Equal("block", getBlockKind result)
    Assert.Equal(Some "Test Document", headToString result.Head)
    Assert.Equal(1, result.Body.Length)
    
    match result.Body.[0] with
    | Text text -> Assert.Equal("Content", text)
    | _ -> Assert.True(false, "Expected text")

[<Fact>]
let ``Nested blocks are parsed correctly`` () =
    let input = """<head>AI Coding Kata</head>
Let's get started with the kata
<block>
<head>Preface</head>
Here is a little story
</block>"""
    
    let result = parseDocument input
    
    Assert.Equal("block", getBlockKind result)
    Assert.Equal(Some "AI Coding Kata", headToString result.Head)
    Assert.Equal(2, result.Body.Length)
    
    match result.Body.[0] with
    | Text text -> Assert.Equal("Let's get started with the kata", text)
    | _ -> Assert.True(false, "Expected text")
    
    match result.Body.[1] with
    | Block nestedBlock ->
        Assert.Equal("block", getBlockKind nestedBlock)
        Assert.Equal(Some "Preface", headToString nestedBlock.Head)
        Assert.Equal(1, nestedBlock.Body.Length)
        
        match nestedBlock.Body.[0] with
        | Text text -> Assert.Equal("Here is a little story", text)
        | _ -> Assert.True(false, "Expected text in nested block")
    | _ -> Assert.True(false, "Expected nested block")

[<Fact>]
let ``Dictionary with colon separator`` () =
    let input = """<dict sep=":">
Key One: Value One
Key Two: Value Two
Key Three: Value Three
</dict>"""
    
    let result = parseDocument input
    
    Assert.Equal("block", getBlockKind result)
    Assert.Equal(1, result.Body.Length)
    
    match result.Body.[0] with
    | Dictionary dict ->
        Assert.Equal("dict", getDictKind dict)
        Assert.Equal(3, dict.Items.Count)
        Assert.Equal("Value One", dict.Items.["Key One"])
        Assert.Equal("Value Two", dict.Items.["Key Two"])
        Assert.Equal("Value Three", dict.Items.["Key Three"])
    | _ -> Assert.True(false, "Expected dictionary")

[<Fact>]
let ``Dictionary with dash separator`` () =
    let input = """<dict sep="-">
Title - AI Coding - for TAT
Kata Number - 
</dict>"""
    
    let result = parseDocument input
    
    Assert.Equal("block", getBlockKind result)
    Assert.Equal(1, result.Body.Length)
    
    match result.Body.[0] with
    | Dictionary dict ->
        Assert.Equal("dict", getDictKind dict)
        Assert.Equal(2, dict.Items.Count)
        Assert.Equal("AI Coding - for TAT", dict.Items.["Title"])
        Assert.Equal("", dict.Items.["Kata Number"])
    | _ -> Assert.True(false, "Expected dictionary")

[<Fact>]
let ``Ordered list with dots`` () =
    let input = """<list kind=".">
1. First
2. Second
</list>"""
    
    let result = parseDocument input
    
    Assert.Equal("block", getBlockKind result)
    Assert.Equal(1, result.Body.Length)
    
    match result.Body.[0] with
    | ListBlock listBlock ->
        Assert.Equal("list", getListKind listBlock)
        Assert.Equal(2, listBlock.Items.Length)
        
        let firstItem = listBlock.Items.[0]
        Assert.Equal("block", getBlockKind firstItem)
        Assert.Equal(Some "1.", numberToString firstItem.Number)
        Assert.Equal(Some "First", headToString firstItem.Head)
        
        let secondItem = listBlock.Items.[1]
        Assert.Equal("block", getBlockKind secondItem)
        Assert.Equal(Some "2.", numberToString secondItem.Number)
        Assert.Equal(Some "Second", headToString secondItem.Head)
    | _ -> Assert.True(false, "Expected list block")

[<Fact>]
let ``Bulleted list with asterisks`` () =
    let input = """<list kind="*">
• First
• Second
• Third
</list>"""
    
    let result = parseDocument input
    
    Assert.Equal("block", getBlockKind result)
    Assert.Equal(1, result.Body.Length)
    
    match result.Body.[0] with
    | ListBlock listBlock ->
        Assert.Equal("list", getListKind listBlock)
        Assert.Equal(3, listBlock.Items.Length)
        
        let firstItem = listBlock.Items.[0]
        Assert.Equal("block", getBlockKind firstItem)
        Assert.Equal(Some "•", numberToString firstItem.Number)
        Assert.Equal(Some "First", headToString firstItem.Head)
        
        let secondItem = listBlock.Items.[1]
        Assert.Equal("block", getBlockKind secondItem)
        Assert.Equal(Some "•", numberToString secondItem.Number)
        Assert.Equal(Some "Second", headToString secondItem.Head)
        
        let thirdItem = listBlock.Items.[2]
        Assert.Equal("block", getBlockKind thirdItem)
        Assert.Equal(Some "•", numberToString thirdItem.Number)
        Assert.Equal(Some "Third", headToString thirdItem.Head)
    | _ -> Assert.True(false, "Expected list block")

[<Fact>]
let ``Nested lists with subitems`` () =
    let input = """<list kind=".">
1. First
2. Second
2.1. Subitem 1
2.2. Subitem 2
</list>"""
    
    let result = parseDocument input
    
    Assert.Equal("block", getBlockKind result)
    Assert.Equal(1, result.Body.Length)
    
    match result.Body.[0] with
    | ListBlock listBlock ->
        Assert.Equal("list", getListKind listBlock)
        Assert.Equal(4, listBlock.Items.Length)
        
        let firstItem = listBlock.Items.[0]
        Assert.Equal(Some "1.", numberToString firstItem.Number)
        Assert.Equal(Some "First", headToString firstItem.Head)
        
        let secondItem = listBlock.Items.[1]
        Assert.Equal(Some "2.", numberToString secondItem.Number)
        Assert.Equal(Some "Second", headToString secondItem.Head)
        
        let subitem1 = listBlock.Items.[2]
        Assert.Equal(Some "2.1.", numberToString subitem1.Number)
        Assert.Equal(Some "Subitem 1", headToString subitem1.Head)
        
        let subitem2 = listBlock.Items.[3]
        Assert.Equal(Some "2.2.", numberToString subitem2.Number)
        Assert.Equal(Some "Subitem 2", headToString subitem2.Head)
    | _ -> Assert.True(false, "Expected list block")

[<Fact>]
let ``List with content and dictionary`` () =
    let input = """<list kind=".">
1. First
First body
2. Second
Some more text
<dict sep=":">
Key: Value
Another Key: Another Value
</dict>
</list>"""
    
    let result = parseDocument input
    
    Assert.Equal("block", getBlockKind result)
    Assert.Equal(1, result.Body.Length)
    
    match result.Body.[0] with
    | ListBlock listBlock ->
        Assert.Equal("list", getListKind listBlock)
        Assert.Equal(2, listBlock.Items.Length)
        
        let firstItem = listBlock.Items.[0]
        Assert.Equal(Some "1.", numberToString firstItem.Number)
        Assert.Equal(Some "First", headToString firstItem.Head)
        Assert.Equal(1, firstItem.Body.Length)
        
        match firstItem.Body.[0] with
        | Text text -> Assert.Equal("First body", text)
        | _ -> Assert.True(false, "Expected text in first item body")
        
        let secondItem = listBlock.Items.[1]
        Assert.Equal(Some "2.", numberToString secondItem.Number)
        Assert.Equal(Some "Second", headToString secondItem.Head)
        Assert.Equal(2, secondItem.Body.Length)
        
        match secondItem.Body.[0] with
        | Text text -> Assert.Equal("Some more text", text)
        | _ -> Assert.True(false, "Expected text in second item body")
        
        match secondItem.Body.[1] with
        | Dictionary dict ->
            Assert.Equal("dict", getDictKind dict)
            Assert.Equal(2, dict.Items.Count)
            Assert.Equal("Value", dict.Items.["Key"])
            Assert.Equal("Another Value", dict.Items.["Another Key"])
        | _ -> Assert.True(false, "Expected dictionary in second item body")
    | _ -> Assert.True(false, "Expected list block")