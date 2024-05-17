USING: ascii combinators kernel peg peg.ebnf multiline regexp sequences sequences.deep splitting strings ;
IN: deckload

! : remove-ws ( code -- ncode ) [ blank? ] reject ;

! (string | (.))*
EBNF: parse-rw [=[
    ws = (" " | "\n" | "\r" | "\t")*
    string2 = "(" ([^()]+ | string2)* ")" => [[ flatten [ { { "(" [ 40 ] } { ")" [ 41 ] } [ ] } case ] map ]]
    string = ("(" ([^()]+ | string2)* ")") => [[ but-last rest { } [ append ] reduce ]]
    rw = ws~ string ws~ string ws~ "@"~ ws~ => [[ [ { } [ append ] reduce >string ] map ]]
    program = rw*
]=]

: apply-rw ( code -- ncode ) ":" split first2 swap parse-rw [ first2 [ <regexp> ] dip re-replace ] each ;