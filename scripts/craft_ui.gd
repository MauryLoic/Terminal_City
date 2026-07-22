extends CanvasLayer
## Crafting window (opened from the inventory).
## Select a recipe, click the gear wheel at the bottom,
## and the assembly succeeds... or produces junk.
## - Weapon: random slot count (0 to 5, high slot counts are rare)
## - Medkit: random potency (S/M/L)

const RECIPES := [
	{
		"nom": "Handcrafted laser pistol",
		"compos": {"compo_canon": 1, "compo_mecanisme": 1, "compo_chassis": 1},
		"chance": 0.65,
		"type": "arme",
	},
	{
		"nom": "Medkit",
		"compos": {"compo_medical": 2},
		"chance": 0.75,
		"type": "soin",
	},
]
const COMPO_NAMES := {
	"compo_canon": "Barrel",
	"compo_mecanisme": "Mechanism",
	"compo_chassis": "Frame",
	"compo_medical": "Medical comp.",
}
# Probabilities for slot count 0..5 (5-slot weapons are rare)
const SLOT_WEIGHTS := [10, 25, 25, 20, 15, 5]

@onready var recipe_box: VBoxContainer = $Center/Panel/VBox/Recipes
@onready var result_label: Label = $Center/Panel/VBox/Result
@onready var gear_button: Button = $Center/Panel/VBox/Bottom/Gear
@onready var close_button: Button = $Center/Panel/VBox/Bottom/Close

var _selected := 0
var _recipe_buttons: Array[Button] = []


func _ready() -> void:
	add_to_group("craft_ui")
	$Center.visible = false
	for i in RECIPES.size():
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_recipe_selected.bind(i))
		recipe_box.add_child(b)
		_recipe_buttons.append(b)
	gear_button.pressed.connect(_on_gear_pressed)
	close_button.pressed.connect(close)
	Inventory.changed.connect(_refresh)
	_refresh()


func open() -> void:
	$Center.visible = true
	result_label.text = ""
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh()


func close() -> void:
	$Center.visible = false
	# Only recapture the mouse if the inventory is closed as well
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	if inv == null or not inv.is_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func is_open() -> bool:
	return $Center.visible


func _on_recipe_selected(i: int) -> void:
	_selected = i
	_refresh()


func _refresh() -> void:
	for i in RECIPES.size():
		var r: Dictionary = RECIPES[i]
		var lines: Array[String] = []
		var ok := true
		for id: String in r.compos:
			var have := int(Inventory.items.get(id, 0))
			var need: int = r.compos[id]
			if have < need:
				ok = false
			lines.append("%s %d/%d" % [COMPO_NAMES.get(id, id), have, need])
		var prefix := "> " if i == _selected else "   "
		_recipe_buttons[i].text = "%s%s\n      %s" % [prefix, r.nom, "   ".join(lines)]
		if i == _selected:
			gear_button.disabled = not ok


func _on_gear_pressed() -> void:
	var r: Dictionary = RECIPES[_selected]
	# Consume the components (failure loses them too: that's the risk)
	for id: String in r.compos:
		if not Inventory.remove_item(id, r.compos[id]):
			return
	Sfx.play_click()
	if randf() < r.chance:
		match r.type:
			"arme":
				var slots := _weighted(SLOT_WEIGHTS)
				Inventory.add_item("laser_slots_%d" % slots)
				result_label.text = "Success! Laser pistol [%d slot%s] — press 2 to equip" \
						% [slots, "s" if slots > 1 else ""]
			"soin":
				var roll := randf()
				var id := "medkit_petit"
				var taille := "S (+25 HP)"
				if roll > 0.85:
					id = "medkit_grand"
					taille = "L (+60 HP)"
				elif roll > 0.5:
					id = "medkit_moyen"
					taille = "M (+40 HP)"
				Inventory.add_item(id)
				result_label.text = "Success! Medkit %s" % taille
	else:
		Inventory.add_item("junk")
		result_label.text = "Assembly failed... the parts end up as junk."


func _weighted(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += w
	var r := randi_range(1, total)
	for i in weights.size():
		r -= weights[i]
		if r <= 0:
			return i
	return 0
