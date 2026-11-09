class_name DamageNumber
extends RefCounted
## Floating damage numbers (Ragnarok-style): a billboard Label3D pops up, rises and fades.
## Color shows how well the damage type works against the target's armor:
## - EFFECTIVE (multiplier > 1.05): big golden-orange number with a pop
## - normal: white
## - RESISTED (multiplier < 0.95): smaller, dimmer white

const COLOR_EFFECTIVE := Color(1.0, 0.68, 0.12)
const COLOR_NORMAL := Color(1.0, 1.0, 1.0)
const COLOR_RESISTED := Color(0.78, 0.78, 0.78)


## Floating text (e.g. "EVADE" when hitting a resetting enemy).
static func spawn_text(parent: Node, pos: Vector3, text: String, color: Color = Color(0.8, 0.8, 0.8)) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.012
	label.font_size = 48
	label.outline_size = 12
	label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	label.modulate = color
	label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(label)
	label.global_position = pos
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", pos + Vector3.UP * 1.2, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.3)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.4).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


static func spawn(parent: Node, pos: Vector3, amount: float, effectiveness: float = 1.0) -> void:
	var effective := DamageTypes.is_effective(effectiveness)
	var resisted := DamageTypes.is_resisted(effectiveness)

	var label := Label3D.new()
	label.text = str(roundi(amount))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.012
	label.font_size = 84 if effective else (50 if resisted else 64)
	label.outline_size = 16 if effective else 12
	label.outline_modulate = Color(0.25, 0.08, 0.0, 1.0) if effective else Color(0.0, 0.0, 0.0, 1.0)
	label.modulate = COLOR_EFFECTIVE if effective else (COLOR_RESISTED if resisted else COLOR_NORMAL)
	label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(label)

	var start := pos + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
	label.global_position = start
	var end := start + Vector3(randf_range(-0.3, 0.3), 1.8 if effective else 1.5, randf_range(-0.3, 0.3))

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", end, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if effective:
		# Pop: start big, settle to normal size.
		label.scale = Vector3.ONE * 1.6
		tween.tween_property(label, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.35)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.5).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)
