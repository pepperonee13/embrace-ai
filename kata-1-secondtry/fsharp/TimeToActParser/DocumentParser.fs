module TimeToActParser.DocumentParser

open System
open System.Text.RegularExpressions
open TimeToActParser.Types

// Dictionary parsing domain operations
let parseDictSeparator (line: string) =
    let pattern = @"<dict\s+sep=""([^""]+)""\s*>"
    let match' = Regex.Match(line, pattern)
    if match'.Success then
        Some (Separator.create match'.Groups.[1].Value)
    else
        None

let rec parseDictionary (lines: string list) (separator: Separator) : Dictionary * string list =
    let rec processDictLines (lines: string list) (acc: Map<string, string>) =
        match lines with
        | [] -> 
            let dict : Dictionary = { Separator = separator; Items = acc }
            (dict, [])
        | line :: rest ->
            let trimmed = line.Trim()
            if String.IsNullOrWhiteSpace(trimmed) then
                processDictLines rest acc
            elif trimmed = "</dict>" then
                let dict : Dictionary = { Separator = separator; Items = acc }
                (dict, rest)
            else
                let separatorValue = Separator.value separator
                let parts = trimmed.Split([|separatorValue|], 2, StringSplitOptions.None)
                if parts.Length = 2 then
                    let key = parts.[0].Trim()
                    let value = parts.[1].Trim()
                    processDictLines rest (acc.Add(key, value))
                else
                    processDictLines rest acc
    
    processDictLines lines Map.empty

// List parsing domain operations
let parseListKind (line: string) =
    let pattern = @"<list\s+kind=""([^""]+)""\s*>"
    let match' = Regex.Match(line, pattern)
    if match'.Success then
        match match'.Groups.[1].Value with
        | "." -> Some Ordered
        | "*" -> Some Bulleted
        | _ -> None
    else
        None

let parseListItem (line: string) (kind: ListKind) =
    let trimmed = line.Trim()
    match kind with
    | Ordered ->
        let pattern = @"^(\d+(?:\.\d+)*\.)\s*(.*)"
        let match' = Regex.Match(trimmed, pattern)
        if match'.Success then
            let marker = ListMarker.create match'.Groups.[1].Value
            let head = DocumentHead.create match'.Groups.[2].Value
            Some (marker, head)
        else
            None
    | Bulleted ->
        if trimmed.StartsWith("•") then
            let marker = ListMarker.create "•"
            let head = DocumentHead.create (trimmed.Substring(1).Trim())
            Some (marker, head)
        else
            None

let rec parseList (lines: string list) (kind: ListKind) : ListBlock * string list =
    let rec processListLines (lines: string list) (acc: Block list) (currentItem: Block option) =
        match lines with
        | [] -> 
            let finalItems = 
                match currentItem with
                | Some item -> acc @ [item]
                | None -> acc
            let listBlock : ListBlock = { Kind = kind; Items = finalItems }
            (listBlock, [])
        | line :: rest ->
            let trimmed = line.Trim()
            if String.IsNullOrWhiteSpace(trimmed) then
                processListLines rest acc currentItem
            elif trimmed = "</list>" then
                let finalItems = 
                    match currentItem with
                    | Some item -> acc @ [item]
                    | None -> acc
                let listBlock : ListBlock = { Kind = kind; Items = finalItems }
                (listBlock, rest)
            else
                match parseListItem trimmed kind with
                | Some (marker, head) ->
                    let newItem = { Number = Some marker; Head = Some head; Body = [] }
                    let updatedAcc = 
                        match currentItem with
                        | Some item -> acc @ [item]
                        | None -> acc
                    processListLines rest updatedAcc (Some newItem)
                | None ->
                    match currentItem with
                    | Some item ->
                        if trimmed.StartsWith("<dict") then
                            match parseDictSeparator trimmed with
                            | Some separator ->
                                let (dict, remaining) = parseDictionary rest separator
                                let updatedItem = { item with Body = item.Body @ [Dictionary dict] }
                                processListLines remaining acc (Some updatedItem)
                            | None -> processListLines rest acc (Some item)
                        else
                            let updatedItem = { item with Body = item.Body @ [Text trimmed] }
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
                processLines remaining { acc with Body = acc.Body @ [Block nestedBlock] }
            | BlockEnd ->
                (acc, rest)
            | DictStart separator ->
                let (dict, remaining) = parseDictionary rest separator
                processLines remaining { acc with Body = acc.Body @ [Dictionary dict] }
            | ListStart kind ->
                let (list, remaining) = parseList rest kind
                processLines remaining { acc with Body = acc.Body @ [ListBlock list] }
            | TextContent text ->
                processLines rest { acc with Body = acc.Body @ [Text text] }
    
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