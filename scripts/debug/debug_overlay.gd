extends CanvasLayer
## Simple text readout for tuning the driving feel. F3 toggles it.

@export var car_path: NodePath

var _car: CarController
var _label: Label


func _ready() -> void:
	_car = get_node_or_null(car_path) as CarController

	_label = Label.new()
	_label.position = Vector2(16.0, 16.0)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible


func _process(_delta: float) -> void:
	if _car == null:
		_label.text = "No car assigned"
		return

	var drift_text := "no"
	if _car.is_drifting:
		drift_text = "YES %s  %.1fs" % ["LEFT" if _car.drift_dir > 0 else "RIGHT", _car.drift_time]

	_label.text = "\n".join([
		"FPS: %d" % Engine.get_frames_per_second(),
		"Speed: %d km/h" % roundi(_car.get_speed_kmh()),
		"Drifting: %s" % drift_text,
		"Drift angle: %d°" % roundi(rad_to_deg(absf(_car.drift_angle))),
		"Tire slip: %d%%" % roundi(_car.tire_slip * 100.0),
		"Surface: %s   %s" % [_car.current_surface, "ground" if _car.on_ground else "AIR %.1fs" % _car.air_time],
		"",
		"W / S   - throttle / brake + reverse",
		"A / D   - steer",
		"Drift   - Space + steer, OR tap S + steer,",
		"          OR full steer + throttle at high speed",
		"          hold W to keep drifting, steer to set the angle,",
		"          counter-steer or release W to exit",
		"R       - reset car",
		"M       - mute sound",
		"Wheel   - camera zoom",
		"F3      - hide this panel",
	])
