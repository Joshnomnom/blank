class_name Crosshair
extends Control
## Crosshair drawn at the mouse position (the OS cursor is hidden while aiming).
## - Aim-assist lock shows how well the CURRENT gun works vs the target's armor:
##   EFFECTIVE (golden orange) / normal lock (red) / RESISTED (grey).
## - RELOAD RING: while the gun is not ready (slow cooldown like rockets, or swapping),
##   the crosshair dims and a ring fills clockwise from the top; a pulse plays when ready.
## - HEAT GAUGE (machine gun): an arc on the right side fills white -> orange -> red.
##   When OVERHEATED: red flashing gauge + "OVERHEATED" text until it cools.

var locked: bool = false
var effectiveness: float = 1.0
var reload_ratio: float = 0.0   ## 0 = ready, 1 = just fired
var heat: float = 0.0           ## 0..1
var overheated: bool = false
var overheat_left: float = 0.0  ## seconds of overheat penalty left

const COLOR_FREE := Color(1.0, 1.0, 1.0, 0.9)
const COLOR_LOCKED := Color(1.0, 0.25, 0.2, 1.0)
const COLOR_EFFECTIVE := Color(1.0, 0.68, 0.12, 1.0)
const COLOR_RESISTED := Color(0.65, 0.65, 0.65, 1.0)
const COLOR_HOT := Color(1.0, 0.2, 0.1, 1.0)
const OUTLINE := Color(0.0, 0.0, 0.0, 0.6)

var _ready_pulse: float = 0.0
var _was_reloading: bool = false
var _time: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	var reloading := reload_ratio > 0.001
	if _was_reloading and not reloading:
		_ready_pulse = 0.25
	_was_reloading = reloading
	_ready_pulse = maxf(_ready_pulse - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var m := get_viewport().get_mouse_position()
	var font := ThemeDB.fallback_font

	var c := COLOR_FREE
	var label := ""
	if locked:
		c = COLOR_LOCKED
		if DamageTypes.is_effective(effectiveness):
			c = COLOR_EFFECTIVE
			label = "EFFECTIVE"
		elif DamageTypes.is_resisted(effectiveness):
			c = COLOR_RESISTED
			label = "RESISTED"

	var reloading := reload_ratio > 0.001
	var not_ready := reloading or overheated
	if not_ready:
		c.a *= 0.4  # dim while the gun can't fire

	# --- Main crosshair ---
	var r := 10.0 if locked else 13.0
	draw_arc(m, r, 0.0, TAU, 32, OUTLINE, 4.0)
	draw_arc(m, r, 0.0, TAU, 32, c, 2.0)
	draw_circle(m, 2.0, c)
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(m + d * (r + 3.0), m + d * (r + 9.0), c, 2.0)

	# --- Reload ring (fills clockwise from the top) ---
	var ring_r := r + 15.0
	if reloading:
		var progress := 1.0 - reload_ratio
		draw_arc(m, ring_r, 0.0, TAU, 48, Color(0.0, 0.0, 0.0, 0.45), 5.0)
		if progress > 0.0:
			draw_arc(m, ring_r, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(1.0, 1.0, 1.0, 0.9), 3.0)
	if _ready_pulse > 0.0:
		var t := 1.0 - _ready_pulse / 0.25
		draw_arc(m, ring_r + t * 10.0, 0.0, TAU, 48, Color(1.0, 0.85, 0.4, 1.0 - t), 3.0)

	# --- Heat gauge (right side arc, bottom -> top) ---
	if heat > 0.01 or overheated:
		var heat_r := r + 24.0
		var start := PI * 0.35            # lower right
		var span := -PI * 0.7             # sweep up to upper right
		draw_arc(m, heat_r, start, start + span, 24, Color(0.0, 0.0, 0.0, 0.45), 6.0)
		var hc := Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.6, 0.1), clampf(heat * 1.6, 0.0, 1.0))
		hc = hc.lerp(COLOR_HOT, clampf((heat - 0.6) / 0.4, 0.0, 1.0))
		if overheated:
			hc = COLOR_HOT
			hc.a = 0.55 + 0.45 * sin(_time * 18.0)
		if heat > 0.0:
			draw_arc(m, heat_r, start, start + span * heat, 24, hc, 4.0)

	# --- Text under the crosshair ---
	var text := label
	var text_color := c
	if overheated:
		text = "OVERHEATED %.1fs" % overheat_left
		text_color = COLOR_HOT
		text_color.a = 0.6 + 0.4 * sin(_time * 18.0)
	if text != "":
		text_color.a = maxf(text_color.a, 0.6)
		var pos := m + Vector2(-70.0, ring_r + 24.0)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 14, 4, Color(0.0, 0.0, 0.0, 0.8))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 14, text_color)
