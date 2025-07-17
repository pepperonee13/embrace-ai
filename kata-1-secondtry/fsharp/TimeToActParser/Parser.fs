module TimeToActParser.Parser

open System
open System.Text.RegularExpressions
open TimeToActParser.Types

let createBlock() = {
    Kind = "block"
    Number = None
    Head = None
    Body = []
}

let createListBlock() = {
    Kind = "list"
    Items = []
}

let createDictionary() = {
    Kind = "dict"
    Items = Map.empty
}

let private parseHeadTag (line: string) =
    let headPattern = @"<head>(.*?)</head>"
    let match' = Regex.Match(line, headPattern)
    if match'.Success then
        Some match'.Groups.[1].Value
    else
        None

let private parseBlockTag (line: string) =
    line.Trim() = "<block>"

let private parseEndBlockTag (line: string) =
    line.Trim() = "</block>"

let private parseDictTag (line: string) =
    let dictPattern = @"<dict\s+sep=""([^""]*)""\s*>"
    let match' = Regex.Match(line, dictPattern)
    if match'.Success then
        Some match'.Groups.[1].Value
    else if line.Trim() = "<dict>" then
        Some ":"
    else
        None

let private parseEndDictTag (line: string) =
    line.Trim() = "</dict>"

let private parseListTag (line: string) =
    let listPattern = @"<list\s+kind=""([^""]*)""\s*>"
    let match' = Regex.Match(line, listPattern)
    if match'.Success then
        Some match'.Groups.[1].Value
    else
        None

let private parseEndListTag (line: string) =
    line.Trim() = "</list>"

let private parseDictItem (line: string) (separator: string) =
    let parts = line.Split([|separator|], 2, StringSplitOptions.None)
    if parts.Length = 2 then
        Some (parts.[0].Trim(), parts.[1].Trim())
    else
        None

let private parseListItem (line: string) (listKind: string) =
    let trimmed = line.Trim()
    match listKind with
    | "." ->
        let dotPattern = @"^(\d+(?:\.\d+)*\.)\s*(.*)"
        let match' = Regex.Match(trimmed, dotPattern)
        if match'.Success then
            Some (match'.Groups.[1].Value, match'.Groups.[2].Value)
        else
            None
    | "*" ->
        if trimmed.StartsWith("•") then
            Some ("•", trimmed.Substring(1).Trim())
        else if trimmed.StartsWith("o") then
            Some ("o", trimmed.Substring(1).Trim())
        else
            None
    | _ -> None

let rec private parseLines (lines: string list) : Block * string list =
    let mutable currentBlock = createBlock()
    let mutable remainingLines = lines
    
    while not remainingLines.IsEmpty do
        let line = remainingLines.Head
        remainingLines <- remainingLines.Tail
        let trimmed = line.Trim()
        
        if not (String.IsNullOrWhiteSpace(trimmed)) then
            match parseHeadTag trimmed with
            | Some head ->
                currentBlock <- { currentBlock with Head = Some head }
            | None ->
                if parseBlockTag trimmed then
                    let (subBlock, remaining) = parseLines remainingLines
                    currentBlock <- { currentBlock with Body = currentBlock.Body @ [Block subBlock] }
                    remainingLines <- remaining
                elif parseEndBlockTag trimmed then
                    remainingLines <- line :: remainingLines.Tail
                    break
                else
                    match parseDictTag trimmed with
                    | Some separator ->
                        let (dict, remaining) = parseDictionary remainingLines separator
                        currentBlock <- { currentBlock with Body = currentBlock.Body @ [Dictionary dict] }
                        remainingLines <- remaining
                    | None ->
                        match parseListTag trimmed with
                        | Some listKind ->
                            let (listBlock, remaining) = parseList remainingLines listKind
                            currentBlock <- { currentBlock with Body = currentBlock.Body @ [ListBlock listBlock] }
                            remainingLines <- remaining
                        | None ->
                            currentBlock <- { currentBlock with Body = currentBlock.Body @ [Text trimmed] }
    
    (currentBlock, remainingLines)

and private parseDictionary (lines: string list) (separator: string) : Dictionary * string list =
    let mutable dict = createDictionary()
    let mutable remainingLines = lines
    
    while not remainingLines.IsEmpty do
        let line = remainingLines.Head
        remainingLines <- remainingLines.Tail
        let trimmed = line.Trim()
        
        if not (String.IsNullOrWhiteSpace(trimmed)) then
            if parseEndDictTag trimmed then
                break
            else
                match parseDictItem trimmed separator with
                | Some (key, value) ->
                    dict <- { dict with Items = dict.Items.Add(key, value) }
                | None ->
                    remainingLines <- line :: remainingLines
                    break
    
    (dict, remainingLines)

and private parseList (lines: string list) (listKind: string) : ListBlock * string list =
    let mutable listBlock = createListBlock()
    let mutable remainingLines = lines
    let mutable currentItem: Block option = None
    
    while not remainingLines.IsEmpty do
        let line = remainingLines.Head
        remainingLines <- remainingLines.Tail
        let trimmed = line.Trim()
        
        if not (String.IsNullOrWhiteSpace(trimmed)) then
            if parseEndListTag trimmed then
                match currentItem with
                | Some item -> listBlock <- { listBlock with Items = listBlock.Items @ [item] }
                | None -> ()
                break
            else
                match parseListItem trimmed listKind with
                | Some (number, head) ->
                    match currentItem with
                    | Some item -> listBlock <- { listBlock with Items = listBlock.Items @ [item] }
                    | None -> ()
                    currentItem <- Some { createBlock() with Number = Some number; Head = Some head }
                | None ->
                    match currentItem with
                    | Some item ->
                        match parseDictTag trimmed with
                        | Some separator ->
                            let (dict, remaining) = parseDictionary remainingLines separator
                            let updatedItem = { item with Body = item.Body @ [Dictionary dict] }
                            currentItem <- Some updatedItem
                            remainingLines <- remaining
                        | None ->
                            match parseListTag trimmed with
                            | Some nestedListKind ->
                                let (nestedList, remaining) = parseList remainingLines nestedListKind
                                let updatedItem = { item with Body = item.Body @ [ListBlock nestedList] }
                                currentItem <- Some updatedItem
                                remainingLines <- remaining
                            | None ->
                                let updatedItem = { item with Body = item.Body @ [Text trimmed] }
                                currentItem <- Some updatedItem
                    | None ->
                        remainingLines <- line :: remainingLines
                        break
    
    match currentItem with
    | Some item -> listBlock <- { listBlock with Items = listBlock.Items @ [item] }
    | None -> ()
    
    (listBlock, remainingLines)

let parseDocument (input: string) =
    let lines = input.Split([|'\n'; '\r'|], StringSplitOptions.RemoveEmptyEntries) |> Array.toList
    let (result, _) = parseLines lines
    result