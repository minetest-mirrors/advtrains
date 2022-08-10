---
title: 'NODE_DEFINITION(7ADVTRAINS) | Advtrains Developer''s Manual'
seealso:
- signal_aspects(7advtrains)
---

# NAME
`node_definition` - Advtrains-specific node definition entries

# DESCRIPTION
This page describes various fields in node definition tables that are used by Advtrains.

# NODE GROUPS
Advtrains uses node groups to identify certain properties of a node. The following node groups are currently read by Advtrains:

* `advtrains_signal`: When set, this property defines the type of signal this node belongs to. `1` indicates that this node is a static signal, and `2` indicates that this node is a signal with a variable aspect.
* `not_blocking_trains`: When set to 1, trains can move through this node.
* `save_in_at_nodedb`: When set to 1, this node should be saved in the internal node database used by Advtrains.

# THE `advtrains` FIELD
The `advtrains` field in the node definition may contain the following fields:

* `get_aspect(pos, node)`: This function should return the signal aspect of the node at the given position.

* `set_aspect(pos, node, asp)`: This function should set the signal aspect of the node to `asp` if possible. `asp` is not guranteed to be an aspect supported by the node.

* `supported_aspects`: This table should contain a list of supported signal aspects.
