USING: ascii combinators kernel peg peg.ebnf persistent.deques multiline regexp sequences sequences.deep splitting strings ;
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
: apply-rw ( code -- ncode ) "#" split first2 swap parse-rw [ first2 [ <regexp> ] dip re-replace ] each ;

! program start with empty deque: <deque> 
: twor ( deq -- ndeq snd fst ) pop-back pop-back spin ; ! get right two
: twol ( deq -- ndeq snd fst ) pop-front pop-front spin ; ! get left two
: ptwor ( deq snd fst -- ndeq ) swapd push-back swap push-back ; ! push two right
: ptwol ( deq snd fst -- ndeq ) swapd push-front swap push-front ; ! push two left

: oner ( deq -- ndeq fst ) pop-back swap ; 
: onel ( deq -- ndeq fst ) pop-front swap ; 

: (~) ( deq -- ndeq ) twor swap ptwor ; 
: (/) ( deq -- ndeq ) twol swap ptwol ; 
: (:) ( deq -- ndeq ) oner dup ptwor ; 
: (;) ( deq -- ndeq ) onel dup ptwol ;
: (!) ( deq -- ndeq ) oner drop ; 
: (?) ( deq -- ndeq ) onel drop ; 


EBNF: parse [=[
    string2 = "(" ([^()]+ | string2)* ")" => [[ flatten [ { { "(" [ 40 ] } { ")" [ 41 ] } [ ] } case ] map ]]
    string = ("(" ([^()]+ | string2)* ")") => [[ but-last rest { } [ append ] reduce flatten >string '[ _ push-back ] ]]
    swapr = "~" => [[ [ (~) ] ]]
    swapl = "/" => [[ [ (/) ] ]]
    dupr = ":" => [[ [ (:) ] ]]
    dupl = ";" => [[ [ (;) ] ]]
    popr = "!" => [[ [ (!) ] ]]
    popl = "?" => [[ [ (?) ] ]]
    catr = "*" => [[ [ (*) ] ]]
    catl = "+" => [[ [ (+) ] ]]
    unitr = "a" => [[ [ a ] ]]
    unitl = "b" => [[ [ b ] ]]
    eval = "^" => [[ parse ]]
    printr = "S" => [[ [ S ] ]]
    printl = "O" => [[ [ O ] ]]
    rotr = "<" => [[ [ (<) ] ]]
    rotl = ">" => [[ [ (>) ] ]]
    prog = (swapr|swapl|dupr|dupl|popr|popl|catr|catl|unitr|unitl|eval|printr|printl|rotr|rotl|string)* => [[ [ ] [ compose ] reduce ]]
]=]