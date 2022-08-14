---
titles:
- rwt_add
- rwt_diff
- rwt_sub
section: 3advtrains
manual: 'Advtrains Developer''s Manual'
shortdesc: add or subtract railway time objects
---

# Synopsis

* `add(t1, t2)`
* `diff(t1, t2)`
* `sub(t1, t2)`

# Description

* `add()` returns the result of adding `t1` and `t2`.
* `diff()` returns the result of subtracting `t1` from `t2`.
* `sub()` returns the result of subtracting `t2` from `t1`.

# Return Value

`add()` and `sub()` return their results as tables. `diff()` returns its result as a number.
