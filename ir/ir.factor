USING: accessors arrays assocs deckload.parser kernel match math
prettyprint sequences strings vectors ;
IN: deckload.ir

MATCH-VARS: ?a ?b ;
TUPLE: matcher pat eq-vars ;
TUPLE: ir.rule { matcher matcher } body ;
TUPLE: match-const { const string } ;
SYMBOL: match-var

C: <ir.rule> ir.rule
C: <matcher> matcher
C: <match-const> match-const

<PRIVATE

: compile-body ( body -- compiled-body ) ;

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

: compile-matcher ( pat -- matcher )
    0 H{ } clone { } roll (compile-matcher) swap <matcher> 2nip ;

: compile-rule ( rule -- ir )
    [ left>> compile-matcher ] [ right>> compile-body ] bi <ir.rule> ;

: compile-def ( def -- ir )
    [ compile-rule ] map ;

PRIVATE>

: compile-to-ir ( defs -- ir )
    [ compile-def ] assoc-map ;
