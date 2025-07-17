module TimeToActParser.DocumentParser

open System
open System.Text.RegularExpressions
open TimeToActParser.Types

// Common regex pattern helper
let tryMatchRegex (pattern: string) (input: string) =
    let match' = Regex.Match(input, pattern)
    if match'.Success then Some match' else None

// Dictionary parsing domain operations
let parseDictSeparator (line: string) =
    let pattern = @"<dict\s+sep=""([^""]+)""\s*>"
    match tryMatchRegex pattern line with
    | Some match' -> Some (Separator.create match'.Groups.[1].Value)
    | None -> None

// Helper function to create dictionary from accumulated items
let createDictionary (separator: Separator) (acc: Map<string, string>) =
    { Separator = separator; Items = acc }

// Helper function to parse key-value pair
let parseKeyValuePair (line: string) (separator: Separator) =
    let separatorValue = Separator.value separator
    let parts = line.Split([|separatorValue|], 2, StringSplitOptions.None)
    if parts.Length = 2 then
        let key = parts.[0].Trim()
        let value = parts.[1].Trim()
        Some (key, value)
    else
        None

let rec parseDictionary (lines: string list) (separator: Separator) : Dictionary * string list =
    let rec processDictLines (lines: string list) (acc: Map<string, string>) =
        match lines with
        | [] -> 
            let dict = createDictionary separator acc
            (dict, [])
        | line :: rest ->
            let trimmed = line.Trim()
            if String.IsNullOrWhiteSpace(trimmed) then
                processDictLines rest acc
            elif trimmed = "</dict>" then
                let dict = createDictionary separator acc
                (dict, rest)
            else
                match parseKeyValuePair trimmed separator with
                | Some (key, value) ->
                    processDictLines rest (acc.Add(key, value))
                | None ->
                    processDictLines rest acc
    
    processDictLines lines Map.empty

// List parsing domain operations
let parseListKind (line: string) =
    let pattern = @"<list\s+kind=""([^""]+)""\s*>"
    match tryMatchRegex pattern line with
    | Some match' ->
        match match'.Groups.[1].Value with
        | "." -> Some Ordered
        | "*" -> Some Bulleted
        | _ -> None
    | None -> None

let parseListItem (line: string) (kind: ListKind) =
    let trimmed = line.Trim()
    match kind with
    | Ordered ->
        let pattern = @"^(\d+(?:\.\d+)*\.)\s*(.*)"
        match tryMatchRegex pattern trimmed with
        | Some match' ->
            let marker = ListMarker.create match'.Groups.[1].Value
            let head = DocumentHead.create match'.Groups.[2].Value
            Some (marker, head)
        | None -> None
    | Bulleted ->
        if trimmed.StartsWith("•") then
            let marker = ListMarker.create "•"
            let head = DocumentHead.create (trimmed.Substring(1).Trim())
            Some (marker, head)
        else
            None

// Helper function to append content to block body
let appendToBody (block: Block) (content: ContentNode) =
    { block with Body = block.Body @ [content] }

// Helper function to finalize current item
let finalizeCurrentItem (currentItem: Block option) (acc: Block list) =
    match currentItem with
    | Some item -> acc @ [item]
    | None -> acc

// Helper function to start new item
let startNewItem (currentItem: Block option) (acc: Block list) (marker: ListMarker) (head: DocumentHead) =
    let newItem = { Number = Some marker; Head = Some head; Body = [] }
    let updatedAcc = finalizeCurrentItem currentItem acc
    (updatedAcc, Some newItem)

let rec parseList (lines: string list) (kind: ListKind) : ListBlock * string list =
    let rec processListLines (lines: string list) (acc: Block list) (currentItem: Block option) =
        match lines with
        | [] -> 
            let finalItems = finalizeCurrentItem currentItem acc
            let listBlock : ListBlock = { Kind = kind; Items = finalItems }
            (listBlock, [])
        | line :: rest ->
            let trimmed = line.Trim()
            if String.IsNullOrWhiteSpace(trimmed) then
                processListLines rest acc currentItem
            elif trimmed = "</list>" then
                let finalItems = finalizeCurrentItem currentItem acc
                let listBlock : ListBlock = { Kind = kind; Items = finalItems }
                (listBlock, rest)
            else
                match parseListItem trimmed kind with
                | Some (marker, head) ->
                    let (updatedAcc, newItem) = startNewItem currentItem acc marker head
                    processListLines rest updatedAcc newItem
                | None ->
                    match currentItem with
                    | Some item ->
                        if trimmed.StartsWith("<dict") then
                            match parseDictSeparator trimmed with
                            | Some separator ->
                                let (dict, remaining) = parseDictionary rest separator
                                let updatedItem = appendToBody item (Dictionary dict)
                                processListLines remaining acc (Some updatedItem)
                            | None -> processListLines rest acc (Some item)
                        else
                            let updatedItem = appendToBody item (Text trimmed)
                            processListLines rest acc (Some updatedItem)
                    | None ->
                        processListLines rest acc None
    
    processListLines lines [] None

// Active patterns for line parsing optimization
let (|EmptyLine|_|) (line: string) =
    if String.IsNullOrWhiteSpace(line.Trim()) then Some () else None

let (|HeadTag|_|) (line: string) =
    let trimmed = line.Trim()
    if trimmed.StartsWith("<head>") && trimmed.EndsWith("</head>") then
        Some (trimmed.Substring(6, trimmed.Length - 13))
    else None

let (|BlockStart|_|) (line: string) =
    if line.Trim() = "<block>" then Some () else None

let (|BlockEnd|_|) (line: string) =
    if line.Trim() = "</block>" then Some () else None

let (|DictStart|_|) (line: string) =
    let trimmed = line.Trim()
    if trimmed.StartsWith("<dict") then
        parseDictSeparator trimmed
    else None

let (|ListStart|_|) (line: string) =
    let trimmed = line.Trim()
    if trimmed.StartsWith("<list") then
        parseListKind trimmed
    else None

let (|TextContent|) (line: string) = line.Trim()

// Block parsing domain operations using active patterns
let rec parseLines (lines: string list) : Block * string list =
    let rec processLines (lines: string list) (acc: Block) =
        match lines with
        | [] -> (acc, [])
        | line :: rest ->
            match line with
            | EmptyLine -> 
                processLines rest acc
            | HeadTag headContent ->
                let head = DocumentHead.create headContent
                processLines rest { acc with Head = Some head }
            | BlockStart ->
                let (nestedBlock, remaining) = parseLines rest
                processLines remaining (appendToBody acc (Block nestedBlock))
            | BlockEnd ->
                (acc, rest)
            | DictStart separator ->
                let (dict, remaining) = parseDictionary rest separator
                processLines remaining (appendToBody acc (Dictionary dict))
            | ListStart kind ->
                let (list, remaining) = parseList rest kind
                processLines remaining (appendToBody acc (ListBlock list))
            | TextContent text ->
                processLines rest (appendToBody acc (Text text))
    
    processLines lines { Number = None; Head = None; Body = [] }

let parseDocument (input: string) =
    if String.IsNullOrWhiteSpace(input) then
        { Number = None; Head = None; Body = [] }
    else
        let lines = input.Split([|'\n'|], StringSplitOptions.None)
                    |> Array.map (fun s -> s.Trim())
                    |> Array.filter (fun s -> not (String.IsNullOrWhiteSpace(s)))
                    |> Array.toList
        
        let (result, _) = parseLines lines
        result