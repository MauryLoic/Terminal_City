extends CanvasLayer
## "LootWindow" autoload — the mob loot screen. When the player loots a
## corpse/wreck, that source calls LootWindow.open(source, contents):
## the window shows what the mob carries and lets the player take items
## one by one (or all at once) into their inventory. Closing returns
## whatever was left to the source, so it can be looted again later.

signal closed

const SLOT := 66.0

var _source: Object = null
var _contents := {}        # id -> count still in the mob

var _panel: Panel
var _grid: GridContainer
var _title: Label
var _slots: Array = []


func _ready() -> void:
	add_to_group("loot_window")
	layer = 3
	visible = false

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(300, 380)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 10
	vbox.offset_right = -12
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	_title = Label.new()
	_title.text = "Loot"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_grid)
	for i in 12:
		var cell := LootCell.new()
		cell.window = self
		cell.index = i
		cell.custom_minimum_size = Vector2(SLOT, SLOT)
		_grid.add_child(cell)
		_slots.append(cell)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(bottom)
	var take_all := Button.new()
	take_all.text = "Take all"
	take_all.custom_minimum_size = Vector2(120, 34)
	take_all.pressed.connect(_take_all)
	bottom.add_child(take_all)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(120, 34)
	close.pressed.connect(close_window)
	bottom.add_child(close)


## Opens the window on a mob's contents. `contents` is an id -> count
## dictionary; `source` is the corpse/wreck node (it receives the
## leftovers when the window closes).
func open(source: Object, contents: Dictionary, title := "Loot") -> void:
	_source = source
	_contents = contents.duplicate()
	_title.text = title
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh()


func is_open() -> bool:
	return visible


## Take one unit of the id at a grid index into the inventory.
func take(index: int) -> void:
	var ids := _contents.keys()
	if index >= ids.size():
		return
	var id: String = ids[index]
	Inventory.add_item(id)
	_contents[id] = int(_contents[id]) - 1
	if int(_contents[id]) <= 0:
		_contents.erase(id)
	Sfx.play_click()
	if _contents.is_empty():
		close_window()
	else:
		_refresh()


func _take_all() -> void:
	for id in _contents:
		Inventory.add_item(id, _contents[id])
	_contents.clear()
	Sfx.play_click()
	close_window()


func close_window() -> void:
	visible = false
	# Hand whatever is left back to the source so it can be re-looted
	if _source != null and is_instance_valid(_source) and _source.has_method("set_remaining_loot"):
		_source.set_remaining_loot(_contents)
	_source = null
	# Recapture the mouse only if no other UI needs it
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	if inv == null or not inv.is_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		close_window()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var ids := _contents.keys()
	for i in _slots.size():
		var c = _slots[i]
		if i < ids.size():
			c.item_id = ids[i]
			c.qty = int(_contents[ids[i]])
		else:
			c.item_id = ""
			c.qty = 0
		c.queue_redraw()


## A loot cell: draws an item and takes it on left click.
class LootCell:
	extends Panel

	var window: Node = null
	var index := 0
	var item_id := ""
	var qty := 0


	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.1, 0.9))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.32, 0.35), false, 1.0)
		if item_id == "":
			return
		var inv := get_tree().get_first_node_in_group("inventory_ui")
		var short := item_id
		if inv != null:
			short = str(inv._item_def(item_id).get("short", item_id))
		draw_string(font, Vector2(6, 26), short,
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 10, 12, Color(0.92, 0.9, 0.85))
		var cnt := "x%d" % qty
		var cw := font.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2(size.x - cw - 5, size.y - 6), cnt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.82, 0.6))


	func _gui_input(event: InputEvent) -> void:
		if item_id == "" or window == null:
			return
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			window.take(index)
