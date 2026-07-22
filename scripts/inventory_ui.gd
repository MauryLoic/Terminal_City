extends CanvasLayer
## Grille d'inventaire (touche I).
## - Clic gauche sur une trousse de soin : l'utiliser
## - Clic droit sur n'importe quel objet : en jeter un (junk compris)
## - Bouton roue crantée : ouvrir la fenêtre de construction

const SLOTS := 16
const ITEM_DEFS := {
	"compo_canon": {"short": "Canon", "label": "Composant d'arme : canon"},
	"compo_mecanisme": {"short": "Mécan.", "label": "Composant d'arme : mécanisme"},
	"compo_chassis": {"short": "Châssis", "label": "Composant d'arme : châssis"},
	"compo_medical": {"short": "Médic.", "label": "Composant médical"},
	"junk": {"short": "Junk", "label": "Débris sans valeur (clic droit : jeter)"},
	"medkit": {"short": "Soin", "label": "Trousse de soin (+40 PV)", "heal": 40.0},
	"medkit_petit": {"short": "Soin S", "label": "Trousse de soin S (+25 PV)", "heal": 25.0},
	"medkit_moyen": {"short": "Soin M", "label": "Trousse de soin M (+40 PV)", "heal": 40.0},
	"medkit_grand": {"short": "Soin L", "label": "Trousse de soin L (+60 PV)", "heal": 60.0},
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


## Définition d'un objet, y compris les armes craftées "ak_slots_N".
func _item_def(id: String) -> Dictionary:
	if ITEM_DEFS.has(id):
		return ITEM_DEFS[id]
	if id.begins_with("ak_slots_"):
		var n := int(id.trim_prefix("ak_slots_"))
		return {
			"short": "AK [%d]" % n,
			"label": "AK-47 artisanale — %d slot%s d'amélioration" % [n, "s" if n > 1 else ""],
		}
	if id.begins_with("laser_slots_"):
		var n := int(id.trim_prefix("laser_slots_"))
		return {
			"short": "Laser [%d]" % n,
			"label": "Pistolet laser artisanal — %d slot%s d'amélioration (touche 2 pour l'équiper)" % [n, "s" if n > 1 else ""],
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
			b.tooltip_text = str(d.get("label", id)) + "\nClic droit : jeter"
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
		if player and player.health < player.MAX_HEALTH \
				and Inventory.remove_item(id):
			player.heal(d.heal)


## Clic droit : jeter une unité de l'objet — elle apparaît au sol devant
## le joueur, reste 30 s (re-ramassable) puis disparaît.
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_I:
		$Center.visible = not $Center.visible
		if $Center.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			# Fermer aussi la construction, puis recapturer la souris
			var craft := get_tree().get_first_node_in_group("craft_ui")
			if craft and craft.is_open():
				craft.close()
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
