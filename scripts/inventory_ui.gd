extends CanvasLayer
## Inventory grid (I or Escape to close).
## - Left click on a medkit: use it
## - Right click on any item: drop one (junk included)
## - Gear wheel button: open the crafting window

const SLOTS := 16
const ITEM_DEFS := {
	"compo_canon": {"short": "Barrel", "label": "Weapon component: barrel"},
	"compo_mecanisme": {"short": "Mech.", "label": "Weapon component: mechanism"},
	"compo_chassis": {"short": "Frame", "label": "Weapon component: frame"},
	"compo_medical": {"short": "Med.", "label": "Medical component (mutant ant)"},
	"compo_organic": {"short": "Gland", "label": "Organic gland (mutant ant)"},
	"res_metal": {"short": "Scrap", "label": "Metal scraps (warbot)"},
	"res_powder": {"short": "Powder", "label": "Chemical powder (warbot)"},
	"res_cell": {"short": "E-core", "label": "Energy core (warbot)"},
	"res_casing": {"short": "Casing", "label": "Spent casings (base critters) — pistol ammo"},
	"pistol": {"short": "Pistol", "label": "Crude pistol — click or drag to the hotbar", "equip": "pistol"},
	"ak_part": {"short": "AK part", "label": "AK-47 part (warbot) — 10 needed"},
	"ak": {"short": "AK-47", "label": "AK-47 assault rifle — click or drag to the hotbar", "equip": "ak"},
	"saber_part": {"short": "Saber pt", "label": "Laser saber part (blue bat) — 10 needed"},
	"saber": {"short": "Saber", "label": "Laser saber — click or drag to the hotbar", "equip": "melee"},
	"junk": {"short": "Junk", "label": "Worthless scrap (right click: drop)"},
	"medkit": {"short": "Med", "label": "Medkit (+40 HP)", "heal": 40.0},
	"medkit_petit": {"short": "Med S", "label": "Medkit S (+40 HP)", "heal": 40.0},
	"medkit_moyen": {"short": "Med M", "label": "Medkit M (+60 HP)", "heal": 60.0},
	"medkit_grand": {"short": "Med L", "label": "Medkit L (+80 HP)", "heal": 80.0},
}

const DroppedItemScript := preload("res://scripts/dropped_item.gd")

@onready var grid: GridContainer = $Center/Panel/VBox/Grid
@onready var _up: Button = $Center/Panel/VBox/Pager/Up
@onready var _down: Button = $Center/Panel/VBox/Pager/Down
@onready var _page_label: Label = $Center/Panel/VBox/Pager/PageLabel

var _page := 0

var _slots: Array[Panel] = []


func _ready() -> void:
	add_to_group("inventory_ui")
	$Center.visible = false
	for i in SLOTS:
		var c := InvCell.new()
		c.index = i
		c.ui = self
		c.custom_minimum_size = Vector2(66, 66)
		grid.add_child(c)
		_slots.append(c)
	$Center/Panel/VBox/Bottom/Craft.pressed.connect(_on_craft_pressed)
	_up.pressed.connect(_page_up)
	_down.pressed.connect(_page_down)
	Inventory.changed.connect(_refresh)
	_refresh()


func _page_up() -> void:
	if _page > 0:
		_page -= 1
		_refresh()


func _page_down() -> void:
	if (_page + 1) * SLOTS < _all_stacks().size():
		_page += 1
		_refresh()


## All visible stacks across the whole inventory (id split into 5s).
func _all_stacks() -> Array:
	var stacks: Array = []
	for id in Inventory.items.keys():
		var total := int(Inventory.items[id])
		while total > 0:
			var q: int = min(total, Inventory.STACK_MAX)
			stacks.append({"id": id, "qty": q})
			total -= q
	return stacks


func is_open() -> bool:
	return $Center.visible


## Hotbar "kind" for an item id, or "" if it cannot go on the quickbar
## (junk, components and resources are excluded).
func hotbar_kind(id: String) -> String:
	var d := _item_def(id)
	if d.has("heal"):
		return "consumable"
	if d.has("equip") or id == "ak" or id == "pistol" or id == "saber" \
			or id.begins_with("ak_slots_") or id.begins_with("laser_slots_"):
		return "weapon"
	return ""


## Left click on an item cell: use a medkit or equip a weapon.
func use_item(id: String) -> void:
	var d := _item_def(id)
	if d.has("heal"):
		# Medkits are consumed from the hotbar. Clicking one moves a
		# stack (up to 5) onto the bar so it can be triggered by key.
		_move_consumable_to_hotbar(id)
	elif d.has("equip"):
		# Clicking a weapon just moves it onto the bar (out of the grid);
		# it is NOT drawn yet — trigger its hotbar slot to equip it.
		var player := get_tree().get_first_node_in_group("player")
		if player and player.hotbar_add_weapon(id):
			Inventory.remove_item(id)


## Right click on an item cell: drop one unit on the ground.
func drop_item(id: String) -> void:
	if Inventory.remove_item(id):
		_spawn_drop(id)


## Item definition, including crafted "ak_slots_N" weapons.
func _item_def(id: String) -> Dictionary:
	if ITEM_DEFS.has(id):
		return ITEM_DEFS[id]
	if id.begins_with("ak_slots_"):
		var n := int(id.trim_prefix("ak_slots_"))
		return {
			"short": "AK [%d]" % n,
			"label": "Handcrafted AK-47 — %d upgrade slot%s" % [n, "s" if n > 1 else ""],
		}
	if id.begins_with("laser_slots_"):
		var n := int(id.trim_prefix("laser_slots_"))
		return {
			"short": "Laser [%d]" % n,
			"label": "Handcrafted laser pistol — %d upgrade slot%s (click or drag to hotbar)" % [n, "s" if n > 1 else ""],
			"equip": "laser",
		}
	return {"short": id, "label": id}


func _refresh() -> void:
	var stacks := _all_stacks()
	# Clamp the page if items were removed
	var pages: int = max(1, int(ceil(float(stacks.size()) / float(SLOTS))))
	_page = clampi(_page, 0, pages - 1)
	var start := _page * SLOTS

	for i in SLOTS:
		var c := _slots[i]
		var gi := start + i
		if gi < stacks.size():
			var id: String = stacks[gi].id
			var d := _item_def(id)
			c.item_id = id
			c.stack_qty = int(stacks[gi].qty)
			c.tooltip_text = str(d.get("label", id)) + "\nClick: use/equip   Drag: to hotbar   Right click: drop"
		else:
			c.item_id = ""
			c.stack_qty = 0
			c.tooltip_text = ""
		c.queue_redraw()

	_page_label.text = "%d/%d" % [_page + 1, pages]
	_up.disabled = _page == 0
	_down.disabled = _page >= pages - 1


## Moves a consumable stack (up to 5) from the inventory onto the
## hotbar: an existing matching stack is topped up first, otherwise the
## first free slot is used. Accepted units leave the inventory.
func _move_consumable_to_hotbar(id: String) -> void:
	var have := Inventory.count(id)
	if have <= 0:
		return
	var target := Hotbar.find_consumable_space(id)
	if target < 0:
		target = Hotbar.first_free()
	if target < 0:
		return
	var accepted := Hotbar.add_consumable(target, id, have)
	if accepted > 0:
		Inventory.remove_item(id, accepted)


func _spawn_drop(id: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var drop := Area3D.new()
	drop.set_script(DroppedItemScript)
	drop.item_id = id
	drop.position = player.global_position \
			- player.global_transform.basis.z * 1.3 + Vector3(0, 0.5, 0)
	get_tree().current_scene.add_child(drop)


func _on_craft_pressed() -> void:
	var craft := get_tree().get_first_node_in_group("craft_ui")
	if craft:
		craft.open()


## Close the inventory (and the crafting window with it), back to game.
func close() -> void:
	$Center.visible = false
	var craft := get_tree().get_first_node_in_group("craft_ui")
	if craft and craft.is_open():
		craft.close()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_I:
		if $Center.visible:
			close()
		else:
			$Center.visible = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Escape also closes the whole inventory (handled before the
	# player's mouse-release toggle thanks to unhandled-input ordering)
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE and $Center.visible:
		close()
		get_viewport().set_input_as_handled()


## An inventory cell: draws its item, handles click (use/equip),
## right click (drop) and drag (to the hotbar). Replaces the old
## Button so that dragging works reliably.
class InvCell:
	extends Panel

	var index := 0
	var item_id := ""
	var stack_qty := 0
	var ui: Node = null


	func _process(_delta: float) -> void:
		queue_redraw()


	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.08, 0.09, 0.1, 0.85))
		draw_rect(rect, Color(0.3, 0.32, 0.35, 0.9), false, 1.0)
		if item_id == "":
			return
		var d: Dictionary = ui._item_def(item_id)
		var short := str(d.get("short", item_id))
		draw_string(font, Vector2(6, 26), short,
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 10, 13, Color(0.92, 0.9, 0.85))
		var cnt := "x%d" % stack_qty
		var cw := font.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2(size.x - cw - 5, size.y - 6), cnt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.82, 0.6))


	func _gui_input(event: InputEvent) -> void:
		if item_id == "":
			return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				ui.use_item(item_id)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				ui.drop_item(item_id)


	## Start a drag if the item can live on the hotbar.
	func _get_drag_data(_pos: Vector2) -> Variant:
		if item_id == "":
			return null
		var kind: String = ui.hotbar_kind(item_id)
		if kind == "":
			return null
		var prev := Panel.new()
		prev.size = Vector2(52, 52)
		var lbl := Label.new()
		var d: Dictionary = ui._item_def(item_id)
		lbl.text = str(d.get("short", item_id))
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.position = Vector2(5, 16)
		prev.add_child(lbl)
		set_drag_preview(prev)
		return {"source": "inventory", "kind": kind, "id": item_id}
