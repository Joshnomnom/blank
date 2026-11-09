# Loot, EXP, Scrap Economy, Chips (Cards) & Making Drops Feel Rare: Research Notes

Session 1, 2026-11-09. 4 standard web searches + existing notes in `WEAPONS_BALANCE_EQUIPMENT.md` §4.3–4.6 (rarity, chips, loot rules). This doc **extends** those; it doesn't replace them.

User request (log #32):
1. Every monster drops EXP and scrap, different per monster; higher level = higher reward; research so the economy doesn't break.
2. Cards: every monster has a very low chance to drop a card that improves a stat when equipped; keep it balanced.
3. What makes a drop feel rare and valuable.

Naming: our design already calls Ragnarok cards **chips** (GAME_DESIGN §6). "Card" and "chip" mean the same thing here. Final name is an open question for the user.

---

## 0. TL;DR

1. **Monster level drives everything.** Each monster gets `level` + `rank` (Normal / Elite / Boss). EXP and scrap come from formulas of level × rank multiplier, not hand-typed numbers. That makes 100 monsters consistent and lets us re-tune one curve instead of 100 rows.
2. **EXP curve:** `mob_exp(L) = 12·L^1.5 + 8`; kills needed per level `8 + 3L + 0.1L²`. Same-level farming then takes ~2 min at L1, ~8 min at L10, ~30 min at L30, ~70 min at L50. **Level-gap modifier**: full EXP within ±5 levels, bonus for harder mobs, falling to 10% for mobs far below you (stops high levels farming trivial mobs for EXP).
3. **Scrap is a faucet; the economy breaks when faucets have no matching sinks.** Scrap per kill grows roughly linearly with level (`4 + 2L`), and **every sink scales with level too** (repair, tuning, chip removal, market tax, fast travel). Target **faucets ≈ 1.1–1.3 × sinks** per level tier. Car repair is our natural sink, and it fits the theme.
4. **Chips:** normal mob **0.05%** (1 in 2,000), elite **0.1%**, boss **3%**. Optional **soft pity** per player per monster type: no change until 2× the expected kills, then ramps up, guaranteed by 3×. Power rules: flat chips are small (+3–5% of one stat); conditional chips are strong but narrow (+10–20% only vs one armor type / on one surface); boss chips change a mechanic but are **unique-equipped**; per-category caps (e.g. +40% total vs one armor type).
5. **Rare feel = real scarcity + loud, tiered presentation + social proof + real usefulness.** Beams only for Epic+ and chips (Rare beams would be ~10/hour, which kills the specialness), tiered sound and reveal, server-wide announcement for chips and Legendaries, a chip album (collection), and provenance ("Dropped by Dune Tyrant, 14:22").

---

## 1. EXP and levels

### 1.1 What others do
- **Ragnarok Online (classic):** EXP was a fixed number per monster; player level didn't change what you got. Later (Renewal and many servers) added a **level-difference modifier**. Examples found: no penalty within ±3 levels, 70% at 3–10 (Ymirheim); −30% at 10–12, −40% at 13–15, −50% at 16+ (Gravity LATAM); RetRO even gives **bonus EXP for higher-level mobs** (up to 140% at +15) and 40% at +21.
- **kRO Renewal** also applies a **drop-rate penalty** by level difference (separate table from EXP).
- Common lesson: without a level-gap modifier, the best EXP/hour is "overpowered player kills easy mobs fast," which empties the intended zones and skips content.

### 1.2 Proposal for our game
Each monster: `level` (1…cap) and `rank`:

| Rank | EXP × | Scrap × | Part drop | Chip chance | Notes |
|---|---|---|---|---|---|
| Normal | 1 | 1 | 15–30% | 0.05% | Most kills |
| Elite | 4 | 4 | 50–70% (+rarity bonus) | 0.1% | ~4× the HP/time of a normal, has a special move (Charge Dash) |
| Boss | 60 | 40 | 3 rolls, big rarity bonus | 3% | Shared by damage share; long respawn timer |

Formulas (constants are `@export` so we can tune):
- `mob_exp(L) = round(12 · L^1.5 + 8)`
- `kills_to_level(L) = round(8 + 3L + 0.1·L²)` (design target, not stored)
- `exp_to_next(L) = mob_exp(L) · kills_to_level(L)`

Resulting table (time assumes ~6 kills/min solo incl. driving between targets):

| Level | EXP / same-level kill | Kills to level | EXP to next | Min per level | Hours from L1 | Scrap / kill | Scrap / hour |
|---|---|---|---|---|---|---|---|
| 1 | 20 | 11 | 220 | 1.8 | 0 | 6 | ~2,200 |
| 5 | 142 | 26 | 3,692 | 4.3 | 0.3 | 14 | ~5,000 |
| 10 | 387 | 48 | 18,576 | 8 | 0.8 | 24 | ~8,600 |
| 20 | 1,081 | 108 | 116,748 | 18 | 3.0 | 44 | ~15,800 |
| 30 | 1,980 | 188 | 372,240 | 31 | 7.2 | 64 | ~23,000 |
| 40 | 3,044 | 288 | 876,672 | 48 | 13.9 | 84 | ~30,000 |
| 50 | 4,251 | 408 | 1,734,408 | 68 | 23.7 | 104 | ~37,000 |

~24 h of pure same-level grinding to L50. **No level cap (decided):** ~138 h to L100, ~413 h to L150, so the curve itself is the soft cap. Quests, bosses and parties change the real pace.

**Level-gap modifier** (`gap = mob_level − player_level`), applied to EXP and scrap:

| gap | Multiplier |
|---|---|
| +1 … +4 | +5% per level (max 120%), a reward for fighting up |
| ≥ +5 | 120%, but those mobs are dangerous anyway |
| −5 … 0 | 100% |
| −6 … −14 | −10% per level below −5 (−6 → 90%, −14 → 10%) |
| ≤ −15 | 10% |

**Chips are NOT penalized by level gap** (proposal). Farming a specific low-level monster for its chip is the Ragnarok loop we want; low chips are weaker and their price will reflect that. Revisit if high-level players flood the market (alternative: ×0.5 at ≤ −15).

**Party/boss sharing:** boss EXP and scrap go to everyone who did ≥ 5% of its damage, split by damage share, plus a small bonus for the top damage (RO MVP style). Normal-mob party sharing is a Phase 6 (multiplayer) detail.

### 1.3 Our current monsters re-expressed
| Monster | Level | Rank | EXP | Scrap avg | Now (code) |
|---|---|---|---|---|---|
| Scrap Drone | 2 | Normal | 42 | 8 | scrap 3–8, no EXP |
| Raider Gunner | 4 | Normal | 104 | 12 | 5–12 |
| Iron Hauler | 6 | Elite | 736 | 64 | 15–30 |
| Dune Tyrant | 12 | Boss | ~30,400 (≈1 level at L12) | 1,120 | 150–250 |

Scrap randomness: `scrap(L) × rank × randf_range(0.7, 1.3)`.

---

## 2. Scrap economy (faucets and sinks)

### 2.1 Principles from the sources
- An economy is **faucets** (currency enters: monster scrap, NPC selling, quests) and **sinks** (currency leaves). Faucets are effectively infinite (people keep killing); **a faucet with no matching drain guarantees inflation** (the sword that cost 1,000 now costs 10,000).
- Classic failure: **income grows with level but prices stay static**, so mid-game players trivialize everything. Fix: **scale prices and sinks with level/zone**, add sinks that scale with wealth (e.g. % market tax, refine costs that rise steeply per +level).
- The opposite failure also happens: high-level sinks (repairs, fees) scale faster than income and players feel poor. Check both.
- A concrete practitioner target: **faucets ≈ 1.1–1.3 × sinks at each tier** (players slowly get richer, but not runaway). It's a heuristic, not a law. Recommended method: model expected currency per encounter by enemy type and **simulate ~100 h** to flag runaway accumulation.
- Drop value scaling by level has no standard formula; build our own model (as below) and tune against sinks.

### 2.2 Faucets (where scrap enters)
| Faucet | Scaling | Note |
|---|---|---|
| Monster scrap | `(4 + 2L) × rank × gap modifier` | The main one |
| Selling parts to NPC | vendor price = item level × rarity factor | RO's main money source was vendor loot. Keep NPC prices low so player trading matters |
| Quests / bounties | Fixed per quest | One-time, easy to control |
| Boss scrap | ×40 | Shared |

### 2.3 Sinks (where scrap leaves), all scale with level
| Sink | Proposal | Why it fits |
|---|---|---|
| **Repair** | Damage taken costs scrap to repair at a garage (cost ∝ car/part level × damage). Death adds a **tow fee**. Target ~20–30% of income | The natural car sink; also makes dying matter without losing items |
| **Tuning (refine +1…+10)** | Cost per attempt grows steeply with + level and item level; failure loses the scrap (and maybe drops +level). Open-ended | The big sink for rich players (RO refine). Wealth-scaling |
| **Chip insertion / removal** | Insert cheap, removal expensive (∝ chip level) | Experimentation has a price |
| **Market tax** | 3–5% of each player sale | Scales with wealth automatically; Phase 7 |
| **Fast travel (garage network)** | Fee ∝ distance/level | Small, constant |
| **Consumables** | Nitro, repair kits, ammo for special guns (later) | Optional |
| **Cosmetics** | Paint, decals | Pure sink, no power |

### 2.4 Guard rails
- **Track it.** Log scrap in/out per source (later server-side). Debug overlay can show scrap/hour now.
- Keep **one currency** for now. If late-game inflation appears, add a higher tier currency/material instead of buffing scrap numbers.
- Most high value should come from **items players trade** (parts, chips), not raw scrap from kills.
- No pay-to-win and no paid loot boxes (ethics, see §4.4).

---

## 3. Chips (cards)

### 3.1 What Ragnarok and others do
- RO cards: one per monster, base rate commonly cited **0.01%** (1 in 10,000 kills on average); some say 0.05%; servers multiply it (e.g. 5× → 0.05%). Ragnarok X lists rates as low as 0.0007%. Bonuses like LUK and "Bubble Gum" items raise it, with caps (one server caps player bonuses at +90%).
- Card types seen: flat stat (Max HP +300), conditional (bonus only if LUK ≥ 77; damage vs a race/element), autocast/scaling (+1 stat per 18 of another stat).
- RO's well-known balance problem: same-category bonuses **stack additively without a cap** (4 × "+20% vs demi-human" = +80%), which made a few cards mandatory. We avoid this with caps.
- RO cards also have **drawbacks** on some strong ones (e.g. a card that grants immunity to one thing but raises a cost elsewhere). Trade-offs keep powerful chips from being pure upgrades.

### 3.2 Drop math (why rates matter)
Chance of **still no drop** after n kills with rate p ≈ e^(−n·p):
| Kills (× expected 1/p) | Still dry |
|---|---|
| 1× | 36.8% |
| 2× | 13.5% |
| 3× | 5.0% |
| 4.6× | 1.0% |

So with pure random rates, 1 in 20 players needs 3× the average. That's what makes people quit. **Pity / bad-luck protection** barely changes the average but cuts off the worst cases. Track pity **per tier/type** so a lucky common drop doesn't reset rare progress.

### 3.3 Proposal: rates
| Rank | Rate | Avg kills | Rough time (focused farming ~200 kills/h on one type) |
|---|---|---|---|
| Normal | 0.05% (1/2,000) | 2,000 | ~10 h |
| Elite | 0.1% (1/1,000) | 1,000 | ~10 h (slower kills) |
| Boss | 3% (1/33) | 33 kills | 1–2 h respawn → weeks server-wide |

More generous than RO (0.01%) because our player count will be small at first. Tune upward if too grindy; easy to raise, very hard to lower once people have them.

**Soft pity (optional, recommended):** per player per monster type, count kills since last chip of that type. Below 2/p: base rate. From 2/p to 3/p: rate ramps linearly up to guaranteed at 3/p. Max wait becomes 3× average instead of unbounded. Keeps the "rare" feel (most players never see it trigger).

**Luck / drop bonuses** (LUK stat, chips that boost drops): multiply the base rate, **capped at +100%** total, with diminishing returns like Diablo 2 magic find: `effective = bonus · K / (bonus + K)`.

**Tester tool:** a debug `chip_rate_mult` so we can test drops without 2,000 kills. Current code values (normal 1%, Hauler 2%, boss 15%) are **test values** and must drop to the above.

### 3.4 Proposal: power budget
Chips must be **sidegrades and specialization, not raw power creep**. Rules:

| Chip class | Source | Example | Budget |
|---|---|---|---|
| **Flat** | Normal mobs | Scrap Drone: Handling +2 / Max HP +3% | ~3–5% of one stat. Useful at any level |
| **Conditional** | Normal / elite | Raider Gunner: +15% kinetic damage vs LIGHT armor. Sand Worm: +20% grip on sand | +10–20%, only in a narrow situation |
| **Trade-off** | Elite | Iron Hauler: ram damage +30%, top speed −5% | Strong upside, real downside |
| **Mechanic (boss)** | Boss | Dune Tyrant: rockets split into 3 mini-rockets on impact; or drifting leaves a damaging shock trail | Changes how you play. **Unique-equipped** (only one copy active) |

Stacking and caps:
- Same bonus type adds, then a **per-category cap**: e.g. "damage vs one armor type" max +40%, "damage of one damage type" max +30%, flat stat from chips max +15% of base.
- Different categories multiply (so mixing is better than stacking one thing).
- **Category lock** (already decided): weapon chips → guns, armor chips → plating, engine chips → engine, etc.

Slots (smaller than the old "0–4 per item" idea, because we have many items: 6 parts + 2–4 guns):
| Item rarity | Slots |
|---|---|
| Common | 0 |
| Uncommon | 0–1 |
| Rare | 1 |
| Epic | 1–2 |
| Legendary | 2 |
That gives ~8–12 chips on a fully geared car: enough build space, not 40 stacked bonuses.

Insert: cheap. Remove: expensive scrap sink, chip survives (so experimenting isn't punishing). Chips are tradeable (market value is part of their value).

### 3.5 Balancing process for chips
1. Define each chip's effect in "% of a relevant stat" and check it against the budget table.
2. Compute the best stacked build per category and check it hits the cap, not above.
3. Check that a chip-less car with level-appropriate parts can still finish the content (chips = optimization, not a requirement).
4. Watch for "mandatory" chips (everyone uses the same one); nerf by narrowing the condition, not by lowering the drop rate.

---

## 4. What makes a drop feel rare and valuable

### 4.1 Levers from the sources
1. **Real scarcity, consistent tiers.** Rarity only works if rarer items are meaningfully better or more distinct. Colors must be consistent everywhere (ground, tooltip, chat, inventory).
2. **Signal scales with value.** RuneScape's loot beam grows in size and visual complexity with the item's value and plays a sound; Diablo uses colored beams visible across the map. "Unique items appear often enough to feel achievable but rarely enough to feel special."
3. **Anticipation and reveal timing.** A rare reward with a ~2 s reveal sequence feels more valuable than the same item appearing instantly.
4. **Don't flood the signal.** If beams appear constantly they stop meaning anything (the "loot explosion" problem).
5. **Pity** removes the worst droughts without changing the average (Genshin: guaranteed at 90 pulls, soft pity from ~75).
6. **Social proof.** Others seeing your drop (announcements, market prices) makes it valuable. RO's server-wide MVP announcements are a classic example.
7. **Fairness.** Clearly communicated drop rates build trust. Reveal animations increase engagement but also the ethical weight, so: **no paid randomness** in our game.

### 4.2 Our current state vs proposal
Right now Rare+ parts and all chips get a beam. With current rates (part chance 20–60%, Rare ≈ 8% of parts), a farming player sees roughly **10 Rare beams per hour**, too many for beams to feel special.

### 4.3 Proposal: presentation ladder
| Tier | On the ground | Sound | On pickup | Social |
|---|---|---|---|---|
| Scrap | Small grey cube, no label | Soft tick | Counter only | — |
| Common | Grey cube + label | Light click | Small toast | — |
| Uncommon | Green glow | Click | Toast | — |
| Rare | Blue glow + short ground ring pulse, **no beam** | Brighter chime | Toast in blue | — |
| Epic | **Purple beam** (7 m) + sparkle | Distinct chime, audible far | Toast + short screen-edge flash | Party sees it |
| Legendary | **Tall orange beam** (20 m, visible across the map), spinning, minimap marker | Unique fanfare | Slow-mo 0.3 s + big banner | **Server-wide announcement** |
| **Chip** | **Unique look**: a spinning card, **gold-white beam**, a distinct drop sound the player learns to love (never used elsewhere) | Unique | **Card-flip reveal (~1.5–2 s)**: card art + name + effect | **Server-wide announcement** "X found the Iron Hauler Chip!" + added to the chip album |

Extra value levers:
- **Hit-stop / delay on the kill** that drops a chip or Legendary (0.15 s) and the drop pops **higher** in its arc. The player knows before seeing it.
- **Provenance**: the tooltip shows "Dropped by Dune Tyrant · 2026-11-09 14:22 · by <name>". Stories make items feel owned.
- **Chip album / bestiary** (collection): each monster entry shows its chip silhouette until found; after discovery it shows the drop rate. Completing a set (e.g. all chips of one zone) gives a small account-wide cosmetic or tiny flat bonus. Gives a goal for already-owned chips too.
- **Usefulness**: every chip has an identity (§3.4). A rare drop that's +1% feels like a scam.
- **Never let a rare drop disappear**: chips and Epic+ despawn much later (e.g. 10 min, currently all items despawn at 90 s) and are protected for the killer for the first minute (multiplayer).

### 4.4 Ethics line
Random drops from gameplay = fine and core to the genre. **No selling random boxes for real money.** Publish drop rates in the bestiary.

---

## 5. What this means for our game (actionable)

When the user approves, the implementation (Phase 4 step) would be:
1. `enemy_data.gd`: add `level`, `rank` (NORMAL/ELITE/BOSS); compute EXP and scrap from formulas in a new `scripts/loot/economy.gd` (all constants `@export`/const in one place). Set Drone L2, Gunner L4, Hauler L6 Elite, Tyrant L12 Boss.
2. Player: `level`, `exp`, `exp_to_next`, level-up feedback (banner, sound later), level-gap modifier. HUD EXP bar.
3. Chips: real rates (0.05% / 0.1% / 3%) + soft pity counters + debug `chip_rate_mult` (tester key) + chip definitions with effects per §3.4 (effects actually applied once stats exist).
4. Presentation: beams only Epic+ and chips; Rare = glow + ring; chip card-flip reveal; despawn 10 min for Epic+/chips; announcement toast style.
5. Sinks: repair cost + tow fee on death are the first sinks (they fit Phase 4 garage). Tuning later.
6. Debug overlay: scrap/hour and EXP/hour counters to check the model.

### Decisions (user, 2026-11-09)
1. Name: **chips**.
2. **No level cap.** The formulas run unbounded; time per same-level level-up: ~68 min at L50, ~133 min at L75, ~218 min at L100, ~451 min at L150 (≈24 h / 65 h / 138 h / 413 h total). The growth itself is the soft cap.
3. **Soft pity: yes** (§3.3).
4. **Level gap does NOT reduce chip drop chance** (EXP and scrap still use the modifier).
5. **Death costs repair only** (scrap). No EXP or item loss.

---

## 6. Sources
- Economy design, faucets/sinks, inflation: https://medium.com/@msahinn21/designing-game-economies-inflation-resource-management-and-balance-fa1e6c894670 · https://dev.to/raiden_studio/economy-design-in-mmorpgs-how-to-manage-inflation-and-player-trade-mfp · https://gamedepth.onrender.com/posts/gold-sinks-why-most-mmorpgs-dont-remove-enough-currency · https://www.gamebanshee.com/9x94 · https://www.strayspark.studio/blog/game-economy-balancing-spreadsheets · https://www.tentonhammer.com/articles/how-virtual-economies-handle-inflation-in-modern-sandbox-mmos · https://gamedev.net/forums/topic/606577-mmorpgs-and-stable-economies/?page=1
- RO EXP / level gap: https://wiki.ymirheim.org/en/EXP · https://ro.gnjoylatam.com/en/intro/guide?cate=1-33 · https://hazyforest.com/server_info · https://ragnaworld-network.gitbook.io/wiki-ragnaworld-network/retro-server/features-and-customizations/experience-penalty · https://the-nine-worlds-ro.gitbook.io/guide/monster · https://projectalfheim.net/wiki/index.php/EXP
- RO cards, rates, examples: https://the-ragnarok-classic-1.gitbook.io/wiki/custom-implementation/mob-drops/card-and-equipment-bonus-drop · https://west-games.com/ragnarok-drop-rate-calculator/ · https://www.touchtapplay.com/what-is-ragnarok-origin-card-drop-rate-explained/ · https://www.ldplayer.net/blog/ragnarok-x-next-generation-cards-list.html · https://sites.google.com/view/coddiwompledad/ragnarok-origin/advanced-guide/card-reference · https://steamcommunity.com/app/215100/discussions/0/616187204211885632/
- Rare-drop feel, beams, pity, ethics: https://runescape.wiki/w/Lootbeams · https://bugnet.io/blog/how-to-design-a-rarity-system-for-items · https://lostrabbitdigital.pages.dev/blog/starbrew-dopamine-loop-pity-timers.html · https://noobfeed.com/articles/psychology-behind-loot-systems-modern-rpgs-shooters · https://gamejuice.pages.dev/articles/reward-progression-juice-levelups-loot · https://devforum.roblox.com/t/how-can-i-make-rare-drops-feel-more-satisfying-to-get/3743045 · https://abratabia.com/game-economy/loot-and-gacha.php
- Diablo 2 magic-find diminishing returns (from memory, standard formula): effective MF for uniques = MF·250/(MF+250).
