% SPEED(7ADVTRAINS) | Advtrains Developer's Manual

# NAME
`speed` - Advtrains speed limit library

# DESCRIPTION
The speed library allows the manipulation of speed limits, which can be represented with

* A non-negative number, which stands for a regular speed limit in m/s, or
* -1 or `nil`, which lifts the speed restriction

The use of other values (in particular, nan and infinity) may result in undefined behavior.

This library is available as `advtrains.speed`.

# NOTES

The meaning of `nil` for the speed limit library differs from its meaning in signal aspect tables, where `nil` keeps the current speed limit.
