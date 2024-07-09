USING: accessors arrays assocs combinators deckload.ir
deckload.parser formatting kernel match math math.parser
namespaces prettyprint ranges sequences sequences.deep
sequences.generalizations sequences.repeating ;

FROM: deckload.ir => match-var ;
IN: deckload.backend-factor

! HELPERS:
: vec-to-str ( vec -- str ) 
    " " join "[ %s ]" sprintf ;

: boilerplate ( -- code ) 
    "USING: continuations match sequences.generalizations quotations ;\nFROM: syntax => _ ;\n\n: deckload-call ( quot -- quot' ) { } swap with-datastack >quotation ;\n\n" ;

:: complex-fried ( body outside quote -- code ) 
    body [
        {
            { [ dup const? ] [ name>> "deckload-%s" sprintf quote push ] }
            { [ dup var? ] [ num>> number>string 63 prefix outside push "_" quote push ] }
        }
    ] ;

: compile-body-helper ( body -- code ) 
    [ 
        {
            { [ dup const? ] [ name>> "deckload-%s" sprintf ] } ! dup name>> names [ = ] with any? swap name>> "deckload-%s" sprintf swap [ "[ " " ]" surround ] when
            { [ dup var? ] [ num>> number>string 63 prefix ] }
            [ V{ } V{ } complex-fried " deckload-call" append ]
        } cond 
    ] map ;

: compile-body ( body -- code ) 
    compile-body-helper [ dup first 100 = [ "[ " " ]" surround ] when ] map dup 
    [
        {
            { [ dup first 91 = ] [ drop "_ call" ] } ! 91 is the ascii number for "[" 
            [ drop "_" ]
        } cond
    ] map " " join "'[ %s ]" sprintf
    [ " " join ] dip "[ %s %s ]" sprintf ;

: compile-pat ( pat -- code )
    [ 
        {
            { [ dup match-const? ] [ const>> "deckload-%s" sprintf ] }
            { [ dup match-var? ] [ num>> number>string 63 prefix ] }
            [ compile-pat vec-to-str ]
        } cond 
    ] map ;

: compile-case ( rule -- code )
    [ matcher>> pat>> compile-pat " " join "{ %s }" sprintf ]
    [ matcher>> eq-vars>> compile-eqvars rule body>> compile-body ] bi
    "{ %s %s }\n" sprinf ;

: compile-normal ( rule -- code )
    dup dup first swap second first matcher>> pat>> length
    [ " 0 " swap repeat "MACRO: deckload-%s ( %s-- 0 )\n" sprintf ]
    [ "%s narray\n" sprintf ] bi
    over [ second [ compile-case ] map concat "{\n%s} match-cond ;\n\n" sprintf ] 
    3array concat ;

: compile-main-body ( body -- code )
    [
        {
            { [ dup const? ] [ name>> "deckload-%s" sprintf ] }
            [ compile-main-body vec-to-str " deckload-call" append ]
        } cond
    ] map ;

: compile-main ( rule -- code ) 
    "MACRO: deckload-main ( -- 0 )\n"
    swap second first body>> compile-main-body " " join 
    "[ %s unparse write ] ;\n\nMAIN: deckload-main\n" sprintf append ;

: compile-rule ( rule -- code ) 
    dup first "main" = [ compile-main ] [ compile-normal ] if ;

: compile-symbols ( ir -- code ) 
    [ 
        dup second empty? [ first "SYMBOL: deckload-%s\n" sprintf ] [ first "DEFER: deckload-%s\n" sprintf ] if
    ] map concat "\n" append 1array ;

: max-arg-length ( ir -- n )
    [ second empty? ] reject [ second [ matcher>> pat>> flatten [ match-var? ] count ] map supremum ] map supremum
    [0..b) >array [ number>string 63 prefix ] map " " join "MATCH-VARS: %s ;\n\n" sprintf 1array ;

: compile-to-factor ( ir -- code )
    >alist 
    [ compile-symbols ] 
    [ max-arg-length ]
    [ [ second empty? ] reject [ compile-rule ] map ]
    tri 3append boilerplate prefix concat ;