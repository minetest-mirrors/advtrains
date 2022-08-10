---
title: 'SIGNAL_ASPECTS(7ADVTRAINS) | Advtrains Developer''s Manual'
seealso:
- speed(7advtrains)
---

# NAME
`signal_aspects` - Signal aspect tables for Advtrains

# DESCRIPTION
A signal aspect table describes the status of a signal in relation to a train following it.

A signal aspect table may contain the following fields:

* `main`: The main aspect of the signal
* `type`: The type of speed restriction imposed by the main aspect
* `dst`: The distant aspect of the signal
* `shunt`: A boolean indicating whether shunting is allowed
* `proceed_as_main`: A boolean indicating whether a train in shunt mode should continue with shunt mode disabled

The `main` and `dst` fields may contain

* A non-negative number indicating the current or next speed limit
* -1, indicating that the speed limit is or will be lifted
* `nil`, indicating that the speed limit is or will not be changed
