extends Node3D
## Phase 1: terrain test area (400 × 400 m, walled). No enemies, nothing to fight - only
## different ground to tune driving on. Layout (top view, north = -Z):
##
##   NW: big hill + high dunes      NE: packed DIRT area with 3 kicker ramps + 1 tabletop
##   ------------- east-west ROAD at z = -40 ----------------------------------------
##   SW: rolling sand dunes         SE: gentle hill, asphalt SKIDPAD (r 32 m) + spur road
##                    START PAD (asphalt) at (0, 150), main north-south ROAD at x = 0
##
## Surfaces (see scripts/world/surfaces.gd): road / dirt / sand. The car asks this node
## which surface it is on via get_surface(pos) (node is in group "surface_map").
## Roads, start pad, skidpad and dirt are flat painted overlays on flattened terrain -
## no collision steps. Terrain: heightmap mesh (noise dunes + gaussian hills), flattened
## near roads/dirt/walls, trimesh collision. Ramps: convex collision shapes.

@export var half_size: float = 200.0
@export var cell_size: float = 2.5
@export var noise_seed: int = 11
## Dune height in the west half (meters, noise amplitude).
@export var dune_amplitude: float = 5.0
## Gentle ground undulation elsewhere on sand.
@export var gentle_amplitude: float = 1.2
@export var wall_height: float = 2.5
@export var wall_thickness: float = 1.5

const ROAD_SHADER := """
shader_type spatial;

uniform vec3 asphalt : source_color = vec3(0.22, 0.22, 0.23);
uniform vec3 paint : source_color = vec3(0.95, 0.9, 0.75);
uniform float road_length = 100.0;
uniform float road_width = 12.0;
uniform bool along_x = false;
uniform bool center_line = true;

void fragment() {
	float across = along_x ? UV.y : UV.x;
	float along = (along_x ? UV.x : UV.y) * road_length;
	float from_center = abs(across - 0.5) * road_width;
	float edge = step(road_width * 0.5 - 0.6, from_center) * step(from_center, road_width * 0.5 - 0.35);
	float dash = 0.0;
	if (center_line) {
		dash = step(from_center, 0.12) * step(0.5, fract(along / 6.0));
	}
	ALBEDO = mix(asphalt, paint, max(edge, dash));
	ROUGHNESS = 0.8;
}
"""

const DIRT_BASE := Color(0.58, 0.44, 0.31)
const DIRT_LINE := Color(0.48, 0.35, 0.24)

# Layout in the XZ plane (Rect2 uses x = world X, y = world Z).
var _start_rect := Rect2(-15.0, 135.0, 30.0, 30.0)
var _roads: Array[Rect2] = [
	Rect2(-6.0, -175.0, 12.0, 310.0),    # north-south main road, z -175..135
	Rect2(-175.0, -46.0, 350.0, 12.0),   # east-west road, centered z = -40
	Rect2(6.0, 84.0, 44.0, 12.0),        # spur road to the skidpad
]
var _skidpad_center := Vector2(80.0, 90.0)
var _skidpad_radius := 32.0
var _dirt_rect := Rect2(40.0, -170.0, 140.0, 105.0)  # x 40..180, z -170..-65

var _noise := FastNoiseLite.new()


func _enter_tree() -> void:
	add_to_group("surface_map")


func _ready() -> void:
	_noise.seed = noise_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.012
	_noise.fractal_octaves = 2

	WorldBuilder.add_environment(self)
	WorldBuilder.add_sun(self)
	_build_terrain()
	_build_overlays()
	_build_ramps()
	_spawn_targets()
	WorldBuilder.add_outer_ground(self)
	WorldBuilder.add_walls(self, half_size * 2.0, wall_height, wall_thickness)
	WorldBuilder.add_wall_poles(self, half_size * 2.0, wall_height, wall_thickness, 10.0)
	WorldBuilder.add_landmarks(self, half_size, 7)


## Surface under a world position: &"road", &"dirt" or &"sand".
func get_surface(pos: Vector3) -> StringName:
	var p := Vector2(pos.x, pos.z)
	if _start_rect.has_point(p):
		return &"road"
	for r in _roads:
		if r.has_point(p):
			return &"road"
	if p.distance_to(_skidpad_center) <= _skidpad_radius:
		return &"road"
	if _dirt_rect.has_point(p):
		return &"dirt"
	return &"sand"


# --------------------------------------------------------------------------
# Terrain heights
# --------------------------------------------------------------------------

func _height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	# Dunes get taller toward the west.
	var amp := lerpf(gentle_amplitude, dune_amplitude, smoothstep(10.0, 40.0, -x))
	# Noise remapped to 0..1 so dunes only rise above 0 (never dip below the outer ground plane).
	var h := clampf(_noise.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0) * amp
	# Big hill in the north-west, gentle hill in the south-east.
	h += 14.0 * exp(-p.distance_squared_to(Vector2(-110.0, -110.0)) / (2.0 * 28.0 * 28.0))
	h += 8.0 * exp(-p.distance_squared_to(Vector2(130.0, 15.0)) / (2.0 * 22.0 * 22.0))
	return h * _flat_mask(p)


func _flat_mask(p: Vector2) -> float:
	# 0 on/near roads, dirt, skidpad, start pad and walls; 1 in open sand.
	var d := _rect_distance(_start_rect, p)
	for r in _roads:
		d = minf(d, _rect_distance(r, p))
	d = minf(d, maxf(p.distance_to(_skidpad_center) - _skidpad_radius, 0.0))
	d = minf(d, _rect_distance(_dirt_rect, p))
	var mask := smoothstep(4.0, 22.0, d)
	var to_wall := half_size - maxf(absf(p.x), absf(p.y))
	mask *= smoothstep(4.0, 20.0, to_wall)
	return mask


func _rect_distance(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dy).length()


# --------------------------------------------------------------------------
# Terrain mesh + collision
# --------------------------------------------------------------------------

func _build_terrain() -> void:
	var cells := int(round(half_size * 2.0 / cell_size))
	var verts := cells + 1

	var heights := PackedFloat32Array()
	heights.resize(verts * verts)
	for j in verts:
		var z := -half_size + j * cell_size
		for i in verts:
			var x := -half_size + i * cell_size
			heights[j * verts + i] = _height(x, z)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in verts:
		var z := -half_size + j * cell_size
		for i in verts:
			var x := -half_size + i * cell_size
			# Normal from neighbor heights (independent of triangle winding).
			var hl := heights[j * verts + maxi(i - 1, 0)]
			var hr := heights[j * verts + mini(i + 1, verts - 1)]
			var hd := heights[maxi(j - 1, 0) * verts + i]
			var hu := heights[mini(j + 1, verts - 1) * verts + i]
			st.set_normal(Vector3(hl - hr, 2.0 * cell_size, hd - hu).normalized())
			st.add_vertex(Vector3(x, heights[j * verts + i], z))

	for j in cells:
		for i in cells:
			var a := j * verts + i
			var b := a + 1
			var c := a + verts
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)

	var mesh := st.commit()

	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.collision_layer = 2  # ground layer: wheel rays only, the car body ignores it
	add_child(body)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = WorldBuilder.make_ground_material(WorldBuilder.SAND_BASE, WorldBuilder.SAND_LINE, 10.0)
	body.add_child(mi)

	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true  # safe regardless of triangle winding
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)


# --------------------------------------------------------------------------
# Painted overlays (visual only - the surface comes from get_surface())
# --------------------------------------------------------------------------

func _build_overlays() -> void:
	_add_road_overlay(_start_rect, 0.03, false)
	_add_road_overlay(_roads[0], 0.04, true)
	_add_road_overlay(_roads[1], 0.045, true)
	_add_road_overlay(_roads[2], 0.045, true)

	# Skidpad: asphalt disc.
	var disc := CylinderMesh.new()
	disc.top_radius = _skidpad_radius
	disc.bottom_radius = _skidpad_radius
	disc.height = 0.04
	disc.radial_segments = 48
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.24, 0.24, 0.25)
	asphalt.roughness = 0.8
	var disc_mi := MeshInstance3D.new()
	disc_mi.mesh = disc
	disc_mi.material_override = asphalt
	disc_mi.position = Vector3(_skidpad_center.x, 0.02, _skidpad_center.y)
	add_child(disc_mi)

	# Dirt area: brown ground with its own grid.
	var dirt_plane := PlaneMesh.new()
	dirt_plane.size = _dirt_rect.size
	var dirt_mi := MeshInstance3D.new()
	dirt_mi.mesh = dirt_plane
	dirt_mi.material_override = WorldBuilder.make_ground_material(DIRT_BASE, DIRT_LINE, 10.0)
	var c := _dirt_rect.get_center()
	dirt_mi.position = Vector3(c.x, 0.03, c.y)
	add_child(dirt_mi)


func _add_road_overlay(rect: Rect2, y: float, center_line: bool) -> void:
	var plane := PlaneMesh.new()
	plane.size = rect.size
	var shader := Shader.new()
	shader.code = ROAD_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var along_x := rect.size.x > rect.size.y
	mat.set_shader_parameter("along_x", along_x)
	mat.set_shader_parameter("road_length", maxf(rect.size.x, rect.size.y))
	mat.set_shader_parameter("road_width", minf(rect.size.x, rect.size.y))
	mat.set_shader_parameter("center_line", center_line)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	var c := rect.get_center()
	mi.position = Vector3(c.x, y, c.y)
	add_child(mi)


# --------------------------------------------------------------------------
# Training targets (Phase 2): a small "shooting range" around the start
# --------------------------------------------------------------------------

func _spawn_targets() -> void:
	# [x, z, max_hp]. Placed off the roads, on sand near the start pad.
	var targets := [
		[-25.0, 115.0, 300.0],
		[25.0, 112.0, 300.0],
		[-35.0, 85.0, 300.0],
		[30.0, 70.0, 300.0],
		[-20.0, 55.0, 300.0],
		[-60.0, 125.0, 2000.0],  # tanky one, for testing sustained fire
	]
	for t in targets:
		var dummy := TargetDummy.new()
		dummy.max_hp = t[2]
		if t[2] > 1000.0:
			dummy.body_color = Color(0.35, 0.4, 0.5)
		add_child(dummy)
		dummy.position = Vector3(t[0], _height(t[0], t[1]), t[1])


# --------------------------------------------------------------------------
# Ramps (in the dirt area, rising toward the north / -Z)
# --------------------------------------------------------------------------

func _build_ramps() -> void:
	_add_kicker(Vector3(70.0, 0.0, -95.0), 6.0, 8.0, 1.2)     # small
	_add_kicker(Vector3(100.0, 0.0, -95.0), 6.0, 10.0, 2.2)   # medium
	_add_kicker(Vector3(130.0, 0.0, -95.0), 8.0, 14.0, 3.5)   # big
	_add_tabletop(Vector3(165.0, 0.0, -115.0), 8.0, 10.0, 12.0, 10.0, 2.5)


func _add_kicker(pos: Vector3, width: float, length: float, height: float) -> void:
	var hw := width * 0.5
	var hl := length * 0.5
	var a := Vector3(-hw, 0.0, hl)
	var b := Vector3(hw, 0.0, hl)
	var c := Vector3(-hw, height, -hl)
	var d := Vector3(hw, height, -hl)
	var e := Vector3(-hw, 0.0, -hl)
	var f := Vector3(hw, 0.0, -hl)
	var faces: Array[PackedVector3Array] = [
		PackedVector3Array([a, b, d, c]),  # slope
		PackedVector3Array([c, d, f, e]),  # back drop
		PackedVector3Array([a, c, e]),     # left side
		PackedVector3Array([b, f, d]),     # right side
		PackedVector3Array([a, e, f, b]),  # bottom
	]
	_add_solid(pos, faces, PackedVector3Array([a, b, c, d, e, f]))


func _add_tabletop(pos: Vector3, width: float, up_len: float, top_len: float, down_len: float, height: float) -> void:
	var hw := width * 0.5
	var total := up_len + top_len + down_len
	var zf := total * 0.5            # front (start of up slope)
	var zs := zf - up_len            # start of top
	var ze := zs - top_len           # end of top
	var zb := -total * 0.5           # back (end of down slope)
	var p0 := Vector3(-hw, 0.0, zf)
	var p1 := Vector3(hw, 0.0, zf)
	var p2 := Vector3(-hw, height, zs)
	var p3 := Vector3(hw, height, zs)
	var p4 := Vector3(-hw, height, ze)
	var p5 := Vector3(hw, height, ze)
	var p6 := Vector3(-hw, 0.0, zb)
	var p7 := Vector3(hw, 0.0, zb)
	var faces: Array[PackedVector3Array] = [
		PackedVector3Array([p0, p1, p3, p2]),      # up slope
		PackedVector3Array([p2, p3, p5, p4]),      # top
		PackedVector3Array([p4, p5, p7, p6]),      # down slope
		PackedVector3Array([p0, p2, p4, p6]),      # left side
		PackedVector3Array([p1, p7, p5, p3]),      # right side
		PackedVector3Array([p0, p6, p7, p1]),      # bottom
	]
	_add_solid(pos, faces, PackedVector3Array([p0, p1, p2, p3, p4, p5, p6, p7]))


func _add_solid(pos: Vector3, faces: Array[PackedVector3Array], hull: PackedVector3Array) -> void:
	# Centroid, used to point every face normal outward.
	var centroid := Vector3.ZERO
	for v in hull:
		centroid += v
	centroid /= float(hull.size())

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var normal := (face[1] - face[0]).cross(face[2] - face[0]).normalized()
		var face_center := Vector3.ZERO
		for v in face:
			face_center += v
		face_center /= float(face.size())
		if normal.dot(face_center - centroid) < 0.0:
			normal = -normal
		for k in range(1, face.size() - 1):
			for v in [face[0], face[k], face[k + 1]]:
				st.set_normal(normal)
				st.add_vertex(v)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.52, 0.42)
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 3  # layer 1 (body hits the back faces) + layer 2 (rays drive on it)
	add_child(body)

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	body.add_child(mi)

	var shape := ConvexPolygonShape3D.new()
	shape.points = hull
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
