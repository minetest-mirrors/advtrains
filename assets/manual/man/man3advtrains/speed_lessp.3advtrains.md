---
titles:
- speed_lessp
- speed_greaterp
- speed_equalp
- speed_not_lessp
- speed_not_greaterp
- speed_not_equalp
- speed_min
- speed_max
section: 3advtrains
manual: 'Advtrains Developer''s Manual'
shortdesc: compare speed limits
---

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
