class_name PlayerHUD
extends Control
## Player HUD (drawn with _draw, no assets):
## - bottom-left: HP bar + numbers, scrap and item counters, GOD MODE tag
## - loot / info toasts stacked above the HP bar (fade out)
## - red screen flash when taking damage
## - DESTROYED overlay with respawn countdown
## - top-center BOSS BAR when a boss (group "bosses") is fighting

var status: PlayerStatus

const BAR_SIZE := Vector2(320.0, 24.0)
const MARGIN := Vector2(24.0, 24.0)
const TEXT := Color(1.0, 0.95, 0.85)
const HP_COLOR := Color(0.25, 0.85, 0.35)
const HP_LOW := Color(0.95, 0.25, 0.15)

var _flash: float = 0.0
var _toasts: Array = []  # untyped on purpose: Array.filter() returns an untyped Array


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func flash_damage(strength: float) -> void:
	_flash = maxf(_flash, strength)


func toast(text: String, color: Color) -> void:
	_toasts.append({"text": text, "color": color, "time": 3.0})
	if _toasts.size() > 6:
		_toasts.pop_front()


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 2.5, 0.0)
	for t in _toasts:
		t["time"] -= delta
	_toasts = _toasts.filter(func(t): return t["time"] > 0.0)
	queue_redraw()


func _draw() -> void:
	if status == null:
		return
	var font := ThemeDB.fallback_font
	var screen := get_viewport_rect().size

	# Damage flash.
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.8, 0.0, 0.0, 0.28 * _flash))

	# HP bar.
	var origin := Vector2(MARGIN.x, screen.y - MARGIN.y - BAR_SIZE.y)
	var ratio := status.health.ratio()
	draw_rect(Rect2(origin - Vector2(3, 3), BAR_SIZE + Vector2(6, 6)), Color(0.0, 0.0, 0.0, 0.7))
	var hp_color := HP_LOW.lerp(HP_COLOR, clampf((ratio - 0.15) / 0.5, 0.0, 1.0))
	draw_rect(Rect2(origin, Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)), hp_color)
	var hp_text := "HP  %d / %d" % [ceili(status.health.hp), roundi(status.health.max_hp)]
	draw_string_outline(font, origin + Vector2(10.0, 18.0), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, 4, Color.BLACK)
	draw_string(font, origin + Vector2(10.0, 18.0), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, TEXT)

	# Inventory counters + god mode tag.
	var inv := "SCRAP %d    PARTS %d" % [status.scrap, status.items.size()]
	if status.god_mode:
		inv += "    [GOD MODE]"
	draw_string_outline(font, origin + Vector2(0.0, -12.0), inv, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, 4, Color.BLACK)
	draw_string(font, origin + Vector2(0.0, -12.0), inv, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.95, 0.85, 0.55))

	# Toasts (newest at the bottom).
	var y := origin.y - 40.0
	for i in range(_toasts.size() - 1, -1, -1):
		var t: Dictionary = _toasts[i]
		var c: Color = t["color"]
		c.a = clampf(t["time"] / 0.6, 0.0, 1.0)
		draw_string_outline(font, Vector2(origin.x, y), t["text"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, 5, Color(0.0, 0.0, 0.0, c.a))
		draw_string(font, Vector2(origin.x, y), t["text"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, c)
		y -= 24.0

	# Boss bar.
	for boss in get_tree().get_nodes_in_group("bosses"):
		if boss.call("is_in_combat"):
			_draw_boss_bar(font, screen, boss)
			break

	# Destroyed overlay.
	if status.is_dead_waiting():
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.0, 0.0, 0.0, 0.45))
		var center := screen * 0.5
		draw_string_outline(font, center + Vector2(-300.0, -10.0), "DESTROYED", HORIZONTAL_ALIGNMENT_CENTER, 600.0, 56, 10, Color.BLACK)
		draw_string(font, center + Vector2(-300.0, -10.0), "DESTROYED", HORIZONTAL_ALIGNMENT_CENTER, 600.0, 56, Color(1.0, 0.3, 0.2))
		var t2 := "Respawning in %.1f" % status.respawn_time_left()
		draw_string(font, center + Vector2(-300.0, 34.0), t2, HORIZONTAL_ALIGNMENT_CENTER, 600.0, 22, TEXT)


func _draw_boss_bar(font: Font, screen: Vector2, boss: Node) -> void:
	var size := Vector2(520.0, 18.0)
	var pos := Vector2((screen.x - size.x) * 0.5, 34.0)
	var r: float = boss.call("hp_ratio")
	draw_rect(Rect2(pos - Vector2(3, 3), size + Vector2(6, 6)), Color(0.0, 0.0, 0.0, 0.75))
	draw_rect(Rect2(pos, Vector2(size.x * r, size.y)), Color(0.85, 0.15, 0.1))
	var title: String = boss.call("get_display_name")
	draw_string_outline(font, pos + Vector2(0.0, -8.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, 5, Color.BLACK)
	draw_string(font, pos + Vector2(0.0, -8.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1.0, 0.8, 0.4))
