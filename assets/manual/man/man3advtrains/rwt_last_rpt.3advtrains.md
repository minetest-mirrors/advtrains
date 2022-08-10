% RWT_LAST_RPT(3ADVTRAINS) | Advtrains Developer's Manual

# NAME
`last_rpt`, `next_rpt`, `time_from_last_rpt`, `time_to_next_rpt` - Calculate time for repeating events

# SYNOPSIS

* `last_rpt(time, interval, offset)`
* `next_rpt(time, interval, offset)`
* `time_from_last_rpt(interval, offset)`
* `time_to_next_rpt(interval, offset)`

# DESCRIPTOIN
The functions described in this page calculates the time or time difference related to events scheduled to repeat with the given interval and at the given offset, in relation to the given time. Whether and when the event actually takes place is not relevant to the API.

* `last_rpt()` returns the time at which the event was expected to occur the last time
* `next_rpt()` returns the time at which the event is expected to occur the next time
* `time_from_last_rpt()` returns the time since the event was expected to occur the last time
* `time_to_next_rpt()` return the time until the event is expected to occur the next time
