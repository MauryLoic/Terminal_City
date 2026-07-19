extends Node
## Autoload "Inventory" — inventaire du joueur, tout simple :
## un dictionnaire id -> quantité. Perdu intégralement à la mort.

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
