:- module(deckload, []).

% Lexer:
plex(Code) :-
    string_codes(Code, Code1),
    tokenize(Code1, Out),
    print_term(Out, []).

tokenize([], []).

tokenize([In|T], Out) :-
    code_type(In, newline),
    tokenize(T, Out).

tokenize([In|T], Out) :-
    code_type(In, space),
    tokenize(T, Out).

% add a variables that captures multiple terms: ~N
tokenize([0'~|T_i], [Out|T_o]) :-
    consume_type(T_i, digit, Remain, DigitList),
    number_codes(Value, DigitList),
    Out = avar(Value),
    tokenize(Remain, T_o).

tokenize([In|T_i], [Out|T_o]) :-
    code_type(In, digit),
    consume_type([In|T_i], digit, Remain, DigitList),
    number_codes(Value, DigitList),
    Out = var(Value),
    tokenize(Remain, T_o).

tokenize([0'(|T_i], [Out|T_o]) :-
    consume_until(T_i, 0'), Remain, Codes),
    string_codes(Value, Codes),
    Out = str(Value),
    tokenize(Remain, T_o).

tokenize([0''|T_i], [Out|T_o]) :-
    code_type(C, space),
    consume_until(T_i, C, Remain, Codes),
    string_codes(Value, Codes),
    Out = sym(Value),
    tokenize(Remain, T_o).

tokenize([0'[|T_i], ['['|T_o]) :- tokenize(T_i, T_o).
tokenize([0']|T_i], [']'|T_o]) :- tokenize(T_i, T_o).

tokenize([A|T_i], [Out|T_o]) :-
    string_codes(Name, [A]),
    Out = sym(Name),
    tokenize(T_i, T_o).

% utils
consume_type([], _, [], []).
consume_type([Char|In], Type, Remain, [Char|Out]) :-
    code_type(Char, Type),
    consume_type(In, Type, Remain, Out).
consume_type([Char|In], Type, [Char|In], []) :-
    \+ code_type(Char, Type).

consume_until([], _, [], []).
consume_until([TargetChar|In], TargetChar, In, []).
consume_until([Char|In], TargetChar, Remain, [Char|Out]) :-
    consume_until(In, TargetChar, Remain, Out).

% Parser:
parse(Text, AST) :-
    string_codes(Text, Code),
    tokenize(Code, Out),
    program(AST, Out, []).

pparse(Code) :-
    string_codes(Code, Code1),
    parse(Code1, AST),
    print_term(AST, []).

program([Expr|Rest]) --> expr(Expr), (program(Rest) | {Rest = []}).

expr(Expr) --> str(Expr) ; rw(Expr) ; sym(Expr) .

str(str(Str)) --> [str(Str)].

sym(sym(Sym)) --> [sym(Sym)].

rw(rw(Pat, Rep)) --> ['['], pat(Pat), [']', '['], pat(Rep), [']'].

pat([Pat|Rest]) --> pat2(Pat), (pat(Rest) | {Rest = []}).

pat2(pstr([Pat|Rest])) --> ['['], pat2(Pat), (pat(Rest) | {Rest = []}), [']'].
pat2(sym(Sym)) --> [sym(Sym)].
pat2(lstr(Str)) --> [str(Str)].
pat2(var(Var)) --> [var(Var)].
pat2(avar(Var)) --> [avar(Var)].

% Rewriter:
a_rewrite([rw(Pat, Rep)|Rest], Stack, Rws, NRws) :- %Rws is a assoc_list
    append(Rws, [Pat-Rep], Rws1),
    a_rewrite(Rest, Stack, Rws1, NRws).
a_rewrite([T|Rest], Stack, Rws, NRws) :-
    member(T, [str(_), sym(_)]),
    append(Stack, [T], NStack),
    apply_rws(Rws, NStack, NStack1),
    a_rewrite(Rest, NStack1, Rws, NRws).

% Evauluator:
% Create a builtins file somewhere for the io builtins and such. also
% compile to assembly in the future.

% only evals strings and builtin functions, this is after the rewrites.
eval(str(Str), Stack, NStack) :-
    append(Stack, [Str], NStack).
eval(sym("S"), [Str|Stack], Stack) :-
    print_term(Str, []).
