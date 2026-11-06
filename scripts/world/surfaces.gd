class_name Surfaces
extends RefCounted
## Ground surface table (Phase 1). Values are MULTIPLIERS / additions applied on top of the
## CarController exports, so the base car tuning stays the "road" feel.
## Research: docs/research/CAR_PHYSICS_RESEARCH.md §8.
##
## grip         × grip_turn (how fast travel follows the nose) and ½-strength × turn_rate
## top_speed    × top_speed (above it the car is slowed by overspeed_decel)
## accel        × accel_max
## rolling_drag  extra constant slowdown (m/s²) - the main "heavy sand" feel
## drift_angle  + degrees added to the target drift angle (loose surfaces slide wider)
## drift_loss   × drift_speed_loss
## dust_trail   0..1 dust kicked up by speed alone (no slip needed)
## dust_color   color of tire dust / smoke
## skid_index   which skid-mark color the shader uses (0 road, 1 dirt, 2 sand)
## squeal       0..1 how much the tire sound is a squeal (road) vs a scrub (sand)

const DATA := {
	&"road": {
		"grip": 1.0, "top_speed": 1.0, "accel": 1.0, "rolling_drag": 0.0,
		"drift_angle": 0.0, "drift_loss": 1.0, "dust_trail": 0.0,
		"dust_color": Color(0.8, 0.8, 0.8), "skid_index": 0.0, "squeal": 1.0,
	},
	&"dirt": {
		"grip": 0.8, "top_speed": 0.92, "accel": 0.92, "rolling_drag": 0.8,
		"drift_angle": 4.0, "drift_loss": 1.2, "dust_trail": 0.25,
		"dust_color": Color(0.62, 0.48, 0.34), "skid_index": 1.0, "squeal": 0.2,
	},
	&"sand": {
		"grip": 0.65, "top_speed": 0.78, "accel": 0.8, "rolling_drag": 2.0,
		"drift_angle": 7.0, "drift_loss": 1.5, "dust_trail": 0.45,
		"dust_color": Color(0.88, 0.78, 0.6), "skid_index": 2.0, "squeal": 0.0,
	},
}


static func get_data(surface: StringName) -> Dictionary:
	if DATA.has(surface):
		return DATA[surface]
	return DATA[&"road"]
