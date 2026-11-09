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
## EXP bar: displayed fill animates toward the real value (wraps through 100% on level-up).
var _exp_shown: float = 0.0
var _shown_level: int = 1
var _level_banner: float = 0.0
var _banner_level: int = 1
var _toasts: Array = []  # untyped on purpose: Array.filter() returns an untyped Array


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_level_up(new_level: int) -> void:
	_level_banner = 2.6
	_banner_level = new_level


func flash_damage(strength: float) -> void:
	_flash = maxf(_flash, strength)


func toast(text: String, color: Color) -> void:
	_toasts.append({"text": text, "color": color, "time": 3.0})
	if _toasts.size() > 6:
		_toasts.pop_front()


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 2.5, 0.0)
	_level_banner = maxf(_level_banner - delta, 0.0)
	if status:
		var target := float(status.exp_points) / float(status.exp_to_next())
		if _shown_level < status.level:
			# Fill to the end first, then wrap to 0 for the new level.
			_exp_shown = move_toward(_exp_shown, 1.0, delta * 2.0)
			if _exp_shown >= 1.0:
				_shown_level = status.level
				_exp_shown = 0.0
		else:
			_shown_level = status.level
			_exp_shown = lerpf(_exp_shown, target, 1.0 - exp(-6.0 * delta))
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

	_draw_nitro(font, origin + Vector2(BAR_SIZE.x + 16.0, 4.0))

	# Inventory counters + god mode tag.
	var inv := "SCRAP %d    BAG %d  [I]" % [status.scrap, status.items.size()]
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

	_draw_exp_bar(font, screen)

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


## Thin full-width EXP bar at the very bottom + "Lv N · x / y EXP (z%)", and the LEVEL UP banner.
func _draw_exp_bar(font: Font, screen: Vector2) -> void:
	var h := 7.0
	var y := screen.y - h
	draw_rect(Rect2(0.0, y - 1.0, screen.x, h + 1.0), Color(0.0, 0.0, 0.0, 0.75))
	draw_rect(Rect2(0.0, y, screen.x * clampf(_exp_shown, 0.0, 1.0), h), Color(0.45, 0.8, 1.0))
	for i in range(1, 10):  # 10% ticks
		var x := screen.x * i / 10.0
		draw_line(Vector2(x, y), Vector2(x, y + h), Color(0.0, 0.0, 0.0, 0.5), 1.0)
	var need := status.exp_to_next()
	var t := "Lv %d    %d / %d EXP  (%.1f%%)" % [status.level, status.exp_points, need, 100.0 * status.exp_points / float(need)]
	var pos := Vector2(screen.x * 0.5 - 200.0, y - 6.0)
	draw_string_outline(font, pos, t, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 14, 4, Color.BLACK)
	draw_string(font, pos, t, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 14, Color(0.7, 0.9, 1.0))

	if _level_banner > 0.0:
		var a := clampf(_level_banner / 0.6, 0.0, 1.0)
		var pop := 1.0 + 0.25 * clampf((_level_banner - 2.3) / 0.3, 0.0, 1.0)
		var size := int(54.0 * pop)
		var center := Vector2(screen.x * 0.5 - 300.0, screen.y * 0.28)
		var gold := Color(1.0, 0.8, 0.25, a)
		draw_string_outline(font, center, "LEVEL UP", HORIZONTAL_ALIGNMENT_CENTER, 600.0, size, 10, Color(0.0, 0.0, 0.0, a))
		draw_string(font, center, "LEVEL UP", HORIZONTAL_ALIGNMENT_CENTER, 600.0, size, gold)
		var sub := "Level %d  ·  car fully repaired" % _banner_level
		draw_string_outline(font, center + Vector2(0.0, 36.0), sub, HORIZONTAL_ALIGNMENT_CENTER, 600.0, 22, 6, Color(0.0, 0.0, 0.0, a))
		draw_string(font, center + Vector2(0.0, 36.0), sub, HORIZONTAL_ALIGNMENT_CENTER, 600.0, 22, Color(1.0, 0.95, 0.85, a))


## Nitro meter right of the HP bar: blue fill, tick marks per dash, white flash on dash.
func _draw_nitro(font: Font, pos: Vector2) -> void:
	var car := status.get_parent() as CarController
	if car == null or car.nitro == null:
		return
	var n := car.nitro
	var size := Vector2(170.0, 16.0)
	draw_rect(Rect2(pos - Vector2(3, 3), size + Vector2(6, 6)), Color(0.0, 0.0, 0.0, 0.7))
	var ratio := n.nitro / n.max_nitro
	var has_charge := n.charges() > 0
	var fill := Color(0.3, 0.65, 1.0) if has_charge else Color(0.2, 0.35, 0.55)
	fill = fill.lerp(Color.WHITE, n.flame * 0.6)
	draw_rect(Rect2(pos, Vector2(size.x * ratio, size.y)), fill)
	# Tick at every dash cost.
	var c := n.dash_cost
	while c < n.max_nitro:
		var x := pos.x + size.x * c / n.max_nitro
		draw_line(Vector2(x, pos.y), Vector2(x, pos.y + size.y), Color(0.0, 0.0, 0.0, 0.8), 2.0)
		c += n.dash_cost
	var label := "NITRO x%d  [Shift]" % n.charges()
	draw_string_outline(font, pos + Vector2(6.0, 13.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, 4, Color.BLACK)
	draw_string(font, pos + Vector2(6.0, 13.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, TEXT)


func _draw_boss_bar(font: Font, screen: Vector2, boss: Node) -> void:
	var size := Vector2(520.0, 18.0)
	var pos := Vector2((screen.x - size.x) * 0.5, 34.0)
	var r: float = boss.call("hp_ratio")
	draw_rect(Rect2(pos - Vector2(3, 3), size + Vector2(6, 6)), Color(0.0, 0.0, 0.0, 0.75))
	draw_rect(Rect2(pos, Vector2(size.x * r, size.y)), Color(0.85, 0.15, 0.1))
	var title: String = boss.call("get_display_name")
	draw_string_outline(font, pos + Vector2(0.0, -8.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, 5, Color.BLACK)
	draw_string(font, pos + Vector2(0.0, -8.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1.0, 0.8, 0.4))
