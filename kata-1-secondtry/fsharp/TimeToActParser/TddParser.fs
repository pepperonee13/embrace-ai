module TimeToActParser.TddParser

open System
open System.Text.RegularExpressions
open TimeToActParser.Types

// Step 3: Add dictionary parsing
let parseDictSeparator (line: string) =
    let pattern = @"<dict\s+sep=""([^""]+)""\s*>"
    let match' = Regex.Match(line, pattern)
    if match'.Success then
        Some match'.Groups.[1].Value
    else
        None

let rec parseDictionary (lines: string list) (separator: string) : Dictionary * string list =
    let rec processDictLines (lines: string list) (acc: Map<string, string>) =
        match lines with
        | [] -> 
            let dict : Dictionary = { Kind = "dict"; Items = acc }
            (dict, [])
        | line :: rest ->
            let trimmed = line.Trim()
            if String.IsNullOrWhiteSpace(trimmed) then
                processDictLines rest acc
            elif trimmed = "</dict>" then
                let dict : Dictionary = { Kind = "dict"; Items = acc }
                (dict, rest)
            else
                let parts = trimmed.Split([|separator|], 2, StringSplitOptions.None)
                if parts.Length = 2 then
                    let key = parts.[0].Trim()
                    let value = parts.[1].Trim()
                    processDictLines rest (acc.Add(key, value))
                else
                    processDictLines rest acc
    
    processDictLines lines Map.empty

// Step 4: Add list parsing
let parseListKind (line: string) =
    let pattern = @"<list\s+kind=""([^""]+)""\s*>"
    let match' = Regex.Match(line, pattern)
    if match'.Success then
        Some match'.Groups.[1].Value
    else
        None

let parseListItem (line: string) (kind: string) =
    let trimmed = line.Trim()
    match kind with
    | "." ->
        let pattern = @"^(\d+(?:\.\d+)*\.)\s*(.*)"
        let match' = Regex.Match(trimmed, pattern)
        if match'.Success then
            Some (match'.Groups.[1].Value, match'.Groups.[2].Value)
        else
            None
    | "*" ->
        if trimmed.StartsWith("•") then
            Some ("•", trimmed.Substring(1).Trim())
        else
            None
    | _ -> None

let rec parseList (lines: string list) (kind: string) : ListBlock * string list =
    let rec processListLines (lines: string list) (acc: Block list) (currentItem: Block option) =
        match lines with
        | [] -> 
            let finalItems = 
                match currentItem with
                | Some item -> acc @ [item]
                | None -> acc
            let listBlock : ListBlock = { Kind = "list"; Items = finalItems }
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
                let listBlock : ListBlock = { Kind = "list"; Items = finalItems }
                (listBlock, rest)
            else
                match parseListItem trimmed kind with
                | Some (number, head) ->
                    let newItem = { Kind = "block"; Number = Some number; Head = Some head; Body = [] }
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

let rec parseLines (lines: string list) : Block * string list =
    let rec processLines (lines: string list) (acc: Block) =
        match lines with
        | [] -> (acc, [])
        | line :: rest ->
            let trimmed = line.Trim()
            if String.IsNullOrWhiteSpace(trimmed) then
                processLines rest acc
            elif trimmed.StartsWith("<head>") && trimmed.EndsWith("</head>") then
                let headContent = trimmed.Substring(6, trimmed.Length - 13)
                processLines rest { acc with Head = Some headContent }
            elif trimmed = "<block>" then
                let (nestedBlock, remaining) = parseLines rest
                processLines remaining { acc with Body = acc.Body @ [Block nestedBlock] }
            elif trimmed = "</block>" then
                (acc, rest)
            elif trimmed.StartsWith("<dict") then
                match parseDictSeparator trimmed with
                | Some separator ->
                    let (dict, remaining) = parseDictionary rest separator
                    processLines remaining { acc with Body = acc.Body @ [Dictionary dict] }
                | None -> processLines rest acc
            elif trimmed.StartsWith("<list") then
                match parseListKind trimmed with
                | Some kind ->
                    let (list, remaining) = parseList rest kind
                    processLines remaining { acc with Body = acc.Body @ [ListBlock list] }
                | None -> processLines rest acc
            else
                processLines rest { acc with Body = acc.Body @ [Text trimmed] }
    
    processLines lines { Kind = "block"; Number = None; Head = None; Body = [] }

let parseDocument (input: string) =
    if String.IsNullOrWhiteSpace(input) then
        { Kind = "block"; Number = None; Head = None; Body = [] }
    else
        let lines = input.Split([|'\n'|], StringSplitOptions.None)
                    |> Array.map (fun s -> s.Trim())
                    |> Array.filter (fun s -> not (String.IsNullOrWhiteSpace(s)))
                    |> Array.toList
        
        let (result, _) = parseLines lines
        result