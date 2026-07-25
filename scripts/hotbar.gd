extends Node
## "Hotbar" autoload — the Neocron-style quickbar: 10 numbered slots
## (keys 1..9 then 0), each holding a weapon or a stack of consumables.
##
## A weapon slot just references the weapon id (weapons are unique and
## also tracked in the inventory). A consumable slot OWNS its units:
## when a medkit stack is dragged here it leaves the inventory and its
## count lives in the slot, capped at STACK_MAX (5), Neocron-style.

signal changed

const SLOT_COUNT := 10
const STACK_MAX := 5

# Each slot is {} (empty) or:
#   weapon:     {"kind": "weapon", "id": String}
#   consumable: {"kind": "consumable", "id": String, "count": int}
var slots: Array[Dictionary] = []


func _ready() -> void:
	for i in SLOT_COUNT:
		slots.append({})
	# Slot 1 starts with the rusty knife, the always-available weapon
	slots[0] = {"kind": "weapon", "id": "melee"}


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= SLOT_COUNT:
		return {}
	return slots[index]


func clear_slot(index: int) -> void:
	if index >= 0 and index < SLOT_COUNT:
		slots[index] = {}
		changed.emit()


func first_free() -> int:
	for i in SLOT_COUNT:
		if slots[i].is_empty():
			return i
	return -1


## Places a weapon reference on a slot, moving it if already present.
func assign_weapon(index: int, id: String) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	for i in SLOT_COUNT:
		if str(slots[i].get("id", "")) == id and str(slots[i].get("kind", "")) == "weapon":
			slots[i] = {}
	slots[index] = {"kind": "weapon", "id": id}
	changed.emit()


## Adds consumable units to a slot (capped at STACK_MAX). Returns the
## number actually accepted; the caller keeps the overflow.
func add_consumable(index: int, id: String, n: int) -> int:
	if index < 0 or index >= SLOT_COUNT:
		return 0
	var slot: Dictionary = slots[index]
	if slot.is_empty():
		var take: int = min(n, STACK_MAX)
		slots[index] = {"kind": "consumable", "id": id, "count": take}
		changed.emit()
		return take
	# Same consumable already there: top it up to the cap
	if str(slot.get("kind", "")) == "consumable" and str(slot.get("id", "")) == id:
		var space: int = STACK_MAX - int(slot.get("count", 0))
		var take2: int = min(n, space)
		if take2 > 0:
			slot["count"] = int(slot.get("count", 0)) + take2
			slots[index] = slot
			changed.emit()
		return take2
	return 0


## Removes one consumable unit from a slot (for use or right-click
## return). Empties the slot when it hits zero. Returns the id, or "".
func take_one(index: int) -> String:
	if index < 0 or index >= SLOT_COUNT:
		return ""
	var slot: Dictionary = slots[index]
	if str(slot.get("kind", "")) != "consumable":
		return ""
	var id: String = str(slot.get("id", ""))
	var c: int = int(slot.get("count", 0)) - 1
	if c <= 0:
		slots[index] = {}
	else:
		slot["count"] = c
		slots[index] = slot
	changed.emit()
	return id


## First slot index holding a matching, non-full consumable stack, or -1.
func find_consumable_space(id: String) -> int:
	for i in SLOT_COUNT:
		var s: Dictionary = slots[i]
		if str(s.get("kind", "")) == "consumable" and str(s.get("id", "")) == id \
				and int(s.get("count", 0)) < STACK_MAX:
			return i
	return -1
