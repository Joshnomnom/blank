# Enemy Spawning, Respawn, Aggro & Chase: Research Notes

> Written 2026-11-06 (Session 1), requested before Phase 3 (enemies):
> "research how MMO RPG enemies should spawn, monster group respawn time, chasing distance".
> Enemy look (design, later): **half-humanoid robot vehicles**. For now they're boxes like our car.
> Read **§0** and **§7** for the conclusions.

---

## 0. TL;DR

1. **Spawn in camps (packs) inside spawn zones**, not one global list. Each mob has its **own respawn timer with a random window** (e.g. 20–40 s instead of a fixed 30 s). Per-mob timers keep farming routes predictable; the randomness stops exact "spawn camping".
2. **Dynamic respawn:** shorten timers when **many players** are in the zone or **most of a pack is dead**. A fixed timer leaves crowds standing around (the classic "10 players kill 10 mobs, then wait 2 minutes" problem). But don't spawn faster than players can kill.
3. **Ragnarok behavior flags** are a great, simple model: **passive / aggressive / assist (link to its group) / looter** (+ later: detector, boss).
4. **Aggro:** aggressive mobs attack when you enter their **sight range** (with line of sight). Assist mobs join when a group member is attacked.
5. **Leash:** mobs give up when you drag them **too far from home** *or* after **a while without being hit** (aggro decay), then **run home and reset** (full HP, can't be damaged while returning). Damage refreshes the chase. This prevents endless chases, "trains" and kiting exploits.
6. **For a car game: driving is defense.** Mobs should be slower than the player's top speed, so escaping by driving well is always possible. Leash distances must be larger than in on-foot MMOs (cars cover 40 m/s).
7. **AI = a simple state machine:** Idle/Wander → Alert (telegraph "!") → Chase → Attack → (Reposition) → Return → Dead → Respawn. Require **line of sight** before attacking.
8. **Field bosses (MVPs):** long timers (60–120 min) with a random window, independent per location, and a **gravestone** showing death time (Ragnarok has had this since 2018).

---

## 1. Spawning and respawn timers

### 1.1 Spawn structure
- **Spawn zone** (an area in a map) → contains **camps/packs** → each pack = N mobs around a center, one or more mob types.
- Mobs **wander inside their camp radius** when idle (looks alive, spreads them out).
- **Don't spawn on top of or right in view of players** (min distance from any player, e.g. 25–40 m, or behind cover). Otherwise "mobs appearing unexpectedly" feels bad (a complaint seen with WoW layering).

### 1.2 Timer models
| Model | How | Pros | Cons |
|---|---|---|---|
| **Per-mob timer** | Each mob respawns X after *its own* death | Predictable farm routes (players like it) | Easy to camp exactly |
| Shared pack timer | Killing one starts the timer for the whole pack | Packs come back together | Long idle gaps |
| **Random window** | Respawn in [min, max], e.g. 4–8 min instead of a fixed 6 | Less exact camping, "exciting/surprising" | Less predictable |
| **Dynamic** | Shorter timer when more players nearby / fewer mobs alive | Crowded zones keep moving | Can feel too aggressive ("instant respawns") if overdone |
| Layering/sharding | Copies of the zone per player group | No crowding | Mobs pop in unexpectedly |

**Recommendation: per-mob timer + random window + mild dynamic scaling.**
```
respawn = random(base_min, base_max)
        × lerp(1.0, 0.5, clamp(players_in_zone / crowd_players, 0, 1))   # crowd: up to 2× faster
        × (0.7 if alive_in_pack <= 1 else 1.0)                            # nearly-cleared pack comes back a bit faster
```
Never faster than a floor (e.g. 8 s), and never respawn inside a player's view or close range.

### 1.3 Suggested timers (to tune)
| Mob tier | Respawn window | Notes |
|---|---|---|
| Normal farming mob | **20–40 s** per mob | Matches a TTK of 2–4 s and travel between packs |
| Elite / pack leader | 3–5 min | Better drops |
| Field boss (MVP) | **60–120 min** ± random window | Independent timer per location; **gravestone** with death time + killer (RO) |
| Instance / dungeon | No respawn (cleared once per run) | |

### 1.4 Density rule of thumb
A solo player should never wait for mobs. If a mob takes ~3 s to kill plus ~5 s to reach the next, a player kills ~7 mobs/min. A camp of 5 mobs with a 30 s average respawn produces ~10 mobs/min, so **one camp of 5 supports ~1–1.5 farming players**. Size zones with several camps, plus dynamic scaling for crowds.

---

## 2. Monster behavior types (Ragnarok model)
From iRO Wiki: monsters range from passive to aggressive; some **assist** their own kind, some fend for themselves; **looters** pick up items from the ground; **detectors** see hidden players; **bosses/MVPs** have boss protocols. Special variants can flip behavior (an *aggressive* "ringleader" among *passive* wolves).

| Flag | Behavior | Our use |
|---|---|---|
| **Passive** | Ignores you until attacked | Starter zone mobs, "neutral wildlife" |
| **Aggressive** | Attacks when you enter sight range | Raiders, drones in dangerous zones |
| **Assist (link)** | Joins when a same-group/same-type mob is attacked | Packs feel like packs; pull carefully |
| **Looter** | Picks up dropped loot | Scrap scavenger robots (fun flavor) |
| **Coward** | Flees at low HP | Light scouts (forces chasing = driving) |
| **Detector** | Sees through stealth | Later, if stealth modules exist |
| **Leader** | Aggressive leader + passive followers that assist it | Nice "pack with a boss" pattern |
RO detail: a monster that respawns near a player it was aggressive to stays aggressive to that player (aggression memory).

---

## 3. Aggro (getting attacked)
- **Sight / aggro radius** per mob type (with **line-of-sight** check: a raycast to the player).
  - Car scale proposal: light mobs **30 m**, heavy **40 m**, snipers **60 m**, bosses 50 m. (On-foot MMOs use ~10–20 m. Cars move 3–5× faster, so radii are larger.)
  - Optional: smaller radius when the player is moving slowly or "sneaking", larger when boosting (engine noise).
- **Alert telegraph:** 0.4–0.8 s "!" above the mob before it commits. Players learn to read and dodge it.
- **Assist/link radius** (~25 m): when a mob is hit, same-pack assist mobs within the radius also aggro. Some games add a short **assist-call delay** to avoid the whole area aggroing at once (Pax Dei's proposed fixes).
- **Threat table** (for parties later): the target is the highest-threat player; threat = damage dealt (+ tank modifiers). Solo: just "the player who hit me or that I saw".

---

## 4. Chase and leash (giving up)
Options seen in WoW, Pantheon, Ashes of Creation and Pax Dei discussions:
| Leash type | How | Notes |
|---|---|---|
| **Distance leash** | Give up beyond X m from spawn/home | Simple; most private servers / common implementation |
| **Time / aggro decay** | Give up after T s without being damaged / without line of sight | Blizzard's live WoW Classic was time-based per one guide; Pax Dei proposes "aggro decay" so distant NPCs give up |
| **Reset on damage** | Taking damage refreshes the chase timer/range | Prevents "kite outside the leash and shoot it for free" |
| No leash | Chase until someone dies or zones | Creates "trains" dragged onto other players (griefing) |
| By mob type | Fast/hunter mobs chase farther than slow guards | Adds flavor (Pantheon idea: mob stamina / aggro dropoff rate) |

**On leash (evade/reset):** the mob drops aggro, **returns home fast**, is **invulnerable and regenerates to full** while returning (prevents "shoot it while it walks home" exploits), then idles again. (WoW: "clears its aggro list and begins evading attacks".)

**Recommendation (hybrid):**
```
give up if: distance(mob, home) > leash_distance                     (e.g. 120 m normal, 200 m elite, boss = arena bound)
        or  time_since_damaged_by_target > aggro_timeout AND no LoS   (e.g. 8 s)
taking damage from the target refreshes the timeout
```
**Car-game specific:** mob max speed ≈ **60–80% of the player's road top speed** (sedan 42 m/s → mobs 25–32 m/s; sand slows both). **Escaping by driving is always possible**, and drifting and dodging are part of combat. Heavy mobs are slow but hit hard; light drones are fast but fragile.

---

## 5. AI state machine (per enemy)
Classic FSM: Idle → Patrol → Chase → Attack with condition-based transitions (detection range, attack range), plus edge cases. Hierarchical FSMs for bosses and squads.
```
IDLE / WANDER ──(player in sight radius + LoS, aggressive)──► ALERT (0.5 s "!")
      ▲                                                         │
      │                                                         ▼
   RETURN ◄──(leash: too far from home / aggro timeout)──── CHASE ──(in attack range + LoS)──► ATTACK
 (invulnerable, regen,                                          ▲                               │
  fast move home)                                               └──(out of range / no LoS)──────┘
      │                                                              (vehicle: REPOSITION / STRAFE)
   IDLE                                         any ──(HP 0)──► DEAD ──(respawn timer)──► spawn at camp
(passive mobs: IDLE → CHASE only when damaged; assist mobs: also when a pack-mate is damaged)
```
Practical tips from the sources:
- **Require a real line-of-sight raycast before ATTACK** (a devlog fix: enemies went to attack without being able to hit).
- Normalize movement directions (erratic movement bug).
- Vehicle enemies need extra states: **reposition/strafe/circle** (don't just drive into the player and stop), keep a preferred range (shooters), ram runs (rammers).

---

## 6. Enemy archetypes for our first zones (proposal)
Look: **half-humanoid robot vehicles** (a robot torso on a wheeled/tracked base). Placeholder: boxes.
| Name (working) | Armor | Behavior | Attack | Speed | Role |
|---|---|---|---|---|---|
| **Scrap Drone** | LIGHT | Aggressive, assist, wanders in packs of 3–5 | Rams / short-range zap | Fast (30 m/s), fragile (150 HP) | Basic farming pack; MG is effective |
| **Raider Gunner** | LIGHT | Aggressive, keeps 25–35 m distance, strafes | Shoots slow bullets (dodgeable) | Medium (25 m/s) | Teaches dodging while shooting |
| **Iron Hauler** | HEAVY | Passive until hit, assists its pack | Heavy ram + shockwave | Slow (18 m/s), tanky (800 HP) | Rockets are effective; "leader" of a pack |
| (later) Sand Worm | ORGANIC | Ambush from the sand | Bite | — | Fire effective |
| (later) Shield Bot | SHIELDED | Aggressive | Energy shots | — | Energy effective |

---

## 7. Recommendation: Phase 3 build order (one step at a time)
1. **Player car HP** + taking damage + destroyed → respawn at the start (needed before enemies can hurt you).
2. **One enemy type (Scrap Drone)** as a box: FSM (idle/wander → alert → chase → attack → return), aggressive, ram/zap attack, leash, LIGHT armor.
3. **Spawner**: a camp of 4 drones, per-mob random respawn 20–40 s, no spawning near or in view of players.
4. Assist/link behavior + a 2nd enemy type (Raider Gunner, ranged).
5. Loot drops (start of the farming loop).
6. Field boss with a long timer and a gravestone (later).

### Proposed starting numbers
```
Scrap Drone: HP 150, LIGHT, speed 30 m/s (on sand ×0.8), sight 30 m, alert 0.5 s,
             attack: ram 15 dmg (cooldown 1.2 s) or zap 8 dmg at ≤6 m,
             leash 120 m from home, aggro timeout 8 s (refreshed by damage),
             return: 2× speed, invulnerable, regen to full
Camp: 4 drones, wander radius 15 m, respawn per mob random 20–40 s (floor 8 s),
      no spawn within 30 m of a player
Player car: HP 500 (TTK by one drone ≈ 40 s, by a pack of 4 ≈ 10 s → must fight smart or drive away)
```

---

## 8. Sources
- Tobold's blog, Dynamic spawn system: https://tobolds.blogspot.com/2007/01/dynamic-spawn-system.html
- Tobold's blog, Spawning: https://tobolds.blogspot.com/2007/10/spawning.html?m=1
- Pantheon forums, features allowing faster respawns: https://www.pantheonmmo.com/content/forums/topic/13936/features-allowing-faster-respawns-to-be-implemented
- Pantheon forums, breaking a camp (shared pack timer, random window): https://seforums.pantheonmmo.com/content/forums/topic/9394/breaking-a-camp
- WoW forums, instant respawns: https://eu.forums.blizzard.com/en/wow/t/enough-with-the-instant-respawns/88401
- WoW forums, respawn rates too high: https://us.forums.blizzard.com/en/wow/t/2355345
- WoW forums, dynamic spawns in Vanilla?: https://us.forums.blizzard.com/en/wow/t/were-dynamic-spawns-in-vanilla/285710
- WoW forums, fix mob spawns: https://eu.forums.blizzard.com/en/wow/t/are-you-going-to-fix-mob-spawns/268564
- Warcraft Wiki, Leash: https://warcraft.wiki.gg/wiki/Leash
- Warcraft Tavern, Leash behavior & kiting: https://www.warcrafttavern.com/wow-classic/guides/leash-behavior
- Pantheon forums, aggro chase range and length: https://seforums.pantheonmmo.com/content/forums/topic/10271/agro-chase-range-and-length
- Pantheon forums, leashing or deal with it: https://www.pantheonmmo.com/content/forums/topic/3748/leashing-or-deal-with-it/view/page/2
- Pantheon forums, should aggro last forever: https://seforums.pantheonmmo.com/content/forums/topic/11675/should-agro-last-forever
- Ashes of Creation forums, mob aggro behaviors: https://forums.ashesofcreation.com/discussion/55675/what-aggro-and-fighting-behaviors-do-you-imagine-for-mobs
- Pax Dei proposed NPC aggro fixes: https://www.pulse.bot/gaming/news/give-mainframe-your-feedback-on-proposed-pax-dei-npc-aggro-fixes-from-endless-chases-to-chain-aggro-237b0390-47da-4165-844f-a832b5ff369e
- iRO Wiki, Monster (passive/aggressive/assist/looter/detector): https://irowiki.org/wiki/Monster
- iRO Wiki, MVP: https://irowiki.org/wiki/MVP
- Ragnarok Research Lab, Creature AI: https://ragnarokresearchlab.github.io/game-mechanics/creature-ai
- Godot forum, state machines and enemy AI: https://forum.godotengine.org/t/state-machines-and-enemy-ai/111974
- Simple enemy AI with FSMs in Godot: https://www.wayline.io/blog/godot-enemy-ai-finite-state-machines
- KidsCanCode, changing behaviors: https://kidscancode.org/godot_recipes/3.x/ai/changing_behaviors/index.html
- Plane AI, states and behaviour (vehicle enemy example): https://babel.speldesign.uu.se/?p=14468
- Shade's Peak AI devlog (LoS check before attack): https://itch.io/devlog/773398/shades-peak-ai.amp
- AI state machines overview: https://aischool.lillytechsystems.com/game-ai/state-machines.html

The proposed numbers (radii, speeds, timers, HP) are starting points for tuning. Forum sources are player and designer opinions, not measured data.
