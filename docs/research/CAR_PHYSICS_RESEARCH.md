# Car Driving Physics: Research Notes

> Purpose: reference for building and upgrading our car handling. Written 2026-11-06 (Session 1).
> Focus: **arcade feel for a top-down combat/farming MMO on the web**, not a racing simulator.
> Read **§0** and **§12** first if you only want the conclusions.

---

## 0. TL;DR

1. Car physics models range from **kinematic arcade** (what we have now) to a **force-based bicycle model** to **full simulation** (Pacejka tires, slip ratio, drivetrain, suspension).
2. For our game (combat first, many cars on screen, web, server-authoritative multiplayer later), **stay in custom-integrated arcade/semi-arcade territory**. Don't use a full sim.
3. The best upgrade path is a **"bicycle-lite" model**: keep `CharacterBody3D` for collisions, but give the **front and rear axles separate grip**. Drift and oversteer then come naturally from physics instead of a hand-made "drift mode", with arcade assists on top.
4. **Suspension can be fake.** Visual body roll/pitch (already in place) and, later, raycasts for wheel height on slopes. Real spring physics isn't needed for gameplay.
5. **Surfaces** (road vs sand) = per-surface multipliers on grip, rolling resistance and top speed.
6. A **custom deterministic-ish integrator in GDScript** is good for networking later. Godot's RigidBody/VehicleBody physics isn't deterministic across machines.

---

## 1. Coordinate frames and basic quantities

**World frame:** Godot uses Y up and −Z forward.
**Car (local) frame**, used in all formulas here:
- `vx` = forward speed (along the car's nose)
- `vy` = lateral speed (sideways), **positive to the LEFT**
- `r` = yaw rate (rad/s), **positive = turning LEFT** (same as Godot's `rotate_y` positive)
- `δ` (delta) = front wheel steering angle, positive = steer left

Converting in Godot:
```gdscript
var fwd  := -global_basis.z        # car forward
var left := -global_basis.x        # car left
var vx := velocity.dot(fwd)
var vy := velocity.dot(left)
# back to world:
velocity = fwd * vx + left * vy  (+ vertical part)
```

**Car geometry symbols**
| Symbol | Meaning | Typical sedan |
|---|---|---|
| m | mass | 1200–1500 kg |
| L | wheelbase (front axle to rear axle) | 2.6–2.8 m |
| a | center of gravity (CG) to front axle | ~1.25 m |
| b | CG to rear axle | ~1.45 m (L − a) |
| h | CG height | 0.45–0.55 m |
| Iz | yaw inertia (resistance to rotating) | ≈ m·(L/2)² ≈ 2000–3000 kg·m² |
| R | wheel radius | 0.30–0.36 m |
| track | left–right wheel distance | 1.5–1.6 m |

Our placeholder sedan: wheelbase 2.7 m (wheels at z = ±1.35), wheel radius 0.36, track 1.72.

---

## 2. The model ladder (from simplest to most realistic)

| Level | Name | How it works | Pros | Cons | Fits us? |
|---|---|---|---|---|---|
| 1 | **Kinematic arcade** (ours now) | Velocity is split into forward and sideways. Grip pulls sideways speed to 0. Steering sets the yaw rate directly. A drift is a state with lower grip. | Simple, stable, very tunable, cheap, easy to network | Drift feels "scripted". No natural oversteer or understeer. | ✅ Phase 0 |
| 2 | **Bicycle-lite** (semi-arcade) | Front and rear axles each have a slip angle and a lateral force with a grip limit. Yaw comes from torque. Drive force eats rear grip. | Natural drift, power oversteer, counter-steer, weight feel. Still cheap. | More tuning, needs low-speed handling | ✅ Recommended upgrade |
| 3 | **Raycast rigid body** | RigidBody plus 4 wheel raycasts. Spring-damper suspension, per-wheel tire forces. | Great on rough terrain, jumps, rollovers | Jittery at low speed, harder to tune, not deterministic, more expensive | ⚠️ Maybe for special vehicles, not the core |
| 4 | **Full sim** | Pacejka tires, slip ratio, wheel spin, engine/clutch/gearbox, differential, tire load sensitivity | Realistic | Needs small timesteps and is unstable at low speed. Overkill. Hard on web. | ❌ |

Classic reference for levels 2 and 4: **Marco Monster, "Car Physics for Games"** (2003). It's a 2D model that separates longitudinal and lateral forces and uses slip angles with a capped linear tire. Developers note its slip-ratio part is unstable at low speed and some implementations "do backflips". Use it for the concepts and its constants table, not as code to copy.

---

## 3. Tires: where all handling comes from

A tire makes force only when it **slips** a little.

### 3.1 Slip angle (lateral)
The angle between where the wheel **points** and where it's **actually moving**.

Bicycle model (one wheel per axle):
```
α_front = atan2(vy + a·r, |vx|) − δ·sign(vx)
α_rear  = atan2(vy − b·r, |vx|)
```
- `vy + a·r`: the front axle's sideways speed (the car's own slide plus the yaw rotation pushing the nose sideways)
- `vy − b·r`: the rear axle's sideways speed
- Our current code computes one slip angle for the whole car: `atan2(|lateral|, |forward|)`. That's the "body slip angle" β, fine for drift detection.

### 3.2 Lateral force vs slip angle (the tire curve)
Force grows roughly **linearly** with small slip, **peaks** around **5–10°** (road tires), then **falls off a bit** as the tire slides.

Options, from simplest:

**(a) Capped linear** (Marco Monster)
```
Fy = clamp(−Cα · α, −μ·Fz, +μ·Fz)
```
- `Cα` = cornering stiffness. For game tuning it's easier to normalize: `Fy = μ·Fz · clamp(−α / α_peak, −1, 1)`
- Simple and stable, but there's no "falloff", so slides feel sticky and binary.

**(b) Linear + falloff (recommended for us)**
```
x = |α| / α_peak
k = x            if x <= 1
k = lerp(1, slide_ratio, smoothstep(1, 3, x))   if x > 1   # e.g. slide_ratio 0.75
Fy = −sign(α) · μ · Fz · k
```
- `slide_ratio` < 1 means grip drops once sliding. **This is what makes drifts feel like drifts**: once the tire breaks loose it holds less, so the car keeps sliding until you correct.

**(c) Pacejka "Magic Formula"** (real-tire fit)
```
F = D · sin( C · atan( B·x − E·(B·x − atan(B·x)) ) )
```
- x = slip angle (or slip ratio), D = peak force = μ·Fz
- B = stiffness, C = shape, E = curvature
- Example values from the literature: dry asphalt B≈10, C≈1.9, D≈1.0 (normalized); snow B≈12, C≈2.3, D≈0.82
- Typical lateral C ≈ 1.3, longitudinal C ≈ 1.65. Some fits cap C ≤ 1.5 and E ≤ 1.1 so the curve doesn't fall back toward 0 at high slip.
- **Verdict:** game devs agree "this level of accuracy isn't that important" as long as it plays well. Option (b) gets ~90% of the feel. Pacejka can be used later as a lookup curve (`Curve` resource) if we want it.

**Godot tip:** a tire curve can be a `Curve` resource exported in the inspector (x = slip / α_peak, y = grip factor). Designers can then draw the curve.

### 3.3 Slip ratio (longitudinal: wheelspin and lockup)
```
κ = (ω·R − vx) / max(|vx|, v_min)
```
ω = wheel angular speed. κ > 0 is wheelspin, κ < 0 is braking lockup.
- Needed only if we simulate wheel rotation separately (burnouts, launch control for drag racing).
- **Unstable at low speed** (dividing by near-zero). Fixes: a minimum speed, or the "relaxation length" filter (§9.2).
- **For us:** skip true slip ratio. Fake wheelspin and burnout visually (smoke, wheel spin speed) and use a launch-boost minigame for drag racing later.

### 3.4 Friction circle (combined grip)
A tire has a **total grip budget**:
```
sqrt(Fx² + Fy²) ≤ μ·Fz
```
- Accelerating or braking hard leaves less sideways grip.
- **This is the physics of power oversteer.** A rear-wheel-drive car on full throttle uses rear grip for drive, the rear loses sideways grip, the tail slides out, and you get a drift.
- Simple game version:
```
Fy_max_rear = sqrt(max((μ·Fz_rear)² − Fx_drive², 0))
```
- The **friction ellipse** variant lets sideways and forward limits differ. It's a common tuning lever.

### 3.5 Load (normal force Fz) and weight transfer
Static load per axle:
```
Fz_front = m·g · b / L
Fz_rear  = m·g · a / L
```
Longitudinal weight transfer (accelerating shifts weight to the back, braking to the front):
```
ΔFz = m · ax · h / L
Fz_front −= ΔFz,  Fz_rear += ΔFz
```
- Braking into a corner gives more front grip and less rear grip, so the tail gets light and is easy to rotate. This is the **"brake to initiate drift" / Scandinavian flick** behaviour, for free.
- Lateral transfer (left/right) mainly matters for per-wheel models. Skip it in bicycle-lite and fake it with visual roll.
- **Smooth `ax`** before using it (low-pass filter), otherwise grip oscillates.

### 3.6 Load sensitivity (optional)
Real tires: doubling the load gives less than double the grip. `μ_eff = μ · (Fz / Fz_nominal)^(-0.1…-0.2)`. Ignore for now.

---

## 4. Bicycle model equations (level 2)

Per physics tick (dt = 1/60):

```
# 1. Local velocities
vx, vy, r  (from velocity and stored yaw rate)

# 2. Loads with weight transfer
Fzf = m·g·b/L − m·ax_smoothed·h/L
Fzr = m·g·a/L + m·ax_smoothed·h/L

# 3. Slip angles
αf = atan2(vy + a·r, |vx|) − δ·sign(vx)
αr = atan2(vy − b·r, |vx|)

# 4. Lateral forces (tire curve, §3.2)
Fyf = tire_curve(αf) · μf · Fzf
Fyr = tire_curve(αr) · μr · Fzr

# 5. Longitudinal forces
Fx_drive = throttle · engine_force(vx)           (rear wheels for RWD)
Fx_brake = −sign(vx) · brake · brake_force
Fx_res   = −C_rr·vx − C_drag·vx·|vx|            (rolling + air)

# 6. Friction circle on the driven axle
Fyr = clamp(Fyr, −sqrt((μr·Fzr)² − Fx_drive²), +sqrt(...))

# 7. Totals in the car frame
Fx_total = Fx_drive + Fx_brake + Fx_res − Fyf·sin(δ)
Fy_total = Fyf·cos(δ) + Fyr
torque   = a·Fyf·cos(δ) − b·Fyr

# 8. Integrate
velocity_world += (fwd·Fx_total + left·Fy_total) / m · dt
r += torque / Iz · dt
rotate_y(r · dt)
move_and_slide()
```

Sign check (with y and r positive to the left): steering left (δ>0) at speed gives αf ≈ −δ, so Fyf > 0 (pushes left) and torque > 0 (turns left). ✓ As the car rotates left, the rear sees αr < 0, so Fyr > 0 (left). Both axles supply the centripetal force. ✓

**Integrating in the world frame** (step 8) avoids the Coriolis terms you need in the body frame (`v̇x = Fx/m + r·vy`, `v̇y = Fy/m − r·vx`). Rotating the car with `rotate_y` automatically makes the old velocity become slip. That's the same trick our current code uses.

### Understeer vs oversteer: the balance knob
- Front saturates first (front force maxed) → **understeer** (car pushes wide). Safe and boring.
- Rear saturates first → **oversteer** (tail slides) → drift.
- Main tuning levers: `μf` vs `μr`, `a` vs `b` (weight distribution), drive type (RWD = more oversteer), `slide_ratio` on the rear.
- **For a drift-friendly arcade car:** rear grip slightly below front, RWD, rear `slide_ratio` around 0.7, plus assists (§7).

### Low-speed problem (important)
At |vx| → 0, slip angles become noisy (atan2 of tiny numbers) and the car jitters or spins in place.
**Fix: blend to a kinematic model at low speed:**
```
r_kinematic = vx · tan(δ) / L          # pure geometric turning, no slip
blend = smoothstep(1.0, 4.0, |vx|)     # m/s
r = lerp(r_kinematic, r_dynamic, blend)
vy *= lerp(0.0, 1.0, blend)            # kill sideways slide when nearly stopped
```
Every shipped car game does something like this.

---

## 5. Engine, gears, resistance

### 5.1 Simple (what arcade games really need)
```
engine_force(v) = F_max · force_curve(v / v_max)     # Curve resource: strong low, weaker high
```
Top speed comes naturally where drive force = resistance, or set a hard cap.

### 5.2 Realistic drivetrain (only if we want gear-shifting gameplay, e.g. drag racing)
```
rpm          = (vx / R) · gear_ratio · diff_ratio · 60 / (2π)
wheel_torque = engine_torque(rpm) · gear_ratio · diff_ratio · efficiency
F_drive      = wheel_torque / R
```
Example values from Marco Monster: gears 2.66 / 1.78 / 1.30 / 1.00 / 0.74 / 0.50, reverse 2.90, differential 3.42, efficiency 0.7, rpm range ~1000–6000, peak torque ~400 N·m around 4400 rpm.
- Auto-shift: shift up at ~90% of max rpm, down below ~40%.
- **Drag-racing minigame** (later): manual shift-timing windows and launch rpm. This model is ideal for that, and it can live **only in the drag mode**.

### 5.3 Resistance
```
F_drag    = −C_drag · v · |v|     C_drag = 0.5 · ρ(1.29) · Cd(~0.3) · A(~2.2 m²) ≈ 0.43
F_rolling = −C_rr · v            C_rr ≈ 30 · C_drag ≈ 12.8 (on road)
```
- Rolling resistance dominates at low speed and air drag at high speed.
- **Sand** = much higher C_rr (×3–5). This is the main thing that makes sand feel heavy.

---

## 6. Suspension (raycast spring-damper)

Used by level-3 models. For us it's useful mainly for **visual wheel placement on bumpy terrain**.

Per wheel, cast a ray down from the mount point:
```
compression    = rest_length − hit_distance           (0 if no hit)
spring_force   = k · compression
damper_force   = c · (compression − last_compression) / dt
F_suspension   = max(spring_force + damper_force, 0) along the surface normal
```
**Choosing k and c** (per wheel, corner mass m_c = m/4 ≈ 300 kg):
- Natural frequency target **f = 1.5–2.5 Hz** (higher = sportier)
- `k = m_c · (2π·f)²`. At f = 2 Hz, k ≈ 47,000 N/m
- Damping ratio **ζ = 0.3–0.7**: `c = 2·ζ·sqrt(k·m_c)`. At ζ = 0.5, c ≈ 3,800 N·s/m
- Separate **bump** (compression) and **rebound** damping helps. Rebound is usually ~1.5× bump.
- **Anti-roll bar**: `F = (comp_left − comp_right) · k_arb`, added to one side and subtracted from the other.
- Without damping, the car bounces forever. This is the #1 beginner bug.
- Grip in raycast cars: the tire's sideways force is often just `−lateral_velocity_at_wheel · grip · mass_share / dt`, capped. It's simple but can jitter at low speed, which is why some Godot devs moved to other approaches.

**Our plan:** keep the car body on a `CharacterBody3D`. Later, for slopes and dunes, use 4 raycasts **only to place the visual wheels and tilt the body** to the ground normal. No spring simulation affects gameplay.

---

## 7. Arcade assists (the "secret sauce" of fun handling)

Real physics alone feels twitchy. Shipped arcade games layer helpers on top:

| Assist | What it does | How |
|---|---|---|
| **Speed-sensitive steering** | Less steering at high speed so the car doesn't twitch | `δ_max = lerp(δ_low, δ_high, speed/v_max)` (we have this) |
| **Steering smoothing** | Keyboard 0/1 becomes analog | `move_toward(steer, target, rate·dt)` (we have this) |
| **Yaw damping** | Stops endless spinning | `r *= exp(−yaw_damp · dt)`, stronger when no steering input |
| **Counter-steer assist** | Makes catching a drift easy | When steering against the slide, temporarily raise rear grip or add a corrective torque |
| **Max slip angle cap** | No spin-outs | Clamp β (we have this, at 55°) |
| **Drift angle "sweet spot" assist** | Holds a stylish 25–45° drift | Small torque toward a target angle while drifting with throttle held |
| **Throttle-steer in drift** | Throttle swings the tail out further, lifting off tucks it in | Scale rear grip by throttle while drifting (we have a version) |
| **Speed retention in drift** | Drifting shouldn't kill all speed | Reduce scrub, or rotate part of the velocity toward the heading instead of deleting it |
| **Handbrake** | Instant drift entry | Rear grip × 0.3–0.5 and extra rear drag (we have whole-car low grip) |
| **Stability control at high speed** | Fast straights feel planted | Extra grip / yaw damping when not steering |
| **Air control** | Jumps feel good | Small yaw/pitch control in the air, auto-level before landing |
| **Collision forgiveness** | Hitting walls isn't miserable | Keep the along-wall velocity, lose only the into-wall part, small bounce; optionally auto-align to the wall |
| **Coyote steer** | Responsive reversing | Swap steer sign when vx < 0 (we have this) |

**Drift keys** (common arcade recipe):
- **Entry:** handbrake tap, a brake-then-turn weight shift, or a hard turn at high speed with throttle (power oversteer).
- **Hold:** throttle and steering control the angle. Rear grip is low but not zero, and grip falls off once sliding.
- **Exit:** counter-steer or lift off throttle, and grip ramps back up smoothly (not instantly, or the car "snaps").
- **Rewards:** drift charge for skills and boost (already planned in the design doc). The `drift_started` / `drift_ended` signals exist for this.

---

## 8. Surfaces (road vs sand vs others)

Per-surface multipliers (looked up from the ground's collider: physics material, group, or metadata):

| Surface | μ (grip) | Rolling resistance ×| Top speed × | Slide ratio | Notes |
|---|---|---|---|---|---|
| Asphalt road | 1.0 | 1 | 1.0 | 0.75 | Fast, grippy |
| Broken road | 0.9 | 1.3 | 0.95 | 0.75 | Small bumps |
| Packed dirt | 0.75 | 1.8 | 0.9 | 0.7 | Easy drifts |
| Sand | 0.6 | 3–5 | 0.7 | 0.65 | Heavy, slow, dust; jeeps get a bonus |
| Salt flat | 0.85 | 1 | 1.05 | 0.6 | Very fast, slidey |
| Mud / oil slick (weapon) | 0.3 | 2 | 0.8 | 0.5 | Combat effect |

**Per-chassis terrain modifiers** (from the RPG design): jeep has sand rolling ×0.5 and sand μ +0.2; muscle car has road speed +10% and sand rolling ×1.3. This is a cheap way to give each car type an identity.

How to detect: after `move_and_slide()`, use `get_last_slide_collision()` or a short raycast down. Read the collider's metadata (`surface = "sand"`) or group. Smooth changes over ~0.2 s so crossing a road edge isn't jarring.

---

## 9. Numerical stability and timestep

### 9.1 Fixed timestep
- Always simulate in `_physics_process` at a fixed rate (60 Hz now). Render smoothness comes from **physics interpolation** (enabled).
- Explicit Euler is fine for arcade models. Stiff systems (raycast springs, Pacejka) may need **substeps** (2–4 per tick) or semi-implicit Euler (update velocity first, then position with the new velocity).

### 9.2 Relaxation length (smooths tire forces)
Instead of an instant slip angle, let the tire "catch up":
```
α_state += (|vx| / σ) · (α_target − α_state) · dt     σ ≈ 0.3–1.0 m
```
This removes low-speed jitter and gives a natural ramp into slides.

### 9.3 Exponential smoothing (frame-rate independent)
```
x = lerp(x, target, 1 − exp(−rate · dt))
```
We already use this for grip and camera.

### 9.4 Clamp everything
Max yaw rate, max slip angle, max force per tick. A single bad frame (collision spike) shouldn't launch the car.

---

## 10. Multiplayer implications (future phases 6–7)

- **Server-authoritative:** the server runs the car simulation from player inputs. Clients predict locally and correct ("client-side prediction + reconciliation").
- Prediction needs the **same simulation on client and server**. Our custom GDScript integrator is good for this: the same code, fixed tick and plain math give "close enough" determinism for reconciliation. Godot RigidBody/Jolt physics isn't deterministic across machines, so it's hard to reconcile.
- **Input packet** per tick: throttle, brake, steer (quantized to a byte each), handbrake, plus later fire and skill. Tiny.
- **Other players' cars**: interpolate between server snapshots (100–150 ms buffer). Don't simulate them.
- **Enemy vehicles (AI)**: use a cheaper level-1 kinematic model. They don't need drifting physics.
- Keep the car simulation as a **pure function-like step** (`simulate(state, input, dt) -> state`) where possible. This makes the later network refactor much easier. Worth doing when we upgrade to bicycle-lite.

---

## 11. Web performance notes

- GDScript math for 1 player car is negligible. 50 cars in a zone is still fine with level-1/2 models.
- Raycasts: 4 per car are cheap. Avoid per-wheel shape casts for many cars.
- Avoid substeps for remote and AI cars, which use interpolation or the simple model anyway.
- Compatibility renderer: draw calls matter more than physics. Combine car meshes once we have real models.

---

## 12. Recommendation for our game

| Stage | When | What |
|---|---|---|
| **A (now)** | Phase 0 | Keep the current **level-1 kinematic** controller and tune it from play-testing. It's stable and good enough to judge the camera and basic feel. |
| **B** | When level 1 feels limiting (likely after the first tuning pass) | Upgrade to **bicycle-lite (level 2)**: separate front/rear grip, tire curve with falloff, friction circle on the rear, smoothed weight transfer, low-speed kinematic blend, yaw damping, and drift assists (§7). Remove the hard "drift mode" grip switch and let drift come from the physics; keep drift *detection* for rewards. |
| **C** | Phase 1 (terrain) | Surface multipliers (§8), ground normal alignment for slopes, raycasts for visual wheels. |
| **D** | Phase 4 (RPG) | Map RPG stats to physics params: Power → engine force, Handling → turn rate and grip, Armor → mass (heavier rams harder, accelerates slower), chassis → weight distribution and drive type. |
| **E** | Phase 6 (multiplayer) | Refactor into `simulate(state, input, dt)` for prediction and reconciliation. |
| **Drag mode only** | Phase 8 | Gears/rpm drivetrain (§5.2) inside the drag minigame. |

**Not recommended:** full Pacejka + slip ratio + per-wheel suspension for the main game. It's costly to tune, unstable at low speed, bad for networking and web performance, and not what a combat MMO needs.

### Bicycle-lite: suggested parameters to start from (sedan)
```
mass 1300 kg, wheelbase 2.7 m, a 1.25, b 1.45, h 0.5, Iz 2400
μ_front 1.05, μ_rear 0.95, α_peak 8°, slide_ratio_front 0.85, slide_ratio_rear 0.7
F_drive_max ≈ 9000 N (≈ 7 m/s² launch), RWD
C_drag 0.43, C_rr 12.8
yaw_damp 2.0, low-speed blend 1–4 m/s
handbrake rear μ × 0.35
```

### Bicycle-lite sketch in GDScript (for Stage B)
```gdscript
func _physics_process(dt: float) -> void:
	var fwd := -global_basis.z; fwd.y = 0; fwd = fwd.normalized()
	var left := -global_basis.x; left.y = 0; left = left.normalized()
	var vx := velocity.dot(fwd)
	var vy := velocity.dot(left)

	var steer := steer_input * max_steer_angle * lerpf(1.0, high_speed_steer, clampf(absf(vx) / v_max, 0, 1))

	# weight transfer (ax_smooth updated from last tick's forward accel)
	var dFz := mass * ax_smooth * cg_height / wheelbase
	var Fzf := mass * G * b / wheelbase - dFz
	var Fzr := mass * G * a / wheelbase + dFz

	# slip angles
	var vx_safe := maxf(absf(vx), 0.5)
	var alpha_f := atan2(vy + a * yaw_rate, vx_safe) - steer * signf(vx)
	var alpha_r := atan2(vy - b * yaw_rate, vx_safe)

	var mu_r := mu_rear * (handbrake_mult if handbrake else 1.0)
	var Fyf := -signf(alpha_f) * mu_front * Fzf * tire_curve(absf(alpha_f), slide_front)
	var Fyr := -signf(alpha_r) * mu_r * Fzr * tire_curve(absf(alpha_r), slide_rear)

	var Fx := throttle * engine_force(vx) - signf(vx) * brake * brake_force
	Fx += -c_rr * vx - c_drag * vx * absf(vx)

	# friction circle on the rear (RWD)
	var rear_cap := sqrt(maxf(pow(mu_r * Fzr, 2) - Fx * Fx, 0.0))
	Fyr = clampf(Fyr, -rear_cap, rear_cap)

	var fx_total := Fx - Fyf * sin(steer)
	var fy_total := Fyf * cos(steer) + Fyr
	var torque := a * Fyf * cos(steer) - b * Fyr

	# integrate
	var accel_world := (fwd * fx_total + left * fy_total) / mass
	velocity.x += accel_world.x * dt
	velocity.z += accel_world.z * dt
	yaw_rate += torque / yaw_inertia * dt

	# low-speed kinematic blend + assists
	var blend := smoothstep(1.0, 4.0, absf(vx))
	yaw_rate = lerpf(vx * tan(steer) / wheelbase, yaw_rate, blend)
	yaw_rate *= exp(-yaw_damp * dt)
	ax_smooth = lerpf(ax_smooth, fx_total / mass, 1.0 - exp(-8.0 * dt))

	rotate_y(yaw_rate * dt)
	move_and_slide()

func tire_curve(x_abs: float, slide_ratio: float) -> float:
	var x := x_abs / alpha_peak
	if x <= 1.0:
		return x
	return lerpf(1.0, slide_ratio, smoothstep(1.0, 3.0, x))
```
This sketch is untested. Expect sign or tuning fixes when we implement it. Gravity, the floor and reset are omitted for brevity.

---

## 13. Glossary

- **Slip angle (α):** angle between where a tire points and where it moves.
- **Body slip angle (β):** the same for the whole car (heading vs travel direction). This is the "drift angle".
- **Slip ratio (κ):** how much a wheel spins faster or slower than the road speed.
- **Cornering stiffness (Cα):** how much sideways force per degree of slip, before the peak.
- **Friction circle:** the total grip shared between accelerating, braking and turning.
- **Understeer:** the front loses grip first, so the car goes wider than steered.
- **Oversteer:** the rear loses grip first, so the tail slides out (drift).
- **Power oversteer:** throttle uses up rear grip, so the tail slides.
- **Weight transfer:** load shifts front/back (and side to side) with acceleration, changing grip.
- **Yaw:** rotation around the vertical axis (turning left/right).
- **Kinematic model:** motion from geometry and rules, no forces.
- **Dynamic model:** motion from forces and torques (F = m·a).
- **Relaxation length:** distance a tire rolls before its force fully responds to a slip change.

---

## 14. Sources

- Marco Monster, *Car Physics for Games* (2003). Mirrors: https://www.asawicki.info/Mirror/Car%20Physics%20for%20Games/Car%20Physics%20for%20Games.html and https://rsms.me/etc/car-physics/
- GameDev.net: Pacejka implementation thread: https://gamedev.net/forums/topic/488361-pacejka-implementation?page=1
- GameDev.net: Simplified Pacejka magic formula: https://gamedev.net/forums/topic/462784-simplified-pacejka-magic-formula/
- GameDev.net: Traction circle and friction curve: https://gamedev.net/forums/topic/710462-car-physics-traction-circle-and-friction-curve/
- GameDev.net: Slip ratio instability: https://gamedev.net/forums/topic/713018-slip-ratio-instability
- GameDev.net: Simple ray cast vehicle (damping): https://rsn.gamedev.net/forums/topic/696087-simple-ray-cast-vehicle
- GDSim devlog (Godot raycast car, lateral force): https://lupine-vidya.itch.io/gdsim/devlog/677587/workshop-iii-rays-go-round-lateral-force-mirror
- Pacejka coefficient examples: https://arxiv.org/pdf/2005.00826 and https://arxiv.org/pdf/2209.04346
- Roblox DevForum: raycast suspension and wheel friction: https://devforum.roblox.com/t/help-with-raycast-suspension/2705715

Typical values for suspension frequency and damping ratio, drag/rolling constants, and the arcade assist list come from general vehicle-dynamics and game-dev practice, not from a single source above.
