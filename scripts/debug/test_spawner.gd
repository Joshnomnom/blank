class_name TestSpawner
extends Node
## Tester tools (Phase 3). Keys:
##   1 Scrap Drone · 2 Raider Gunner · 3 Iron Hauler · 4 Dune Tyrant (boss)
##     -> spawned instantly at the crosshair aim point (15–70 m from the car).
##        Tester enemies have no camp: they don't respawn.
##   5 respawn every dead camp member now (also the boss)
##   K kill all enemies (they drop loot)
##   G god mode (no damage) · H heal to full

const SPAWN_KEYS := {
	&"debug_spawn_1": &"scrap_drone",
	&"debug_spawn_2": &"raider_gunner",
	&"debug_spawn_3": &"iron_hauler",
	&"debug_spawn_4": &"dune_tyrant",
}


func _unhandled_input(event: InputEvent) -> void:
	for action in SPAWN_KEYS:
		if event.is_action_pressed(action):
			_spawn(SPAWN_KEYS[action])
			return
	if event.is_action_pressed("debug_respawn_camps"):
		for camp in get_tree().get_nodes_in_group("spawn_camps"):
			camp.call("debug_respawn_now")
		_toast("Camps respawned")
	elif event.is_action_pressed("debug_kill_all"):
		for e in get_tree().get_nodes_in_group("enemies"):
			e.call("debug_kill")
		_toast("Killed all enemies")
	elif event.is_action_pressed("debug_god"):
		var status := _status()
		if status:
			status.god_mode = not status.god_mode
			_toast("God mode %s" % ("ON" if status.god_mode else "OFF"))
	elif event.is_action_pressed("debug_heal"):
		var status := _status()
		if status:
			status.heal_full()
			_toast("Healed")


func _spawn(id: StringName) -> void:
	var car := get_tree().get_first_node_in_group("player") as CarController
	if car == null:
		return
	var weapons := car.get_node_or_null("Weapons") as WeaponController
	var pos := weapons.aim_point if weapons else car.global_position - car.global_basis.z * 30.0
	var offset := pos - car.global_position
	offset.y = 0.0
	if offset.length() < 1.0:
		offset = -car.global_basis.z
	pos = car.global_position + offset.normalized() * clampf(offset.length(), 15.0, 70.0)
	var from := pos + Vector3.UP * 60.0
	var hit := car.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 120.0, Layers.GROUND))
	if not hit.is_empty():
		pos.y = (hit["position"] as Vector3).y
	var data := EnemyData.make(id)
	var enemy := Enemy.create(data, pos, null, 12.0)
	get_tree().current_scene.add_child(enemy)
	_toast("Spawned %s" % data.display_name)


func _status() -> PlayerStatus:
	var car := get_tree().get_first_node_in_group("player") as CarController
	return car.status if car else null


func _toast(text: String) -> void:
	var status := _status()
	if status:
		status.toast(text, Color(0.6, 0.85, 1.0))
