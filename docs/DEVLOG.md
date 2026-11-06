# Dev Log

Running record of what we've built, decided, and what's next.
**Read "Current Status" first when resuming work.** New sessions go at the top of the log, newest first.

Related docs: [GAME_DESIGN.md](GAME_DESIGN.md) (overall plan) · [research/](research/) (all research notes).

---

## Current Status

| | |
|---|---|
| **Phase** | **2: combat basics** (step 1: one gun). Phases 0 (driving) and 1 (terrain) are done and accepted. |
| **State** | **Phase 2 step 1 (one gun) is done and accepted** ("it's good now, feels okay"): mouse-aimed roof turret, machine gun, aim assist, target dummies with HP bars, damage numbers. Sound is deferred (backlog). |
| **Git** | Repo: https://github.com/Joshnomnom/blank (branch `main`). Commit 1 `e1b2348` = Phase 0 + Phase 1. Commit 2 = Phase 2 step 1. **Rule: commit + push after the user accepts a step.** |
| **Next** | User tests shooting. Then the next combat steps, one at a time: gun skill + cooldown → a 2nd gun + Q/E swap → enemies that move/fight back (Phase 3). |
| **Main scene** | `scenes/terrain_test.tscn` (new). The old flat arena `scenes/test_drive.tscn` still works (car uses "road" grip there). |
| **After that** | Phase 2, combat basics (one weapon, a dummy target). The car model is planned around Phase 2–3, when weapon mounts need a real shape. |
| **Research** | [research/CAR_PHYSICS_RESEARCH.md](research/CAR_PHYSICS_RESEARCH.md) (physics math; §8 surfaces) · [research/DRIVING_GAME_FEEL.md](research/DRIVING_GAME_FEEL.md) (game feel, Driving v2 design) · [research/VEHICLE_GROUND_PHYSICS.md](research/VEHICLE_GROUND_PHYSICS.md) (ground-following approaches, pitfalls, our bug, decision to keep kinematic + rays) |
| **Physics layers** | **Layer 1 = solid** (walls, ramps; the car body collides). **Layer 2 = ground** (terrain, flat ground; only wheel rays touch it). Ramps = 1+2. The car body `collision_mask = 1`, the rays use `ground_probe_mask = 3`. **New ground/static objects must follow this.** |

### Things most likely to need fixing or tuning in Phase 1 (check first)
- **New ground system** (raycast suspension, never run): watch for jitter on dunes (2.5 m mesh facets), the car leaving the ground too easily or too rarely over crests (`launch_factor`), or the box hitting steep ground (it's raised 0.4 m).
- **Jumps**: gravity is now 22 in the air. Launch speed comes from the ground's vertical speed at the lip. Tune with `gravity`, `launch_factor`, `air_pitch_follow`, `air_align_speed`.
- **Sand feel**: sand is slower (top speed ×0.78, drag 2 m/s²) and slidier (grip ×0.65). It might feel too sluggish. Tune in `surfaces.gd`.
- **The camera can clip into dunes** when the car is in a dip behind a crest (no camera collision yet).
- **Terrain generation time**: about 26k height samples in GDScript at load, so expect a short pause on start (more on web).

### How to run
1. Open the project in Godot 4.7.2 (Project Manager → Import → `project.godot`).
2. Press **F5**. The main scene is `scenes/terrain_test.tscn`. To use the old flat arena, open `scenes/test_drive.tscn` and press F6.

### Controls
| Key | Gamepad | Action |
|---|---|---|
| W / ↑ | Right trigger | Throttle (**hold to keep a drift going**) |
| S / ↓ | Left trigger | Brake, then reverse. **A quick tap + steer starts a drift.** |
| A, D / ←, → | Left stick | Steer. In a drift: into the corner = wider angle, counter-steer = straighten/exit. In the air: small yaw control. |
| Space | A | Handbrake (+ steer at speed = drift) |
| Mouse | | Aim the roof turret (crosshair turns red when aim assist locks a target) |
| LMB (hold) | | Fire machine gun |
| ESC | | Show/hide the mouse cursor (firing is disabled while the cursor is shown) |
| R | Back | Reset car to spawn |
| M | | Mute / unmute sound |
| Mouse wheel | | Camera zoom |
| F3 | | Toggle debug panel (shows surface and ground/air) |

### Terrain test area map (400 × 400 m, north = −Z, start at the south)
```
              N (-Z)
  +--------------------------------------+
  | NW: big hill (14 m)   |  NE: DIRT area     |
  |     + high dunes      |  kickers S/M/L at z=-95  |
  |                       |  (x=70/100/130), tabletop x=165 |
  |====== east-west ROAD (z = -40) ===========|
  | SW: rolling sand dunes| SE: gentle hill (8 m),|
  |                       |  asphalt SKIDPAD r=32 at (80,90) |
  |          main N-S ROAD (x=0) ---- spur road --> skidpad |
  |              START PAD (0,150)            |
  +--------------------------------------+
              S (+Z)
```
Ramps rise toward the north. Approach them driving north from the east-west road.

---

## Project Structure

```
project.godot              Godot config (Compatibility renderer, physics interpolation on, main = terrain_test)
export_presets.cfg         Web export preset (single-threaded) → build/web/index.html
.gitignore                 ignores .godot/ and build/
CLAUDE.md                  working rules for Claude sessions (incl. the mandatory DOCUMENTATION RULE)
docs/
  GAME_DESIGN.md           overall game plan and roadmap
  DEVLOG.md                this file
  research/
    CAR_PHYSICS_RESEARCH.md  car physics math, models, tuning values, upgrade plan
    DRIVING_GAME_FEEL.md     game feel: diagnosis of v1, drift controller, juice, Driving v2 plan
scenes/
  terrain_test.tscn        MAIN scene (Phase 1): Terrain + Sedan (spawn 0,0.3,150) + ChaseCamera + DebugOverlay
  test_drive.tscn          Phase 0 flat arena: Arena + Sedan + ChaseCamera + DebugOverlay
  vehicles/sedan.tscn      CharacterBody3D (CarController) + box collision + Model + Effects + Audio + Weapons
scripts/
  core/input_setup.gd          autoload "InputSetup": registers all input actions in code
  vehicles/car_controller.gd   class CarController: arcade driving (grip + drift-angle controller) + terrain
  vehicles/sedan_model.gd      class SedanModel: placeholder mesh, wheel spin/steer, body lean, brake lights
  vehicles/car_effects.gd      tire dust/smoke (surface colored, dust trail on loose ground) + drives skid marks
  vehicles/skid_marks.gd       class SkidMarks: fading skid marks (MultiMesh ring buffer + shader, color per surface)
  vehicles/car_audio.gd        synthesized engine / tire scrub / road squeal / wind (AudioStreamGenerator)
  camera/chase_camera.gd       class ChaseCamera: third-person chase, continuous drift/speed effects, impact shake
  combat/weapon_controller.gd  class WeaponController ("Weapons" node on the car): mouse aim, aim assist, firing, HUD
  combat/weapon_data.gd        class WeaponData (Resource): gun stats (+ planned skill fields); make_machine_gun()
  combat/turret.gd             class Turret: roof turret mesh, yaw/pitch toward the aim point, recoil, muzzle flash
  combat/projectiles.gd        class Projectiles: data-driven bullets (segment raycasts), MultiMesh tracers, impact sparks/dust
  combat/health.gd             class Health: reusable HP component (damaged / died signals)
  combat/target_dummy.gd       class TargetDummy: training target (HP bar shader, hit flash, death burst, respawn)
  combat/damage_number.gd      class DamageNumber: floating Label3D damage numbers
  ui/crosshair.gd              class Crosshair: crosshair drawn at the mouse (red when locked)
  world/surfaces.gd            class Surfaces: road / dirt / sand property table
  world/world_builder.gd       class WorldBuilder: shared static helpers (sky, sun, fog, grid material, walls, poles, landmarks)
  world/terrain_test.gd        Phase 1 terrain area: heightmap dunes and hills, roads, skidpad, dirt, ramps, surface map
  world/test_arena.gd          Phase 0 flat arena (uses WorldBuilder)
  debug/debug_overlay.gd       on-screen speed / drift / angle / slip / surface / air / FPS + controls help
```

### Conventions so far
- **GDScript only.** C# web export is limited.
- **Compatibility renderer**, so the editor matches the web build. **Avoid StandardMaterial3D vertex colors on particles** (they rendered black); use small custom shaders.
- Placeholder art, sound and worlds are **built in code**, so there are no asset files yet.
- **Input actions are registered in code** (`input_setup.gd`), not in Project Settings.
- Gameplay values are `@export` variables so they can be tuned in the Inspector. Surface values live in `surfaces.gd`.
- Godot axes: the car faces **−Z**, up is +Y, and a positive yaw turns left.
- Node order in `sedan.tscn` matters: Model must come before Effects (Effects reads Model in `_ready`).
- **Surface lookup is by math, not colliders.** A world node in group `"surface_map"` implements `get_surface(pos) -> StringName`. Painted areas have no collision, so there are no ledges.

---

## How Systems Work

### Car controller (`scripts/vehicles/car_controller.gd`)
The car is a `CharacterBody3D` with fully custom movement. It tracks **two directions**:
- **heading**: where the nose points (the node's yaw)
- **travel_dir**: where the car moves (a flat unit vector)
- **drift_angle** = the signed angle from `travel_dir` to the nose (positive = nose left of travel)

`speed` is signed (negative = reversing; when reversing, travel_dir = heading).

**Ground system (raycast suspension; replaced the `is_on_floor` approach in feedback round 4):**
- `motion_mode = FLOATING`: `move_and_slide()` only handles walls and obstacles. The collision box (1.8 × 0.8 × 4.4) is centered at y 0.8, so its **bottom is 0.4 m above the wheels**. **The body's `collision_mask` = 1 (solid only), so it never collides with the ground layer (2).** Only the rays touch the ground.
- `_probe_ground()`: **4 rays, one per wheel** (±0.86 m sideways, ±1.35 m along, using the flat heading), from 1.5 m above, 5 m down, mask `ground_probe_mask` 3, excluding the car. Ground height = average contact y. Ground normal = **plane through the 4 contacts** when all hit, otherwise the average hit normal.
- **On the ground**: `global_position.y` = ground height every tick, so the car sits exactly on its wheels with no floating. The ground's vertical speed is tracked and smoothed (rate 15, which filters mesh facets).
- **Take-off**: if the ground's vertical acceleration < −`gravity` × `launch_factor` (the ground falls away faster than gravity can follow, e.g. ramp lips and sharp crests) **and speed > 3 m/s**, or no ray hits, the car launches with the ground's last vertical speed, so ramps throw it upward.
- **In the air**: `vertical_speed −= gravity (22) × dt`, horizontal motion kept, small yaw control. The body turns toward the flight path (`air_pitch_follow` 0.6, `air_align_speed` 3), **clamped to ±25° and scaled by speed/8 m/s**, so slow or straight-down falls stay level.
- **Landing**: when the car's y ≤ ground + **0.05** while falling, or whenever it's below the ground, it lands. Calls `model.on_landed(fall)` (visual suspension dip). Landing faster than 7 m/s → `landed` + `impacted` (camera shake).
- **Body tilt** (`_align_body`): up vector slerps to the ground normal at `ground_align_speed` 12.

**Each physics tick:**
1. **Input**: steering moves toward the input at `steer_in_speed` (5/s), and recenters or flips faster at `steer_out_speed` (9/s).
2. **Surface** (`_update_surface`): asks the surface map for the surface under the car (only when on the ground) and blends the multipliers from `Surfaces` at `surface_blend_speed` 6. Without a surface map, `default_surface` ("road") is used.
3. **Brake-tap detection.** A brake press ≤ 0.3 s opens a 0.4 s window where steering starts a drift.
4. **Burnout.** Slamming the throttle below 3 m/s on the ground starts a 0.6 s burnout: `burnout_amount`, a tail wiggle, and fast rear wheel spin.
5. **On the ground:**
   - **Speed**: top = `top_speed` 42 × surface top. Accel = `accel_max` 11 × surface accel × lerp(1, 0.25, ratio^1.6); ×0.6 while drifting. Brake 25, coast 2, reverse 12 m/s, handbrake drag 7. **Above the surface's top speed** (road → sand) it slows at `overspeed_decel` 10 m/s². Surface `rolling_drag` is always applied.
   - **Slope**: `speed += slope_gravity(9) × (floor normal's horizontal part · travel_dir) × dt`, so downhill speeds up and uphill slows.
   - **Grip mode**: target yaw = steer × turn_rate 2.2 × lerp(1, surface grip, 0.5) × low-speed factor × high-speed factor (0.45 at top). Yaw inertia (`yaw_response_grip` 8). travel_dir rotates toward the heading at `grip_turn` 10 × surface grip, keeping speed. Exit blend 0.3 s after drifts, ×0.25 with the handbrake.
   - **Drift entry** (speed ≥ 11 and |steer| ≥ 0.3): handbrake, brake-tap + |steer| > 0.5, or power-over (|steer| > 0.85, throttle > 0.9, speed > 70% of the surface top) held **0.5 s**. On entry, a smooth **kick** of `drift_kick_deg` **8°** eased over 0.25 s (smoothstep); yaw rate is kept.
   - **Drift mode**: target angle = neutral **25°**, into the corner up to **40°** (+**3°** throttle, + surface `drift_angle`: dirt +4, sand +7), counter-steer down to 0°, +8° handbrake. Path bends at `drift_turn_rate` **1.35** rad/s × (0.5 + 0.5 × steer_rel). The nose follows target error × 5, with yaw response 3. Speed loss 3 m/s² × surface `drift_loss` × (1 − 0.7 × throttle). Spin clamp 70°. Exit (after 0.25 s) at angle < 8°, everything released, brake > 0.5, speed < 7 m/s, or a hard wall hit; grip blends back over 0.3 s.
6. **In the air**: no grip and no speed change; travel_dir and speed are kept. Small yaw control (`air_steer_rate` 1.2 rad/s). `air_time` counts up.
7. **tire_slip** (0..1, zero in the air): drift angle × speed, leftover slide, handbrake 0.7, hard braking 0.45, burnout.
8. **Move**: velocity = horizontal travel_dir × speed (+ vertical_speed in the air) → `move_and_slide()`. **Walls** (normal.y < 0.7): speed and travel_dir come from the slid velocity (only the into-wall part is lost); a loss > 4 m/s emits `impacted`; > 6 m/s ends a drift.
9. **Ground update** (rays: follow, take off or land; see above), then **body tilt**.

**Public state:** `speed, travel_dir, steer_input, throttle_input, brake_input, handbrake_input, yaw_rate, is_drifting, drift_dir, drift_angle, drift_time, burnout_amount, tire_slip, on_ground, air_time, vertical_speed, current_surface`, plus `get_speed_kmh()` and `reset_to_spawn()`.
**Signals:** `drift_started(direction)`, `drift_ended(duration)`, `impacted(strength)`, `landed(fall_speed)`.

### Surfaces (`scripts/world/surfaces.gd`)
| | grip | top speed | accel | rolling drag | drift angle | drift loss | dust trail | squeal |
|---|---|---|---|---|---|---|---|---|
| **road** | 1.0 | 1.0 | 1.0 | 0 | +0° | ×1.0 | 0 | 1.0 |
| **dirt** | 0.8 | 0.92 | 0.92 | 0.8 | +4° | ×1.2 | 0.25 | 0.2 |
| **sand** | 0.65 | 0.78 | 0.8 | 2.0 | +7° | ×1.5 | 0.45 | 0 |
Also: dust colour (road light grey, dirt brown, sand tan) and skid colour index (0/1/2).

### Sedan model (`scripts/vehicles/sedan_model.gd`)
- Placeholder sedan of 1.8 × 4.4 m. Yellow headlights at the front (−Z), red taillights at the back. It tilts with the car body on slopes.
- Interface: `update_visuals(car: CarController, delta)` and `get_rear_wheel_ground_points() -> Array[Vector3]`.
- **Wheel spin:** the fronts turn at road speed. The rears are locked with the handbrake, road + 45 rad/s × burnout, road × 1.5 + 8 in a drift with throttle.
- **Front wheel steer:** follows input; **in a drift they point along travel_dir** (counter-steer look).
- **Body lean:** roll from yaw_rate × speed + 0.05 rad extra in drifts; pitch from acceleration.
- **Brake lights:** emission 1 → 5 when braking or using the handbrake.
- **Visual landing suspension** (no gameplay effect): `on_landed(fall)` gives the body a downward velocity (fall × 0.12, capped). A damped spring (stiffness 140, damping 14, ≈1.9 Hz, ζ≈0.6) settles it. Body y offset clamped ±0.18 m.

### Effects (`car_effects.gd` + `skid_marks.gd`)
- **Dust/smoke:** one `CPUParticles3D` per rear wheel with a custom billboard shader (`SMOKE_SHADER`): color from the `dust_color` uniform (set per surface), procedural circle, alpha = particle color alpha × lifetime fade. **Intensity = max(tire_slip, surface dust_trail × speed factor)**: loose surfaces kick up dust from about 6 m/s, full at about 26 m/s, even without sliding.
- **Skid marks:** `SkidMarks` (a top-level `MultiMeshInstance3D`, one draw call). A 0.26 m quad every 0.35 m per rear wheel while slip > 0.25. 800-segment ring buffer; custom data = (spawn time, strength, surface index). The shader picks the road (black), dirt (brown) or sand (light) color and fades over 8 s.

### Audio (`car_audio.gd`), v2 after "the sound is weird"
- `AudioStreamGenerator` at 22050 Hz, filled every frame in GDScript. One mixed stream at −6 dB. **M toggles mute** (master bus).
- **Engine:** sine harmonics of the firing frequency (1×0.55, 2×0.28, 3× and 4× scaled by throttle "brightness") + a sub-octave sine 0.35, random 0.82–1.0 amplitude per cycle (rumble), low-passed. Pitch 32→105 Hz from a fake RPM with 5 fake gears. Rpm rises a bit in drifts, burnouts and the air. Volume 0.3 × (0.5 + 0.5 × throttle).
- **Tires:** band-passed noise scrub (volume 0.18 × slip × (1 − 0.7 × squeal)) + a quiet squeal of two detuned wobbling sines at ~780 and ~1015 Hz (0.08 × slip × squeal; road only).
- **Wind:** low-passed noise, 0.1 × speed ratio².
- v1 used saw + square waves and a loud pure 950 Hz squeal, which sounded buzzy and weird.

### Chase camera (`scripts/camera/chase_camera.gd`): third-person chase
- Base: 8 m behind, **6 m up**, aims 1.2 m up and **3 m ahead**, which gives about a 24° look-down. (It was 3.2 m up / 4 m ahead, about 10°. The user asked for "a little top angle, but not too high".) Follow 12, rotate 4.
- **Continuous drift effects (no state switching):** yaw = 60% travel direction / 40% nose (`heading_weight` 0.4). Lateral shift (1.2 m) and roll (3°) scale with `drift_angle / 30°`. Up to 10% closer over 2 s of drifting. Smoothed at `drift_effect_speed` 3.
- **Speed:** FOV 65° → 82°, lower and closer at top speed, subtle shake above 70%.
- **Impacts and hard landings:** trauma shake.
- Mouse-wheel zoom 0.7–1.6×. **No terrain collision yet**, so it can clip into dunes.

### Combat, Phase 2 step 1 (`scripts/combat/`)
**Design (user decision):** a mouse-aim turret. Later, each gun gets an active skill with a cooldown and Q/E swaps guns. Step 1 = one normal gun only.
- **WeaponController** (node "Weapons" on the Sedan, after Model): creates the Turret on the model's `"roof"` mount (`SedanModel.get_mount()`, a child of the body, so it leans and bounces with it), a Projectiles node, and the HUD (crosshair + weapon label). Hides the OS cursor; ESC toggles it (no firing while the cursor is visible).
  - **Aim** (every physics tick): **aim assist** first: the live node in group `"targets"` whose `get_aim_point()` is nearest the cursor on screen, within `aim_assist_radius_px` 70 and the weapon range → aim exactly at it (crosshair turns red). Otherwise a camera ray through the mouse (400 m, mask 3, excluding the car) → hit point, or the ray end.
  - **Fire**: hold LMB; a cooldown accumulator fires `fire_rate` shots/s exactly. Direction = barrel forward + random cone spread (`spread_deg`). Damage × random 0.9–1.1 (varied numbers). Lifetime = range / speed.
- **WeaponData** machine gun: damage 8, 10 shots/s (~80 DPS), spread 1.2°, bullet 220 m/s, range 160 m, tracer color gold. Skill fields exist but are unused.
- **Turret**: base → yaw pivot (head) → pitch pivot → barrel → muzzle. Turns at yaw 8 rad/s, pitch 6 rad/s, pitch −15°..+35°, computed in the turret's own (tilted) space. Recoil (barrel kicks back 0.12 m) and a 0.045 s muzzle-flash billboard per shot.
- **Projectiles**: bullets are packed arrays (pos, vel, life, damage), max 128. Each tick: a raycast from the old to the new position (mask 3, excluding the shooter) so there's no tunnelling. Hit → `take_damage(amount, pos)` on the collider or its parent; sparks on targets/solids, a dust puff on the ground layer. Tracers: ONE MultiMesh of 3 m × 0.07 m glowing boxes. Impact particles: pooled one-shot CPUParticles3D (6 sparks, 6 dust), StandardMaterial albedo (**no vertex colors**), shrink-out scale curve.
- **Health**: `max_hp`, `hp`, `take_damage`, `damaged(amount, at)`, `died`, `reset()`, `ratio()`. Reusable for enemies and player cars later.
- **TargetDummy** (StaticBody3D, layer 1, group "targets"): post + torso + head with yellow stripes, box collision 1.2 × 2.5 × 0.8. On hit: damage number, health bar shown (billboard shader quad, `ratio` uniform, drawn on top), white emission flash 0.12 s. On death: spark burst, hidden, collision disabled, respawn after 4 s at full HP. `get_aim_point()` = 1.6 m up.
- **DamageNumber**: Label3D billboard, no depth test, rises 1.6 m with ease-out over 0.8 s and fades, then frees itself.
- **Targets placed** in terrain_test (`_spawn_targets`, on sand around the start, height from `_height`): 5 × 300 HP at (−25,115), (25,112), (−35,85), (30,70), (−20,55), and a tanky blue-grey one with 2000 HP at (−60,125).
- No gun sound yet (sound is deferred).

### Terrain test area (`scripts/world/terrain_test.gd`)
- 400 × 400 m, 2.5 m grid: 161 × 161 height samples → indexed mesh with normals from neighbor heights, **trimesh collision** (`backface_collision = true`).
- **Height** = dune noise (FastNoiseLite simplex smooth, freq 0.012, 2 octaves, remapped to 0..1 so it never goes below 0) × amplitude (1.2 m gentle → 5 m dunes in the west) + hills (NW 14 m σ28 at (−110, −110); SE 8 m σ22 at (130, 15)), × **flat mask** (0 within 4 m of roads, dirt, skidpad and start pad, blending to 1 at 22 m; also flat within 4–20 m of the walls).
- **Overlays (visual only, no collision):** roads with a shader (asphalt, edge lines, 6 m dashed center line), start pad, skidpad disc, dirt plane with a brown grid. Heights 0.02–0.045 to avoid z-fighting.
- **Ramps:** convex solids built from face lists (outward normals computed against the centroid). Kickers small (6 × 8 × 1.2 m), medium (6 × 10 × 2.2), large (8 × 14 × 3.5) at z = −95, plus a tabletop (8 m wide, 10 up / 12 top / 10 down, 2.5 m high) at (165, −115).
- `get_surface(pos)`: start pad / roads / skidpad → road, dirt rect → dirt, anything else → sand.
- Walls, flag poles, outer sand plane, landmarks, sky, sun and fog come from `WorldBuilder`.

### Flat test arena (`scripts/world/test_arena.gd`), Phase 0
- 200 × 200 m flat grid ground, striped walls, poles, landmarks. No surface map, so the car uses "road" values.

---

## Session Log

### Session 1 (2026-11-06): planning, Phase 0, research, Driving v2, Phase 1 start
**Decisions**
- Engine: **Godot 4.7.2**, targeting **web** (desktop builds come for free).
- Camera: **third-person chase** (first top-down chase, changed in this session). Handling: **arcade**.
- Setting: **desert wasteland**, desert cities, roads and sand.
- **Core gameplay = farming, fighting, bosses.** Racing, drift and drag are side activities.
- Working style: **one small step at a time.** Phase 0 = one sedan in an enclosed space, no obstacles.
- **Documentation rule** (`CLAUDE.md`): every request updates the DEVLOG, research goes to `docs/research/`, and user feedback gets logged.
- The user asked to do all Driving v2 steps (v2.1–v2.7) at once.
- **Next after Phase 0: the terrain test area (map) before the car model.** Terrain changes driving and tuning; the car model is a visual swap and is better done when weapons need mount points.

**Done (in order)**
1. Wrote `docs/GAME_DESIGN.md` (vision, Ragnarok → car system mapping, roadmap).
2. Created the Godot project and the Phase 0 v1 files. The user imported it.
3. Added the DEVLOG and `CLAUDE.md`.
4. Research 1, `CAR_PHYSICS_RESEARCH.md` (3 searches).
5. Camera changed to third-person chase.
6. **Feedback:** "the driving still doesn't hit it."
7. Research 2, `DRIVING_GAME_FEEL.md` (4 searches): v1 diagnosis, drift-angle controller, juice, v2 plan.
8. Strengthened the documentation rule in `CLAUDE.md`.
9. **Implemented Driving v2 (v2.1–v2.7)**: controller rewrite + drift controller, wheel spin, smoke and skids, camera effects, speed references, synthesized audio.
10. **Feedback #1:** "the drift kick isn't smooth, it suddenly shifts the back." Cause: the nose was rotated 12° in one frame and yaw_rate was overwritten. Fix: the kick is eased over `drift_kick_time` 0.25 s with smoothstep, and yaw_rate is kept.
11. **Feedback #2 (screenshot):** (a) the camera has a gap when starting a drift; (b) a black ball at the tires on every restart.
    - (a) Cause: the camera switched on `is_drifting` and its blend lagged the angle. Fix: only continuous values (`heading_weight` yaw blend always on; offset and tilt from drift_angle; tighten smoothed).
    - (b) Cause: the burnout dust puffs rendered black (StandardMaterial3D vertex colors on particles in Compatibility). Fix: custom `SMOKE_SHADER`.
12. **Feedback #3:** "the driving feels a lot better now, but drifting might be too much maybe. Let's do a terrain test area." **Phase 0 is considered done.**
    - **Drift toned down:** base angle 30→25°, max 48→40°, throttle bonus 5→3°, kick 12→8°, drift turn rate 1.5→1.35 rad/s, power-over hold 0.25→0.5 s. (Revert any of these in the Inspector if it now feels too tame.)
13. **Implemented the Phase 1 terrain test area:**
    - new `surfaces.gd` (road/dirt/sand table), `world_builder.gd` (shared helpers; `test_arena.gd` refactored onto it), `terrain_test.gd` + `terrain_test.tscn` (now the main scene)
    - controller: surface blending, overspeed decel, rolling drag, slope gravity, ground-plane velocity, body tilt to the ground, air mode (jumps), hard-landing signal and shake, power-over relative to the surface top speed
    - effects: dust color per surface, dust trail on loose ground at speed, skid color per surface
    - audio: road squeal vs sand scrub
    - debug: surface + ground/air display

14. **Feedback #4 (Phase 1 ran):** (1) "the sound is weird"; (2) "on hills and ramps the car looks like it's floating"; (3) "the jump physics are off"; (4) "move the camera up a little, a top angle but not too high".
    - (2)+(3) Cause: ground detection used `is_on_floor()` with velocity projected along the slope. Moving parallel to a slope often doesn't register a floor contact, so the car flickered between ground and air. In "air" it applied gravity and slowly levelled the body (looked like floating on slopes). Jumps launched at random and leveled wrongly. The rigid 4.4 m box also rested on its corners at ramp feet and crests.
    - Fix: a **raycast suspension** ground system (see How Systems Work): floating motion mode, a raised collision box, 4 wheel rays, exact ground height plus plane-fit tilt, and take-off only when the ground falls away faster than gravity. Air gravity 22, nose follows the flight path.
    - (1) Fix: the engine was rebuilt from sine harmonics (no saw/square buzz), the squeal is quieter and detuned, volumes are lower, and **M mutes**.
    - (4) Fix: camera height 3.2 → 6 m, look-ahead 4 → 3 m (~24° down).
    - `sedan.tscn`: collision box size y 0.9 → 0.8, center y 0.45 → 0.8.
    - Not re-tested yet.

15. **Feedback #5 (2 screenshots): "I'm not even driving now, do research on physics."** The car hovered ~0.3 m or sat pitched nose-down, and couldn't drive.
    - Research (3 searches) → `docs/research/VEHICLE_GROUND_PHYSICS.md`: the 4 approaches (kinematic + rays, RigidBody springs like Very Very Valet, sphere car, VehicleBody3D), spring-damper math, and a pitfall list. Two known pitfalls matched our bug exactly.
    - Root cause: falling at spawn with speed 0, the air "follow flight path" pitch tipped the nose straight down. The tipped collision box hit the ground before the rays registered landing, so the car was held up and stayed in "air" mode forever (no throttle in the air).
    - Fixes: (1) **collision layers**: ground = layer 2, the car body mask = 1 only, so the chassis never touches the ground; ramps are layers 1+2. (2) Air pitch clamped ±25° and scaled by speed. (3) Landing tolerance 0.05 / "below ground → land". (4) No launch below 3 m/s. (5) Visual landing suspension spring on the model.
    - **Decision: keep the kinematic + rays approach** (not RigidBody springs). It's deterministic for multiplayer and keeps the drift controller; the failures were specific pitfalls.
    - Not re-tested yet.

16. **Feedback #6:** "it's okay now, but the sound is still weird; we'll fix it later." The round-5 ground fixes work. **Phase 1 is accepted.** Sound is deferred to the backlog (plan: replace the synth with real CC0 engine/tire samples, or a better synth).

17. **Git set up** at the user's request: `git init -b main`, added `.gitattributes` (`* text=auto eol=lf`), remote `https://github.com/Joshnomnom/blank.git`, commit `e1b2348` "Phase 0 + Phase 1", pushed to `main`. Godot `.gd.uid` files are committed (as recommended); `.godot/` is ignored.
18. **Combat decision:** aiming = **A. mouse-aim turret**. The user also wants each gun to have a **skill with a cooldown** and **Q/E to swap guns**, but "let's try just one normal gun first". Recorded in GAME_DESIGN.md.
19. **Implemented Phase 2 step 1** (see How Systems Work → Combat): input actions `fire` (LMB) and `toggle_cursor` (ESC); `input_setup._add_action` gained a mouse-buttons parameter; `SedanModel.get_mount("roof")`; new `scripts/combat/*` and `scripts/ui/crosshair.gd`; Weapons node in `sedan.tscn`; 6 dummies in terrain_test. **Not tested yet.**

**Backlog (deferred, not forgotten)**
- **Sound**: still "weird". Replace the synthesized audio with real samples (CC0 packs), with pitch shifting by RPM. Also add gun sounds.
- Camera collision with dunes (the camera can clip into terrain).
- Gamepad aiming (right stick) for the turret.

20. **Feedback #7:** "it's good now, feels okay". **Phase 2 step 1 (one gun) is accepted.** Committed and pushed as commit 2 ("Phase 2 step 1").

**Not done / known unknowns**
- Next combat step not started: a gun skill with a cooldown (needs decisions: what the machine gun skill does, and which key).
- Camera terrain collision isn't done (it may clip into dunes).

**Open questions**
- Game title (ideas: Wasteland Drive Online, Rust & Nitro, Dune Runners).
- Keep power-over drift entry? (Now requires a 0.5 s hold.)
- Car model source when it's time: Kenney Car Kit (CC0), own Blender model, or an artist.
