% Verifies that a postcondition matches a store/heap

% Top call
% verify(-ands, -stars, -store, -heap)

verify(Ands, Stars, Store, Heap):-
  verify_ands(Ands, Store, Heap),
  verify_stars(Stars, Store, Heap),
  write('success'), halt.
verify(_, _, _, _):-
  halt.

verify_ands([], _, _).
verify_ands([points_to(Var, Val)|Rest], Store, Heap):-
  points_to(Var, Val, Store, Heap),
  verify_ands(Rest, Store, Heap).
verify_ands([equals(Var, Val)|Rest], Store, Heap):-
  equals(Var, Val, Store),
  verify_ands(Rest, Store, Heap).

verify_stars([], _, []):-
  !.
verify_stars([], _, Heap):-
  write('Leaking heap chunks: '),
  write(Heap),
  fail.
verify_stars([points_to(Var, Val)|Rest], Store, Heap):-
  points_to_kill(Var, Val, Store, Heap, NewHeap),
  verify_stars(Rest, Store, NewHeap).
verify_stars([equals(Var, Val)|Rest], Store, Heap):-
  equals(Var, Val, Store),
  verify_stars(Rest, Store, Heap).

points_to(Var, Val, Store, Heap):-
  equals(Var, Address, Store),
  equals(Address, Val, Heap).

points_to_kill(Var, Val, Store, Heap, NewHeap):-
  equals(Var, Address, Store),
  remove(Address, Val, Heap, NewHeap).

equals(Var, Val, []):-
  write(Var), write('Does not equal'), write(Val),
  fail.
equals(Var, Val, [(Var, Val)|_]).
equals(Var, Val, [(Other, _)|Rest]):-
  Var \= Other,
  equals(Var, Val, Rest).

remove(_, _, [], _):-
  write('Trying to dispose of an empty heap'),
  fail.
remove(Address, Value, [(Address, Value)|Rest], Rest).
remove(Address, Value, [(Other, _)|Rest], NewHeap):-
  Address \= Other,
  remove(Address, Value, Rest, Intermediate),
  NewHeap = [(Other, Value)|Intermediate].
