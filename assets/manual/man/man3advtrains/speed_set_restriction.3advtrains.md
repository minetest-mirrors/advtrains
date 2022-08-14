---
titles:
- speed_set_restriction
- speed_merge_aspect
section: 3advtrains
manual: 'Advtrains Developer''s Manual'
shortdesc: apply speed limits to trains
---

# Synopsis

* `set_restriction(train, type, val)`
* `merge_aspect(train, asp)`

# Description
`set_restriction()` sets the speed restriction of the given type of the given train to `val` and updates train object correspondingly.

`merge_aspect()` sets the speed restriction of the given train based on the value of the signal aspect.

# Return Value
`set_restriction()` and `merge_aspect()` do not return any value.
