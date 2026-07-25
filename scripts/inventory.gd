extends Node
## "Inventory" autoload — the player's inventory.
##
## Internally it stays a simple id -> total count map, so all the loot
## and crafting code keeps working unchanged. Stack-of-5 behaviour is a
## presentation concern handled by inventory_ui (an id with 12 units is
## shown as stacks 5 + 5 + 2). Consumables that sit on the hotbar are
## NOT in here — they have been moved out into a Hotbar cell.

signal changed

const STACK_MAX := 5

var items := {}


func add_item(id: String, n := 1) -> void:
	items[id] = int(items.get(id, 0)) + n
	changed.emit()


func remove_item(id: String, n := 1) -> bool:
	if int(items.get(id, 0)) < n:
		return false
	items[id] = int(items[id]) - n
	if int(items[id]) <= 0:
		items.erase(id)
	changed.emit()
	return true


func count(id: String) -> int:
	return int(items.get(id, 0))


func clear() -> void:
	items.clear()
	changed.emit()


## Number of full/partial stacks an id occupies in the grid.
func stack_count(id: String) -> int:
	var total := int(items.get(id, 0))
	return int(ceil(float(total) / float(STACK_MAX)))
