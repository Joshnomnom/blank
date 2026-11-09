# Levels & EXP: Feel, Readability, Boss Reward Sharing: Research Notes

Session 1, 2026-11-09 (log #40). 3 standard web searches. **The numbers (EXP curve, scrap curve, rank multipliers, level-gap modifier, economy rules) are already in [LOOT_ECONOMY_CHIPS.md](LOOT_ECONOMY_CHIPS.md) §1–2 and are not repeated here.** This doc covers what that one didn't:
1. How level-ups and EXP gains should *feel*.
2. How to show a monster's danger from its level (the "con color" idea).
3. How boss EXP/scrap is split by damage (RO MVP rules), for now and for multiplayer later.

---

## 1. Level-up and EXP feedback

### Findings
- Progression juice = make each unit of growth feel ceremonially significant: an **EXP bar fill animation**, a **level-up fanfare sequence**, a **radial particle burst**, and a **distinct sound used only for level-up**. The sequence must still feel good at the 100th level-up, not just the first.
- Reward other milestones (first kill of a type, personal bests) **separately** instead of piling everything into the level-up moment.
- An academic study on juice: motivation comes from reducing uncertainty about what happened. **Over-amplified feedback can hurt** the feeling of competence. A critical article warns against "every level-up is a seizure-inducing light show." So: clear, proportionate, short.
- JRPG level-up screens (Bravely Default II praised, Dragon Quest XI less so) show that pacing and clarity matter more than effects volume.

### What we do
| Moment | Feedback |
|---|---|
| Kill | Floating **"+42 EXP"** (light blue) above the wreck, beside the scrap/loot. Small. |
| EXP gained | A **thin full-width EXP bar** at the bottom of the screen; the fill **animates** toward the new value (not an instant jump). Text: "Lv 5 · 1,234 / 3,692 EXP (33.4%)". |
| Level up | (1) the bar fills to 100% and wraps; (2) a big **"LEVEL UP · 5"** banner (gold, ~2.5 s fade); (3) a **gold ring burst** expanding on the ground around the car + brief light; (4) **full repair** (HP to max, as WoW-style level-ups do); (5) toast. No screen-filling flash, no slow-mo. Sound later (sound is deferred) and must be a level-up-only sting. |
| Multi-level jumps (boss) | One banner showing the final level; the ring once. |

---

## 2. Showing danger: level + con colors

### Findings (World of Warcraft mob difficulty colors)
- **Gray**: much lower level, gives **no EXP**. **Green**: lower but still gives EXP. **Yellow**: within ±2 levels. **Orange**: 3–4 levels higher. **Red**: 5+ higher, "rather dangerous, maybe with a party of three or more." **Skull**: 10+ higher, level hidden.
- Gray/green thresholds shift with the player's level in WoW (fixed in ours for simplicity). Exact WoW numbers vary by version; the idea is what matters.
- The same mob **changes color as you level**, which is itself a progression signal ("those drones are green now").

### What we do (matched to our level-gap modifier)
| Gap (mob − player) | Color | Reward multiplier (EXP + scrap) |
|---|---|---|
| ≤ −15 | **Gray** | 10% |
| −14 … −6 | **Green** | 90% … 10% |
| −5 … +2 | **Yellow** | 100% … 110% |
| +3 … +4 | **Orange** | 115% … 120% |
| +5 … +9 | **Red** | 120% |
| ≥ +10 | **Skull**: "Lv ??" in red | 120% |

The name plate shows **"Lv 4  Raider Gunner"** in the con color. It updates when the player levels. Chips ignore the gap (decided, log #33).

---

## 3. Boss reward sharing (RO MVP rules)

### Findings
- **Official RO (Renewal guide): EXP is given in proportion to the damage each player dealt** to the monster's HP; the top damage dealer gets the most.
- **Tap bonus**: each additional attacker adds **+25%** to the total EXP pool (3 attackers on a 100-EXP mob → 150 EXP shared). One private server uses +50% per extra attacker; versions differ.
- **Party share**: leader picks "Each Take" (by damage) or "Even Share" (equal split; members on the same map, within 10 levels; dead members get nothing).
- **MVP extras** (servers): the MVP reward/title goes to the **top damage dealer** (+ their party). Exact rules vary by server.

### What we do
- **Now (single player):** each enemy tracks the damage the player dealt (`player_damage`). **Bosses:** reward × share, where share = min(1, player_damage / max HP), and you need **≥ 5%** to get anything. Normal and elite mobs: full reward. Damage resets if the boss leashes home and regenerates. The tester kill key counts as player damage.
- **Multiplayer (Phase 6):** per-player damage tables; boss EXP/scrap by damage share; **tap bonus +25% per extra attacker** (RO official) so grouping is never worse than solo; party "Each Take / Even Share" option; MVP bonus (extra loot roll) for the top damage dealer.

---

## 4. What this means for our game (this step)
1. `scripts/loot/economy.gd` (class `Economy`): the formulas from LOOT_ECONOMY_CHIPS.md §1 (mob EXP, EXP to next level, scrap per kill, rank multipliers, level-gap modifier) + con colors from §2 here.
2. `EnemyData`: `level` and `rank` (NORMAL / ELITE / BOSS). Drone L2, Gunner L4, Hauler L6 Elite, Tyrant L12 Boss. Old fixed `scrap_min/max` replaced by the formula.
3. Enemy name plates show level in the con color; enemies track player damage; on death they grant EXP to the player and scale scrap by gap (and boss share).
4. PlayerStatus: level, EXP, level-up (full repair, ring burst, banner). HUD: animated EXP bar + "+EXP" floating text.
5. Tester keys: **L** = +1 player level; **9** = cycle the level offset of tester-spawned monsters (0, +3, +5, +10, −6, −15) to see every con color and multiplier.
6. Levels don't give stats yet (stat system later). No level cap (decided).

## 5. Sources
- Level-up juice: https://gamejuice.pages.dev/articles/reward-progression-juice-levelups-loot · https://publikationen.bibliothek.kit.edu/1000171104/152952099 · https://ar5iv.arxiv.org/html/2011.09201 · https://wayline.io/blog/the-juice-problem-how-exaggerated-feedback-is-harming-game-design · https://kotaku.com/bravely-default-2-s-level-up-screen-is-so-satisfying-1846388261 · https://megacatstudios.com/blogs/game-development/mega-cat-developer-juice-guide-v1-0-08-23-17
- Con colors: https://warcraft.wiki.gg/wiki/Mob_difficulty_colors · https://wowpedia.fandom.com/wiki/DifficultyColors · https://warcraft.wiki.gg/wiki/Gray · https://warcraft.wiki.gg/wiki/Green · https://warcraft.wiki.gg/wiki/Red
- RO EXP sharing / MVP: https://renewal.playragnarok.com/gameguide/HowToPlay_basicsystem05.aspx · https://projectalfheim.net/wiki/index.php/EXP · https://gitlab.com/originsro/originsro/-/issues/2821 · https://ymir-ragnarok-online.gitbook.io/ymir-ro/gameplay-guides/mvp-and-miniboss-guide
