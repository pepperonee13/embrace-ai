module TimeToActParser.JsonSerializer

open System.Text.Json
open TimeToActParser.Types

let rec private serializeContentNode (node: ContentNode) =
    match node with
    | Text text -> JsonSerializer.Serialize(text)
    | Block block -> serializeBlock block
    | ListBlock listBlock -> serializeListBlock listBlock
    | Dictionary dict -> serializeDictionary dict

and private serializeBlock (block: Block) =
    let mutable properties = [("kind", JsonSerializer.Serialize("block"))]
    
    match block.Number with
    | Some (OrderedList number) -> properties <- properties @ [("number", JsonSerializer.Serialize(number))]
    | Some (BulletedList marker) -> properties <- properties @ [("number", JsonSerializer.Serialize(marker))]
    | None -> ()
    
    match block.Head with
    | Some head -> properties <- properties @ [("head", JsonSerializer.Serialize(DocumentHead.value head))]
    | None -> ()
    
    if not block.Body.IsEmpty then
        let bodyJson = block.Body |> List.map serializeContentNode |> fun items -> "[" + String.concat "," items + "]"
        properties <- properties @ [("body", bodyJson)]
    
    let propsString = properties |> List.map (fun (k, v) -> sprintf "\"%s\":%s" k v) |> String.concat ","
    "{" + propsString + "}"

and private serializeListBlock (listBlock: ListBlock) =
    let itemsJson = listBlock.Items |> List.map serializeBlock |> fun items -> "[" + String.concat "," items + "]"
    sprintf "{\"kind\":\"list\",\"items\":%s}" itemsJson

and private serializeDictionary (dict: Dictionary) =
    let itemsJson = 
        dict.Items 
        |> List.map (fun (k, v) -> sprintf "\"%s\":%s" k (JsonSerializer.Serialize(v)))
        |> String.concat ","
        |> fun items -> "{" + items + "}"
    
    sprintf "{\"kind\":\"dict\",\"items\":%s}" itemsJson

let toJson (block: Block) =
    serializeBlock block