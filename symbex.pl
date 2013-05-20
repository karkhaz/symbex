#!/usr/bin/gprolog --consult-file
% State: Program,TopAddress, Heap, Store
%           |        |        |      |
%           |        |        |      --- List of (Identifer, Value)
%           |        |        --- List of (Address, Value)
%           |        --- Number indicating top heap address, initially 0
%           --- List of commands
%
% Abstract Syntax
% ===============
% COM_LIST is a (prolog) list of COMMAND
% EXP      := <number>
%          || IDENT
%          || plus(EXP, EXP)
%          || mult(EXP, EXP)
%          || minus(EXP, EX)
% BOOL     := eq(EXP, EXP)
%          || ne(EXP, EXP)
%          || lt(EXP, EXP)
%          || gt(EXP, EXP)
%          || le(EXP, EXP)
%          || ge(EXP, EXP)
%          || and(BOOL, BOOL)
%          || or(BOOL, BOOL)
% IDENT    := <atom>
% COMMAND  := assign(IDENT, EXP)
%          || new(IDENT, EXP)
%          || lookup(IDENT, IDENT)     Note, we can only look up variables
%          || mutate(IDENT, EXP)
%          || deallocate(IDENT)
%          || ifthenelse(BOOL, COM_LIST, COM_LIST)
%

% Top call from ruby program. Execute a program to determine its final
% state.
% execute(-(State), +(State)).
execute_top(InitState, FinalState):-
  execute(InitState, FinalState).
% Exit if that didn't work.
execute_top(_, _):-
  halt.

execute(([], Address, FinalHeap, FinalStore),
        ([], Address, FinalHeap, FinalStore)).
execute(([Command|Rest], Address, Heap, Store), FinalState):-
  transform(Command, Address, Heap, Store, NAddress, NHeap, NStore),
  execute((Rest, NAddress, NHeap, NStore), FinalState).

% Go from one state to the next by executing a single command.
% One rule for each of the commands in the language.
% transform(-Commnd, -Address, -Heap, -Store, +NAddress, +NHeap, +NStore)
transform(assign(Var, Exp), Adrss, Heap, Store, Adrss, Heap, NStore):-
  atom(Var),
  show('M@assign'), show(Var), show(Exp), show(Store), show(Heap),
  a_eval(Exp, Store, Val),
  add_to_store(Var, Val, Store, NStore),
  show(NStore), show(Heap).
transform(new(Var, Exp), Adrss, Heap, Store, NAdrss, NHeap, NStore):-
  atom(Var),
  show('M@new'), show(Var), show(Exp), show(Store), show(Heap),
  a_eval(Exp, Store, Val),
  NAdrss is Adrss - 1,
  add_to_store(Var, Adrss, Store, NStore),
  add_to_heap(Adrss, Val, Heap, NHeap),
  show(NStore), show(NHeap).
transform(lookup(Var1, Var2), Adrss, Heap, Store, Adrss, Heap, NStore):-
  show('M@lookup'), show(Var1), show(Var2), show(Store), show(Heap),
  heap_value(Var2, Heap, Store, Value),
  add_to_store(Var1, Value, Store, NStore),
  show(NStore),
  show(Heap).
transform(mutate(Var, Exp), Adrss, Heap, Store, Adrss, NHeap, Store):-
  show('M@mutate'), show(Var), show(Exp), show(Store), show(Heap),
  a_eval(Exp, Store, Val),
  a_eval(Var, Store, HAddress),
  mutate_heap(HAddress, Val, Heap, NHeap),
  show(Store), show(NHeap).
transform(deallocate(Var), Adrss, Heap, Store, Adrss, NHeap, Store):-
  show('M@dispose'), show(Var), show(Store), show(Heap),
  a_eval(Var, Store, Val),
  deallocate(Val, Heap, NHeap),
  show(Store), show(NHeap).
transform(ifthenelse(Bool, TrueProg, _),
          Adrss, Heap, Store, NAdrss, NHeap, NStore):-
  show('M@conditional'), show(Bool), show(Store), show(Heap),
  b_eval(Bool, Store, Result),
  mytrue(Result), show(TrueProg),
  execute((TrueProg, Adrss, Heap, Store), (_, NAdrss, NHeap, NStore)).
transform(ifthenelse(Bool, _, FalseProg),
          Adrss, Heap, Store, NAdrss, NHeap, NStore):-
  b_eval(Bool, Store, Result),
  myfalse(Result), show(FalseProg),
  execute((FalseProg, Adrss, Heap, Store), (_, NAdrss, NHeap, NStore)).

% Evaluation of a variable
% store_value(-Var, -Store, +Value)
store_value(Var, [], _):-
  atom_concat(Var, ' has not been initialized', Message),
  error(Message).
store_value(Var, [(Var, Value)|_], Value).
store_value(Var, [(Other, _)|Rest], Value):-
  Var \= Other,
  store_value(Var, Rest, Value).

% Assignment. Adds a new variable to the store if it doesn't already
% exist, and sets the value of the variable. Always succeeds.
% add_to_store(-Var, -Value, -OldStore, +NewStore)
add_to_store(Var, Value, [], [(Var, Value)]).
add_to_store(Var, Value, [(Var, _)    |Rest],
                              [(Var, Value)|Rest]).
add_to_store(Var, Value, [(Other, Old)|Rest], NewStore):-
  Var \= Other,
  add_to_store(Var, Value, Rest, Intermediate),
  NewStore = [(Other, Old)|Intermediate].

% Allocates a new heap cell at the given address. Always succeeds, even
% if there is already a heap cell at address Addrs: beware!
add_to_heap(Addrs, Val, Heap, [(Addrs, Val)|Heap]).

% Gets the value of a heap cell that is pointed to by the variable. Fails
% if the variable does not point to a heap cell, or does not exist.
% heap_value(-Var, -Heap, -Store, +Val)
heap_value(Var, Heap, Store, Val):-
  store_value(Var, Store, Address),
  heap_value_lookup(Var, Address, Heap, Val).
heap_value_lookup(_, Address, [(Address, Val)|_], Val).
heap_value_lookup(Var, Address, [(Other, _)|Rest], Val):-
  Address \= Other,
  heap_value_lookup(Var, Address, Rest, Val).
heap_value_lookup(Var, _, [], _):-
  atom_concat(Var, ' does not point to a heaplet', Message),
  error(Message).

% Changes the value of a heap cell at a given address. Fails if no heap
% cell exists at that address.
% mutate_heap(-Address, -Val, -Heap, +NewHeap)
mutate_heap(_, _, [], _):-
  error('Tried to mutate a non-existent heaplet').
mutate_heap(Address, Val, [(Address, _)|Rest], [(Address, Val)|Rest]).
mutate_heap(Address, Val, [(Other, OVal)|Rest], NewHeap):-
  Address \= Other,
  mutate_heap(Address, Val, Rest, IHeap),
  NewHeap = [(Other, OVal)|IHeap].

% Removes a heaplet from the heap. Fails if the heaplet does not exist at
% that address.
% deallocate(-Address, -Heap, +NewHeap)
deallocate(_, [], _):-
  error('Tried to deallocate a nonexistant heaplet').
deallocate(Address, [(Address, _)|Rest], Rest):- !.
deallocate(Address, [(Other, Val)|Rest], NewHeap):-
  deallocate(Address, Rest, IHeap),
  NewHeap = [(Other, Val)|IHeap].

% Evaluation of arithmetic expressions.
% a_eval(-Expression, -Store, +Result)
a_eval(X, _, X):-
  number(X), !.
a_eval(Var, Store, Value):-
  atom(Var), !,
  store_value(Var, Store, Value).
a_eval(plus(X, Y), Store, Result):-
  a_eval(X, Store, XRes),
  a_eval(Y, Store, YRes),
  Result is XRes + YRes.
a_eval(mult(X, Y), Store, Result):-
  a_eval(X, Store, XRes),
  a_eval(Y, Store, YRes),
  Result is XRes * YRes.
a_eval(minus(X, Y), Store, Result):-
  a_eval(X, Store, XRes),
  a_eval(Y, Store, YRes),
  Result is XRes - YRes.

% Evaluation of boolean expressions
% Result can checked by calling mytrue/1 or myfalse/1 on it
% b_eval(-Expression, -Store, +Result)
b_eval(and(X, Y), Store, Result):-
  b_eval(X, Store, XRes),
  b_eval(Y, Store, YRes),
  mytrue(XRes),
  mytrue(YRes), !,
  mytrue(Result).
b_eval(and(_, _), _, Result):-
  myfalse(Result).

b_eval(or(X, _), Store, Result):-
  b_eval(X, Store, XRes),
  mytrue(XRes), !,
  mytrue(Result).
b_eval(or(_, Y), Store, Result):-
  b_eval(Y, Store, YRes),
  mytrue(YRes), !,
  mytrue(Result).
b_eval(or(_, _), _, Result):-
  myfalse(Result).

b_eval(eq(X, Y), Store, Result):-
  a_eval(X, Store, XRes),
  a_eval(Y, Store, YRes),
  XRes == YRes, !,
  mytrue(Result).
b_eval(eq(_, _), _, Result):-
  myfalse(Result).

b_eval(ne(X, Y), Store, Result):-
  b_eval(eq(X, Y), Store, EqRes),
  mytrue(EqRes), !, myfalse(Result).
b_eval(ne(X, Y), Store, Result):-
  b_eval(eq(X, Y), Store, EqRes),
  myfalse(EqRes), !, mytrue(Result).

b_eval(lt(X, Y), Store, Result):-
  a_eval(X, Store, XRes),
  a_eval(Y, Store, YRes),
  XRes < YRes, !,
  mytrue(Result).
b_eval(lt(_, _), _, Result):-
  myfalse(Result).

b_eval(ge(X, Y), Store, Result):-
  b_eval(lt(X, Y), Store, LtRes),
  mytrue(LtRes), !, myfalse(Result).
b_eval(ge(X, Y), Store, Result):-
  b_eval(lt(X, Y), Store, LtRes),
  myfalse(LtRes), !, mytrue(Result).

b_eval(gt(X, Y), Store, Result):-
  a_eval(X, Store, XRes),
  a_eval(Y, Store, YRes),
  XRes > YRes, !,
  mytrue(Result).
b_eval(gt(_, _), _, Result):-
  myfalse(Result).

b_eval(le(X, Y), Store, Result):-
  b_eval(gt(X, Y), Store, GtRes),
  mytrue(GtRes), !, myfalse(Result).
b_eval(le(X, Y), Store, Result):-
  b_eval(gt(X, Y), Store, GtRes),
  myfalse(GtRes), !, mytrue(Result).


% Error
error(Message):-
  write('#Error - '),
  write(Message), nl,
  fail.

% True and false. Don't use literal values anywhere else.
mytrue('true').
myfalse('false').

% Printing
show(Message):-
  write(Message), nl.
