module TimeToActParser.Types

type ContentNode = 
    | Text of string
    | Block of Block
    | ListBlock of ListBlock
    | Dictionary of Dictionary

and Block = {
    Kind: string
    Number: string option
    Head: string option
    Body: ContentNode list
}

and ListBlock = {
    Kind: string
    Items: Block list
}

and Dictionary = {
    Kind: string
    Items: Map<string, string>
}