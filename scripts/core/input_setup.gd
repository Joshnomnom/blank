extends Node
## Registers the game's input actions at startup (keyboard + gamepad).
## Kept in code so bindings are easy to read and change in one place.

const DEADZONE := 0.2


func _ready() -> void:
	_add_action("accelerate", [KEY_W, KEY_UP], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_add_action("brake", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_add_action("steer_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_add_action("steer_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_add_action("handbrake", [KEY_SPACE], [JOY_BUTTON_A], [])
	_add_action("reset_car", [KEY_R], [JOY_BUTTON_BACK], [])
	_add_action("toggle_debug", [KEY_F3], [], [])
	_add_action("toggle_mute", [KEY_M], [], [])


func _add_action(action: StringName, keys: Array, buttons: Array, axes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, DEADZONE)

	for key in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event(action, key_event)

	for button in buttons:
		var button_event := InputEventJoypadButton.new()
		button_event.button_index = button
		InputMap.action_add_event(action, button_event)

	for axis in axes:
		var axis_event := InputEventJoypadMotion.new()
		axis_event.axis = axis[0]
		axis_event.axis_value = axis[1]
		InputMap.action_add_event(action, axis_event)
