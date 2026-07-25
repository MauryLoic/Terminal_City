extends Control
## Vertical quickbar drawn down the right edge of the screen, Neocron
## style: 10 numbered cells (1..9, 0) showing what each hotkey holds.
## The active weapon slot is highlighted; consumables show their count.

const CELL := 52.0
const PAD := 6.0
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Hotbar.changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var n := Hotbar.SLOT_COUNT
	var total_h := n * CELL + (n - 1) * PAD
	var vp := get_viewport_rect().size
	var x := vp.x - CELL - 14.0
	var y0 := (vp.y - total_h) * 0.5

	var player := get_tree().get_first_node_in_group("player")
	var active_id := ""
	if player != null:
		active_id = player.current_weapon()

	var inv := get_tree().get_first_node_in_group("inventory_ui")

	for i in n:
		var y := y0 + i * (CELL + PAD)
		var rect := Rect2(x, y, CELL, CELL)
		var slot: Dictionary = Hotbar.get_slot(i)

		# Cell background and border
		draw_rect(rect, Color(0.05, 0.06, 0.07, 0.72))
		var border := Color(0.4, 0.42, 0.45, 0.9)
		var is_active: bool = not slot.is_empty() \
				and slot.get("kind", "") == "weapon" \
				and str(slot.get("id", "")) == active_id
		if is_active:
			border = Color(1.0, 0.55, 0.2, 1.0)
		draw_rect(rect, border, false, 2.0 if is_active else 1.0)

		# Hotkey number, top-left
		draw_string(font, Vector2(x + 4, y + 15), KEYS[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.78, 0.8))

		if slot.is_empty():
			continue

		# Item short label, centered
		var id: String = slot.get("id", "")
		var short := id
		var count := -1
		if inv != null:
			short = str(inv._item_def(id).get("short", id))
			if slot.get("kind", "") == "consumable":
				count = int(Inventory.items.get(id, 0))

		var col := Color(0.92, 0.9, 0.85)
		if count == 0:
			col = Color(0.5, 0.5, 0.5)   # owned none right now
		var tw := font.get_string_size(short, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2(x + (CELL - tw) * 0.5, y + 32), short,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)

		# Consumable count, bottom-right
		if count >= 0:
			var cnt := "x%d" % count
			var cw := font.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(font, Vector2(x + CELL - cw - 4, y + CELL - 5), cnt,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.82, 0.6))
