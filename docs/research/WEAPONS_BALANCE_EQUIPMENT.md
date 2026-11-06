# Weapons, Game Balancing, Customization & Equipment: Research Notes

> Written 2026-11-06 (Session 1), requested by the user before choosing the 2nd gun:
> "research on weapons choosing for game, game balancing, and customizations and equipment items".
> Design context: car = character, **each gun is its own attack type** (no gun skills), Q/E swaps guns,
> core loop = farming / fighting / bosses (Ragnarok-like MMO). See [GAME_DESIGN.md](../GAME_DESIGN.md).
> Read **§0** and **§6** for the conclusions.

---

## 0. TL;DR

1. **One weapon per role.** A new gun must do something no other gun does. Two guns that differ only in looks or numbers add complexity, not depth (Halo 3 design notes).
2. **Spread weapons across many axes** (range, burst vs sustained, single vs area, projectile speed, skill needed, driving synergy). **Avoid "equal DPS everywhere"**: if every gun is equally good everywhere, players pick one and never swap (Battlefield V devs).
3. **Tune each weapon at its intended range**, not across the board. Nerf a weapon *outside* its role, not *in* it (Halo 3 sniper fix: a longer delay between shots hurt it only outside its role).
4. **Give swapping a reason**: **damage types vs armor types** (like Ragnarok's element table). Some enemies resist bullets but take full explosive damage, and so on. This makes Q/E swapping a real decision.
5. **Limit loadouts with a budget**: Crossout uses **energy** (weapons cost energy; the vehicle has a cap) and a **Power Score** (sum of parts → matchmaking). For us: chassis energy + mount slots, and Power Score → zone recommendation.
6. **Equipment** in the Ragnarok style: **rarity tiers** (bounded stats, affix count grows with rarity), **refine +0…+10** with a safe limit and risk beyond it, and **card/chip slots** filled with rare monster drops. Chips are what make *farming specific monsters* worthwhile, which is exactly our core loop.
7. **Balance with formulas and a spreadsheet**, then verify with play data. Players getting good at a weapon is not proof that it's balanced.

---

## 1. Weapon design principles (from shipped games)

| Principle | Source | What it means for us |
|---|---|---|
| **One weapon per role**; same-role weapons add complexity, not depth | Halo 3 design notes (via "Paradigms of Weapon Design") | Each new gun needs a distinct job: close burst, area, sustained, precision, control, defensive |
| Check whether weapons are **used outside their role** or **strictly dominate** others | same | Watch for "machine gun is best everywhere" |
| **Make the damage gap between the fastest and slowest guns as large as possible** | Battlefield V (DICE) | Machine gun = many small hits; rocket/railgun = few huge hits |
| **Equal DPS is a failure mode**: players find one gun that works everywhere and stick to it | Battlefield V | Guns must be *great* in their role and *weak* outside it |
| **Tune TTK per weapon at its ideal range**; avoid "brute-force" global changes | Battlefield 1/V | Balance shotgun close, railgun far, separately |
| Nerf a weapon's **off-role** use, not its core | Halo 3 sniper change | e.g. a slow rocket projectile weakens it at long range, not up close |
| **Use data, not intuition**; competence ≠ balance | Halo devs, CoD Mobile (data-driven balance) | Later: log damage and kills per weapon in playtests |

### The axes a weapon can differ on
| Axis | Low end | High end |
|---|---|---|
| Effective range | Flamethrower (10 m) | Railgun (200 m) |
| Damage per hit | Machine gun (8) | Railgun (300) |
| Delivery | Sustained stream | Burst / single shot with cooldown |
| Targets | Single target | Area (explosion), cone, pierce, chain |
| Projectile | Instant / very fast | Slow (needs leading), arcing (grenades) |
| Skill needed | Easy (aim assist helps a lot) | Hard (charge timing, leading) |
| **Driving synergy** (our unique axis) | Needs a stable aim | Rewards drifting alongside (flamer), ramming (spikes), kiting (rear mines) |
| Uptime | Always on | Cooldown / overheat / charge |
| Effect | Pure damage | Slow, knockback, burn (damage over time), stun (EMP) |

---

## 2. Proposed weapon roster for our game (roles, not final numbers)

| Gun | Role | Attack type | Strong at | Weak at | Damage type | Mount |
|---|---|---|---|---|---|---|
| **Machine Gun** ✅ built | Sustained all-rounder | Fast stream, small hits | Mid range, picking off | Armored targets, groups | Kinetic | Roof / side |
| **Shotgun** | Close burst | 8–10 pellets in a cone, ~1 shot/s | Point blank, fast mobs | Range (pellets spread) | Kinetic | Roof / front |
| **Rocket Launcher** | Area / anti-group | Slow rocket, explosion radius, 1.5 s cooldown | Groups, armored | Fast single targets (slow projectile), point blank (self-splash?) | Explosive | Roof |
| **Flamethrower** | Close damage over time | Continuous short cone, burn | Drifting alongside, swarms | Range, fire-resistant mobs | Fire | Front / side |
| **Railgun** | Precision | Hold to charge → piercing beam | Long range, bosses' weak spots | Close/fast targets, swarms | Energy | Roof |
| **Tesla Coil** | Control | Chains between nearby enemies, slows | Groups of light mobs | Single tanky target | Energy | Roof |
| **Mine Dropper / Oil Slick** | Defensive / kiting | Dropped behind, triggers | Being chased (kiting bosses) | Attacking head-on | Explosive / effect | Rear |
| **Ram Spikes** | Melee by driving | Damage = impact speed × mass | Skilled drivers, charging | Standing still | Kinetic | Front |

**Suggested build order** (each step adds a *new mechanic* that later guns reuse):
1. Machine Gun ✅ (projectiles, hits, HP)
2. **Rocket Launcher** → adds **explosions / area damage** (later reused by grenades, mines, boss attacks)
3. **Shotgun** → adds **multi-pellet** shots and **damage falloff with range**
4. Flamethrower → adds **cones and damage over time (burn)**
5. Railgun → adds **charge** and **pierce**
6. Mines / oil → adds **rear mount + placed objects**
7. Ram spikes → adds **collision damage**

### How Q/E fits with mounts (proposal)
- **Roof turret** = the mouse-aimed main weapon. **Q/E cycles through the guns equipped in roof weapon slots** (e.g. 2–3 slots depending on chassis). Swapping takes a short time (~0.3–0.5 s), so swapping is a decision, not spam.
- **Front / rear / side mounts** = always active or on their own key (e.g. rear mines on Shift, front rams always on). Decide later, when we get there.

---

## 3. Balancing framework

### 3.1 Effective DPS and a power budget
```
raw_dps        = damage_per_hit × hits_per_shot × shots_per_second
effective_dps  = raw_dps × hit_rate(range, target speed) × uptime × area_factor
```
- `hit_rate`: how often it really hits at its intended range (machine gun ~70% with spread; slow rocket vs fast mob ~40%).
- `uptime`: 1.0 for a stream, less with cooldowns, overheat or charge time.
- `area_factor`: average number of enemies hit (rocket into a pack ≈ 2–3).
- **Rule:** in its own role a weapon should beat the others by 20–50%. Outside its role it should be clearly worse.

### 3.2 Time-to-kill (TTK) targets (proposal, PvE)
| Target | Solo TTK with the right gun | Notes |
|---|---|---|
| Normal farming mob (same level) | **2–4 s** | Farming must feel fast |
| Elite mob | 10–20 s | |
| Field boss (MVP-style) | 3–8 min for a party | Needs mechanics and dodging |
| PvP car vs car | 8–15 s | Long enough to react and drive away |
Reference: shooter PvP TTKs are far shorter (Battlefield V close range = 4 bullets ≈ 0.33 s). That's fine for on-foot shooters, too fast for car combat where driving is the skill.

Current numbers check: Machine Gun 8 dmg × 10/s = **80 DPS**; a 300 HP dummy = 3.75 s ✓ inside the "normal mob" target.

### 3.3 Damage formula: armor and mitigation
Options seen in RPGs:
| Type | Formula | Pros | Cons |
|---|---|---|---|
| Subtractive | `dmg = atk − def` | Simple | Small hits do 0 vs high defense (bad for machine guns) |
| Divisive | `dmg = atk × k / def` | | Unstable at low defense |
| **Ratio (recommended)** | `dmg = atk × K / (K + armor)` | **Diminishing returns, never 0**, easy to read as a % | Needs K tuned per level |
| Hit-size based | `mit = def / (def + hit)` | Big hits pierce armor better (favors rockets/railgun) | Harder to reason about |

**Recommendation:** ratio armor `taken = dmg × K / (K + armor)`, with `K ≈ 50 + 10 × level`, so armor stays meaningful as levels rise. Example: armor = K → 50% reduction; armor = 3K → 75%. (Path of Exile uses a related armor/(armor+X) curve; ratio curves give "very high armor has diminishing returns".)
- Apply **armor penetration to the armor value before** the formula, not to the final damage.
- Keep buffs and debuffs as **% modifiers in separate multipliers** (they stack cleanly in a spreadsheet).
- Optional Ragnarok flavor: armor % from equipment plus a flat reduction from the Armor stat (RO's "hard DEF + soft DEF").

### 3.4 Damage types × armor types (the reason to swap guns)
Our version of Ragnarok's element table. Proposal:
| ↓ damage \ armor → | Light (scrap drones, raiders) | Heavy (armored trucks) | Shielded (tech/robots) | Organic (sand worms, beasts) |
|---|---|---|---|---|
| **Kinetic** (MG, shotgun, rams) | **125%** | 60% | 80% | 100% |
| **Explosive** (rockets, mines) | 100% | **130%** | 80% | 100% |
| **Fire** (flamer) | 100% | 70% | 60% | **150%** |
| **Energy** (railgun, tesla) | 80% | 100% | **150%** | 90% |
- Each enemy type shows its armor type (an icon / colored HP bar). Players read it and **swap with Q/E**. This is the decision that makes multiple attack types matter.
- Bosses can switch armor type per phase (e.g. the shield breaks, then it's heavy armor).

### 3.5 Loadout budget (Crossout-inspired)
- **Energy:** each chassis provides energy (e.g. sedan 8, truck 12). Each weapon costs energy (MG 2, shotgun 3, rocket 4, railgun 5). This limits stacking the strongest guns and creates trade-offs.
- **Mount slots per chassis:** sedan = 1 roof + 1 front + 1 rear; truck = 2 roof + sides; buggy = 1 roof + rear… This is a chassis identity.
- **Weight:** armor plates and big guns add mass, so acceleration drops (`accel ∝ engine power / mass`). Builds trade firepower and armor against mobility.
- **Power Score (PS)** = the sum of the PS of all equipped parts. Use it for **zone recommendations and matchmaking** (Crossout matches by PS). Crossout re-tunes PS and energy costs in patches, so plan to adjust these numbers.

### 3.6 Balancing process
1. Spreadsheet: per weapon → raw DPS, effective DPS at each range, TTK vs each enemy type and armor.
2. Plot curves (damage vs armor, DPS vs range) to spot dominance.
3. Playtest with logging: damage dealt per weapon, time used, kills, swaps.
4. Change one weapon at a time, within its role.

---

## 4. Customization & equipment

### 4.1 Two separate layers (already in our design)
- **Performance**: stats from chassis, parts, weapons, refine and chips.
- **Cosmetic**: paint, wraps, body kits, rims. Never affects stats (good for monetization and fairness).

### 4.2 Equipment slots (proposal)
| Slot | Main stat | Secondary examples |
|---|---|---|
| Weapons (per mount) | Damage, fire rate | Range, spread, armor pen |
| Engine | Acceleration / top speed | Energy +1 |
| Tires | Grip / handling | Sand grip, drift angle |
| Suspension | Landing / off-road stability | Jump control |
| Armor plating | Armor (mitigation) | Mass + |
| Nitro | Boost amount | Recharge |
| Module (electronics) | Special: radar, shield, repair | Cooldown − |

### 4.3 Rarity tiers (bounded power)
| Tier | Color | Random bonus lines (affixes) | Notes |
|---|---|---|---|
| Common | White | 0 | Base stats only |
| Uncommon | Green | 1 | |
| Rare | Blue | 2 | |
| Epic | Purple | 3 | |
| Legendary | Orange | 2–3 + **a unique effect** | e.g. "rockets split into 3 mini rockets". Horizontal (new behavior), not just bigger numbers |
- **Bounded stats:** cap the stat ranges so old gear stays relevant. New content adds **new interactions**, not endless bigger numbers (horizontal progression).
- Typical pattern: affix count scales with rarity (Grim Dawn: ≤5 lines, most items 2–3).
- Salvage unwanted items into materials (for refining and crafting).

### 4.4 Refine / tuning (Ragnarok-style, slightly softer)
- Garage NPC (our "Kafra") tunes parts and weapons **+1 … +10**. Each + adds a % to the main stat.
- **Safe limit** (e.g. +4) = 100% success. Above it the success chance drops each level (RO: risk beyond the safe limit; the safe limit varies by item tier).
- RO-classic failure = **the item breaks**. That's harsh but it's the famous money sink. **Recommendation:** failure = lose 1 refine level; only at +8 and above can it **break**, and a **protection item** (bought or farmed) prevents breaking. Some RO versions also offer "safe refining" at a higher cost.
- Upgrade risk vs reward creates tension (Last Epoch's crafting has a similar "it can seal/fail" risk).

### 4.5 Chips (our version of Ragnarok cards), which drives farming
- Each monster type has **one chip** with a **very low drop rate** (e.g. 0.01–0.1%). Bosses' chips are build-defining.
- Items have **0–4 chip slots** (higher rarity → more likely to have slots; a "socket enchant" can add one, as on some RO servers).
- Chips are **category-locked** (weapon chips → weapons, armor chips → plating…), as RO cards only go into their own equipment type.
- Insert = permanent (RO classic), or removal at a high cost (some servers). Recommendation: removable for a high price, so experimentation isn't punished too hard.
- Example chips: "Scrap Drone chip: +15% damage vs Light armor", "Sand Worm chip: +20% grip on sand", "Raider Boss chip: machine gun bullets ricochet once".
- **Why it matters:** players farm *specific* monsters for *specific* chips. That's the Ragnarok farming loop, and it fits our core.

### 4.6 Loot rules (keep the economy healthy)
- Drop tables per monster: currency + materials + gear (rarity roll) + chip (rare).
- Trade rules: chips and most gear tradeable (player market); top rewards bind on equip.
- Optional identification step (Savaru's Affixology hides affixes until identified). In Ragnarok, "unidentified items" are classic flavor.

---

## 5. Stat mapping (our 6 stats → combat)
| Stat | Combat effect | Driving effect |
|---|---|---|
| **Power** | +% weapon damage | Acceleration |
| **Handling** | Turret turn speed | Grip, turn rate |
| **Armor** | Armor value (mitigation) | +Mass (heavier) |
| **Tech** | Energy capacity, faster swaps and cooldowns | — |
| **Precision** | Less spread, crit chance | — |
| **Luck** | Crit damage, **drop rate** (RO's LUK feel) | — |

---

## 6. Recommendations: what to do next (in order)
1. **2nd gun = Rocket Launcher** (explosive, area damage, cooldown). Most different from the machine gun, and it adds the **explosion system** later guns reuse.
2. **Q/E swap** between the two, with a short swap time and a HUD showing the guns plus the rocket's cooldown.
3. **Damage types** on weapons (kinetic / explosive) and **armor types** on dummies (e.g. a "heavy" dummy that takes 60% from the machine gun and 130% from rockets), so swapping matters right away.
4. Then Shotgun → Flamethrower → Railgun… one at a time.
5. Equipment, rarity, refine and chips come in **Phase 4 (RPG core)**, after real enemies exist (Phase 3). This doc is the design reference for then.

---

## 7. Sources
- Paradigms of Weapon Design (Halo 3 design notes: one weapon per role, sniper fix, data over intuition): https://dondeq2.com/2017/07/29/bring-back-the-rush-paradigms-of-weapon-design/
- Battlefield V gunplay changes (distinct classes, large damage spread, equal-DPS problem, close-range TTK): https://www.ea.com/games/battlefield/news/gunplay-weapons-improvements-features-battlefield-5
- Battlefield V TTK FAQ: https://mp1st.com/news/battlefield-5-ttk-changes-explained-by-dice-check-out-this-big-faq
- Improving Battlefield 1 weapon balance (bullets-to-kill at the ideal range): https://www.ea.com/games/battlefield/news/improving-battlefield-1-weapon-balance
- Weapon balance in Call of Duty Mobile (data-based): https://gamedeveloper.com/design/weapon-balance-in-i-call-of-duty-mobile-i-a-data-based-player-centric-approach
- Crossout beginner's guide (PlayStation Blog): https://blog.playstation.com/?p=191158
- Crossout official guide: https://old.crossout.net/en/game/guide
- Crossout mass testing (energy cost changes): https://forum.crossout.net/t/mass-testing-third-testing/21382
- Crossout tips (energy, power score): https://www.gaming.net/crossout-best-tips-for-beginners/
- Crossout forum, playing skill vs building skill: https://forum.crossout.net/t/playing-skill-vs-building-skill/10356?page=2
- Item rarity & affixes design doc (bounded power, horizontal progression): https://atherion.pages.dev/game-design/gameplay/items-rarity-and-affixes
- Grim Dawn item affixes: https://gamebanshee.com/k38dd
- Last Epoch community guide (upgrade risk): https://forum.lastepoch.com/t/community-game-guide/26057/10
- Savaru's Affixology (identification): https://www.curseforge.com/minecraft/mc-mods/savarus-affixology
- Diablo 4 forum, rarity alternatives: https://eu.forums.blizzard.com/en/d4/t/an-alternative-system-for-white-blues-and-yellows/22761
- iRO Wiki, Refinement (Upgrade): https://irowiki.org/classic/Upgrade
- iRO Wiki, Card System: https://irowiki.org/classic/Card
- Ragnarevival refinement system (Thor): https://wiki.ragnarevival.com/wiki/Refinement_System_(Thor)
- Project Alfheim cards: https://projectalfheim.net/wiki/index.php/Cards
- RO mobile refine guide: https://sites.google.com/view/ragnarok-mobile-newbie-book/basic-elements/strengthen-refine-upgrade
- RPG Maker forum, "Fun with formulas": https://rpgmaker.net/forums/topics/19829
- Yanfly Armor Scaling: https://yanfly.moe/wiki/Armor_Scaling_(YEP)
- How Final Fantasy and Dragon Quest handle combat math: https://gamedeveloper.com/design/number-punchers-how-i-final-fantasy-i-and-i-dragon-quest-i-handle-combat-math
- Calculating RPG damage/defense values: https://jvm-gaming.org/t/calculating-rpg-damage-defense-values/38394
- Armor Scaling mod (hit-size based mitigation): https://www.curseforge.com/minecraft/mc-mods/armor-scaling
- PoE effective DPS calculator (unofficial): https://everycalculators.com/path-of-exile-effective-dps-calculator.html

Proposed numbers (TTK targets, energy costs, armor table, drop rates, K constant) are starting points to tune in spreadsheets and playtests, not values taken from a source.
