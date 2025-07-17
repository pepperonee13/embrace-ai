open TimeToActParser.TddParser
open TimeToActParser.JsonSerializer

[<EntryPoint>]
let main argv =
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
    let json = toJson result
    
    printfn "%s" json
    0
