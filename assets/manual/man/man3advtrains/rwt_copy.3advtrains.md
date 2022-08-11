---
title: 'rwt_copy(3advtrains)'
manual: 'Advtrains Developer''s Manual'
---

# Name
`copy`, `new`, `to_table`, `to_secs`, `to_string` - Create and copy railway time objects

# Synopsis

* `copy(obj)`
* `new(cycles, minutes, seconds)`
* `to_table(obj)`
* `to_secs(obj [, cycles])`
* `to_string(obj [, no_cycles])`

# Description

* `copy()` returns a copy of `obj`.
* `new()` creates a new railway time object with the given number of cycles, minutes, and seconds.
* `to_table()`, `to_secs()`, and `to_string()` convert `obj` to a table, number, or string, respectively. If `cycles` is passed to `to_secs()`, that value is used as the number of cycles. If `no_cycles` is passed to `to_string()`, the number of cycles is set to zero.

# Return Value

* `copy()` returns the copy that is created. If `obj` is a table, the returned value is not identical to `obj`.
* `new()` returns the newly created object as a table.
* `to_table()`, `to_secs()`, `to_string()` returns the conveerted object.

# Notes

`to_table()` returns `obj` if it is a table.
