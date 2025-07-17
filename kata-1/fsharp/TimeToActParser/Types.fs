module TimeToActParser.Types

// Domain-specific value objects
type Separator = Separator of string

type ListMarker = 
    | OrderedList of string  // "1.", "2.1.", etc.
    | BulletedList of string // "•", "o", etc.

type ListKind = 
    | Ordered    // "."
    | Bulleted   // "*"

type DocumentHead = DocumentHead of string

// Core domain types with explicit discrimination
type ContentNode = 
    | Text of string
    | Block of Block
    | ListBlock of ListBlock
    | Dictionary of Dictionary

and Block = {
    Number: ListMarker option
    Head: DocumentHead option
    Body: ContentNode list
}

and ListBlock = {
    Kind: ListKind
    Items: Block list
}

and Dictionary = {
    Separator: Separator
    Items: Map<string, string>
}

// Domain operations
module ListMarker =
    let create (marker: string) = 
        if marker = "•" then BulletedList marker
        elif marker.Contains(".") then OrderedList marker
        else BulletedList marker
    
    let value = function
        | OrderedList s -> s
        | BulletedList s -> s

module DocumentHead =
    let create (value: string) = DocumentHead value
    let value (DocumentHead h) = h

module Separator =
    let create (value: string) = Separator value
    let value (Separator s) = s
    let defaultColon = Separator ":"

// Test helper functions for backward compatibility
module TestHelpers =
    let getBlockKind (block: Block) = "block"
    let getListKind (list: ListBlock) = "list"
    let getDictKind (dict: Dictionary) = "dict"
    
    let headToString = function
        | Some head -> Some (DocumentHead.value head)
        | None -> None
    
    let numberToString = function
        | Some marker -> Some (ListMarker.value marker)
        | None -> None