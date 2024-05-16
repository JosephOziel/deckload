USING: ascii kernel peg peg.ebnf multiline regexp sequences sequences.deep ;
IN: deckload

: remove-ws ( code -- ncode ) [ blank? ] reject ;

EBNF: parse-rewrites [=[
    ws = (" " | "\n" | "\r" | "\t")
    string = ("(" ([^()]+ | string)* ")") => [[ dup ignore = [ drop { } ] [ second flatten ] if ]]
    rw = ws~ string ws~ string ws~ "@" ws~
]=]