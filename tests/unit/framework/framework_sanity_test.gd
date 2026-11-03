## Seed unit suite created by /test-setup.
##
## It proves the gdUnit4 runner discovers and executes suites under
## res://tests/unit, so a run that reports "No test cases found" (exit 0 with no
## tests) can never be mistaken for a pass. It depends on no production code;
## delete it once a real system has its own suite under tests/unit/[system]/.
extends GdUnitTestSuite


func test_integer_addition_returns_sum() -> void:
	# Arrange
	var left: int = 2
	var right: int = 3

	# Act
	var sum: int = left + right

	# Assert
	assert_int(sum).is_equal(5)


func test_dictionary_round_trip_preserves_values() -> void:
	# Arrange
	var source: Dictionary = {"name": "goblin", "attack": 2, "health": 1}

	# Act
	var copy: Dictionary = source.duplicate()

	# Assert
	assert_dict(copy).is_equal(source)
	assert_str(copy["name"]).is_equal("goblin")
	assert_int(copy["attack"]).is_equal(2)


func test_auto_freed_node_does_not_leak() -> void:
	# Arrange -- auto_free: a Node left alive is an orphan (gdUnit4 exit 101)
	var node: Node = auto_free(Node.new())
	node.name = "SanityNode"

	# Act
	var child: Node = auto_free(Node.new())
	node.add_child(child)

	# Assert
	assert_object(node).is_not_null()
	assert_int(node.get_child_count()).is_equal(1)
