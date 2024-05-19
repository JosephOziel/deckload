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

tokenize([0'`|T_i], [Out|T_o]) :-
    consume_until(T_i, 0'`, Remain, Codes),
    string_codes(Value, Codes),
    Out = word(Value),
    tokenize(Remain, T_o).

tokenize([0'{|T_i], ['{'|T_o]) :- tokenize(T_i, T_o).
tokenize([0'}|T_i], ['}'|T_o]) :- tokenize(T_i, T_o).

tokenize([A|T_i], [Out|T_o]) :-
    string_codes(Name, [A]),
    Out = word(Name),
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
parse(Code, AST) :-
    tokenize(Code, Out),
    program(AST, Out, []).

pparse(Code) :-
    parse(Code, AST),
    print_term(AST, []).


