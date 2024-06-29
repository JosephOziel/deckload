USING: peg peg.ebnf kernel strings sequences multiline ;
IN: deckload.parser

TUPLE: var { name string } ;
TUPLE: const { name string } ;
TUPLE: rule left right ;
C: <var> var
C: <const> const
C: <rule> rule

! should groups be represented some way?
EBNF: deckload-parse [=[
    spaces = [ \t\n\r]* => [[ drop ignore ]]
    ident = [^=.[\]$ \t\n\r]+ => [[ >string <const> ]]
    var = "$"~ [^=.[\]$ \t\n\r]+ => [[ >string <var> ]]
    expr = (spaces ( "["~ expr "]"~ | ident | var ) spaces)+
    def = expr "="~ expr "."~ => [[ first2 <rule> ]]
    prog = def*
]=]
