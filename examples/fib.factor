USING: continuations match sequences.generalizations quotations ;
FROM: syntax => _ ;

: deckload-call ( quot -- quot' ) { } swap with-datastack >quotation ;

SYMBOL: deckload-z
SYMBOL: deckload-s
DEFER: deckload-*
DEFER: deckload-+
DEFER: deckload-fac
DEFER: deckload-main

MATCH-VARS: ?0 ?1 ;

MACRO: deckload-* (  0  0 -- 0 )
2 narray
{
{ { ?0 deckload-z } [  [ deckload-z ] '[ _ call ]  ] }
{ { ?1 [ ?0 deckload-s ] } [ ?1 ?0 '[ _ _ deckload-* ] ?1 [ deckload-+ ] '[ _ deckload-call _ call ]  ] }
} match-cond ;

MACRO: deckload-+ (  0  0 -- 0 )
2 narray
{
{ { ?0 deckload-z } [  ?0 '[ _ ]  ] }
{ { ?1 [ ?0 deckload-s ] } [  ?1 '[ _ deckload-s ] ?0 [ deckload-+ ] '[ _ deckload-call _ _ call ]  ] }
} match-cond ;

NEED TO CURRY EVERY VARIABLE
ALSO FACTOR COMES WITH NON LINEAR PATTERN MATCHING, SO NO NEED TO HANDLE IT