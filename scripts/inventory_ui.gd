extends CanvasLayer
## Grille d'inventaire (touche I). Cliquer sur une trousse de soin
## l'utilise (+40 PV).

const SLOTS := 16
const ITEM_DEFS := {
	"medkit": {"label": "Trousse de soin (+40 PV)", "short": "Soin", "usable": true},
}

@onready var grid: GridContainer = $Center/Panel/VBox/Grid

var _slots: Array[Button] = []


func _ready() -> void:
	$Center.visible = false
	for i in SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(66, 66)
		b.disabled = true
		b.pressed.connect(_on_slot_pressed.bind(i))
		grid.add_child(b)
		_slots.append(b)
	Inventory.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var ids := Inventory.items.keys()
	for i in SLOTS:
		var b := _slots[i]
		if i < ids.size():
			var id: String = ids[i]
			var d: Dictionary = ITEM_DEFS.get(id, {})
			b.text = "%s\nx%d" % [d.get("short", id), Inventory.items[id]]
			b.disabled = not d.get("usable", false)
			b.tooltip_text = d.get("label", id)
		else:
			b.text = ""
			b.disabled = true
			b.tooltip_text = ""


func _on_slot_pressed(i: int) -> void:
	var ids := Inventory.items.keys()
	if i >= ids.size():
		return
	var id: String = ids[i]
	if id == "medkit":
		var player := get_tree().get_first_node_in_group("player")
		if player and player.health < player.MAX_HEALTH \
				and Inventory.remove_item("medkit"):
			player.heal(40.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_I:
		$Center.visible = not $Center.visible
		if $Center.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
