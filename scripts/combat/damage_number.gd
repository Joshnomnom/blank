class_name DamageNumber
extends RefCounted
## Floating damage numbers (Ragnarok-style): a billboard Label3D pops up, rises and fades.

static func spawn(parent: Node, pos: Vector3, amount: float, color: Color = Color(1.0, 0.95, 0.6)) -> void:
	var label := Label3D.new()
	label.text = str(roundi(amount))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.012
	label.font_size = 64
	label.outline_size = 14
	label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	label.modulate = color
	label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(label)

	var start := pos + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
	label.global_position = start
	var end := start + Vector3(randf_range(-0.3, 0.3), 1.6, randf_range(-0.3, 0.3))

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", end, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)
