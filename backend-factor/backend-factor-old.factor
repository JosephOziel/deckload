USING: accessors arrays assocs combinators deckload.ir
deckload.parser formatting kernel match math math.parser
namespaces prettyprint ranges sequences sequences.deep
sequences.generalizations sequences.repeating ;

FROM: deckload.ir => match-var ;
IN: deckload.backend-factor

CONSTANT: names V{ }

! HELPERS:
: vec-to-str ( vec -- str ) 
    " " join "[ %s ]" sprintf ;

: boilerplate ( -- code ) 
    "USING: continuations match sequences.generalizations quotations ;\nFROM: syntax => _ ;\n\n: deckload-call ( quot -- quot' ) { } swap with-datastack >quotation ;\n\n" ;

:: compile-pat ( pat n! -- code )
    pat
    [ { 
        { [ dup match-const? ] [ const>> "deckload-%s" sprintf ] }
        { [ dup match-var = ] [ drop n dup 1 - n! number>string 63 prefix ] }
        [ n compile-pat vec-to-str ] 
    } cond ] map ;

: compile-eqvars ( eqvars -- code )
    dup empty? [ drop "" ] 
    [ 
        [ dup second [ first ] dip "%s %s =" sprintf ] map 
        dup length 1 - " and" swap repeat
        [ " " join ] dip append
    ] if ;

: compile-body-helper ( body -- code ) 
    [ 
        {
            { [ dup const? ] [ name>> "deckload-%s" sprintf ] } ! dup name>> names [ = ] with any? swap name>> "deckload-%s" sprintf swap [ "[ " " ]" surround ] when
            { [ dup var? ] [ num>> number>string 63 prefix ] }
            [ compile-body-helper vec-to-str 39 prefix " deckload-call" append ]
        } cond 
    ] map ;

: compile-body ( eq-vars body -- code )
    compile-body-helper [ dup first 100 = [ "[ " " ]" surround ] when ] map dup 
    [ 
        {
            { [ dup first 91 = ] [ drop "_ call" ] } ! 91 is the ascii number for "[" :: _ call
            ! { [ dup first 39 = ] [ drop "_ [ ] output>sequence" ] } ! "'" :: _ [ ] output>sequence
            [ drop "_" ]
        } cond 
    ] map " " join "'[ %s ]" sprintf
    [ " " join ] dip pick dup empty? [ drop " '[ _ ] when" ] unless "[ %s %s %s %s ]" sprintf ;

:: compile-case ( rule -- code ) 
    "{ "
    rule matcher>> pat>> dup flatten [ match-var = ] count 1 - compile-pat " " join "{ %s }" sprintf
    " "
    rule matcher>> eq-vars>> compile-eqvars rule body>> compile-body
    " }\n"
    5 narray concat ;

:: compile-normal ( fn -- code ) 
    fn first dup names push
    fn second first matcher>> pat>> length :> l
    l " 0 " swap repeat "MACRO: deckload-%s ( %s-- 0 )\n" sprintf
    l "%s narray\n" sprintf
    fn second [ compile-case ] map concat "{\n%s} match-cond ;\n\n" sprintf
    3array concat ;

: compile-main-body ( body -- code )
    [
        {
            { [ dup const? ] [ name>> "deckload-%s" sprintf ] }
            [ compile-main-body vec-to-str " deckload-call" append ]
        }
    cond ] map ;

: compile-main ( fn -- code )
    "MACRO: deckload-main ( -- 0 )\n"
    swap second first body>> compile-main-body " " join 
    "[ %s unparse write ] ;\n\nMAIN: deckload-main\n" sprintf append ;

: compile-symbols ( assoc -- code ) 
    dup [ nip empty? ] assoc-filter keys [ "SYMBOL: deckload-%s\n" sprintf ] map
    swap [ nip empty? not ] assoc-filter keys [ "DEFER: deckload-%s\n" sprintf ] map append
    concat "\n" append ;

: compile-rule ( rule -- code ) 
    dup first "main" = [ compile-main ] [ compile-normal ] if ;

: max-arg-length ( assoc -- len )
    [ nip empty? not ] assoc-filter [ [ matcher>> pat>> flatten [ match-var = ] count ] map supremum ] assoc-map values supremum ;

: compile-to-factor ( ir -- code )
    dup compile-symbols 1array
    swap dup max-arg-length [0..b) >array [ number>string 63 prefix ] map " " join "MATCH-VARS: %s ;\n\n" sprintf 1array
    swap [ nip empty? not ] assoc-filter [ over [ 2array compile-rule ] dip swap ] assoc-map
    values append append boilerplate prefix concat ;