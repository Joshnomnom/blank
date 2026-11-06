# Vehicle Ground Physics: Research Notes

> Written 2026-11-06 (Session 1), after the feedback round-4 ground system left the car stuck
> ("I'm not even driving now"; screenshots: car hovering, then pitched nose-down, not moving).
> Topic: how arcade car games keep a car on the ground over slopes, ramps and jumps,
> the pitfalls, and what we chose. Companion to [CAR_PHYSICS_RESEARCH.md](CAR_PHYSICS_RESEARCH.md) §6 (suspension)
> and [DRIVING_GAME_FEEL.md](DRIVING_GAME_FEEL.md).

---

## 1. The four common approaches

| Approach | How it works | Pros | Cons | Examples |
|---|---|---|---|---|
| **A. Kinematic + ground rays** ("hover/snap") | Your own code moves a kinematic body. Rays down from the wheels find the ground: snap the height to it and align the up-vector to the hit normals. A grounded flag decides drive vs fly. | Fully controllable, stable, deterministic (good for netcode), cheap | You write jumps, landing and slopes yourself; edge cases need care | KidsCanCode "3D Kinematic Car: Slopes & Ramps" (Godot); **our current approach** |
| **B. RigidBody + raycast spring suspension** | One rigid body. Per wheel: ray → spring-damper force at the contact point, plus traction/steering forces from the wheel's velocity. Physics handles gravity, pitch, roll and jumps. | Natural weight, bounce, landings and rollovers | Harder to tune, jitter at low speed, not deterministic, our drift controller would have to become forces | Very Very Valet (Toyful Games, Unity); GDSim devlog (Godot) |
| **C. Sphere car** | A physics sphere rolls around (rolling handles slopes and bumps); the car mesh follows the sphere and is aligned to the ground normal. | Very simple, robust on terrain | Floaty or "marble" feel, little control over the details | KidsCanCode "Arcade-style Car" (Godot 4) |
| **D. Built-in VehicleBody3D** | The engine's raycast vehicle | Quick start | Hard to make arcade/drifty; the docs and community call it limited | Godot VehicleBody3D |

### Approach B math (for reference / if we ever switch)
Per wheel, ray down from the mount point, rest length `L0`:
```
compression x = L0 − hit_distance        (0 if no hit → wheel in the air)
spring  F_s = k · x                       (zero force at rest length: Hooke's law on the DISPLACEMENT)
damper  F_d = c · (dx/dt)                 (without damping the car bounces forever)
F = max(F_s + F_d, 0) along the contact normal, applied at the wheel position
k = m_corner · (2π·f)²   (f ≈ 1.5–2.5 Hz)     c = 2·ζ·√(k·m_corner)   (ζ ≈ 0.3–0.7)
```
- One forum rule of thumb: `damping ≈ 6·√stiffness` (a single user's tuning, not a standard).
- Run the raycasts in the **physics step**, not per rendered frame, or it wiggles.
- "Too bouncy" → more damping, less stiffness. "Floats" → raise the gravity scale.
- Traction (Very Very Valet style): sideways force = −(wheel lateral velocity) × grip × mass share / dt.

---

## 2. Pitfalls found in the research (and which ones bit us)

| # | Pitfall | Source | Bit us? |
|---|---|---|---|
| 1 | **The chassis collider hits the ground or ramp before the wheel rays register it**, so the rays "miss" and the body gets blocked. Fix: the body collider **doesn't collide with the ground layer**, or use a simplified ground collider. | Unity forum, arcade car physics | **YES**, the main cause (§3) |
| 2 | **In the air, don't rotate the car toward the ground or flight path at low speed.** KidsCanCode: "when neither wheel is on the ground, the car doesn't rotate at all". | KidsCanCode kinematic car | **YES**: we pitched toward the flight path even at speed 0, so falling straight down meant nose straight down |
| 3 | A **missing ray hit** must not be read as "the ground is far below" in a way that flips states every frame. KidsCanCode assumes horizontal ground for a missing wheel. | KidsCanCode | partly |
| 4 | "Grounded" should be a robust state: **coyote time** (stay grounded a few ms after losing contact), landing tolerance, landing delay | Kinematic controller docs (flutter_scene), forums | partly |
| 5 | A floating/hover body never reports `is_on_floor()`, so logic gated on it silently fails | forum note on a floating character | Yes in round 3 (we used `is_on_floor()` while sliding along slopes, which caused flicker); fixed in round 4 by the rays |
| 6 | No damping → endless bounce | VVV summary, Roblox threads | not yet (we have no springs) |
| 7 | Raycasts outside the physics step → jitter | Roblox thread | no (we raycast in `_physics_process`) |

---

## 3. Our bug (feedback round 5): what happened, step by step
1. Spawn at y = 0.3 in "air" state; the car falls.
2. `_align_body()` in the air pitched the nose toward the flight path: `atan2(vertical_speed, max(|speed|, 1)) × 0.6`. At speed 0 that's ≈ −45° or more, so the **nose tipped down while falling**.
3. Nose-down by ~18°, the front-bottom corner of the collision box (local y +0.4, z −2.2) is ~0.3 m **below** the car origin, so it touched the ground first (the body collided with the terrain).
4. `move_and_slide()` stopped the fall at origin ≈ 0.3 m. The landing test (`y ≤ ground + 0.02`) never passed, so the car **stayed "in the air" forever**: no throttle (air mode), the nose kept tipping, and the box kept propping it up.
5. Result: screenshot 1 (pitched nose-down) and screenshot 2 (hovering ~0.3 m), and the car can't drive.

---

## 4. Decision: keep approach A (kinematic + rays), make it robust

**Why not switch to B (RigidBody springs)?**
- Our drift-angle controller, speed-keeping turns and all the tuning are kinematic. B would mean re-doing them as forces, which is a big rewrite with new tuning problems (low-speed jitter, bounce).
- A is deterministic and simple, which matters later for server-authoritative multiplayer (research doc §10).
- The failures were **specific, known pitfalls** (§2 #1 and #2), not a flaw of the approach.
- **Weight and bounce can be faked visually** with a spring on the *model only* (no gameplay effect). That gives most of B's feel.

**Fixes applied:**
1. **Collision layers:** terrain and flat ground → **layer 2 (ground)** only. The car body's `collision_mask` = layer 1 only, so **the chassis never touches the ground**; only the wheel rays do (mask 1+2). Walls are layer 1. Ramps are layers 1+2 (rays stand on them, and the body still hits their vertical back faces).
2. **Air rotation:** flight-path pitch is scaled by horizontal speed (0 when slower than ~8 m/s) and clamped to ±25°. Slow or straight-down falls stay level.
3. **Landing tolerance:** land when within 0.05 m (was 0.02) while falling, or whenever below the ground.
4. **No take-off at low speed:** the "ground falls away faster than gravity" launch only counts above 3 m/s, so crawling over bumps never launches.
5. **Visual landing suspension:** a damped spring on the model's body (not gameplay). It dips on landings proportional to fall speed and settles (~ζ 0.6).

**If A still isn't good enough** (e.g. we want real bouncy off-road suspension for jeeps), the plan is a **hybrid**: keep A for the horizontal and drift logic, and add a per-wheel visual spring (wheels move up and down independently, body follows). That's still not physics-driven.

---

## 5. Sources
- KidsCanCode, 3D Kinematic Car: Slopes & Ramps: https://kidscancode.org/godot_recipes/3.x/3d/kinematic_car/car_slopes/index.html
- KidsCanCode, Arcade-style Car (sphere car, Godot 4): https://kidscancode.org/godot_recipes/4.x/3d/3d_sphere_car
- Unity forum, how to achieve arcade car physics (chassis hitting ramps before rays): https://discussions.unity.com/t/how-to-achive-this-type-of-arcade-car-physics/854777
- Unity forum, Arcade Kart Physics: https://discussions.unity.com/t/arcade-kart-physics/498149
- Very Very Valet car physics (summary of the Toyful Games video): https://opentools.ai/youtube-summary/making-custom-car-physics-in-unity-for-very-very-valet
- GDSim devlog, Suspending a RigidBody I & II: https://lupine-vidya.itch.io/gdsim/devlog/677580/workshop-i-suspending-a-rigidbody-mirror , https://lupine-vidya.itch.io/gdsim/devlog/677582/workshop-ii-suspending-a-rigidbody-part-2-mirror
- Godot raycast suspension tutorial (itch.io): https://red-bone-game-studio.itch.io/supension-tutorial-godot
- Rapier character controller (slopes, snapping): https://rapier.rs:443/docs/user_guides/javascript/character_controller
- flutter_scene ThirdPersonControllerComponent (ground snap, coyote time, landing delay): https://pub.dev/documentation/flutter_scene/latest/kit/ThirdPersonControllerComponent-class.html
- Roblox DevForum, In Depth Scripted Car Physics: https://devforum.roblox.com/t/in-depth-scripted-car-physics/3915628
- Roblox DevForum, Car Suspension (Scripted) (damping rule of thumb): https://devforum.roblox.com/t/car-suspension-scripted/92283?page=2
- Roblox DevForum, raycast suspension and inclines: https://devforum.roblox.com/t/raycast-suspension-car-does-not-keep-up-with-inclines/2796848
- Roblox DevForum, suspension bouncing out of control: https://devforum.roblox.com/t/raycast-suspension-acting-weird-and-starts-bouncing-out-of-control-when-player-is-on-top-of-car/2024987
