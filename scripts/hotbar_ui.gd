extends Control
## Vertical quickbar down the right edge, Neocron style: 10 numbered
## cells (1..9, 0), each holding a weapon or a consumable. Supports
## drag-and-drop: drag an item from the inventory onto a cell to bind
## it, or drag between cells to reorder. Keys 1..0 trigger the cells.

const CELL := 52.0
const PAD := 6.0
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

var _cells: Array[Panel] = []


func _ready() -> void:
	add_to_group("hotbar_ui")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	for i in Hotbar.SLOT_COUNT:
		var cell := HotbarCell.new()
		cell.index = i
		cell.custom_minimum_size = Vector2(CELL, CELL)
		cell.size = Vector2(CELL, CELL)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(cell)
		_cells.append(cell)

	get_viewport().size_changed.connect(_reposition)
	_reposition()


func _reposition() -> void:
	var n := Hotbar.SLOT_COUNT
	var total_h := n * CELL + (n - 1) * PAD
	var vp := get_viewport_rect().size
	var x := vp.x - CELL - 14.0
	var y0 := (vp.y - total_h) * 0.5
	for i in n:
		_cells[i].position = Vector2(x, y0 + i * (CELL + PAD))


## A single quickbar cell: draws itself, and is both a drag source and
## a drop target for inventory/hotbar items.
class HotbarCell:
	extends Panel

	const K := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

	var index := 0


	func _process(_delta: float) -> void:
		queue_redraw()


	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var slot: Dictionary = Hotbar.get_slot(index)
		var rect := Rect2(Vector2.ZERO, size)

		draw_rect(rect, Color(0.05, 0.06, 0.07, 0.72))

		var player := get_tree().get_first_node_in_group("player")
		var active_id := ""
		if player != null:
			active_id = str(player.current_weapon())
		var is_active: bool = not slot.is_empty() \
				and str(slot.get("kind", "")) == "weapon" \
				and str(slot.get("id", "")) == active_id
		var border: Color = Color(1.0, 0.55, 0.2, 1.0) if is_active \
				else Color(0.4, 0.42, 0.45, 0.9)
		draw_rect(rect, border, false, 2.0 if is_active else 1.0)

		draw_string(font, Vector2(4, 15), K[index],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.78, 0.8))

		if slot.is_empty():
			return

		var id: String = str(slot.get("id", ""))
		var inv := get_tree().get_first_node_in_group("inventory_ui")
		var short := id
		var count := -1
		if inv != null:
			short = str(inv._item_def(id).get("short", id))
		if str(slot.get("kind", "")) == "consumable":
			count = int(slot.get("count", 0))

		var col: Color = Color(0.92, 0.9, 0.85)
		if count == 0:
			col = Color(0.5, 0.5, 0.5)
		var tw := font.get_string_size(short, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2((size.x - tw) * 0.5, 32), short,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)

		if count >= 0:
			var cnt := "x%d" % count
			var cw := font.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(font, Vector2(size.x - cw - 4, size.y - 5), cnt,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.82, 0.6))


	## Left click triggers the slot; right click clears it.
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var player := get_tree().get_first_node_in_group("player")
				if player:
					player.use_hotbar_slot(index)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				var slot: Dictionary = Hotbar.get_slot(index)
				if str(slot.get("kind", "")) == "consumable":
					# Return one unit to the inventory (respects 5-stacks)
					var id := Hotbar.take_one(index)
					if id != "":
						Inventory.add_item(id)
				elif str(slot.get("kind", "")) == "weapon":
					# Return the weapon to the inventory grid. The base
					# knife (id "melee") can't be unslotted — it is the
					# always-available fallback and lives nowhere else.
					var wid := str(slot.get("id", ""))
					if wid == "melee":
						pass   # keep the knife on the bar
					else:
						Hotbar.clear_slot(index)
						Inventory.add_item(wid)
						var player := get_tree().get_first_node_in_group("player")
						if player:
							player.unequip_weapon(wid)
				else:
					Hotbar.clear_slot(index)


	## Drag an already-bound item out of its cell (to move or swap it).
	func _get_drag_data(_pos: Vector2) -> Variant:
		var slot: Dictionary = Hotbar.get_slot(index)
		if slot.is_empty():
			return null
		set_drag_preview(_make_preview(str(slot.get("id", ""))))
		return {
			"source": "hotbar",
			"from_index": index,
			"kind": str(slot.get("kind", "")),
			"id": str(slot.get("id", "")),
		}


	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("id") and data.has("kind")


	func _drop_data(_pos: Vector2, data: Variant) -> void:
		var d: Dictionary = data
		var kind := str(d.get("kind", ""))
		var id := str(d.get("id", ""))

		# Reordering within the hotbar: plain swap of the two slots
		if str(d.get("source", "")) == "hotbar":
			var from: int = int(d.get("from_index", -1))
			if from >= 0 and from != index:
				var here: Dictionary = Hotbar.get_slot(index)
				var moved: Dictionary = Hotbar.get_slot(from)
				Hotbar.slots[index] = moved
				Hotbar.slots[from] = here
				Hotbar.changed.emit()
			return

		# From the inventory
		if kind == "weapon":
			Hotbar.assign_weapon(index, id)
			# The weapon leaves the grid (it now lives on the bar); the
			# player still "owns" it via the weapons list / _owns_* checks
			Inventory.remove_item(id)
			return

		# Consumable: move the whole inventory stack of this id onto the
		# cell, up to the 5 cap; the accepted units leave the inventory
		var have := Inventory.count(id)
		if have <= 0:
			return
		var accepted := Hotbar.add_consumable(index, id, have)
		if accepted > 0:
			Inventory.remove_item(id, accepted)


	func _make_preview(id: String) -> Control:
		var p := Panel.new()
		p.size = Vector2(48, 48)
		var lbl := Label.new()
		var inv := get_tree().get_first_node_in_group("inventory_ui")
		lbl.text = str(inv._item_def(id).get("short", id)) if inv else id
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.position = Vector2(4, 14)
		p.add_child(lbl)
		return p
