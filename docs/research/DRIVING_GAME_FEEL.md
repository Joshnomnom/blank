# Driving Game Feel: Research Notes

> Written 2026-11-06 (Session 1), after the user said: **"the driving still doesn't hit it."**
> Companion to [CAR_PHYSICS_RESEARCH.md](CAR_PHYSICS_RESEARCH.md), which covers the math. This doc covers **why arcade driving feels good or bad**, and what to change in our controller.
> Topics: car movement, turning, speed, drifting, wheel spin, feedback ("juice").
> Read **§1 (Diagnosis)** and **§9 (Plan)** first.

---

## 0. Key insights from research

1. **Feel matters more than numbers.** Developers repeatedly say good drifting is controlled by "feel" rather than clinical inputs. Getting "acceleration, adherence, turning angles, suspension feel" right is hard and always needs iteration.
2. **Fix control response before adding effects.** A practitioner write-up: tune control response first; FOV, blur and audio can't fix a car that feels sluggish.
3. **Arcade drift games usually don't simulate tires during a drift.** The Godot 4 DriftCarG4 project has **no tire friction model**. It uses a **drift controller that regulates the drift angle**, a separate steering controller for normal turning, and a lateral force that removes sideways velocity. This is the core idea for our v2.
4. **Make drifting a tool, not the default.** Drifting should be a fundamental part of play, but not the answer to every corner. It also shouldn't engage too early, and normal grip shouldn't feel like ice.
5. **Sense of speed comes from many cues together:** FOV, camera height and placement, camera shake, sound, and **nearby scenery passing by**. Research: motion blur **does not** help (it can even reduce perceived speed). Camera height and FOV have the most direct evidence.
6. **"Juice" makes it read as fun:** tire smoke, skid marks that fade over time, rear light trails, speed lines, camera tilt and tightening during long drifts, and **particle intensity tied to drift tightness**.
7. **Steering needs separate in and out speeds:** a steering curve (max steer vs speed), a steer-in speed, and a separate, faster **recenter speed**.

---

## 1. Diagnosis: why our Phase 0 controller probably "doesn't hit"

From reading our `car_controller.gd` against the research:

| # | Problem | Why it feels bad | Fix (see §2–§8) |
|---|---|---|---|
| 1 | **Yaw is set directly from steering** (`yaw_rate = steer × turn_rate`) | No rotational weight. The car turns like a cursor, robotic and instant. | Yaw **inertia**: angular velocity moves toward a target at a grip-based rate (§3) |
| 2 | **Drift is a binary state** that switches grip (9 → 1.4 → 9) | Grip "snaps", and entering or exiting feels like a switch flipping, not a car | **Drift angle controller** + smooth grip blend (§4) |
| 3 | **Sideways speed is deleted** by grip | Drifts bleed speed like hitting glue. Turning at speed feels draggy. | **Rotate** velocity toward the heading (keep most speed) instead of deleting the lateral part (§4.4) |
| 4 | **Drift is only reachable with the handbrake** (normal grip 9 is too high to break loose) | Steering hard at speed does nothing interesting | Several entry methods: handbrake, brake-tap + steer, power-over at high steer (§4.2) |
| 5 | **No control over drift angle** while sliding | The player can't "hold" a drift, it just happens to them | Steering sets the **target drift angle**, throttle sets the speed (§4.3) |
| 6 | **Flat, linear acceleration** (`move_toward`) and a top speed of only 119 km/h | No punch off the line, no rush of speed | Acceleration curve with a strong launch, higher top speed (§2) |
| 7 | **Zero feedback**: no tire smoke, skid marks, engine or tire sound, or camera reaction | Even good physics feels dead without feedback. This is probably the **biggest** single factor. | §6, §7 |
| 8 | **Empty, flat arena** with only grid lines | No objects pass by, so speed can't be felt | Add **non-colliding** visual speed references: posts, flags, ground decals (§7.4). These aren't obstacles. |
| 9 | Wheels spin exactly at road speed | No burnout, wheelspin or lockup drama | A separate **visual wheel speed** state (§5) |
| 10 | The camera follows the car's heading | During a drift it swings with the nose, so the slide is hard to read | Follow a heading/velocity blend and add a lateral offset in drifts (§7.2) |

---

## 2. Movement: acceleration and speed

**What feels good (arcade):**
- **Strong launch, tapering top end.** Most of the "punch" is in 0–60% of top speed.
- Use a **speed → acceleration curve** instead of engine/gear simulation. Open-source arcade controllers use a speed curve in place of complex engine settings.
- **Throttle response is instant.** No lag between pressing and accelerating; delays read as "heavy" in a bad way.
- **Coasting slows the car gently.** Braking is strong but not instant. Reverse is slow.
- **Fake gear shifts** (optional, later): a short 0.1–0.15 s dip in acceleration + engine pitch drop at speed thresholds. That's what gives "speeding" its rhythm without real gears.

**Formula:**
```
accel = accel_max · accel_curve(speed / top_speed)      # Curve: 1.0 at 0 → ~0.25 at 1.0
speed += accel · throttle · dt
```
**Suggested sedan values:** top speed ~42 m/s (150 km/h), 0→100 km/h in ~3.5–4 s (arcade-fast), accel_max ~11 m/s², brake ~25 m/s², coast ~2 m/s².

**Mass feel without physics:** heavier cars (later: jeep, truck) get lower `accel_max`, slower yaw response and more speed retention in drifts. Lighter cars get the opposite. One "weight" stat can drive all three.

---

## 3. Turning

### 3.1 Steering input
- **Steering curve by speed:** full lock at low speed, about 35–50% at top speed.
- **Steer-in speed** ~4–6 /s and a **faster recenter speed** ~8–10 /s. Releasing the key straightens quickly, which feels responsive.
- **Counter-steer is faster:** when the input reverses direction, use the recenter speed, so flicks feel snappy.

### 3.2 Yaw with inertia (fix for problem #1)
Instead of `yaw_rate = steer × turn_rate`:
```
target_yaw_rate = steer · turn_rate · speed_factor
yaw_rate = lerp(yaw_rate, target_yaw_rate, 1 − exp(−yaw_response · dt))
```
- `yaw_response` ≈ 6–10 with grip (snappy but not instant), ≈ 2–4 in a drift (floaty, weighty).
- This one change makes the car feel like it has mass.

### 3.3 Grip turning: velocity follows the nose
In normal driving, the car's **velocity direction** should follow its heading quickly (high grip), **keeping the speed**:
```
vel_dir = vel_dir.slerp(heading, 1 − exp(−grip_turn · dt))   # grip_turn ≈ 8–12
speed slightly reduced by "cornering scrub" (≈ 2–5% per second at full steer)
```

---

## 4. Drifting (arcade drift-angle controller)

The approach used in arcade drift games like DriftCarG4: **don't simulate tires during a drift. Directly control the angle between the nose and the velocity.**

### 4.1 Two separate directions
- **Heading** = where the nose points (car rotation)
- **Travel direction** = where the car moves (velocity)
- **Drift angle** = the signed angle between them.

In **grip mode**, travel follows the heading tightly (§3.3).
In **drift mode**, two controllers run:
1. The **angle controller** rotates the *heading* so the drift angle approaches a *target angle*.
2. The **path controller** bends the *travel direction* slowly with steering, so the car still turns through the corner.

### 4.2 Entering a drift (multiple ways)
| Method | Condition | Feel |
|---|---|---|
| Handbrake | Handbrake + steer + speed > ~40 km/h | Instant, reliable |
| Brake-tap | Brake tapped (< 0.3 s) then steer hard at speed | Skilled, "feint" style |
| Power-over | Full steer + full throttle + speed > ~70% of top speed for ~0.25 s | Natural power slide |

On entry, apply a **kick**: an instant yaw impulse toward the steer direction (≈ 10–15° of instant drift angle). This makes the entry feel decisive.

### 4.3 Holding: steering sets the target drift angle
```
dir = drift direction (+1 = tail out to the right, i.e. car turning left)
steer_rel = steer · dir          # +1 = steering into the corner, −1 = counter-steering
target_angle = lerp(base_angle, max_angle, (steer_rel + 1) / 2)
#   steering in    → max_angle  (~45–50°): tighter, sharper turn
#   neutral        → base_angle (~30°)
#   counter-steer  → min        (~10–15°): straightens toward exit
heading_yaw += (target_angle − current_angle) · angle_response · dt   # angle_response ≈ 4–6
```
- **Path bending:** `travel_dir` rotates by `dir · drift_turn_rate · (0.5 + 0.5·steer_rel) · dt`. Drift turn rate ≈ 1.2–1.8 rad/s, more than grip turning, so **drifting through a corner is faster than gripping**. That's the reward.
- **Throttle in a drift:** keeps the speed up (and could add ~5° of angle). Lifting off reduces the angle and slows the car more.

### 4.4 Speed in a drift (fix for problem #3)
- Don't delete lateral speed. Speed is kept along the travel direction and lost slowly:
```
speed -= drift_speed_loss · (1 − throttle·0.7) · dt      # ≈ 2–4 m/s² loss
```
- Optional reward later (combat phases): **drift charge** builds with angle × speed × time and can be spent on boost or skills. This fits our design doc.

### 4.5 Exiting
- Exit when: the drift angle falls below ~8° (counter-steered out), the speed falls below ~25 km/h, or the angle passes ~70° (spin-out protection: clamp, don't spin).
- **Blend out over 0.2–0.35 s**: travel direction is pulled to the heading with a grip that ramps up. Never snap.
- A small **exit boost** (mini-turbo) based on drift length is a classic arcade reward. Note it for later; not Phase 0.

### 4.6 Why this works
- The player **always controls** the angle with steering. No random spin-outs.
- Drifts **keep speed**, so they feel powerful, not punishing.
- The tuning values are **readable** (degrees, rad/s), so it's easy to iterate on feel.
- It suits **networking**: simple, deterministic-ish state (heading, travel dir, speed, drift flag, angle).

---

## 5. Wheel spin (visual and feel)

Keep a separate **visual wheel speed** per axle instead of always matching road speed:

| Situation | Rear wheels | Front wheels | Effects |
|---|---|---|---|
| Launch (throttle, speed < ~8 m/s) | Spin much faster than road speed (burnout) for ~0.5 s | Road speed | Smoke at rear, tire squeal, slight tail wiggle |
| Drifting with throttle | Faster than road (×1.3–1.6) | Road speed | Smoke scaled by drift angle |
| Handbrake | **Locked (0)** | Road speed | Skid marks, squeal |
| Hard braking | Slightly slow, near lock | Same | Short skid marks |
| Normal | Road speed | Road speed | none |

```
target_rear_spin = road_spin · (1 + slip_extra)
rear_spin = lerp(rear_spin, target_rear_spin, 1 − exp(−10·dt))
```
Optional launch tail wiggle: a small sinusoidal yaw (±2°) for 0.4 s during a burnout launch. It's cheap and adds a lot of character.

---

## 6. Feedback / juice: car

| Effect | Trigger | Implementation (Godot, Compatibility-safe) |
|---|---|---|
| **Tire smoke** | Drift, burnout, handbrake | `CPUParticles3D` at the rear wheels. Emission amount and size scale with drift angle × speed. On sand, use a **tan dust** color. |
| **Skid marks** | Drifting, locked wheels | Ribbon mesh per rear wheel (`ImmediateMesh` or a pooled quad strip). Points every ~0.3 m, **fade over 5–10 s**, capped point count. |
| **Body roll and pitch** | Turning and acceleration | Already done. Increase roll during drifts (~4–6°). |
| **Tail lights brighten** | Braking | Raise emission energy |
| **Exhaust pops / flame** | Lifting off at high rpm, or drift exit | Small particle burst (later) |
| **Wheel steering** | Visual steer angle **follows counter-steer** in drifts | Show the front wheels pointing along the travel direction during a drift. This is very readable. |

---

## 7. Feedback / juice: camera and world

### 7.1 Speed cues (evidence-based)
- **FOV widens with speed.** We already do 65°→78°. Could go up to ~85°.
- **Camera drops lower and pulls slightly closer at high speed** (lower = ground rushes by).
- **Subtle high-speed shake**: small Perlin-noise offset (±0.03–0.06 m) above ~70% of top speed. Players report this helps "greatly" when it's subtle.
- **Skip motion blur.** Research says it doesn't help and can lower perceived speed. It's also costly on web.
- **Speed lines** (screen-space streaks) as a cheap arcade alternative to blur. Optional.

### 7.2 Drift camera
- Follow a **blend of heading and velocity direction** (e.g. 40% heading, 60% velocity) during a drift, so the car is seen **sliding sideways**.
- **Lateral offset**: shift the camera slightly to the outside of the drift.
- **Tilt/roll** the camera 2–4° into the drift. Tighten (move a little closer) the longer the drift lasts.

### 7.3 Collisions
- Short camera shake on wall impact, scaled by impact speed. Spark particles.

### 7.4 World references (problem #8)
- Speed can't be felt on an empty plane. Add **non-colliding** visual references: rows of short posts or flags along lines, painted ground arrows or tire marks, distant landmarks (mesas, towers) outside the walls for direction.
- These are not obstacles; the user's "no obstacles" rule still holds.

---

## 8. Sound (a big part of feel; can be done with no asset files)

- **Engine:** pitch = lerp(0.8, 2.0, rpm_fake). A fake rpm rises with speed within each fake gear and drops at shifts. Godot: `AudioStreamPlayer3D` with a looping engine sample, or **synthesize** with `AudioStreamGenerator` (sawtooth + noise), which is fine as a placeholder.
- **Tire squeal:** volume scaled by drift angle and speed, pitch varying slightly.
- **Wind:** volume rises with speed. A strong, cheap speed cue.
- **Impacts:** thud and scrape on walls.
- Web note: browsers start audio only after the first user input (a click or key). Expect that.

---

## 9. Plan: "Driving v2" for our controller

Phase 0 is still **driving only**. These steps all belong in Phase 0, one at a time, play-testing after each:

| Step | Change | Fixes |
|---|---|---|
| **v2.1 Core motion rewrite** | Heading vs travel direction; yaw inertia; grip turning keeps speed; acceleration curve; top speed ~150 km/h; steer in/out/counter speeds | #1, #3, #6 |
| **v2.2 Drift controller** | Entry methods + kick; target-angle controller; path bending; speed retention; smooth exit; spin-out clamp | #2, #4, #5 |
| **v2.3 Visual wheel spin** | Burnout, drift spin, handbrake lock, front wheels showing counter-steer | #9 |
| **v2.4 Car juice** | Tire smoke, skid marks, brake lights, more drift roll | #7 |
| **v2.5 Camera juice** | Drift camera blend, lateral offset, tilt, speed shake, lower at speed | #7, #10 |
| **v2.6 Speed references** | Non-colliding posts, flags and arrows, distant landmarks | #8 |
| **v2.7 Sound** | Engine (synth/placeholder), tire squeal, wind | #7 |

**Recommendation:** do **v2.1 + v2.2 together** first, since that's the core of "it doesn't hit". Then add juice step by step.

### v2 starting values (sedan)
```
top_speed 42 m/s (150 km/h) · accel_max 11 · brake 25 · coast 2 · reverse max 12
steer_in 5 /s · steer_out 9 /s · turn_rate 2.2 rad/s · high_speed_steer 0.45
yaw_response_grip 8 · yaw_response_drift 3
grip_turn 10 · cornering_scrub 0.03
drift: min_speed 11 m/s · kick 12° · base_angle 30° · max_angle 48° · min_angle 12°
       angle_response 5 · drift_turn_rate 1.5 rad/s · speed_loss 3 m/s² · exit_blend 0.3 s
       exit_angle 8° · spin_clamp 70° · power_over_hold 0.25 s
```

---

## 10. Reference projects worth reading (if more depth is needed)

- **DriftCarG4** (Godot 4, arcade drift, no tire model, drift-angle controller): https://notabug.org/tomaga/DriftCarG4
- **Godot Easy Vehicle Physics** (MIT, Godot 4.3+, has a drift demo; parameters in one `vehicle.gd` with tooltips): https://godotassetlibrary.com/asset/5tYPX8/godot-easy-vehicle-physics
- **arcadecarphysics** (speed curve instead of engine sim; references a Seena Burns car-controller post and a GDC talk on arcade vs sim): https://github.com/sergeymakeev/arcadecarphysics
- Vehicle system docs (steering curve, steering speed, recenter speed): https://sites.google.com/view/vehicle-system-documentation/general/arcade-physics

---

## 11. Sources

- Unity forum: implementing an arcade drift mechanic: https://discussions.unity.com/t/how-would-you-implement-a-car-drifting-arcade-game-mechanic/924750
- Unreal forum: arcade drift vehicle system: https://forums.unrealengine.com/t/arcade-drift-vehicle-system-code-and-game-logic/121664/4
- Andi Hamilton's newsletter #54, Best Drifts: https://andihamilton.beehiiv.com/p/andi-hamiltons-videogame-newsletter-issue-54-best-drifts
- Inertial Drift review (separate drift stick): https://primagames.com/reviews/inertial-drift-review
- Absolute Drift review: https://gamecritics.com/ryan-hamann/absolute-drift-review/
- All-Star Fruit Racing (drift as a component that shouldn't be overused): https://pcgamesn.com/all-star-fruit-racing/all-star-fruit-racing-unreal-engine-4
- itch.io comment (drift engaging too early, low friction): https://itch.io/post/2824802
- Reddit "juicy racer" thread snapshot: https://reddit.sentinel-team.org/posts/1u38a7c/snapshots/2026-06-12T14%3A00%3A24.587466Z
- Sense of speed study (blur lowers perceived speed; camera altitude raises it): https://rd.springer.com/chapter/10.1007/978-3-319-55834-9_14
- Disney Research: simulated motion blur doesn't improve racing experience: https://studios.disneyresearch.com/?p=32591
- Why speed is hard to capture in racing games: https://www.operationsports.com/why-is-speed-so-hard-to-capture-in-racing-games/
- Forza forum: camera shake for sense of speed: https://forums.forza.net/t/camera-shake-for-increased-sense-of-speed/708232
- Making a racing game feel fast and responsive: https://www.itechguides.com/how-to-make-a-racing-game-feel-fast-and-responsive/
- Small browser racer comments (fading skid marks): https://n1tr0xide.itch.io/cursor-racing/comments
- Electron Studio Godot racing tutorial (torque impulse steering in drift, reduced damping): https://electronstudio.github.io/godot_racing/tutorial

Values in §2–§9 are proposed starting points from game-dev practice. They are not measured and will be tuned in play-tests.
