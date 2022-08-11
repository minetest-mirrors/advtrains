---
title: 'speed_lessp(3advtrains)'
manual: 'Advtrains Developer''s Manual'
---

# Name
`lessp`, `greaterp`, `equalp`, `not_lessp`, `not_greaterp`, `not_equalp`, `min`, `max` - Speed limit comparison functions

# Synopsis

* `lessp(a, b)`
* `greaterp(a, b)`
* `equalp(a, b)`
* `not_lessp(a, b)`
* `not_greaterp(a, b)`
* `min(a, b)`
* `max(a, b)`

# Description
`lessp()`, `greaterp()`, `equalp()`, `not_lessp()`, `not_greaterp()`, and `not_equalp()` are predicate functions that returns, respectively,

* Whether `a` is more strict than `b`
* Whether `a` is less strict than `b`
* Whether `a` and `b` indicate the same speed limit
* Whether `a` is not more strict than `b`
* Whether `a` is nor less strict than `b`
* Whether `a` and `b` do not indicate the same speed limit

`min()` returns the speed limit that is more strict. `max()` returns the speed limit that is less strict.
