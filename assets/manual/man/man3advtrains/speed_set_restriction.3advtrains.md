% SPEED_SET_RESTRICTION(3ADVTRAINS) | Advtrains Developer's Manual

# NAME
`set_restriction`, `merge_aspect` - Apply speed limits to trains

# SYNOPSIS

* `set_restriction(train, type, val)`
* `merge_aspect(train, asp)`

# DESCRIPTION
`set_restriction()` sets the speed restriction of the given type of the given train to `val` and updates train object correspondingly.

`merge_aspect()` sets the speed restriction of the given train based on the value of the signal aspect.

# RETURN VALUE
`set_restriction()` and `merge_aspect()` do not return any value.
