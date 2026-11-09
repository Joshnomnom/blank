class_name SpawnCamp
extends Node3D
## A camp / pack of enemies around this node's position. Research: docs/research/ENEMY_SPAWNING_AI.md §1.
## - members: one enemy id per slot (mix types for "leader + followers" packs).
## - Each slot has its OWN respawn timer: random [respawn_min, respawn_max] × dynamic factor
##   (more players nearby -> up to 2× faster; pack nearly cleared -> ×0.7), never below
##   respawn_floor.
## - Never spawns within min_player_distance of the player (retries every second).
## - Assist: when one member is first attacked, members with the assist flag within
##   assist_radius join after a short random delay (0.2–0.6 s).
## - Boss camps (show_gravestone): a gravestone with name, time of death and a respawn
##   countdown stands where the boss died until it respawns (Ragnarok MVP style).
## Must be a child of a world-aligned node (enemies are added to the same parent).

@export var members: Array[StringName] = [&"scrap_drone"]
@export var radius: float = 15.0
@export var respawn_min: float = 20.0
@export var respawn_max: float = 40.0
@export var respawn_floor: float = 8.0
@export var min_player_distance: float = 30.0
@export var assist_radius: float = 25.0
@export var crowd_players: float = 4.0
@export var show_gravestone: bool = false

var _slots: Array = []   # [{ "id": StringName, "enemy": Enemy, "timer": float }]
var _gravestone: Node3D
var _grave_label: Label3D
var _grave_text: String = ""


func _ready() -> void:
	add_to_group("spawn_camps")
	for id in members:
		_slots.append({"id": id, "enemy": null, "timer": randf_range(0.0, 0.5)})


func _physics_process(delta: float) -> void:
	for slot in _slots:
		if slot["enemy"] != null:
			continue
		slot["timer"] -= delta
		if slot["timer"] <= 0.0:
			if _player_too_close():
				slot["timer"] = 1.0
			else:
				_spawn(slot)


func _process(_delta: float) -> void:
	if _gravestone and _gravestone.visible:
		var left := 0.0
		for slot in _slots:
			left = maxf(left, slot["timer"])
		_grave_label.text = "%s\nRespawn in %d:%02d" % [_grave_text, int(left) / 60, int(left) % 60]


## Respawn every dead member now (tester key).
func debug_respawn_now() -> void:
	for slot in _slots:
		if slot["enemy"] == null:
			_spawn(slot)


func on_member_died(enemy: Enemy) -> void:
	for slot in _slots:
		if slot["enemy"] == enemy:
			slot["enemy"] = null
			slot["timer"] = _respawn_time()
			if show_gravestone:
				_show_gravestone(enemy)


func on_member_attacked(enemy: Enemy) -> void:
	for slot in _slots:
		var other: Enemy = slot["enemy"]
		if other == null or other == enemy or not other.is_alive():
			continue
		if other.global_position.distance_to(enemy.global_position) <= assist_radius:
			var p := enemy.target
			get_tree().create_timer(randf_range(0.2, 0.6)).timeout.connect(_delayed_assist.bind(other, p))


func _delayed_assist(other: Enemy, p: CarController) -> void:
	if is_instance_valid(other) and is_instance_valid(p):
		other.assist_join(p)


func _respawn_time() -> float:
	var base := randf_range(respawn_min, respawn_max)
	var players := 0
	for p in get_tree().get_nodes_in_group("player"):
		if (p as Node3D).global_position.distance_to(global_position) < radius + 150.0:
			players += 1
	var factor := lerpf(1.0, 0.5, clampf(float(players) / crowd_players, 0.0, 1.0))
	var alive := 0
	for slot in _slots:
		if slot["enemy"] != null:
			alive += 1
	if _slots.size() > 1 and alive <= 1:
		factor *= 0.7
	return maxf(base * factor, respawn_floor)


func _player_too_close() -> bool:
	for p in get_tree().get_nodes_in_group("player"):
		if (p as Node3D).global_position.distance_to(global_position) < min_player_distance + radius:
			return true
	return false


func _spawn(slot: Dictionary) -> void:
	var a := randf() * TAU
	var r := sqrt(randf()) * radius * 0.6
	var pos := global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
	pos.y = _ground_height(pos)
	var enemy := Enemy.create(EnemyData.make(slot["id"]), pos, self, maxf(radius, 6.0))
	get_parent().add_child(enemy)
	slot["enemy"] = enemy
	slot["timer"] = 0.0
	if _gravestone:
		_gravestone.visible = false


func _ground_height(pos: Vector3) -> float:
	var from := pos + Vector3.UP * 60.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 120.0, Layers.GROUND)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else pos.y


func _show_gravestone(enemy: Enemy) -> void:
	if _gravestone == null:
		_gravestone = Node3D.new()
		get_parent().add_child(_gravestone)
		var stone_mat := StandardMaterial3D.new()
		stone_mat.albedo_color = Color(0.45, 0.43, 0.42)
		var stone := BoxMesh.new()
		stone.size = Vector3(1.4, 2.0, 0.4)
		var mi := MeshInstance3D.new()
		mi.mesh = stone
		mi.material_override = stone_mat
		mi.position = Vector3(0.0, 1.0, 0.0)
		_gravestone.add_child(mi)
		var cross := BoxMesh.new()
		cross.size = Vector3(1.8, 0.3, 0.42)
		var cmi := MeshInstance3D.new()
		cmi.mesh = cross
		cmi.material_override = stone_mat
		cmi.position = Vector3(0.0, 1.6, 0.0)
		_gravestone.add_child(cmi)
		_grave_label = Label3D.new()
		_grave_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_grave_label.pixel_size = 0.008
		_grave_label.font_size = 40
		_grave_label.outline_size = 10
		_grave_label.modulate = Color(1.0, 0.85, 0.5)
		_grave_label.position = Vector3(0.0, 3.2, 0.0)
		_gravestone.add_child(_grave_label)
	_grave_text = "%s\nDestroyed at %s" % [enemy.get_display_name(), Time.get_time_string_from_system()]
	_gravestone.global_position = enemy.global_position
	_gravestone.visible = true
