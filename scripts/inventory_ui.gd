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
	"pistol": {"short": "Pistol", "label": "Crude pistol — click to equip", "equip": "pistol"},
	"ak_part": {"short": "AK part", "label": "AK-47 part (warbot) — 10 needed"},
	"ak": {"short": "AK-47", "label": "AK-47 assault rifle — click to equip", "equip": "ak"},
	"saber_part": {"short": "Saber pt", "label": "Laser saber part (blue bat) — 10 needed"},
	"saber": {"short": "Saber", "label": "Laser saber — click to equip (melee)", "equip": "melee"},
	"junk": {"short": "Junk", "label": "Worthless scrap (right click: drop)"},
	"medkit": {"short": "Med", "label": "Medkit (+40 HP)", "heal": 40.0},
	"medkit_petit": {"short": "Med S", "label": "Medkit S (+40 HP)", "heal": 40.0},
	"medkit_moyen": {"short": "Med M", "label": "Medkit M (+60 HP)", "heal": 60.0},
	"medkit_grand": {"short": "Med L", "label": "Medkit L (+80 HP)", "heal": 80.0},
}

const DroppedItemScript := preload("res://scripts/dropped_item.gd")

@onready var grid: GridContainer = $Center/Panel/VBox/Grid

var _slots: Array[Button] = []


func _ready() -> void:
	add_to_group("inventory_ui")
	$Center.visible = false
	for i in SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(66, 66)
		b.disabled = true
		b.pressed.connect(_on_slot_pressed.bind(i))
		b.gui_input.connect(_on_slot_gui_input.bind(i))
		grid.add_child(b)
		_slots.append(b)
	$Center/Panel/VBox/Bottom/Craft.pressed.connect(_on_craft_pressed)
	Inventory.changed.connect(_refresh)
	_refresh()


func is_open() -> bool:
	return $Center.visible


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
			"label": "Handcrafted laser pistol — %d upgrade slot%s (click to equip)" % [n, "s" if n > 1 else ""],
			"equip": "laser",
		}
	return {"short": id, "label": id}


func _refresh() -> void:
	var ids := Inventory.items.keys()
	for i in SLOTS:
		var b := _slots[i]
		if i < ids.size():
			var id: String = ids[i]
			var d := _item_def(id)
			b.text = "%s\nx%d" % [d.get("short", id), Inventory.items[id]]
			b.disabled = false
			b.tooltip_text = str(d.get("label", id)) + "\nClick: use/equip (adds to hotbar)   Right click: drop"
		else:
			b.text = ""
			b.disabled = true
			b.tooltip_text = ""


func _on_slot_pressed(i: int) -> void:
	var ids := Inventory.items.keys()
	if i >= ids.size():
		return
	var id: String = ids[i]
	var d := _item_def(id)
	if d.has("heal"):
		var player := get_tree().get_first_node_in_group("player")
		# A medkit also earns a quickbar slot the first time you use it,
		# so it can be re-triggered by its number key afterwards
		_ensure_on_hotbar("consumable", id)
		if player and player.health < player.max_health() \
				and Inventory.remove_item(id):
			player.heal(d.heal)
	elif d.has("equip"):
		# Weapons: clicking equips them, and drops them onto the first
		# free quickbar slot if they are not already on the bar
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.equip_weapon(str(d.equip))
			_ensure_on_hotbar("weapon", id)


## Puts an item on the quickbar if it is not already there, choosing
## the first free slot. Weapons and medkits both go through here so a
## single click both uses the item and binds its hotkey.
func _ensure_on_hotbar(kind: String, id: String) -> void:
	for i in Hotbar.SLOT_COUNT:
		if Hotbar.get_slot(i).get("id", "") == id:
			return
	var free := Hotbar.first_free()
	if free >= 0:
		Hotbar.assign(free, kind, id)


## Right click: drop one unit of the item — it appears on the ground in
## front of the player, stays 30 s (pickable again) then disappears.
func _on_slot_gui_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		var ids := Inventory.items.keys()
		if i < ids.size() and Inventory.remove_item(ids[i]):
			_spawn_drop(ids[i])


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
