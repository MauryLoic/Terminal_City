extends Node
## "Inventory" autoload — the player's inventory, kept simple:
## a dictionary id -> count. Entirely lost on death.

signal changed

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


func clear() -> void:
	items.clear()
	changed.emit()
