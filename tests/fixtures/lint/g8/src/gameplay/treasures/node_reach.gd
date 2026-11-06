## Planted G8 violations. Lines 6-9 each hold one alternative that no other gate hits;
## The other alternatives of the gate are G1, G2 and G3 hits as well, so they are not planted.
extends RefCounted


var holder: Node = null
var cast: Variant = holder as Node
var made: Variant = Node.new()
var loop: Variant = Engine.get_main_loop()
