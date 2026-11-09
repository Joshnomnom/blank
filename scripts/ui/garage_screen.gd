class_name GarageScreen
extends Control
## Phase 4 step 2: GARAGE screen (opened at a GarageZone with F; F or ESC closes).
## Tabs:
##   LOADOUT  - which owned guns sit in the chassis' gun slots (Q/E order). >= 1 gun mounted.
##   TUNING   - +1..+10 on guns and parts (equipped or in the bag). Safe up to +4, then a
##              success chance; failure = −1 level; at +8 and up a failed PART can BREAK.
##   BODY KIT - paint + front / rear / roof / side pieces. Visual only. Buy once, switch freely.
## Data + rules live in Equipment / ItemDB / SedanModel; this is only the UI.

signal closed

const BG := Color(0.07, 0.07, 0.08, 0.95)
const PANEL := Color(0.12, 0.12, 0.14, 1.0)
const ACCENT := Color(0.85, 0.6, 0.25)
const TEXT := Color(0.92, 0.9, 0.85)
const DIM := Color(0.6, 0.6, 0.6)
const GOOD := Color(0.4, 0.95, 0.4)
const BAD := Color(1.0, 0.4, 0.35)
const KIT_LABELS := {"paint": "Paint", "front": "Front", "rear": "Rear", "roof": "Roof", "side": "Side"}

var status: PlayerStatus
var _tab: String = "loadout"
var _sel: Variant = null          # loadout: gun uid · tuning: item uid · kits: category
var _last_result: String = ""
var _last_color: Color = TEXT

var _scrap_label: Label
var _tab_box: HBoxContainer
var _list: VBoxContainer
var _details: RichTextLabel
var _actions: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func open(p_status: PlayerStatus) -> void:
	if status != p_status:
		status = p_status
		status.equipment.changed.connect(_refresh)
	visible = true
	_sel = null
	_last_result = ""
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("interact") or event.is_action_pressed("toggle_cursor")):
		close()
		get_viewport().set_input_as_handled()


# --- Build -------------------------------------------------------------------

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
	frame.add_theme_stylebox_override("panel", _box(BG, ACCENT, 2, 14))
	center.add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	frame.add_child(outer)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	outer.add_child(head)
	head.add_child(_label("GARAGE", 24, ACCENT))
	_tab_box = HBoxContainer.new()
	_tab_box.add_theme_constant_override("separation", 6)
	head.add_child(_tab_box)
	_scrap_label = _label("", 18, Color(0.95, 0.85, 0.55))
	head.add_child(_scrap_label)
	outer.add_child(_label("Temporary garage zone  ·  F or ESC: close", 13, DIM))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	outer.add_child(cols)

	var left := _panel(cols, Vector2(380.0, 500.0))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380.0, 500.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	var right := _panel(cols, Vector2(440.0, 500.0))
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.custom_minimum_size = Vector2(440.0, 300.0)
	_details.add_theme_font_size_override("normal_font_size", 15)
	_details.add_theme_color_override("default_color", TEXT)
	right.add_child(_details)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 4)
	right.add_child(_actions)


func _panel(parent: Control, size: Vector2) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(PANEL, Color(0.25, 0.25, 0.28), 1, 10))
	p.custom_minimum_size = size + Vector2(20.0, 20.0)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
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


func _button(text: String, color: Color, selected: bool, callback: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.clip_text = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0.0, 34.0)
	b.add_theme_font_size_override("font_size", 15)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, color)
	var border := ACCENT if selected else Color(0.3, 0.3, 0.33)
	b.add_theme_stylebox_override("normal", _box(Color(0.16, 0.16, 0.18), border, 2 if selected else 1, 6))
	b.add_theme_stylebox_override("hover", _box(Color(0.22, 0.22, 0.25), border, 2 if selected else 1, 6))
	b.add_theme_stylebox_override("pressed", _box(Color(0.22, 0.22, 0.25), ACCENT, 2, 6))
	b.pressed.connect(callback)
	return b


func _section(text: String) -> void:
	_list.add_child(_label(text, 13, DIM))


# --- Refresh -----------------------------------------------------------------

func _refresh() -> void:
	if not visible or status == null:
		return
	_scrap_label.text = "SCRAP %d" % status.scrap
	for c in _tab_box.get_children():
		c.queue_free()
	for t in [["loadout", "LOADOUT"], ["tuning", "TUNING"], ["kits", "BODY KIT"]]:
		var b := _button(t[1], ACCENT if _tab == t[0] else TEXT, _tab == t[0], _set_tab.bind(t[0]))
		b.custom_minimum_size = Vector2(120.0, 34.0)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tab_box.add_child(b)
	for c in _list.get_children():
		c.queue_free()
	for c in _actions.get_children():
		c.queue_free()
	match _tab:
		"loadout": _refresh_loadout()
		"tuning": _refresh_tuning()
		"kits": _refresh_kits()


func _set_tab(tab: String) -> void:
	_tab = tab
	_sel = null
	_last_result = ""
	_refresh()


func _select(value: Variant) -> void:
	_sel = value
	_last_result = ""
	_refresh()


func _action(text: String, callback: Callable, enabled: bool = true) -> void:
	_actions.add_child(_button(text, TEXT, false, callback, enabled))


# --- LOADOUT -----------------------------------------------------------------

func _refresh_loadout() -> void:
	var eq := status.equipment
	_section("GUN SLOTS  (Q / E swap order)")
	for i in eq.gun_slots:
		var uid: int = eq.mounted[i]
		var gun := eq.get_gun(uid)
		var text := "Slot %d:  %s" % [i + 1, gun["name"] if not gun.is_empty() else "(empty)"]
		_list.add_child(_button(text, TEXT if not gun.is_empty() else DIM, _sel is int and _sel == uid and uid != -1, _select.bind(uid)))
	_section("OWNED GUNS")
	for gun in eq.guns:
		var where := eq.mounted.find(gun["uid"])
		var tag := ("  [slot %d]" % (where + 1)) if where >= 0 else ""
		_list.add_child(_button(gun["name"] + tag, Loot.RARITY_COLORS[gun["rarity"]], _sel is int and _sel == gun["uid"], _select.bind(gun["uid"])))

	var sel_gun := eq.get_gun(_sel if _sel is int else -1)
	if sel_gun.is_empty():
		_details.text = "[color=#999]Select a gun.\n\nThe sedan has %d gun slots. Q / E swaps between mounted guns in slot order. New guns will come from loot and shops later.[/color]" % eq.gun_slots
		return
	var w := ItemDB.gun_weapon_data(sel_gun)
	var t := "[b]%s[/b]\n[color=#999]%s damage[/color]\n\n" % [sel_gun["name"], DamageTypes.TYPE_NAMES[w.damage_type]]
	t += "Damage  %d%s\n" % [roundi(w.damage), "  (+%d%% tuning)" % roundi(ItemDB.TUNE_GUN_PER_LEVEL * 100.0 * ItemDB.tune_level(sel_gun)) if ItemDB.tune_level(sel_gun) > 0 else ""]
	t += "Fire rate  %.2f / s\n" % w.fire_rate
	if w.explosion_radius > 0.0:
		t += "Explosion radius  %.1f m\n" % w.explosion_radius
	if w.heat_per_shot > 0.0:
		t += "Overheats after %d shots\n" % ceili(1.0 / w.heat_per_shot)
	_details.text = t
	var mounted_at := eq.mounted.find(sel_gun["uid"])
	for i in eq.gun_slots:
		if i == mounted_at:
			continue
		var verb := "Move to" if mounted_at >= 0 else "Mount in"
		_action("%s slot %d" % [verb, i + 1], eq.mount_gun.bind(sel_gun["uid"], i))
	if mounted_at >= 0:
		_action("Unmount" if eq.mounted_count() > 1 else "Unmount (need at least 1 gun)", eq.unmount_gun.bind(mounted_at), eq.mounted_count() > 1)


# --- TUNING ------------------------------------------------------------------

func _refresh_tuning() -> void:
	var eq := status.equipment
	var sel: Dictionary = {}
	var section := ""
	for item in eq.tunables():
		var s := "GUNS" if item["kind"] == "gun" else ("EQUIPPED PARTS" if eq.is_equipped(item) else "BAG PARTS")
		if s != section:
			section = s
			_section(s)
		var is_sel: bool = _sel is int and _sel == item["uid"]
		if is_sel:
			sel = item
		_list.add_child(_button(item["name"], Loot.RARITY_COLORS[item["rarity"]], is_sel, _select.bind(item["uid"])))

	var t := ""
	if sel.is_empty():
		t = "[color=#999]Select a gun or part to tune.\n\nTuning +1..+10 costs scrap. Up to +4 always works. Above that each try can fail (lose 1 level). From +8, a failed PART can BREAK (it's destroyed; its chips go back to the bag).[/color]"
	else:
		var level := ItemDB.tune_level(sel)
		t = "[b]%s[/b]\n" % sel["name"]
		t += "[color=#999]Tuning level +%d / +%d[/color]\n\n" % [level, ItemDB.TUNE_MAX]
		if sel["kind"] == "gun":
			t += "Damage bonus  +%d%%" % roundi(ItemDB.TUNE_GUN_PER_LEVEL * 100.0 * level)
			if level < ItemDB.TUNE_MAX:
				t += "  →  [color=#66ff66]+%d%%[/color]" % roundi(ItemDB.TUNE_GUN_PER_LEVEL * 100.0 * (level + 1))
			t += "\n"
		else:
			var now: Dictionary = ItemDB.part_lines(sel, false)[0]
			t += "%s" % ItemDB.format_line(now["key"], now["value"])
			if level < ItemDB.TUNE_MAX:
				var base := float(sel["main"]["value"])
				var next := base * (1.0 + ItemDB.TUNE_MAIN_PER_LEVEL * (level + 1))
				t += "  →  [color=#66ff66]%s[/color]" % ItemDB.format_line(now["key"], next)
			t += "\n"
		if level < ItemDB.TUNE_MAX:
			var chance := ItemDB.tune_chance(sel)
			var cost := ItemDB.tune_cost(sel)
			var col := GOOD if chance >= 1.0 else (Color(1.0, 0.8, 0.3) if chance >= 0.5 else BAD)
			t += "\nSuccess chance  [color=#%s]%d%%[/color]\n" % [col.to_html(false), roundi(chance * 100.0)]
			t += "Cost  %d scrap\n" % cost
			if chance < 1.0:
				t += "[color=#ff9966]Fail: drops to +%d[/color]\n" % maxi(level - 1, 0)
			if ItemDB.can_break(sel):
				t += "[color=#ff5544][b]Fail can BREAK this part (%d%% of fails)[/b][/color]\n" % roundi(ItemDB.TUNE_BREAK_CHANCE * 100.0)
			_action("TUNE  +%d → +%d   (%d scrap)" % [level, level + 1, cost], _do_tune.bind(sel), status.scrap >= cost)
		else:
			t += "\n[color=#ffb347]MAX TUNED[/color]\n"
	if _last_result != "":
		t += "\n[color=#%s][b]%s[/b][/color]" % [_last_color.to_html(false), _last_result]
	_details.text = t


func _do_tune(item: Dictionary) -> void:
	var before := ItemDB.tune_level(item)
	var name_before: String = item.get("base_name", item["name"])
	var result := status.equipment.tune(item)
	match result:
		"success":
			_last_result = "SUCCESS!  +%d" % (before + 1)
			_last_color = Color(1.0, 0.75, 0.2)
		"fail":
			_last_result = "FAILED  → +%d" % ItemDB.tune_level(item)
			_last_color = BAD
		"broken":
			_last_result = "BROKEN!  %s was destroyed." % name_before
			_last_color = Color(1.0, 0.2, 0.15)
			_sel = null
		_:
			return
	status.toast(_last_result, _last_color)
	_refresh()


# --- BODY KITS ---------------------------------------------------------------

func _refresh_kits() -> void:
	var eq := status.equipment
	if not (_sel is String):
		_sel = "paint"
	_section("PARTS OF THE CAR")
	for category in SedanModel.KITS:
		var current: String = SedanModel.KITS[category][eq.kits[category]][0]
		_list.add_child(_button("%s:  %s" % [KIT_LABELS[category], current], TEXT, _sel == category, _select.bind(category)))

	var category: String = _sel
	var options: Array = SedanModel.KITS[category]
	var t := "[b]%s[/b]\n[color=#999]Looks only, no stats. Buy once, then switch for free.[/color]\n" % KIT_LABELS[category]
	if _last_result != "":
		t += "\n[color=#%s]%s[/color]" % [_last_color.to_html(false), _last_result]
	_details.text = t
	for i in options.size():
		var opt_name: String = options[i][0]
		var cost: int = options[i][1]
		var equipped_now: bool = eq.kits[category] == i
		var tag := "EQUIPPED" if equipped_now else ("owned" if eq.kit_owned(category, i) else "%d scrap" % cost)
		var b := _button("%s   —   %s" % [opt_name, tag], ACCENT if equipped_now else TEXT, equipped_now,
			_do_kit.bind(category, i), equipped_now or eq.kit_owned(category, i) or status.scrap >= cost)
		if category == "paint":
			var swatch := ColorRect.new()
			swatch.color = SedanModel.PAINT_COLORS[i]
			swatch.custom_minimum_size = Vector2(22.0, 22.0)
			swatch.position = Vector2(390.0, 6.0)
			swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(swatch)
		_actions.add_child(b)


func _do_kit(category: String, index: int) -> void:
	if status.equipment.set_kit(category, index):
		_last_result = ""
	else:
		_last_result = "Not enough scrap"
		_last_color = BAD
		_refresh()
