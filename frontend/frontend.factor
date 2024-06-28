USING: peg peg.ebnf kernel ;
IN: deckload.frontend

EBNF: deckload-parse [=[
    spaces = [ \t\n\r]* => [[ drop ignore ]]
    ident = [0-9a-zA-Z]+
    var = "$" [0-9a-zA-Z]+
    expr = (spaces ( "[" expr "]" | ident | var ) spaces)+
    def = expr "=" expr "."
    prog = def*
]=]

"[ abba $0 ] = [ $1 ] cdf . " deckload-parse .
