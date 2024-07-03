USING: arrays kernel match math.parser multiline peg peg.ebnf
sequences strings vectors ;
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

: flatten ( tree -- flattened )
    dup vector? [
        [ flatten ] map dup empty? 
        [ unclip-last dup vector? [ append ] [ suffix ] if ] unless
        dup length 1 = [ first ] when
    ] when ;


EBNF: deckload-parse [=[
    spaces = [ \t\n\r]* => [[ drop ignore ]]
    import = "@"~ spaces [^=.[\]$@]+ spaces "."~ => [[ >string <import> ]]
    ident = [^=.[\]$@ \t\n\r]+ => [[ >string <const> ]]
    var = "$"~ [0-9]+ => [[ string>number <var> ]]
    expr = (spaces ( "["~ expr "]"~ | ident | var ) spaces)+ => [[ flatten ]]
    def = expr "="~ expr "."~ => [[ first2 swap unclip-last { { T{ const f ?a } [ ?a ] } [ "the last item on the left of a rule should be a const" throw ] } match-cond spin <rule> ]]
    prog = (def | import)*
]=]
