extends Node
## "Hotbar" autoload — the Neocron-style quickbar model: 10 numbered
## slots (keys 1..9 then 0) that can each hold a weapon or a consumable.
## The UI (hotbar_ui.gd) reads this, and the player triggers a slot by
## its number. Slots survive across the session; a weapon slot stays
## valid, a consumable slot empties itself when the last unit is used.

signal changed

const SLOT_COUNT := 10

# Each slot is either {} (empty) or {"kind": "weapon"/"consumable", "id": String}
var slots: Array[Dictionary] = []


func _ready() -> void:
	for i in SLOT_COUNT:
		slots.append({})


## Assign an item to a slot. If it already sits in another slot, it is
## moved rather than duplicated (one item, one hotkey).
func assign(index: int, kind: String, id: String) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	for i in SLOT_COUNT:
		if slots[i].get("id", "") == id:
			slots[i] = {}
	slots[index] = {"kind": kind, "id": id}
	changed.emit()


func clear_slot(index: int) -> void:
	if index >= 0 and index < SLOT_COUNT:
		slots[index] = {}
		changed.emit()


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= SLOT_COUNT:
		return {}
	return slots[index]


## First empty slot index, or -1 if the bar is full.
func first_free() -> int:
	for i in SLOT_COUNT:
		if slots[i].is_empty():
			return i
	return -1
