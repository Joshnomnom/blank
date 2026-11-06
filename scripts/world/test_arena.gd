extends Node3D
## Phase 0 test arena: flat sand-looking ground with a grid, enclosed by four walls.
## No surface map here, so the car uses its default surface ("road" grip).
## Speed references (non-colliding): striped walls, flag poles on the walls, distant landmarks.
## Shared building code lives in world_builder.gd.

@export var arena_size: float = 200.0
@export var wall_height: float = 2.5
@export var wall_thickness: float = 1.5
@export var grid_cell: float = 10.0
@export var pole_spacing: float = 10.0
@export var landmark_seed: int = 7


func _ready() -> void:
	WorldBuilder.add_environment(self)
	WorldBuilder.add_sun(self)
	_build_ground()
	WorldBuilder.add_outer_ground(self)
	WorldBuilder.add_walls(self, arena_size, wall_height, wall_thickness)
	WorldBuilder.add_wall_poles(self, arena_size, wall_height, wall_thickness, pole_spacing)
	WorldBuilder.add_landmarks(self, arena_size * 0.5 + 100.0, landmark_seed)


func _build_ground() -> void:
	var size := arena_size + wall_thickness * 2.0 + 20.0

	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 2  # ground layer: wheel rays only, the car body ignores it
	add_child(body)

	var shape := BoxShape3D.new()
	shape.size = Vector3(size, 2.0, size)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, -1.0, 0.0)
	body.add_child(collision)

	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = WorldBuilder.make_ground_material(WorldBuilder.SAND_BASE, WorldBuilder.SAND_LINE, grid_cell)
	body.add_child(mesh)
