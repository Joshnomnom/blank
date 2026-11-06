class_name Crosshair
extends Control
## Crosshair drawn at the mouse position (the OS cursor is hidden while aiming).
## Turns red when the aim assist has locked onto a target.

var locked: bool = false

const COLOR_FREE := Color(1.0, 1.0, 1.0, 0.9)
const COLOR_LOCKED := Color(1.0, 0.25, 0.2, 1.0)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var m := get_viewport().get_mouse_position()
	var c := COLOR_LOCKED if locked else COLOR_FREE
	var r := 10.0 if locked else 13.0
	var outline := Color(0.0, 0.0, 0.0, 0.6)
	draw_arc(m, r, 0.0, TAU, 32, outline, 4.0)
	draw_arc(m, r, 0.0, TAU, 32, c, 2.0)
	draw_circle(m, 2.0, c)
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(m + d * (r + 3.0), m + d * (r + 9.0), c, 2.0)
