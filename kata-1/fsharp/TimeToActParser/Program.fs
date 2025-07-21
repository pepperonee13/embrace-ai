open TimeToActParser.DocumentParser
open TimeToActParser.JsonSerializer

[<EntryPoint>]
let main argv =
    let input = """<list kind=".">
1. Beginning
2. Main 
2.1. Subsection
<list kind="*">
* Bullet 1
* Bullet 2
</list>
3. Ending
</list>"""
    
    let result = parseDocument input
    let json = toJson result
    
    printfn "%s" json
    0
