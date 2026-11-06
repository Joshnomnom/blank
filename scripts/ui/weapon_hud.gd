class_name WeaponHUD
extends Control
## Bottom-right weapon bar: one slot per gun, the current gun highlighted, Q / E hints,
## damage type tag, and a cooldown overlay + seconds left. Drawn with _draw (no assets).

var controller: WeaponController

const SLOT_SIZE := Vector2(190.0, 62.0)
const GAP := 10.0
const MARGIN := Vector2(24.0, 24.0)
const BG := Color(0.06, 0.06, 0.07, 0.75)
const BG_ACTIVE := Color(0.14, 0.12, 0.08, 0.9)
const BORDER_ACTIVE := Color(1.0, 0.75, 0.25)
const BORDER := Color(0.4, 0.4, 0.42, 0.8)
const TEXT := Color(1.0, 0.95, 0.85)
const TEXT_DIM := Color(0.7, 0.7, 0.7)
const COOLDOWN := Color(0.0, 0.0, 0.0, 0.6)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if controller == null:
		return
	var font := ThemeDB.fallback_font
	var count := controller.weapons.size()
	var screen := get_viewport_rect().size
	var total_w := count * SLOT_SIZE.x + (count - 1) * GAP
	var origin := Vector2(screen.x - MARGIN.x - total_w, screen.y - MARGIN.y - SLOT_SIZE.y)

	# Q / E hints at the ends.
	if count > 1:
		_draw_key(font, origin + Vector2(-34.0, SLOT_SIZE.y * 0.5 - 13.0), "Q")
		_draw_key(font, origin + Vector2(total_w + 8.0, SLOT_SIZE.y * 0.5 - 13.0), "E")

	for i in count:
		var w := controller.weapons[i]
		var pos := origin + Vector2(i * (SLOT_SIZE.x + GAP), 0.0)
		var rect := Rect2(pos, SLOT_SIZE)
		var active := i == controller.current
		draw_rect(rect, BG_ACTIVE if active else BG)

		# Cooldown overlay shrinking from right to left (only for slow guns; rapid-fire would flicker).
		var cd := controller.cooldown_ratio(i) if w.cooldown() > 0.3 else 0.0
		if cd > 0.0:
			draw_rect(Rect2(pos + Vector2(SLOT_SIZE.x * (1.0 - cd), 0.0), Vector2(SLOT_SIZE.x * cd, SLOT_SIZE.y)), COOLDOWN)
			var left := controller.cooldown_left(i)
			if left > 0.25:
				draw_string(font, pos + Vector2(SLOT_SIZE.x - 46.0, 24.0), "%.1fs" % left, HORIZONTAL_ALIGNMENT_RIGHT, 40.0, 15, TEXT_DIM)

		draw_rect(rect, BORDER_ACTIVE if active else BORDER, false, 3.0 if active else 1.5)
		draw_string(font, pos + Vector2(12.0, 26.0), w.display_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, SLOT_SIZE.x - 60.0, 17, TEXT if active else TEXT_DIM)
		var type_color: Color = DamageTypes.TYPE_COLORS[w.damage_type]
		draw_string(font, pos + Vector2(12.0, 48.0), DamageTypes.TYPE_NAMES[w.damage_type], HORIZONTAL_ALIGNMENT_LEFT, SLOT_SIZE.x - 20.0, 13, type_color)

		# Heat bar along the bottom of the slot (guns that can overheat).
		if w.heat_per_shot > 0.0:
			var h := controller.heat(i)
			var hot := controller.is_overheated(i)
			var bar := Rect2(pos + Vector2(4.0, SLOT_SIZE.y - 8.0), Vector2(SLOT_SIZE.x - 8.0, 4.0))
			draw_rect(bar, Color(0.0, 0.0, 0.0, 0.6))
			var hc := Color(1.0, 0.85, 0.5).lerp(Color(1.0, 0.2, 0.1), clampf((h - 0.4) / 0.6, 0.0, 1.0))
			if hot:
				hc = Color(1.0, 0.2, 0.1, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.018))
				draw_string(font, pos + Vector2(SLOT_SIZE.x - 96.0, 48.0), "OVERHEAT", HORIZONTAL_ALIGNMENT_RIGHT, 88.0, 13, hc)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * h, bar.size.y)), hc)

		# Swap progress bar under the active slot.
		if active and controller.swap_timer > 0.0:
			var p := 1.0 - controller.swap_timer / controller.swap_time
			draw_rect(Rect2(pos + Vector2(0.0, SLOT_SIZE.y + 3.0), Vector2(SLOT_SIZE.x * p, 4.0)), BORDER_ACTIVE)

	# Controls hint above the slots.
	draw_string(font, origin + Vector2(0.0, -10.0), "LMB fire  ·  Q/E swap  ·  ESC cursor", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, TEXT_DIM)


func _draw_key(font: Font, pos: Vector2, key: String) -> void:
	draw_rect(Rect2(pos, Vector2(26.0, 26.0)), BG)
	draw_rect(Rect2(pos, Vector2(26.0, 26.0)), BORDER, false, 1.5)
	draw_string(font, pos + Vector2(0.0, 19.0), key, HORIZONTAL_ALIGNMENT_CENTER, 26.0, 16, TEXT)
