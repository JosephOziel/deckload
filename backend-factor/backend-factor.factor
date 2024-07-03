USING: accessors arrays combinators deckload.ir deckload.parser formatting kernel match namespaces math
math.parser prettyprint ranges sequences sequences.deep sequences.generalizations sequences.repeating
;
FROM: deckload.ir => match-var ;
IN: deckload.backend-factor

CONSTANT: names V{ }

! HELPERS:
: vec-to-str ( vec -- str ) 
    " " join "V{ %s }" sprintf ;

: boilerplate ( -- code ) 
    "USING: sequences.generalizations match ;\nFROM: syntax => _ ;\n\n" ;

:: compile-pat ( pat n! -- code )
    pat
    [ { 
        { [ dup match-const? ] [ const>> <const> ] }
        { [ dup match-var = ] [ drop n dup  1 - n! ] }
        [ n compile-pat ] 
    } cond ] map ;

: compile-body ( body -- code )
    [ 
        {
            { [ dup const? ] [ dup name>> names member? [ name>> "[ `%s` ]" sprintf ] [ unparse ] if ] }
            { [ dup var? ] [ num>> number>string ] }
            [ compile-body vec-to-str ]
        } cond 
    ] map dup 
    [ 
        {
            { [ dup first 91 = ] [ drop "_ call" ] } ! 91 is the ascii number for [
            [ drop "_" ]
        } cond 
    ] map " " join "'[ %s ]" sprintf
    [ " " join ] dip "[ %s %s ]" sprintf ;

:: compile-case ( rule -- code ) 
    "{ "
    rule matcher>> pat>> dup flatten [ match-var = ] count 1 - compile-pat unparse unclip drop 
    " "
    rule body>> compile-body
    " }\n" 5 narray concat ;

:: compile-normal ( fn -- code ) 
    fn second [ matcher>> pat>> flatten [ match-var = ] count ] map supremum [0..b) >array [ number>string ] map " " join "MATCH-VARS: %s ;\n" sprintf
    fn first dup names push
    fn second first matcher>> pat>> length :> l
    l " 0 " swap repeat "MACRO: `%s` (%s-- 0 )\n" sprintf
    l "%s narray\n" sprintf
    fn second [ compile-case ] map "" join "{\n%s} match-cond ;\n\n" sprintf
    4array concat ;

! assumes all rules for the function take in the same number of args
! : compile-rule ( rule -- code ) 
!     first "main" = [ compile-main ] [ compile-normal ] if
! ;
