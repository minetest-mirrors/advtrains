% SPEED_LESSP(3ADVTRAINS) | Advtrains Developer's Manual

# NAME
`lessp`, `greaterp`, `equalp`, `not_lessp`, `not_greaterp`, `not_equalp`, `min`, `max` - Speed limit comparison functions

# SYNOPSIS

* `lessp(a, b)`
* `greaterp(a, b)`
* `equalp(a, b)`
* `not_lessp(a, b)`
* `not_greaterp(a, b)`
* `min(a, b)`
* `max(a, b)`

# DESCRIPTION
`lessp()`, `greaterp()`, `equalp()`, `not_lessp()`, `not_greaterp()`, and `not_equalp()` are predicate functions that returns, respectively,

* Whether `a` is more strict than `b`
* Whether `a` is less strict than `b`
* Whether `a` and `b` indicate the same speed limit
* Whether `a` is not more strict than `b`
* Whether `a` is nor less strict than `b`
* Whether `a` and `b` do not indicate the same speed limit

`min()` returns the speed limit that is more strict. `max()` returns the speed limit that is less strict.
