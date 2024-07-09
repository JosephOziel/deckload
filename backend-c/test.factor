USING: deckload.backend-c deckload.ir deckload.parser io kernel
multiline ;
[[

$0 z + = $0.
$1 [$0 s] + = [$1 s] $0 +.
$0 z * = z.
$1 [$0 s] * = [$1 $0 *] $1 +.

z fac = z s.
[$0 s] fac = [$0 fac] [$0 s] *.

main = [[[[[[[[[[z s] s] s] s] s] s] s] s] s] s] fac.

]] deckload-parse compile-to-ir 
"main" swap compile-to-c write
