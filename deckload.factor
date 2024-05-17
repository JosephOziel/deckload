USING: ascii combinators kernel peg peg.ebnf multiline regexp sequences sequences.deep splitting strings ;
IN: deckload

EBNF: parse-rw [=[
    string2 = "(" ([^()]+ | string2)* ")" => [[ flatten [ { { "(" [ 40 ] } { ")" [ 41 ] } [ ] } case ] map ]]
    string = ("(" ([^()]+ | string2)* ")") => [[ but-last rest { } [ append ] reduce ]]
    rw = {string string "@"~} => [[ [ { } [ append ] reduce >string ] map ]]
    program = rw*
]=]

! LIMITATIONS TO THE REGEX REWRITES (also possibly to fix)
! -doesnt apply recursively
! -no backreferences :(
: apply-rw ( code -- ncode ) ":" split first2 swap parse-rw [ first2 [ <regexp> ] dip re-replace ] each ;