---
title: 'rwt(7advtrains)'
manual: 'Advtrains Developer''s Manual'
seealso:
- rwt_add(3advtrains)
- rwt_copy(3advtrains)
- rwt_last_rpt(3advtrains)
- rwt_now(3advtrains)
---

# Name
`rwt` - Advtrains railway time

# Description
Advtrains depends on Minetest's "dtime" for most operations, and may slow itself down when necessary to prevent unexpected behavior, such as in a situation with a significant amount of lag. As a result, the internal time used by Advtrains is not synchronized to real-life time due to lag and server restarts. Railway time was therefore introduced as a method of accurately measuring internal time and, with this information, implementing a scheduling system. It can, however, also be set up to keep in sync with real-life time.

Railway time is counted in cycles, minutes, and seconds, roughly corresponding to their real-life counterparts, with cycles roughly corresponding to hours. For a valid railway time object, it is expected that

* The "cycles" element is an integer,
* The "minutes" element is an integer between 0 and 59 (inclusive), and
* The "seconds" element is an integer between 0 and 59 (inclusive).

Railway time may be represented in three formats:

* As a table with the `c`, `m`, `s` fields holding the cycles, minutes, and seconds, respectively,
* As a string with the cycles, minutes and seconds delimited with a semicolon,
* For zero cycles, as a string with the minutes and seconds delimited with a semicolon, or
* As a number representing the number of seconds since 0;0;0.

If railway time is represented as a string, each element may have a variable length and do not require padding zeroes, and an element of the string may be empty if it is at the beginning or the end of the string.

The railway time API is available in the `advtrains.interlocking.rwt` table or, for LuaATC, in the `rwt` table.
