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
let createDictionary (separator: Separator) (acc: (string * string) list) =
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
    let rec processDictLines (lines: string list) (acc: (string * string) list) =
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
                    processDictLines rest (acc @ [(key, value)])
                | None ->
                    processDictLines rest acc
    
    processDictLines lines []

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

// Extract bullet detection patterns
let isBulletMarker (line: string) (marker: string) =
    line.Trim().StartsWith(marker + " ")

let extractBulletContent (line: string) (marker: string) =
    let trimmed = line.Trim()
    if trimmed.StartsWith(marker) then
        trimmed.Substring(marker.Length).Trim()
    else
        ""

let parseOrderedListItem (line: string) =
    let trimmed = line.Trim()
    let pattern = @"^(\d+(?:\.\d+)*\.)\s*(.*)"
    match tryMatchRegex pattern trimmed with
    | Some match' ->
        let marker = ListMarker.create match'.Groups.[1].Value
        let head = DocumentHead.create match'.Groups.[2].Value
        Some (marker, head)
    | None -> None

let parseBulletedListItem (line: string) =
    let trimmed = line.Trim()
    if isBulletMarker trimmed "•" then
        let marker = ListMarker.create "•"
        let head = DocumentHead.create (extractBulletContent trimmed "•")
        Some (marker, head)
    elif isBulletMarker trimmed "*" then
        let marker = ListMarker.create "*"
        let head = DocumentHead.create (extractBulletContent trimmed "*")
        Some (marker, head)
    elif isBulletMarker trimmed "o" then
        let marker = ListMarker.create "o"
        let head = DocumentHead.create (extractBulletContent trimmed "o")
        Some (marker, head)
    else
        None

let parseListItem (line: string) (kind: ListKind) =
    match kind with
    | Ordered -> parseOrderedListItem line
    | Bulleted -> parseBulletedListItem line

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

// Helper functions for nested list detection
let isNestedOrderedItem (line: string) =
    let trimmed = line.Trim()
    let pattern = @"^(\d+\.\d+\.)\s*(.*)"
    tryMatchRegex pattern trimmed |> Option.isSome

let isNestedBulletItem (line: string) =
    let trimmed = line.Trim()
    trimmed.StartsWith("o ") || trimmed.StartsWith("* ")

let isNestableListItem (line: string) =
    isNestedOrderedItem line || isNestedBulletItem line

// Collect consecutive nested items at the same level, stopping at explicit tags
let collectNestedItems (lines: string list) =
    let rec collect (lines: string list) (acc: string list) =
        match lines with
        | [] -> acc
        | line :: rest ->
            let trimmed = line.Trim()
            if trimmed.StartsWith("<list") || trimmed.StartsWith("</list>") then
                acc // Stop collecting when we hit explicit list tags
            elif isNestedOrderedItem trimmed then
                collect rest (acc @ [line])
            elif isNestedBulletItem trimmed then
                collect rest (acc @ [line])
            else
                acc
    
    collect lines []

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
                // Check if this is a nested item that should be collected
                // Don't auto-nest if there are explicit <list> tags in the remaining content
                // Also don't auto-nest if we're parsing the same kind of list (explicit lists should be flat)
                if isNestableListItem trimmed && currentItem.IsSome && not (rest |> List.exists (fun l -> l.Trim().StartsWith("<list"))) && not (kind = Bulleted && trimmed.StartsWith("* ")) then
                    // Collect nested items and create nested list
                    let nestedItems = collectNestedItems (line :: rest)
                    let nestedListKind = if isNestedOrderedItem trimmed then Ordered else Bulleted
                    // Parse nested items as individual blocks instead of recursive parseList
                    let nestedBlocks = nestedItems |> List.choose (fun item ->
                        match parseListItem item nestedListKind with
                        | Some (marker, head) -> Some { Number = Some marker; Head = Some head; Body = [] }
                        | None -> None)
                    let nestedList = { Kind = nestedListKind; Items = nestedBlocks }
                    let updatedItem = appendToBody currentItem.Value (ListBlock nestedList)
                    // Skip the consumed nested items
                    let remainingLines = List.skip (List.length nestedItems) (line :: rest)
                    processListLines remainingLines acc (Some updatedItem)
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
                            elif trimmed.StartsWith("<list") then
                                match parseListKind trimmed with
                                | Some nestedKind ->
                                    let (nestedList, remaining) = parseList rest nestedKind
                                    // For explicit nested lists, we need to find the appropriate parent
                                    // For bulleted lists, attach to the last main item (not a sub-item)
                                    if nestedKind = Bulleted && acc.Length > 0 then
                                        // Find the last item that doesn't have a decimal sub-number (like "2.1.")
                                        let lastMainItem = acc |> List.rev |> List.tryFind (fun block ->
                                            match block.Number with
                                            | Some number -> 
                                                let numStr = ListMarker.value number
                                                not (numStr.Contains(".") && numStr.Length > 2) // Not a sub-item like "2.1."
                                            | None -> false)
                                        match lastMainItem with
                                        | Some target -> 
                                            let updatedTarget = appendToBody target (ListBlock nestedList)
                                            let updatedAcc = acc |> List.map (fun b -> if b = target then updatedTarget else b)
                                            // Finalize current item and continue
                                            let finalAcc = finalizeCurrentItem currentItem updatedAcc
                                            processListLines remaining finalAcc None
                                        | None -> 
                                            let updatedItem = appendToBody item (ListBlock nestedList)
                                            processListLines remaining acc (Some updatedItem)
                                    else
                                        let updatedItem = appendToBody item (ListBlock nestedList)
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