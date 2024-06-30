USING: accessors arrays assocs deckload.parser kernel match math
prettyprint sequences strings vectors ;
IN: deckload.ir

FROM: syntax => _ ;

MATCH-VARS: ?a ?b ;
TUPLE: matcher pat eq-vars ;
TUPLE: ir.rule { matcher matcher } body ;
TUPLE: match-const { const string } ;
SYMBOL: match-var

C: <ir.rule> ir.rule
C: <matcher> matcher
C: <match-const> match-const

<PRIVATE

: compile-body ( num-vars bindings body -- compiled-body ) 
    dup vector? [ [ compile-body ] 2with map ] [
        {
            { T{ var f ?a } [ ?a swap at - 1 - <var> ] }
            [ 2nip ]
        } match-cond
    ] if ;

: (compile-match-terminal) ( num-vars bindings eq-vars pat -- num-vars' bindings' eq-vars' compiled-matcher )
    {
        { T{ var f ?a }
            [ ?a pick at* 
                [ reach 2array suffix [ 1 + ] 2dip ]
                [ drop [ [ 1 + ] keep ] [ [ ?a swap set-at ] keep ] [ ] tri* ] if match-var 
            ] }
        { T{ const f ?a } [ ?a <match-const> ] }
    } match-cond ;

: (compile-matcher) ( num-vars bindings eq-vars pat -- num-vars' bindings' eq-vars' compiled-matcher )
    dup vector? [ [ (compile-matcher) ] map ] [ (compile-match-terminal) ] if ;

: compile-matcher ( pat -- matcher num-vars bindings )
    0 H{ } clone { } roll (compile-matcher) swap reach '[ [ _ swap - 1 - ] map ] map <matcher> -rot ;

: compile-rule ( rule -- ir )
    [ left>> compile-matcher ] keep right>> compile-body <ir.rule> ;

: compile-def ( def -- ir )
    [ compile-rule ] map ;

: group-by-name ( rules -- defs )
    H{ } clone swap [
        2dup name>> swap at* 
        [ swap suffix! drop ] [ drop [ 1vector ] keep name>> rot [ set-at ] keep ] if 
    ] each ;

PRIVATE>

: compile-to-ir ( rules -- ir )
    group-by-name [ compile-def ] assoc-map ;
