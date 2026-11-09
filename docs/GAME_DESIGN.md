# Game Design Plan (Working Draft)

> Status: loose plan, will change as we build. We build **one thing at a time** and only move on when the current step feels good.

Working title: **TBD**. Ideas: *Wasteland Drive Online*, *Rust & Nitro*, *Dune Runners*.

---

## 1. Vision

A **3D online action RPG where your car is your character**, set in a desert wasteland.
It takes the structure of classic MMORPGs like Ragnarok Online (levels, stats, jobs, farming, loot, upgrades, bosses, guilds) and swaps the hero for an armed, customizable car.

**The main gameplay is farming, fighting and bosses.** Racing, drifting and drag racing are side activities that make driving fun and give extra rewards, but they are not the core.

## 2. Pillars

1. **Driving feels great.** Arcade handling that's easy to pick up, with satisfying drifts. If moving around isn't fun, nothing else matters.
2. **Your car is your character.** Chassis = race, driver job = class, parts and weapons = gear.
3. **Loot-driven RPG progression.** Farm zones, kill bosses, find rare parts, upgrade with risk.
4. **A social wasteland.** Parties, crews, a player market, world bosses, crew wars.

## 3. Technical decisions

| Topic | Decision |
|---|---|
| Engine | **Godot 4.7.2** |
| Language | **GDScript** (C# web export is limited) |
| Renderer | **Compatibility** (WebGL 2), so the editor looks the same as the web build |
| Main target | **Web browser** (single-threaded export, easy hosting). Desktop builds come for free. |
| Camera | **Third-person chase camera**: low and behind the car, follows its heading, FOV widens with speed |
| Handling | **Arcade**: custom car controller, not the built-in VehicleBody3D |
| Art style | Stylized / low-poly to keep the web build fast. Placeholder shapes at first. |
| Multiplayer (later) | The server owns the game state. Headless Godot server over **WebSocket**. Database for accounts and saves. |

## 4. Setting

- **Wasteland desert world**: sand dunes, broken highways, dirt roads, rocky canyons, scrapyards.
- **Desert cities**: walled, sun-bleached towns built from scrap and old concrete. They're safe zones with garages, shops and NPCs.
- **Roads vs sand**: paved roads are fast and grippy. Sand is slower and slidier, kicks up dust and suits jeeps and off-roaders.
- Zone ideas: Rust Flats (starter), Dune Sea, Scrap Canyon, Dead Highway, Salt Lake, the Burning City (high level).

## 5. Core loops

- **Moment to moment:** drive → fight → drift and dodge → collect loot
- **Session:** leave town → farm a zone or hunt a boss → return with XP, scrap and parts → repair, upgrade and tune at the garage
- **Long term:** level up → change job → unlock new zones and chassis → group bosses and crew wars → build and show off your dream car

## 6. RPG systems (Ragnarok → our game)

| Ragnarok | Our game |
|---|---|
| Race / class | **Chassis** (sedan, jeep, wagon, muscle, truck, buggy…) sets base stats and weight class |
| Job tree | **Driver Job** with a skill tree. Examples: Racer → Speedster / Drift Ace · Brawler → Juggernaut · Gunner → Artillery · Mechanic → Engineer (support / repair) |
| STR AGI VIT INT DEX LUK | **Power / Handling / Armor / Tech / Precision / Luck** |
| Base level + job level | **Driver level + job level** |
| Weapons | **Weapon mounts:** roof, front, rear, sides (machine gun, rockets, ram spikes, flamethrower, EMP, mines, oil slick…) |
| Armor and gear | **Parts:** engine, turbo, tires, suspension, nitro, armor plating |
| Cards | **Chips / decals** dropped by enemies, slotted into parts for bonuses |
| Refine +1 to +10 (can break) | **Tuning:** upgrades with a chance to fail. Main money sink. |
| Monsters and fields | **Hostile machines and creatures:** scrap drones, raider gangs, sand worms, mutant beasts. **Enemy look (decided): half-humanoid robot vehicles** (a robot upper body on a wheeled/tracked vehicle base). Placeholder boxes until the art phase. |
| MVP bosses | **Giant boss machines** on spawn timers, fought by groups. **Boss fight style (decided): "Space Invaders on wheels"**: in a flat arena the boss keeps its distance and throws readable patterns (orb fans, rings with gaps, spirals, telegraphed mortars, charge dashes). You dodge by driving and fire back. Phases change the fight. |
| Kafra / warps | **Garage network:** storage, repair, fast travel between towns |
| Vending | **Player market / roadside stalls** |
| Guilds and War of Emperium | **Crews and Territory War** over towns and districts |
| Quests and instances | **Story missions, dungeons, heists** |

**Combat controls (decided 2026-11-06):**
- **Mouse-aim turret:** WASD drives, the mouse aims the roof turret, LMB fires. Car direction and gun direction are separate, so you can drift one way and shoot another. Light aim assist snaps to targets near the cursor.
- **No special skills on guns.** Instead, **each gun IS a different type of attack**, so the guns you attach decide how you fight (clarified by the user 2026-11-06). Each gun has its own fire rate / cooldown between attacks.
- Attack type ideas: rapid stream (machine gun), close spread blast (shotgun), slow explosive with area damage (rocket / grenade launcher), continuous short-range cone (flamethrower), charged long-range shot (railgun), dropped behind the car (mines, oil slick from a rear mount).
- **Q / E swap between equipped guns.**
- **Damage types × armor types** (like Ragnarok's elements): kinetic / explosive / fire / energy vs light / heavy / shielded / organic. Effective hits show **golden-orange damage numbers**, resisted hits small white ones, and the crosshair says EFFECTIVE / RESISTED. Reading the enemy and swapping to the right gun is a core combat skill.
- Built one step at a time: step 1 = one machine gun (done). Next: a 2nd gun type + Q/E swap.

**Combat idea:** driving well powers your combat. Drifting charges a meter for skills and boost, ramming deals damage based on speed and mass, and dodging is done by driving. This keeps the driving and the RPG connected instead of separate.

## 7. Side activities (not the core)

- **Race events:** circuit and sprint across the wasteland
- **Drift trials:** scored by angle, speed and line
- **Drag strip:** launch, shift timing, nitro timing
- **Arena PvP**
- **Garage cosmetics:** paint, wraps, body kits, rims (visual only, separate from stats)

## 8. Roadmap (one step at a time)

| Phase | Goal | Done when |
|---|---|---|
| **0. Driving prototype** | **Only a car to test the driving system.** One placeholder car, flat test ground, top-down chase camera, arcade handling with drifting. Nothing else. | Driving and drifting feel fun on their own |
| 1. Terrain feel | Road vs sand surfaces, slopes and ramps, a few obstacles | Driving off-road feels different and good |
| 2. Combat basics | One weapon mount, one weapon, a dummy target, damage and HP | Shooting while driving feels good |
| 3. Enemies and loot | Simple enemy AI, death, loot drops, pickup | A small farming loop works |
| 4. RPG core | Stats, levels, inventory, parts, garage UI, save/load | Progression is felt in the car |
| 5. First content slice | One town, two farming zones, one boss, three chassis, one job tree, NPC shop | 30 minutes of real gameplay |
| 6. Multiplayer | Server, shared zones, parties, chat | Friends can farm together |
| 7. MMO layer | Accounts, persistence, crews, market, territory war | Persistent online world |
| 8. Side activities and live content | Racing, drift, drag, more chassis, jobs, zones, events | Ongoing |

## 9. Phase 0 detail: driving prototype

**Scope (only this):**
- One placeholder car built from simple shapes
- Large flat test ground with a grid/markers to read speed and direction
- Third-person chase camera with smooth follow
- Arcade controller: accelerate, brake/reverse, steer, handbrake drift
- Tunable values (exposed in the inspector) to iterate on feel
- Simple debug readout (speed, drift state)
- Runs in the editor and as a web export

**Not in Phase 0:** weapons, enemies, terrain types, HUD art, UI menus, multiplayer.

## 10. Open questions (decide later)

- Game title
- Fixed vs rotating camera option for players
- Mobile browser support (touch controls)?
- How death works (respawn at garage? lose durability? drop items?)
- Monetization model (cosmetics only?)
- Art pipeline for 3D car models
