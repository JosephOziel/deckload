USING: ascii kernel peg peg.ebnf multiline regexp sequences sequences.deep splitting ;
IN: deckload

! : remove-ws ( code -- ncode ) [ blank? ] reject ;

! (string | (.))*
EBNF: parse-rw [=[
    ws = (" " | "\n" | "\r" | "\t")*
    string2 = "(" ([^()]+ | string2)* ")" => [[ flatten ]]
    string = ("(" ([^()]+ | string2)* ")") | "()"~ => [[ dup ignore = [ drop { } ] [ second flatten ] if ]]
    rw = ws~ string ws~ string ws~ "@"~ ws~
    program = rw* 
]=]

: apply-rw ( code -- ncode ) 