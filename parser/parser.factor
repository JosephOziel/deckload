USING: arrays peg peg.ebnf kernel strings sequences multiline math.parser match ;
IN: deckload.parser

TUPLE: var num ;
TUPLE: const name ;
TUPLE: rule name left right ;
TUPLE: import file ;

C: <var> var
C: <const> const
C: <rule> rule
C: <import> import 

MATCH-VARS: ?a _ ;

EBNF: deckload-parse [=[
    spaces = [ \t\n\r]* => [[ drop ignore ]]
    import = "@"~ spaces [^=.[\]$@]+ spaces "."~ => [[ >string <import> ]]
    ident = [^=.[\]$@ \t\n\r]+ => [[ >string <const> ]]
    var = "$"~ [0-9]+ => [[ string>number <var> ]]
    expr = (spaces ( "["~ expr "]"~ | ident | var ) spaces)+
    def = expr "="~ expr "."~ => [[ first2 swap unclip-last { { T{ const f ?a } [ ?a ] } [ "the last item on the left of a rule should be a const" throw ] } match-cond spin <rule> ]]
    prog = (import)*
]=]