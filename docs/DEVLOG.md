# Dev Log

Running record of what we've built, decided, and what's next.
**Read "Current Status" first when resuming work.** New sessions go at the top of the log, newest first.

Related docs: [GAME_DESIGN.md](GAME_DESIGN.md) (overall plan) · [research/](research/) (all research notes).

---

## Current Status

| | |
|---|---|
| **Phase** | **4: RPG core**. Steps 1–3 (bag + part stats + chips, temporary garage, nitro dash) **accepted by the user** ("happy now", log #39) and committed (commit 5). Phases 0–3 done. |
| **Latest** | **Commit 5: Phase 4 steps 1–3** (bag I, garage F, nitro dash Shift, slerp fix, NitroDash preload fix). Details: How Systems Work → Phase 4 steps 1–3. |
| **Phase 3 state** | **Phase 3 (all 6 steps) implemented, first play-test done (feedback #9):** player HP/death/respawn + HUD, enemies (Scrap Drone, Raider Gunner, Iron Hauler, boss Dune Tyrant) with an FSM, spawn camps with respawn timers + assist, loot drops (scrap / parts with rarity / chips) + inventory, field boss with a gravestone + boss bar, and **tester instant-spawn keys** (1–4 spawn, 5 respawn camps, K kill all, G god, H heal). See How Systems Work → Phase 3. |
| **Previous** | **Phase 2 step 2 accepted and committed (commit 3):** Rocket Launcher + Q/E swap + damage × armor types (colored numbers, EFFECTIVE/RESISTED) + crosshair reload ring + machine gun overheat with penalty lockout. Sound is deferred. |
| **Git** | Repo: https://github.com/Joshnomnom/blank (branch `main`). Commit 1 `e1b2348` = Phase 0 + Phase 1. Commit 2 `7e671e9` = Phase 2 step 1. Commit 3 `c813f9e` = Phase 2 step 2. **Commit 4 `313ad1c` = Phase 3 (enemies, loot, boss, tester tools) + feedback #9.** Commit 5 `1fc1f95` = Phase 4 steps 1–3 (bag, garage, nitro). **Rule: commit + push after the user accepts a step.** |
| **Next** | **Waiting on the user's go-ahead.** Proposed next Phase 4 step: **levels, EXP and scrap from monster level** (monster level + rank, player level + EXP bar, level-gap modifier, level-up feedback). Then: real chip rates + soft pity + presentation, repair cost, save/load. Open: dash i-frames? Research: [research/LOOT_ECONOMY_CHIPS.md](research/LOOT_ECONOMY_CHIPS.md). |
| **Main scene** | `scenes/terrain_test.tscn`. The old flat arena `scenes/test_drive.tscn` still works (car uses "road" grip there). |
| **After that** | Phase 5 (first content slice: one town, two farming zones, one boss, three chassis, one job tree, NPC shop). The real car model and half-humanoid robot enemy models come when the art pass starts; everything is still placeholder boxes. |
| **Research** | [research/CAR_PHYSICS_RESEARCH.md](research/CAR_PHYSICS_RESEARCH.md) · [research/DRIVING_GAME_FEEL.md](research/DRIVING_GAME_FEEL.md) · [research/VEHICLE_GROUND_PHYSICS.md](research/VEHICLE_GROUND_PHYSICS.md) · [research/WEAPONS_BALANCE_EQUIPMENT.md](research/WEAPONS_BALANCE_EQUIPMENT.md) · [research/ENEMY_SPAWNING_AI.md](research/ENEMY_SPAWNING_AI.md) · [research/ENEMY_BOSS_DESIGN.md](research/ENEMY_BOSS_DESIGN.md) · [research/LOOT_ECONOMY_CHIPS.md](research/LOOT_ECONOMY_CHIPS.md) |
| **Physics layers** | `scripts/combat/layers.gd`: **1 SOLID** (walls, ramps, dummies), **2 GROUND** (terrain; rays only), **4 PLAYER**, **8 ENEMY**. Ramps = 1+2. Car: layer 4, mask 1+8. Enemies: layer 8, mask 1+4. Player shots/aim: 1+2+8; enemy shots: 1+2+4; player rocket explosions damage 1+8; sight blockers 1+2. Car wheel rays 1+2, enemy/pickup ground rays 2. **New objects must follow this.** |

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
| LMB (hold) | | Fire the current gun |
| Q / E | LB / RB | Previous / next gun (0.35 s swap) |
| 1 / 2 / 3 / 4 | | **Tester:** spawn Scrap Drone / Raider Gunner / Iron Hauler / Dune Tyrant boss at the crosshair (15–70 m away; no respawn) |
| 5 | | **Tester:** respawn every dead camp member now (incl. the boss) |
| K / G / H | | **Tester:** kill all enemies (drop loot) / god mode toggle / heal to full |
| B (hold) | Y | Look back (camera flips 180°) |
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
  research/                (full list: Research row in Current Status)
    CAR_PHYSICS_RESEARCH.md  car physics math, models, tuning values, upgrade plan
    DRIVING_GAME_FEEL.md     game feel: diagnosis of v1, drift controller, juice, Driving v2 plan
    LOOT_ECONOMY_CHIPS.md    EXP/scrap curves, economy faucets/sinks, chip rates + power budget, rare-drop feel
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
  vehicles/nitro_dash.gd       class NitroDash (node "Nitro", created by CarController): Shift dash, nitro meter, flames
  vehicles/car_audio.gd        synthesized engine / tire scrub / road squeal / wind (AudioStreamGenerator)
  camera/chase_camera.gd       class ChaseCamera: third-person chase, continuous drift/speed effects, impact shake
  combat/weapon_controller.gd  class WeaponController ("Weapons" node on the car): guns list, Q/E swap, per-gun cooldowns, mouse aim, aim assist + effectiveness, firing, HUD
  combat/weapon_data.gd        class WeaponData (Resource): gun stats, Kind (BULLET/ROCKET), damage_type, explosion; make_machine_gun(), make_rocket_launcher()
  combat/damage_types.gd       class DamageTypes: damage type × armor type multiplier table, names, colors
  combat/turret.gd             class Turret: roof turret, one gun model per Kind (MG barrel / rocket pod), swap pop-in, yaw/pitch aim, recoil, muzzle flash
  combat/projectiles.gd        class Projectiles: data-driven bullets (segment raycasts, damage type), MultiMesh tracers, impact sparks/dust
  combat/rocket.gd             class Rocket: one rocket node (raycast flight, smoke trail) → Explosion
  combat/explosion.gd          class Explosion: reusable area damage (sphere query, falloff) + flash/fireball/smoke/light + camera shake
  combat/health.gd             class Health: reusable HP component (damaged / died signals)
  combat/target_dummy.gd       class TargetDummy: training target (HP bar shader, hit flash, death burst, respawn)
  combat/damage_number.gd      class DamageNumber: floating Label3D damage numbers
  combat/layers.gd             class Layers: physics layer constants (SOLID 1, GROUND 2, PLAYER 4, ENEMY 8 + masks)
  combat/world_health_bar.gd   class WorldHealthBar: billboard HP bar quad (shader)
  enemies/enemy.gd             class Enemy: FSM (idle/alert/combat/return/dead), melee/ranged/boss attacks, leash, box robot-vehicle model
  enemies/enemy_data.gd        class EnemyData: stats + behavior flags + loot; make(id): scrap_drone, raider_gunner, iron_hauler, dune_tyrant
  enemies/boss_brain.gd        class BossBrain: boss phases + bullet-hell patterns (fan, ring w/ gap, mortar, spiral, charge, shock)
  combat/orb_projectiles.gd    class OrbProjectiles: shared slow glowing boss orbs (player-only hitbox)
  combat/ground_strike.gd      class GroundStrike: telegraphed ground blast (red disc → explosion, knockback)
  enemies/spawn_camp.gd        class SpawnCamp: pack slots, per-slot random + dynamic respawn, assist calls, boss gravestone
  loot/loot.gd                 class Loot: rarity table, part/chip/scrap rolls (parts/chips built by ItemDB), drop()
  items/item_db.gd             class ItemDB: slots, stat table + caps, main stats by rarity, affixes, chip defs, make_part/make_chip
  player/equipment.gd          class Equipment ("Equipment" under Status): equipped parts + chips -> car/HP/gun stats
  ui/bag_screen.gd             class BagScreen: I-key bag (car slots, bag grid, details/compare, equip/unequip/insert/remove)
  ui/garage_screen.gd          class GarageScreen: garage tabs LOADOUT / TUNING / BODY KIT
  world/garage_zone.gd         class GarageZone: TEMPORARY garage pad + shed (visual only), F prompt, opens GarageScreen
  loot/pickup.gd               class Pickup: dropped item (pop-out, bob, beam for Rare+, magnet, collect)
  player/player_status.gd      class PlayerStatus ("Status" on the car): HP, armor, death/respawn, invuln, god mode, inventory
  debug/test_spawner.gd        class TestSpawner: tester keys (spawn 1–4, respawn camps 5, kill all K, god G, heal H, give part 6 / chip 7 / scrap 8)
  ui/player_hud.gd             class PlayerHUD: HP bar, scrap/bag count, toasts, damage flash, DESTROYED overlay, boss bar
  ui/crosshair.gd              class Crosshair: crosshair at the mouse; locked = red, EFFECTIVE = gold + label, RESISTED = grey + label
  ui/weapon_hud.gd             class WeaponHUD: bottom-right gun slots (current highlighted, damage type, cooldown overlay, Q/E hints, swap bar)
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

### Combat, Phase 2 step 2: Rocket Launcher, Q/E swap, damage × armor types
- **Damage types × armor types** (`damage_types.gd`, multiplier on damage):
  | dmg \ armor | LIGHT | HEAVY | SHIELDED | ORGANIC |
  |---|---|---|---|---|
  | KINETIC (MG) | **1.25** | 0.60 | 0.80 | 1.00 |
  | EXPLOSIVE (rocket) | 1.00 | **1.30** | 0.80 | 1.00 |
  | FIRE (planned) | 1.00 | 0.70 | 0.60 | **1.50** |
  | ENERGY (planned) | 0.80 | 1.00 | **1.50** | 0.90 |
  Effective = multiplier > 1.05, resisted = < 0.95. Targets apply it in `take_damage(amount, at, damage_type)`, then `Health.take_damage(final, at, multiplier)`.
- **Feedback:** damage numbers are **golden orange (1.0, 0.68, 0.12), big (84 px), with a pop scale** when effective; white (64 px) when normal; **dim white (50 px)** when resisted. The crosshair, when locked on a target, turns **gold + "EFFECTIVE"**, red (normal), or **grey + "RESISTED"** for the *current* gun. Dummies show a colored armor label ("LIGHT ARMOR" tan, "HEAVY ARMOR" steel blue) above them. The hit flash is stronger on effective hits.
- **Rocket Launcher** (`make_rocket_launcher`): EXPLOSIVE, 90 dmg at the center, 1 shot per 1.5 s, rocket 60 m/s, range 150 m (then it explodes), spread 0.3°, **explosion radius 6 m, linear falloff to 40% at the edge**. `Rocket` node: segment raycast per tick (mask 3, excluding the shooter), explodes 0.2 m off the hit surface; body + exhaust glow + smoke trail (lingers 0.7 s after the explosion).
- **Explosion** (reusable): sphere shape query (layer 1, ≤32 results), each damageable hit once, distance measured to its `get_aim_point()`. Visuals: transparent flash sphere growing to 0.85 × radius in 0.22 s and fading, OmniLight flash (energy 6 → 0 in 0.35 s), fireball (22 particles) + smoke (14), shrink curves (no vertex colors). Camera shake via `ChaseCamera.add_trauma()` scaled by distance (0 beyond 45 m). Frees itself after 1.6 s. Its **position is set before add_child**, because the damage query runs in `_ready()`.
- **Balance check:** MG vs LIGHT = 10 dmg × 10/s = 100 DPS (300 HP in 3 s); MG vs HEAVY = 48 DPS (6.3 s). Rocket vs HEAVY = 117 per 1.5 s = 78 DPS (3.8 s); rocket vs a group of 3 light = ~90 + 2 × ~70 per shot. So **MG wins vs light, rockets win vs heavy and groups**.
- **Q/E swap** (`weapon_prev` Q / LB, `weapon_next` E / RB): 0.35 s swap with no firing; the new gun model pops in (scale 0.2 → 1, back-ease). **Each gun keeps its own cooldown** and holstered guns keep recharging (no swap-cancel exploit, no lost cooldown).
- **Turret** now holds one model per Kind: the MG long barrel, or an olive rocket pod with two tubes and a yellow stripe. Each has its own muzzle and recoil (MG 0.12, rocket 0.2); the muzzle flash moves to the active muzzle (bigger and longer for rockets).
- **WeaponHUD**: bottom-right slots (190 × 62) with name, damage-type tag (colored), a gold border on the active slot, a dark cooldown overlay + seconds (only for guns with a cooldown > 0.3 s), Q/E key boxes at the ends, a swap progress bar, and the hint "LMB fire · Q/E swap · ESC cursor".
- **Dummies** now: LIGHT at (−25,115), (−35,85), (−20,55) + **a tight group of 3 LIGHT** at (40,128), (44.5,131), (37,133) for splash tests; HEAVY (armor plates, steel blue) at (25,112), (30,70), and the 2000 HP tank at (−60,125).

### Phase 3: enemies, player HP, spawning, loot, boss, tester tools
Research basis: `docs/research/ENEMY_SPAWNING_AI.md`. Enemy look (final art): half-humanoid robot vehicles; now boxes.

**Player HP** (`scripts/player/player_status.gd`, node "Status" on the Sedan after Weapons; `scripts/ui/player_hud.gd`)
- 600 HP, armor LIGHT (enemy kinetic damage ×1.25, explosive ×1.0). `CarController.take_damage()` forwards here; damage × armor multiplier → Health. A red screen flash scales with the hit size.
- Destroyed: `controls_enabled = false` (all inputs zero, no firing), an explosion, a "DESTROYED / Respawning in X" overlay, then after 3 s `reset_to_spawn()` + full HP + **2 s invulnerability** (the car blinks).
- `god_mode`, `heal_full()`, inventory: `scrap` (int) + `items` (Array of dicts), `collect(item)` → toast in the rarity color.
- HUD: HP bar bottom-left (green → red), "SCRAP n  PARTS n [GOD MODE]", toasts stacked above (3 s fade), **boss bar top-center** while a boss is in combat.
- `CarController` gained: group "player", layer PLAYER / mask SOLID+ENEMY, `is_alive()`, `get_aim_point()`, `take_damage()`, `apply_knockback(impulse)` (mixes into the travel velocity; +y launches), `collect()`, `controls_enabled`.

**Enemy** (`scripts/enemies/enemy.gd`, data `enemy_data.gd`), a CharacterBody3D (floating), layer ENEMY, mask SOLID+PLAYER, groups targets/enemies(/bosses)
- **FSM:** IDLE (wander within the camp radius; aggressive ones scan every 0.25 s: sight radius + LoS raycast) → **ALERT** (stop, face, yellow "!" for 0.5 s) → COMBAT → RETURN (leash) → IDLE; DEAD.
- Passive mobs engage only when damaged; first hit → COMBAT immediately + `camp.on_member_attacked()` (assist).
- **COMBAT styles:** MELEE = chase, ram when within reach (damage + knockback + a small spark explosion), then back off 0.7 s at an angle and come again. RANGED = keep 20–34 m, strafe (flip every 1.5–3 s), shoot when in LoS and range (slow red tracer bullets, 45 m/s, dodgeable). BOSS = melee + a 3-bullet cannon volley (2.5 s cd, 8–60 m) + **shockwave**: a red ground ring grows for 1.2 s (telegraph), then a blast (radius 12, 60 dmg, knockback + small launch).
- **Leash:** beyond `leash_range` from home, OR no damage for `aggro_timeout` AND no sight for 3 s, OR the player is dead → RETURN: 1.6× speed home, **invulnerable** (hits show "EVADE"), regen 40%/s, then reset to full HP.
- **Movement:** vehicle-like (turn rate, accel, slows on sharp turns), surface multiplier (sand 0.8, dirt 0.9), separation from other enemies, ground snap by a ray (layer GROUND) + tilt to the normal. Enemy bullets come from one shared `Projectiles` node (group "enemy_shots", hit mask ENEMY_SHOTS, red, thicker tracers).
- Hit feedback = same as dummies (damage numbers with effectiveness colors, white flash, `WorldHealthBar`). Name label + colored armor label above.
- **Death:** explosion visual, `Loot.drop()`, camp notified, freed.
- Placeholder model: a dark wheeled base + 4 wheels, robot torso, head with an eye strip (red = aggressive, yellow = passive), arms; melee types have a front ram plow, ranged types a gun arm. Size × `scale`.

| Enemy | Armor | HP | Speed | Behavior | Attack | Loot |
|---|---|---|---|---|---|---|
| Scrap Drone | LIGHT | 150 | 30 | aggressive, assist, sight 30, leash 120 | ram 15, cd 1.2, knock 10 | 3–8 scrap, 20% part, 1% chip |
| Raider Gunner | LIGHT | 220 | 25 | aggressive, assist, sight 40, leash 130 | bullets 12, cd 1.1, range 50, keeps 20–34 m | 5–12, 30%, 1% |
| Iron Hauler | HEAVY | 800 | 18 | **passive**, assist, leash 110 | ram 35, cd 2, knock 22 | 15–30, 60% (+rarity), 2% |
| **Dune Tyrant (boss)** | HEAVY | 6000 | 20 | aggressive, sight 50, leash 90, timeout 12 | ram 45 / volley 3×18 / shockwave 60 | 150–250, 3 rolls (big rarity bonus), 15% chip |
All are slower than the car's road top speed (42 m/s): driving away always works.

**SpawnCamp** (`scripts/enemies/spawn_camp.gd`): slots = `members` ids; **per-slot respawn = random [min, max] × dynamic factor** (players within radius+150 m: up to 2× faster at 4 players; ≤1 alive in a multi-slot pack: ×0.7), floor 8 s; never spawns within `min_player_distance` (30 m, boss 40 m) + radius of the player (retries every 1 s). Assist: members within 25 m of the attacked one join after 0.2–0.6 s. **Boss gravestone** (`show_gravestone`): stone + cross + label "Name / Destroyed at HH:MM:SS / Respawn in m:ss".
Camps in terrain_test: 4 drones SW (−90,60); 3 drones (60,−18); 3 gunners + 1 drone W (−125,5); Iron Hauler + 3 drones SE (125,45); **Dune Tyrant on the NW hill (−110,−110)**, test respawn 3–5 min (real: 60–120 min).

**Loot** (`scripts/loot/loot.gd`, `pickup.gd`): always scrap; per item roll: a part "Prefix Slot" (Rusty/Salvaged/Tuned/Military/Prototype × Engine/Tires/Armor Plate/…) with rarity Common 70 / Uncommon 20 / Rare 8 / Epic 1.8 / Legendary 0.2 (the non-common weights × (1 + rarity_bonus)); chip "<Enemy> Chip" (Epic purple). Pickups pop out of the wreck in an arc, then bob and spin; parts and chips have a name label; **Rare+ and chips get a light beam**; magnet within 9 m, collected at 2.2 m → toast; despawn after 90 s. Stats for parts and chips come in Phase 4.

**Tester tools** (`scripts/debug/test_spawner.gd`, created by terrain_test): 1–4 spawn an enemy at the crosshair aim point (clamped 15–70 m from the car, snapped to the ground, no camp → no respawn); 5 respawn all dead camp members now; K kill all (with loot); G god mode; H heal.

**Changed for Phase 3:** physics layers (see Current Status); `Explosion` has a `mask` and damage 0 = visual only; `Projectiles.hit_mask`; rockets and the aim ray use `Layers.PLAYER_SHOTS`; the weapon controller won't fire while dead; `DamageNumber.spawn_text()` ("EVADE"); `WorldHealthBar` (a shared billboard bar).

### Phase 4 step 1: bag screen, part stats, chips (log #34)
**Bag vs garage (decided log #34):** the **bag (I)** works anywhere: equip/unequip parts, insert/remove chips. The **town garage** (next step) does gun loadout, tuning +1..+10 and visual body kits.

**Items** (`scripts/items/item_db.gd`, plain Dictionaries, ready for JSON saves)
- Slots: **Engine, Tires, Suspension, Armor Plate, Nitro, Module** (the old 8 drop slot names are gone).
- Main stat by slot, Common/Uncommon/Rare/Epic/Legendary: Engine **Top Speed** 3/5/7/9/12% · Tires **Grip** 4/6/9/12/15% · Suspension **Knockback Resist** 10/15/20/25/30% · Armor Plate **Max HP** +60/100/150/200/260 · Nitro **Nitro Recharge** 10/15/20/25/30% (was Acceleration until log #37) · Module **Field Repair** 3/5/7/9/12 HP/s.
- Random affixes = rarity count (0/1/2/3/3) from: top_speed 1–3, accel 2–4, grip 2–4, handling 2–4, max_hp 20–50, armor 2–4, kb_resist 3–6, repair 0.5–1.5, damage 2–5, kinetic 3–6, explosive 3–6 (× (1 + 0.25 × rarity)); never the slot's main stat.
- Chip sockets: Common 0, Uncommon 50% 1, Rare 1, Epic 1–2, Legendary 2.
- Car total caps: Damage Reduction 50%, Knockback Resist 60%, Kinetic 30%, Explosive 30%, Blast Radius 40%.
- **Chips** (one per monster, category-locked): Scrap Drone → Tires: Handling +4% (remove 50 scrap) · Raider Gunner → Module: Kinetic +10% (80) · Iron Hauler → Armor Plate: Max HP +120, Top Speed −4% (trade-off, 150) · **Dune Tyrant → any part, UNIQUE**: Explosive +12%, Blast Radius +20% (400). Insert = free; remove = scrap, the chip returns to the bag.
- Legendary unique effects are not in yet.

**Equipment** (`scripts/player/equipment.gd`): captures the car's base values once, then on every change sets `top_speed`, `accel_max`, `grip_turn` (grip), `turn_rate` + `drift_turn_rate` (handling), `CarController.knockback_resist`, `Health.max_hp` (a gain is also added to current HP), `PlayerStatus.damage_reduction` (× (1 − r) after the armor-type multiplier), `PlayerStatus.repair_rate` (HP/s after `repair_delay` 4 s without damage), `WeaponController.damage_bonus` / `type_bonus` (damage × (1 + all + type)), `blast_radius_mult` → `Rocket.radius_mult`.

**Bag screen** (`scripts/ui/bag_screen.gd`, CanvasLayer 8): I toggles (ESC also closes). Opening shows the mouse and hides the crosshair (`WeaponController.set_menu_open`); guns don't fire and ignore Q/E/ESC while it's open; **the car can still drive**. Left: 6 slot buttons (rarity color, sockets ◆/◇), guns (read-only), car stats. Middle: bag (chips first, then by rarity), scrap. Right: details, "IF EQUIPPED" car-total diff (green/red), action buttons. Click selects; double-click / right-click equips or unequips.

### Phase 4 step 2: temporary garage (log #35)
**Zone** (`scripts/world/garage_zone.gd`): `_garage_rect` Rect2(−37, 139, 22, 22) in terrain_test (flattened, road surface, road overlay), zone center (−26, 150), radius 9 m, glowing orange ring, open shed (posts/roof/back wall, **no collision**), "GARAGE" sign. Inside + speed ≤ 3 m/s → "[F] OPEN GARAGE" prompt (otherwise "Stop to open the garage"). Opening: car `controls_enabled = false`, speed 0, `WeaponController.set_menu_open(true)`. F or ESC closes. Bag (I) can't open while the garage is open and vice versa (`WeaponController.ui_open`).

**Loadout** (`Equipment.guns`, `mounted`, `gun_slots` = 2): guns are owned items (`ItemDB.make_gun`: machine_gun, rocket_launcher; shown as Rare). Mount into a slot (swaps if already mounted elsewhere), move, unmount (at least 1 stays). `WeaponController.set_loadout(list)` rebuilds the gun list (resets cooldowns/heat, current = slot 1). `ItemDB.gun_weapon_data(gun)` = fresh WeaponData with tuning applied.

**Tuning** (`Equipment.tune`, rules in `ItemDB`): +1..+10 on guns, equipped parts and bag parts. Part: +6% of the main stat per level (+10 = +60%). Gun: +3% damage per level (+10 = +30%). Success by target level: +1..+4 100%, +5 80%, +6 65%, +7 50%, +8 35%, +9 25%, +10 15%. Cost = 50 × target² × (1 + 0.5 × rarity) scrap (guns count as Rare). Fail = −1 level. Target ≥ +8 and fail → 25% the PART breaks (destroyed; its chips go back to the bag). Guns never break. Names show "+N".

**Body kits** (`SedanModel.KITS`, `PAINT_COLORS`, `set_kit`; `Equipment.kits`, `owned_kits`, `set_kit`): paint (8 colors, 100 scrap each, Rust Red free), front (Bull Bar 150, Ram Plow 300), rear (Lip Spoiler 120, Big Wing 250), roof (Light Bar 150, Roof Rails 120), side (Armor Skirts 200, Side Pipes 180). Buy once, switch for free. Visual only, no collision, no stats.

### Phase 4 step 3: nitro dash (log #37)
`scripts/vehicles/nitro_dash.gd`, created by `CarController._ready` as child "Nitro" (`car.nitro`).
- **Input** `nitro`: Shift / gamepad B. Needs: meter ≥ `dash_cost`, `dash_cooldown` 0.5 s passed, controls enabled, alive, speed > −3 m/s. Works on the ground and in the air.
- **Meter**: `max_nitro` 100, `dash_cost` 34, `regen_per_sec` 9 + `drift_charge_per_sec` 10 while drifting on the ground; × `regen_mult` (Equipment: 1 + Nitro Recharge %).
- **Dash**: adds `dash_speed_gain` 16 m/s × `power_mult` (1 + Dash Power %) spread over `dash_time` 0.22 s (from ≥ 0 if rolling back). Sets `CarController.boost_hold` = `overspeed_hold` 0.35 s, during which the "over top speed → slow down" drag (`overspeed_decel`) is paused; after that the extra speed bleeds off at 10 m/s².
- **Feel**: two blue additive flame cones out of the rear bumper (length/width by `flame` 0..1, flicker) + blue OmniLight; `ChaseCamera.add_trauma(0.3)` + new `ChaseCamera.kick_fov(10°)` (decays 14°/s; FOV smoothing now 8/s); HUD nitro bar (right of HP: fill, tick per dash, "NITRO xN [Shift]", flashes white while boosting).
- **Items**: Nitro slot main stat changed from Acceleration to **Nitro Recharge** 10/15/20/25/30% (cap 100%); new affixes nitro_regen 3–6 and nitro_power ("Dash Power", cap 40%) 3–6. Acceleration is still an affix.
- No sound yet (sound is deferred). No invulnerability during the dash (open question).

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

21. **Design correction (user):** "no skill for gun, I just mean we will not have just one attack, but many types of attack based on the gun attached." I had misread "skill + cooldown". **There are no gun skills: each gun is its own attack type** (stream, spread blast, explosive, flame cone, charged shot, rear-dropped mines…), each with its own fire rate / cooldown, swapped with Q/E. Fixed GAME_DESIGN.md, removed the unused `skill_name` / `skill_cooldown` fields from `weapon_data.gd`, and updated the comments.

22. **Research (user request): weapons, balancing, customization and equipment** (5 searches) → `docs/research/WEAPONS_BALANCE_EQUIPMENT.md`. Key points: one weapon per role; avoid equal DPS; tune per intended range; a **damage type × armor type table** (Ragnarok element style) to make Q/E swapping meaningful; a Crossout-style **energy budget + mount slots + Power Score**; ratio armor formula `dmg × K/(K+armor)`; PvE TTK targets (normal mob 2–4 s); rarity tiers with bounded stats; RO-style refine +0..+10 (softer failure); **chips** (RO cards) as the farming driver. Recommended order: Rocket Launcher → Q/E swap → damage/armor types → Shotgun → Flamethrower → Railgun…

23. **User request:** "do a Rocket Launcher and Q/E swap system, also damage and armor types, but show some sign: if the gun isn't effective, white damage; if effective, golden orange numbers." → Implemented Phase 2 step 2 (see How Systems Work → step 2). New files: `damage_types.gd`, `rocket.gd`, `explosion.gd`, `ui/weapon_hud.gd`. Changed: health (effectiveness), damage_number (colors), weapon_data (Kind, damage_type, explosion), projectiles (damage type), turret (multi-gun), weapon_controller (swap, cooldowns, effectiveness), crosshair (effective/resisted), target_dummy (armor types), camera (`add_trauma`), input (Q/E), terrain dummies. **Not tested yet.**

24. **User request:** "make a reload effect on the crosshair, also the machine gun can overheat." (Step 2 not yet tested by the user at this point.)
    - **Crosshair reload ring:** while the current gun isn't ready (a cooldown > 0.3 s, e.g. rockets, or a gun swap in progress), the crosshair dims to 40% and a white ring (radius r+15) fills clockwise from the top. A gold pulse ring expands and fades for 0.25 s when it's ready. `WeaponController.reload_ratio()` feeds it.
    - **Machine gun overheat** (`WeaponData` heat fields): +0.025 heat per shot (**40 shots = 4 s of continuous fire → overheat**). Cools 0.4/s after a 0.25 s pause. **Overheated: can't fire, cools 0.5/s, unlocks at 0 (a ~2 s lockout).** Spread × (1 + heat × 1.5), so it gets less accurate as it heats. Guns cool while holstered too.
    - **Heat feedback:** crosshair heat gauge (right-side arc, white → orange → red; flashing red + "OVERHEATED" text when locked out); MG barrel glows orange-red (emission = heat² × 3); **steam** vents from the barrel while overheated; the HUD slot has a heat bar plus a flashing "OVERHEAT".
    - Balance note: bursts under 4 s still give the full ~80 DPS, but sustained fire is now ~80 DPS for 4 s then 0 for 2 s (≈53 DPS average). Rockets help cover the lockout, which encourages swapping.
    - Not tested yet.

25. **Feedback (design):** "if the player ignores it and fires until the gun overheats, it should give a longer wait as a penalty, no?" Correct. **Bug in my values:** overheat recovery (2.0 s) was FASTER than stopping in time (0.25 + 0.97/0.4 ≈ 2.7 s), so overheating was rewarded.
    - Fix: normal cooling 0.4 → **0.5/s** (full → 0 in ~2.25 s incl. the 0.25 s delay). Overheat: new **`overheat_delay` 0.8 s** before cooling starts, then **0.3/s** → **~4.1 s lockout**, nearly 2× the normal recovery.
    - The crosshair now shows **"OVERHEATED 3.2s"** (countdown, `WeaponController.overheat_time_left()`).
    - Design rule for future heat/ammo guns: **the penalty state must always recover slower than good play.**

26. **Feedback #8:** "feels okay now". **Phase 2 step 2 accepted** (rocket launcher, Q/E swap, damage × armor types with colored numbers, reload ring, overheat with penalty). Committed and pushed as commit 3.

27. **User chose enemies (Phase 3) next.** Enemy look decided: **half-humanoid robot vehicles**, kept as a model plan only; boxes for now (GAME_DESIGN.md updated). The user asked for research first.
28. **Research: enemy spawning, respawn, aggro and chase** (4 searches) → `docs/research/ENEMY_SPAWNING_AI.md`. Key points: camps/packs in spawn zones; **per-mob respawn timers with a random window** + mild dynamic scaling (crowds, nearly-cleared packs); never spawn near or in view of players; RO behavior flags (passive / aggressive / assist / looter / coward / leader); aggro sight radius + LoS + an "!" alert telegraph; **hybrid leash** (distance from home OR an aggro timeout without damage, refreshed by damage) → return home invulnerable + regen; **mobs slower than the player** (driving is defense); FSM idle → alert → chase → attack → return → dead → respawn; MVP long timers + gravestone. Proposed order: player HP → Scrap Drone (box) with FSM → spawner camp → assist + Raider Gunner → loot → field boss.

29. **User request:** "do all 6, but add an instant spawn for testers too." → **Implemented all of Phase 3** (player HP, Scrap Drone FSM, spawn camps, assist + Raider Gunner + Iron Hauler, loot, field boss with gravestone) **+ tester tools** (keys 1–4 / 5 / K / G / H). New folders: `scripts/enemies/`, `scripts/loot/`, `scripts/player/`; new files `layers.gd`, `world_health_bar.gd`, `player_hud.gd`, `test_spawner.gd`; the "Status" node in `sedan.tscn`. **Physics layers reworked** (player 4, enemy 8). Not tested yet.

30. **Feedback #9 (first Phase 3 play):** (1) "add B for looking back"; (2) "monsters just drive to hit; at least elites should have moves, like charge then dash very fast; research AI enemy behavior and enemy design"; (3) "Boss fight: drive to dodge and fire back, like Space Invaders, where the boss throws attacks at you and you dodge while attacking."
    - Research (3 searches) → `docs/research/ENEMY_BOSS_DESIGN.md`: attack anatomy telegraph → windup → strike → **recovery = punish window**; charger pattern (freeze, lock direction, inert recovery, cooldown); "every attack must telegraph"; **attack tokens** (Doom 2016, the pool on the target); clear enemy roles; bullet-hell readability (bright, low density, small player hitbox, 2D-readable patterns); **phases must change the fight**.
    - Implemented:
      - **B = look back** (hold; instant 180° camera flip and back; mouse aim still works). Gamepad Y.
      - **Attack tokens** on the car (`request_attack_token` / `release_attack_token`, max 2 rammers). Rammers without a token **circle the player** at `orbit_radius` (14 m, Hauler 16 m) and wait their turn; after a ram they back off 0.8 s and release the token.
      - **Elite Charge Dash** (Iron Hauler; the boss in P2+): windup 1 s with a **red ground lane** + "!!" + shaking (direction locks at 60%), dash 2.6× speed for ≤1.1 s, hit = 2× damage + knockback 30 + launch; **crash into a wall/obstacle = STUNNED 1.6 s, +50% damage taken (gold numbers)**; else recovery 0.8 s; cooldown 6 s.
      - **Raider Gunner aim laser:** a red laser for 0.45 s before each shot; the aim locks at the start (+0.25 s velocity lead), so moving dodges it.
      - **Boss rework** (`boss_brain.gd`): keeps 24–36 m, strafes, stays within 40 m of the arena center; patterns fan / ring-with-gap / mortar / spiral (P2+) / charge (P2+) / shock (if you hug it); never the same twice; gap 1.6 / 1.2 / 0.8 s by phase; phase changes are announced (toast) + a 24-orb ring.
      - New reusable **`OrbProjectiles`** (big slow glowing orbs, MultiMesh, player-only hitbox 1.3 m + orb 0.55 m, wall/ground checks 10×/s, 18 dmg each (explosive)) and **`GroundStrike`** (red rim + filling disc telegraph, optional falling shell, then a blast: damage + knockback + launch).
      - **Flat boss arena** (radius 55 m at (−110, −115), ring of 32 glowing orange pylons); the NW hill moved to (−160, 30) (12 m). Boss leash 90 → 60.
    - Not tested yet.

31. **Feedback #10 (2026-11-09):** "the direction is starting to be okay now; tidy the docs and put the code on git before the next step." **Phase 3 direction accepted** (no detailed tuning report yet).
    - Docs tidied: Current Status rows brought up to date (Phase/Next/After that/Research were stale from Phase 2), research list completed.
    - **Commit 4 `313ad1c` "Phase 3: enemies, loot, field boss, tester tools + feedback #9"** pushed to `main`.
    - Next: wait for the user's go-ahead; planned Phase 4 (RPG core).

32. **User request (design talk before Phase 4):** "(1) every monster has EXP and scrap drops, different per monster, higher level higher reward; research so the economy doesn't break; (2) cards: every monster has a very low chance to drop a card that improves a stat when equipped, well balanced, research; (3) research what makes a drop feel rare and valuable."
    - Research (4 searches) → `docs/research/LOOT_ECONOMY_CHIPS.md`. Proposals (not decided yet):
      - Monsters get `level` + `rank` (Normal ×1 / Elite ×4 / Boss EXP ×60, scrap ×40). `mob_exp(L) = 12·L^1.5 + 8`, kills per level `8 + 3L + 0.1L²` (~8 min/level at L10, ~70 min at L50, ~24 h to L50). Scrap `4 + 2L` × rank × 0.7–1.3. Level-gap modifier: 100% within ±5, +5%/level above (max 120%), −10%/level below −5, floor 10%.
      - Economy: faucets ≈ 1.1–1.3 × sinks per tier; all sinks scale with level: **repair + tow fee** (first sinks), tuning/refine (big open-ended), chip removal, market tax, fast travel, cosmetics.
      - Chips (= cards): normal 0.05%, elite 0.1%, boss 3%; optional soft pity (ramps from 2× to guaranteed at 3× the average kills); flat chips 3–5% of one stat, conditional +10–20% narrow, elite trade-off chips, boss mechanic chips unique-equipped; per-category caps (e.g. +40% vs one armor type); slots 0–2 by rarity; drop bonuses capped +100% with diminishing returns.
      - Rare feel: beams only Epic+ and chips (Rare beams now ≈ 10/hour, too many); tiered sound/reveal; chip card-flip reveal + unique sound; server-wide announcements; chip album; provenance; longer despawn for Epic+/chips.
      - Current code chip rates (1% / 2% / 15%) are test values, far above the proposal.
    - Open questions to the user: chips or cards name; level cap (50 proposed); pity yes/no; level gap on chips (proposed no); death penalty (scrap fee only vs RO-style EXP loss).
    - No code changed.

33. **Decisions (user):** "1. we call them chips; 2. no level cap; 3. cards have soft pity; 4. killing much lower-level monsters does not reduce card drop chance; 5. dying costs repair."
    - Recorded in GAME_DESIGN §6 ("Loot, EXP and chips") and the research doc. No level cap checked against the curve: ~218 min per level at L100 (~138 h total), so the growth is a natural soft cap.
    - Proposed Phase 4 split (one step at a time): **step 1** levels + EXP + scrap formulas (monster level/rank, player level, EXP bar, level-gap modifier, level-up feedback, tester keys); **step 2** chips (real rates, soft pity, chip presentation and beams only Epic+); **step 3** repair cost on damage/death (first scrap sink); then stats + equipping parts, garage UI, save/load.
    - No code changed. Waiting on the user's go-ahead.

34. **User request:** "we might need to create a garage first so we can test our items and equipment, like a bag screen: (1) press I to open a menu where the player can equip/unequip items, chips, etc.; (2) car part modification like cool parts has to be done in a garage in town."
    - Clarified with the user: **town garage = visual body kits + tuning +1..+10 + gun mounts/loadout**; **bag stats are real now**; **6 part slots + guns** (Engine, Tires, Suspension, Armor Plate, Nitro, Module).
    - Built step 1 = **the bag** (How Systems Work → Phase 4 step 1): new `items/item_db.gd`, `player/equipment.gd`, `ui/bag_screen.gd`; `loot.gd` now drops real parts/chips; hooks in `car_controller.gd` (`knockback_resist`), `player_status.gd` (equipment, bag, damage reduction, field repair), `weapon_controller.gd` (damage bonuses, blast radius, `set_menu_open`, `ui_open`), `rocket.gd` (`radius_mult`), `player_hud.gd` ("BAG n [I]"), `input_setup.gd` (I, 6, 7, 8), `test_spawner.gd` (give part / chip / scrap).
    - Chip drop rates in `enemy_data.gd` are still the test values (1% / 2% / 15%); real rates come with the chip step.
    - **Not tested.** Watch: UI layout/size at your resolution, double-click behaviour, car feel with big Top Speed/Grip bonuses, HP gain when equipping armor.
    - Town garage is the next step (not started).

35. **User request:** "do a garage just as a temporary zone; after that I want to add a new mechanic, a nitro dash."
    - Built step 2 (How Systems Work → Phase 4 step 2): new `world/garage_zone.gd`, `ui/garage_screen.gd`; `item_db.gd` (tuning rules, guns as items, tuned main stat in `part_lines`, "+N" names); `equipment.gd` (guns/loadout, tune, kits); `weapon_controller.gd` (`set_loadout`); `sedan_model.gd` (body kit pieces + paint); `terrain_test.gd` (garage rect: flat, road surface, overlay, zone); `input_setup.gd` (**F = interact**, gamepad X); `bag_screen.gd` (tuned main stat shown, won't open over the garage).
    - Tuning failure rule follows the research recommendation (WEAPONS_BALANCE_EQUIPMENT.md §4.4): −1 level, break possible only from +8 (no protection item yet).
    - **Not tested** (neither bag nor garage). Watch: script errors, prompt visibility, body kit piece positions on the car, tuning costs vs current scrap income (use key 8 for +1000 scrap).
    - **Next mechanic after testing: Nitro Dash** (not started).

36. **Bug report (user, error log):** `car_controller.gd:725 @ _align_body(): The axis Vector3 (0.992168, 0.0, 0.114362) must be normalized` (from `Basis.set_axis_angle`).
    - Cause: `_up.slerp(target_up, t)` builds its rotation axis from `cross(_up, target_up)`. When the two are almost equal (e.g. flat ground) the cross is ~zero and the normalized axis comes out slightly off (length 0.9975), so Godot rejects it. Old latent bug, not from the garage/bag code.
    - Fix: normalized lerp instead of slerp (skipped if the blend is ~zero) in `car_controller._align_body` and the same pattern in `enemy.gd` ground snap. **Rule: don't use Vector3.slerp for smoothing up vectors; use lerp + normalized.**
    - Not re-tested.

37. **User request:** "okay let's add nitro dash."
    - Built step 3 (How Systems Work → Phase 4 step 3): new `vehicles/nitro_dash.gd`; `car_controller.gd` (`nitro`, `boost_hold` pauses over-speed drag); `chase_camera.gd` (`kick_fov`); `input_setup.gd` (`nitro` = Shift / pad B); `item_db.gd` (Nitro main stat → Nitro Recharge; nitro_regen / nitro_power affixes); `equipment.gd` (regen_mult / power_mult); `player_hud.gd` (nitro bar); `bag_screen.gd` (stats lines); `debug_overlay.gd` (help: 6/7/8, Shift, I, F).
    - Design choices made by default (tell me to change): forward-only burst, 2 dashes from a full meter, drifting refills faster (GAME_DESIGN combat idea "drifting charges a meter"), air dash allowed, **no i-frames**.
    - **Not tested.** Watch: dash strength (16 m/s ≈ +58 km/h), how long the extra speed lasts, flame position at the rear bumper, whether drift-charging feels noticeable.

38. **Bug report (user):** `car_controller.gd:174 - Parse Error: Could not find type "NitroDash" in the current scope` (and :222).
    - Cause: the new `class_name NitroDash` script was created outside the editor and the editor's global class cache hadn't registered it yet, so `car_controller.gd` (which every scene needs) failed to parse.
    - Fix: `car_controller.gd` now uses `const NitroDashScript := preload("res://scripts/vehicles/nitro_dash.gd")` for the type and `.new()`. **Rule: core scripts that everything depends on should preload new helper scripts by path instead of relying on a fresh class_name.** If "Could not find type X" appears for another new class: Project → Reload Current Project rebuilds the cache.
    - Not re-tested.

39. **Feedback #11:** after "what is the next step" (test bag/garage/nitro first), the user said: "happy now". **Phase 4 steps 1–3 accepted** (bag, garage, nitro dash, plus the slerp and NitroDash preload fixes). Committed and pushed as commit 5 (`1fc1f95`). No tuning changes requested. Next step waits on the user's go-ahead (proposed: levels/EXP/scrap).

**Not done / known unknowns**
- Phase 3 + feedback #9 changes: the user played and says the direction is OK, but no detailed tuning feedback yet. Likely tuning: enemy speeds and damage, leash ranges, the boss's difficulty, loot amounts, enemies getting stuck on dunes or walls (straight-line chasing, no pathfinding).
- Not in scope yet: threat tables for parties, looter behavior, enemy pathfinding, "not in view" spawn check (only distance), enemy sounds. Watch: rocket explosion visuals (transparent sphere + light in Compatibility), rocket self-hits near the car (the shooter is excluded, but rockets exploding on close ground still look fine?), swap feel, number colors.
- Camera terrain collision isn't done (it may clip into dunes).

**Open questions**
- Game title (ideas: Wasteland Drive Online, Rust & Nitro, Dune Runners).
- Keep power-over drift entry? (Now requires a 0.5 s hold.)
- Car model source when it's time: Kenney Car Kit (CC0), own Blender model, or an artist.
