USING: accessors arrays ascii assocs assocs.extras deckload.ir
deckload.parser formatting io.encodings.utf8 io.files kernel
literals match math math.order multiline namespaces sequences
splitting strings vectors ;
FROM: syntax => _ ;
FROM: deckload.ir => match-var ;
IN: deckload.backend-c

<PRIVATE

CONSTANT: c-boilerplate $[ "vocab:deckload/backend-c/boilerplate.c" utf8 file-contents ]
CONSTANT: c-stack "s"
CONSTANT: c-num-args "n"
CONSTANT: c-args-start "p"
CONSTANT: c-funcname-prefix "deckload_"
CONSTANT: c-varname-prefix "var_"

MATCH-VARS: ?a ;

: c-var ( n -- c-expr )
    c-varname-prefix swap "%s%d" sprintf ; inline

: assign-var ( v func -- c-expr )
    [ c-var ] dip "(%s = shallow_clone(%s)).ty" sprintf ; inline

: c-encode-func-name ( name -- c-safe-name )
    [ dup alpha?
        [ 1string ] [ dup "_" = [ drop "__" ] [ "_b_%d" sprintf ] if ] if
    ] V{ } map-as "" join c-funcname-prefix prepend ;

: c-match-const ( func const -- c-expr )
    dupd c-encode-func-name "%s.ty == FUNC \n&& %s.data.func == %s" sprintf ; inline

: get-func-at ( idx func -- func' )
    swap "vec_last(%s.data.block, %d)" sprintf ; inline

: assert-vec-matches ( func len -- s )
    dupd "%s.ty == BLOCK \n&& vec_len(%s.data.block) == %d" sprintf ; inline

: assert-enough-args ( min-args -- string )
    c-num-args "%d <= %s" sprintf ; inline

: stack-last ( n -- c-expr )
    c-stack swap "vec_last(*%s, %d)" sprintf ; inline

: assert-eq-vars ( a b -- c-cond )
    [ c-var ] bi@ "eq(%s,%s)" sprintf ; inline

: and ( a b -- c-expr ) "%s && %s" sprintf ; inline

: add-semicolons ( seq -- c-code )
    "" [ ";\n" append append ] reduce ; inline

DEFER: (compile-pat)

: compile-pat-block ( num-vars func pat -- num-vars c-cond )
    [ length assert-vec-matches swap ] 2keep <reversed> swap
    '[ _ get-func-at swap (compile-pat) ] map-index
    rot prefix " \n&& " join ;

: compile-pat-terminal ( num-vars func pat -- num-vars c-cond )
    {
        { match-var [ [ [ 1 + ] keep ] dip assign-var ] }
        { T{ match-const f ?a } [ ?a c-match-const ] }
    } match-cond ;

: (compile-pat) ( num-vars func pat -- num-vars c-cond )
    dup vector? [ compile-pat-block ] [ compile-pat-terminal ] if ;

: compile-pat ( pat -- num-vars c-cond )
    [ length assert-enough-args 0 ] keep
    <reversed> [ stack-last swap (compile-pat) ] map-index
    rot prefix " \n&& " join ;

: compile-eq-vars ( eq-vars -- c-cond )
    [ first2 assert-eq-vars ] map " \n&& " join ;

: compile-matcher ( m -- num-vars c-cond )
    [ pat>> compile-pat ]
    [ eq-vars>> compile-eq-vars dup empty? [ " \n&& " prepend ] unless ] bi
    append ;

: compile-body-call ( arg-start term -- c-stmt )
    {
        { T{ var f ?a } [ ?a c-var c-stack rot "d_call(shallow_clone(%s), %s, %s, 1);" sprintf ] }
        { T{ const f ?a } [ ?a c-encode-func-name c-stack rot "d_call(func_new(%s), %s, %s, 0);" sprintf ] }
    } match-cond ;

: c-from-last-idx ( n -- c-expr )
    c-stack swap "vec_len(*%s)-(%s)" sprintf ;

: compile-case-body ( num-args body -- c-code )
    dup vector?
    [ swap [ unclip-last over length ] dip "%s+%s" sprintf ] [ V{ } clone spin ] if
    [ [ "0" swap compile-case-body ] map "\n" join ] 2dip
    c-from-last-idx swap compile-body-call "%s\n%s" sprintf ;

: compile-tail-call ( func -- c-stmt v/f )
    {
        { T{ var f ?a } [ ?a [ c-var ] keep ] }
        { T{ const f ?a } [ ?a c-encode-func-name "func_new(%s)" sprintf f ] }
    } match-cond ;

: compile-case-body-root ( body -- c-body c-end v/f )
    "0" swap dup vector? [ unclip-last ] [ V{ } clone swap ] if
    [
        dup empty? 
        [ 2drop "" ] [ [ compile-case-body ] with map "\n" join ] if
    ] [ compile-tail-call ] bi* ;

: compile-case-begin ( num-args -- c-stmt )
    c-stack swap "vec_dec_len(%s, %d);\n" sprintf ;

: compile-case-end ( forbidden num-vars -- c-code )
    <iota> swap [ [ = not ] curry filter ] when*
    [ c-var "func_drop(%s)" sprintf ] map add-semicolons ;

: compile-rule ( rule -- num-vars c-code )
    [ matcher>> compile-matcher ]
    [ matcher>> pat>> length compile-case-begin ]
    [ body>> compile-case-body-root ] tri
    [ reach ] 2dip rot compile-case-end swap
    "if(%s) {\n%s\n%s\n%s\nreturn %s;\n}" sprintf ;

: compile-rules ( rules -- num-vars c-code )
    0 swap [ compile-rule [ max ] dip ] map "\n" join ;

: compile-func-sig ( name -- c-code )
    c-stack c-args-start "Func %s(Vec* %s, size_t %s)" sprintf ;

: compile-func-begin ( num-vars name -- c-code )
    compile-func-sig swap [ c-num-args c-stack c-args-start ] dip
    <iota> [ c-var ] map ", " join dup empty? [ "Func %s;" sprintf ] unless
    "%s {\nsize_t %s=vec_len(*%s)-%s;\n%s\n" sprintf ;

: compile-func-end ( name -- c-code )
    c-stack swap c-stack c-num-args "vec_push(%s, func_new(%s));\nvec_into_block(%s, %s+1);\nreturn none();\n}\n\n" sprintf ;

: compile-function ( name rules -- c-func )
    compile-rules
    [ swap c-encode-func-name [ compile-func-begin ] [ compile-func-end ] bi ] dip
    swap [ "%s\n%s" sprintf ] bi@ ;

: compile-functions ( functions -- c-funcs )
    "" [ compile-function append ] assoc-reduce ;

: compile-print-name ( name -- c-stmt )
    dup [ c-encode-func-name ] dip "if(f.data.func==%s) printf(\"%s\")" sprintf ;

: compile-print ( names -- c-func )
    [ compile-print-name ] map add-semicolons
    [[
void print(Func arg) {
    FrozenBlock* s = new_buf(INIT_CAP*sizeof(FrozenBlock));
    size_t len=0, cap=INIT_CAP;
    Vec block;
    if(arg.ty==BLOCK) {
        block = arg.data.block;
    } else {
        block = vec_new();
        vec_push(&block, arg);
    }
    s[len++]=fb_new(block);
    FrozenBlock* t;
    Func f;
    printf("[ ");

    while(len--) {
        t=s+len;
        f=fb_advance(t);
        if(f.ty==NONE) {
            fb_drop(*t);
            printf("] ");
            continue;
        }
        len++;
        if(f.ty==BLOCK) {
            printf("[ ");
            s=ensure(s, len+1, &cap, sizeof(FrozenBlock));
            s[len++] = fb_new(f.data.block);
        } else {
            assert(f.ty==FUNC);
            %s
            printf(" ");
        }
    }
    free_buf(s);
}
    ]] sprintf ;

: compile-main ( entry-point -- c-main )
    c-encode-func-name
    [[
char buf[BUFSIZ];

int main(int argc, char* argv) {
    setbuf(stdout, buf);
    Vec v=vec_new();
    d_call(func_new(%s), &v, 0, 0);
    while(vec_len(v)) {
        print(vec_pop(&v));
        printf("\n");
    }
    fflush(stdout);
    vec_drop(v);
    if(num_allocs) {
        printf("%%d allocations not freed, please report this to the devs\n", num_allocs);
        return -1;
    }
    return 0;
}
    ]] sprintf ;

: compile-nonboilerplate ( entry-point ir -- c-code )
    [ compile-main ] dip
    [ keys [ c-encode-func-name compile-func-sig ] map add-semicolons ]
    [ compile-functions ]
    [ keys compile-print ] tri
    roll 4array "\n" join ;

: repeat-string ( n b -- b^n )
    "" -rot '[ _ append ] times ; inline

: add-indent ( n string -- indented )
    swap " " repeat-string prepend ; inline

: format ( code -- beauty )
    split-lines 0 swap
    [
        [ blank? ] trim dup
        [ ?last CHAR: { = ]
        [ ?first CHAR: } = ] bi or
        [
            [
                tuck
                [ [ CHAR: { = ] count ]
                [ [ CHAR: } = ] count ] bi - 4 * [ + ] keepd
                rot ?first CHAR: } = [ 4 - ] when
            ] keep
        ] [ dupd ] if dup empty? [ nip ] [ add-indent ] if
    ] map "\n" join nip ;

PRIVATE>

: compile-to-c ( entry-point ir -- c-code )
    compile-nonboilerplate format c-boilerplate prepend ;
