class_name BagScreen
extends Control
## Phase 4 step 1: the BAG screen (I key). Built from plain Controls, no assets.
##
##   left:   CAR - the 6 part slots (name in rarity color + chip sockets ◆ filled / ◇ empty),
##           the guns (read-only: gun loadout changes at a town garage, later), car stats
##   middle: BAG - unequipped parts and loose chips, scrap
##   right:  DETAILS of the selected item: stats, compare vs the equipped part (green/red),
##           actions: Equip / Unequip / Insert chip into <slot> / Remove chip (costs scrap)
##
## Click = select. Double-click or right-click = quick action (equip / unequip).
## The car keeps driving while the bag is open (MMO style); guns don't fire.
## I or ESC closes it.

var status: PlayerStatus

const BG := Color(0.07, 0.07, 0.08, 0.94)
const PANEL := Color(0.12, 0.12, 0.14, 1.0)
const BORDER := Color(0.85, 0.6, 0.25)
const TEXT := Color(0.92, 0.9, 0.85)
const DIM := Color(0.6, 0.6, 0.6)
const GOOD := Color(0.4, 0.95, 0.4)
const BAD := Color(1.0, 0.4, 0.35)

## {"where": "bag", "uid": int} or {"where": "slot", "slot": String} or {}.
var _selected: Dictionary = {}
var _open: bool = false

var _slots_box: VBoxContainer
var _guns_label: Label
var _stats_label: RichTextLabel
var _bag_grid: GridContainer
var _bag_title: Label
var _details: RichTextLabel
var _actions: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	status.equipment.changed.connect(_refresh)


func is_open() -> bool:
	return _open


func toggle() -> void:
	var weapons := status.get_parent().get_node_or_null("Weapons") as WeaponController
	if not _open and weapons and weapons.ui_open:
		return  # another menu (garage) is open
	_open = not _open
	visible = _open
	if weapons:
		weapons.set_menu_open(_open)
	if _open:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_bag") or (_open and event.is_action_pressed("toggle_cursor")):
		toggle()
		get_viewport().set_input_as_handled()


# --- Build -----------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(BG, BORDER, 2, 14))
	center.add_child(frame)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	frame.add_child(outer)

	var title := _label("GARAGE BAG", 22, BORDER)
	outer.add_child(title)
	var hint := _label("Click: select   ·   Double/right-click: equip / unequip   ·   I or ESC: close", 13, DIM)
	outer.add_child(hint)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	outer.add_child(cols)

	# Left: car.
	var left := _column(cols, 330.0, "CAR")
	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 4)
	left.add_child(_slots_box)
	left.add_child(_label("GUNS  (change at a town garage)", 13, DIM))
	_guns_label = _label("", 14, TEXT)
	left.add_child(_guns_label)
	left.add_child(_label("CAR STATS", 13, DIM))
	_stats_label = _rich(330.0, 210.0)
	left.add_child(_stats_label)

	# Middle: bag.
	var mid := _column(cols, 360.0, "")
	_bag_title = mid.get_child(0) as Label
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360.0, 470.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = 2
	_bag_grid.add_theme_constant_override("h_separation", 4)
	_bag_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_bag_grid)

	# Right: details.
	var right := _column(cols, 340.0, "DETAILS")
	_details = _rich(340.0, 330.0)
	right.add_child(_details)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 4)
	right.add_child(_actions)


func _column(parent: Control, width: float, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL, Color(0.25, 0.25, 0.28), 1, 10))
	panel.custom_minimum_size = Vector2(width + 20.0, 560.0)
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(_label(title, 16, BORDER))
	return v


func _box(fill: Color, border: Color, width: int, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(pad)
	return sb


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _rich(w: float, h: float) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_active = true
	r.custom_minimum_size = Vector2(w, h)
	r.add_theme_font_size_override("normal_font_size", 14)
	r.add_theme_color_override("default_color", TEXT)
	return r


func _item_button(text: String, color: Color, selected: bool, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.clip_text = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(width, 34.0)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, color)
	var border := BORDER if selected else Color(0.3, 0.3, 0.33)
	b.add_theme_stylebox_override("normal", _box(Color(0.16, 0.16, 0.18), border, 2 if selected else 1, 6))
	b.add_theme_stylebox_override("hover", _box(Color(0.22, 0.22, 0.25), border, 2 if selected else 1, 6))
	b.add_theme_stylebox_override("pressed", _box(Color(0.22, 0.22, 0.25), BORDER, 2, 6))
	return b


func _action_button(text: String, enabled: bool, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0.0, 32.0)
	b.pressed.connect(callback)
	_actions.add_child(b)


## Click selects; double-click or right-click runs the quick action.
func _hook(b: Button, select: Dictionary, quick: Callable) -> void:
	b.gui_input.connect(_on_item_input.bind(select, quick))


func _on_item_input(e: InputEvent, select: Dictionary, quick: Callable) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT or mb.double_click:
		_selected = select
		quick.call()
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		_selected = select
		_refresh()


# --- Actions -----------------------------------------------------------------

func _do_equip(part: Dictionary) -> void:
	if part.get("kind") != "part":
		return
	_selected = {"where": "slot", "slot": part["slot"]}
	status.equipment.equip(part)


func _do_unequip(slot: String) -> void:
	status.equipment.unequip(slot)


func _do_insert(chip: Dictionary, slot: String) -> void:
	_selected = {"where": "slot", "slot": slot}
	status.equipment.insert_chip(chip, slot)


func _do_remove(slot: String, index: int) -> void:
	if not status.equipment.remove_chip(slot, index):
		status.toast("Not enough scrap", BAD)


static func _sort_items(a: Dictionary, b: Dictionary) -> bool:
	if a["kind"] != b["kind"]:
		return a["kind"] == "chip"
	if a["rarity"] != b["rarity"]:
		return a["rarity"] > b["rarity"]
	return str(a["name"]) < str(b["name"])


# --- Refresh -----------------------------------------------------------------

func _refresh() -> void:
	if not _open:
		return
	var eq := status.equipment

	# Slots.
	for c in _slots_box.get_children():
		c.queue_free()
	for slot in ItemDB.SLOTS:
		var part := eq.get_part(slot)
		var sel: bool = _selected.get("where") == "slot" and _selected.get("slot") == slot
		var text: String
		var color := DIM
		if part.is_empty():
			text = "%s:  (empty)" % slot
		else:
			text = "%s:  %s  %s" % [slot, part["name"], _sockets_text(part)]
			color = Loot.RARITY_COLORS[part["rarity"]]
		var b := _item_button(text, color, sel, 330.0)
		_slots_box.add_child(b)
		_hook(b, {"where": "slot", "slot": slot}, _do_unequip.bind(slot))

	# Guns (read-only for now).
	var weapons := status.get_parent().get_node_or_null("Weapons") as WeaponController
	var guns := ""
	if weapons:
		for i in weapons.weapons.size():
			guns += "%d. %s\n" % [i + 1, weapons.weapons[i].display_name]
	_guns_label.text = guns.strip_edges()

	_stats_label.text = _car_stats_text()

	# Bag.
	for c in _bag_grid.get_children():
		c.queue_free()
	_bag_title.text = "BAG  (%d)      SCRAP %d" % [status.items.size(), status.scrap]
	var sorted: Array = status.items.duplicate()
	sorted.sort_custom(_sort_items)
	for item in sorted:
		var sel: bool = _selected.get("where") == "bag" and _selected.get("uid") == item["uid"]
		var label: String = item["name"]
		if item["kind"] == "part" and int(item["sockets"]) > 0:
			label += "  " + _sockets_text(item)
		if item["kind"] == "chip":
			label = "▣ " + label
		var b := _item_button(label, Loot.RARITY_COLORS[item["rarity"]], sel, 176.0)
		b.tooltip_text = item["name"]
		_bag_grid.add_child(b)
		_hook(b, {"where": "bag", "uid": item["uid"]}, _do_equip.bind(item))

	_refresh_details()


func _sockets_text(part: Dictionary) -> String:
	var n := int(part["sockets"])
	var used := (part["chips"] as Array).size()
	return "◆".repeat(used) + "◇".repeat(n - used)


func _find_bag(uid: int) -> Dictionary:
	for item in status.items:
		if item["uid"] == uid:
			return item
	return {}


func _refresh_details() -> void:
	for c in _actions.get_children():
		c.queue_free()
	var eq := status.equipment
	var t := ""
	match _selected.get("where", ""):
		"slot":
			var slot: String = _selected["slot"]
			var part := eq.get_part(slot)
			if part.is_empty():
				t = "[color=#999]%s slot is empty.\nSelect a %s in the bag to equip it.[/color]" % [slot, slot]
			else:
				t = _part_text(part, "EQUIPPED")
				_action_button("Unequip", true, _do_unequip.bind(slot))
				for i in (part["chips"] as Array).size():
					var chip: Dictionary = part["chips"][i]
					var cost: int = chip["remove_cost"]
					_action_button("Remove %s  (%d scrap)" % [chip["name"], cost], status.scrap >= cost,
						_do_remove.bind(slot, i))
		"bag":
			var item := _find_bag(_selected["uid"])
			if item.is_empty():
				_selected = {}
			elif item["kind"] == "part":
				t = _part_text(item, "IN BAG")
				t += _compare_text(item)
				var current := eq.get_part(item["slot"])
				var equip_text := "Equip"
				if not current.is_empty():
					equip_text = "Equip  (replaces %s)" % current["name"]
				_action_button(equip_text, true, _do_equip.bind(item))
			else:
				t = _chip_text(item)
				for slot in ItemDB.SLOTS:
					var part := eq.get_part(slot)
					if part.is_empty() or not ItemDB.chip_fits(item, part):
						continue
					var reason := eq.chip_block_reason(item, part)
					var label := "Insert into %s" % slot
					if reason != "":
						label += "  (%s)" % reason
					_action_button(label, reason == "", _do_insert.bind(item, slot))
				if _actions.get_child_count() == 0:
					t += "\n[color=#999]Equip a %s with a free socket to insert this chip.[/color]" % \
						("part" if item["slot"] == "Any" else item["slot"])
		_:
			t = "[color=#999]Select a part or chip.\n\nParts drop from monsters. Chips are very rare drops (one per monster type) that go into the sockets ◇ of equipped parts.[/color]"
	_details.text = t


func _part_text(part: Dictionary, where: String) -> String:
	var c: Color = Loot.RARITY_COLORS[part["rarity"]]
	var t := "[color=#%s][b]%s[/b][/color]\n" % [c.to_html(false), part["name"]]
	t += "[color=#999]%s · %s · %s[/color]\n\n" % [Loot.RARITY_NAMES[part["rarity"]], part["slot"], where]
	var main: Dictionary = ItemDB.part_lines(part, false)[0]
	t += "[b]%s[/b]" % ItemDB.format_line(main["key"], main["value"])
	if ItemDB.tune_level(part) > 0:
		t += "  [color=#ffb347](tuned +%d)[/color]" % ItemDB.tune_level(part)
	t += "\n"
	for a in part["affixes"]:
		t += "%s\n" % ItemDB.format_line(a["key"], a["value"])
	var sockets := int(part["sockets"])
	if sockets > 0:
		t += "\n[color=#999]Chip sockets %d[/color]\n" % sockets
		for chip in part["chips"]:
			t += "[color=#bf66ff]▣ %s[/color]\n" % chip["name"]
			for s in chip["stats"]:
				t += "   %s\n" % ItemDB.format_line(s["key"], s["value"])
		for i in sockets - (part["chips"] as Array).size():
			t += "[color=#777]◇ empty[/color]\n"
	return t


func _chip_text(chip: Dictionary) -> String:
	var t := "[color=#bf66ff][b]▣ %s[/b][/color]\n" % chip["name"]
	t += "[color=#999]Chip · fits: %s%s[/color]\n\n" % [chip["slot"], "  · UNIQUE (one active)" if chip["unique"] else ""]
	for s in chip["stats"]:
		var v: float = s["value"]
		var col := GOOD if v >= 0.0 else BAD
		t += "[color=#%s]%s[/color]\n" % [col.to_html(false), ItemDB.format_line(s["key"], v)]
	t += "\n[color=#999]Insert: free · Remove: %d scrap (the chip comes back)[/color]\n" % chip["remove_cost"]
	return t


## Car totals change if this bag part replaced the equipped one in its slot.
func _compare_text(part: Dictionary) -> String:
	var eq := status.equipment
	var now := eq.totals
	var after := eq.totals_with(part)
	var keys := {}
	for k in now: keys[k] = true
	for k in after: keys[k] = true
	var t := "\n[color=#999]IF EQUIPPED (car total change)[/color]\n"
	var any := false
	for k in ItemDB.STATS:
		if not keys.has(k):
			continue
		var d: float = after.get(k, 0.0) - now.get(k, 0.0)
		if absf(d) < 0.01:
			continue
		any = true
		var col := GOOD if d > 0.0 else BAD
		t += "[color=#%s]%s[/color]\n" % [col.to_html(false), ItemDB.format_line(k, d)]
	if not any:
		t += "[color=#999]no change[/color]\n"
	return t


func _car_stats_text() -> String:
	var eq := status.equipment
	var car := status.get_parent() as CarController
	var t := ""
	t += "Top Speed  %d km/h  %s\n" % [roundi(car.top_speed * 3.6), _pct(eq.stat("top_speed"))]
	t += "Acceleration  %s\n" % _pct(eq.stat("accel"), true)
	t += "Grip  %s     Handling  %s\n" % [_pct(eq.stat("grip"), true), _pct(eq.stat("handling"), true)]
	t += "Max HP  %d\n" % roundi(status.health.max_hp)
	t += "Damage Reduction  %d%%     Knockback Resist  %d%%\n" % [roundi(eq.stat("armor")), roundi(eq.stat("kb_resist"))]
	t += "Field Repair  %.1f HP/s\n" % eq.stat("repair")
	t += "Damage  %s   Kinetic  %s   Explosive  %s\n" % [_pct(eq.stat("damage"), true), _pct(eq.stat("kinetic_dmg"), true), _pct(eq.stat("explosive_dmg"), true)]
	t += "Blast Radius  %s
" % _pct(eq.stat("blast_radius"), true)
	t += "Nitro Recharge  %s     Dash Power  %s" % [_pct(eq.stat("nitro_regen"), true), _pct(eq.stat("nitro_power"), true)]
	return t


func _pct(v: float, always: bool = false) -> String:
	if absf(v) < 0.01:
		return "+0%" if always else ""
	var col := GOOD if v > 0.0 else BAD
	return "[color=#%s]%s%d%%[/color]" % [col.to_html(false), "+" if v > 0.0 else "", roundi(v)]
