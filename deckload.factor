USING: combinators command-line.parser deckload.backend-c
deckload.ir deckload.parser io io.encodings.utf8 io.files kernel
match namespaces quotations strings ;

IN: deckload

SYMBOLS: compile-func input-path output-path ;

: to-backend ( string -- backend )
    {
        { "c" [ [ compile-to-c ] ] }
    } case ;

: main ( -- )
    {
        T{ option
            { name "backend" }
            { help "set the backend (possible values are \"c\" and \"factor\")" }
            { type quotation }
            { convert [ to-backend ] }
            { variable compile-func }
        }
        T{ option
            { name "input-path" }
            { help "set the path to the file to compile" }
            { type string }
            { variable input-path }
        }
        T{ option
            { name "output-path" }
            { help "set the path to the compiled code's destination" }
            { type string }
            { variable output-path }
        }
    } [
         input-path get utf8 file-contents
         deckload-parse compile-to-ir compile-func get call( ir -- compiled-code )
         output-path get utf8 [ write ] with-file-writer
    ] with-options ;

MAIN: main
