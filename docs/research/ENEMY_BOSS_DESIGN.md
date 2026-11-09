# Enemy Behavior & Boss Fight Design: Research Notes

> Written 2026-11-06 (Session 1) after the first Phase 3 play-test. User feedback:
> (1) add **B to look back**; (2) "monsters just drive to hit; at least elites should have
> moves, like **charge then dash very fast**"; (3) the boss fight should be **"drive to dodge
> and fire back, like Space Invaders: the boss throws attacks at you and you dodge while
> attacking"**. Companion to [ENEMY_SPAWNING_AI.md](ENEMY_SPAWNING_AI.md).

---

## 0. TL;DR

1. **Every attack = TELEGRAPH → WINDUP → STRIKE → RECOVERY.** The telegraph says *what* is coming and *where*. The windup gives time to react (~0.5–1.2 s). Recovery is the **punish window**, when the enemy is open and inert.
2. **Charge attacks** (our "charge then dash"): the enemy stops, winds up (stationary), **locks its direction at the end of the windup**, dashes, then is inert during recovery. A cooldown stops instant re-use. Bonus: crashing into a wall → **stunned**, taking extra damage.
3. **"Every attack must telegraph":** players should die to their own mistakes, not surprises. Color-code telegraphs (some games: blue = parry, red = must evade). Ours: **red = get out of the way**.
4. **Attack tokens** (Doom 2016 GDC talk, via secondhand write-ups): a token pool limits how many enemies attack at once. Others **flank / circle / wait** and swap in, so it doesn't turn into a pile-up. Put the pool on the **target** (the player). Tokens control *when* enemies attack; positioning (circling) is a separate job.
5. **Roles:** give enemies clear roles (tank, damage, support/ranged) so players can pick targets. "Unclear roles make target choice hard."
6. **Boss = readable bullet patterns:** bright projectiles, **low density = readable**, high density = "curtain"; the player's hitbox is smaller than the model; patterns read as **2D from the camera** (Returnal approach), which suits our top-down-ish camera on a flat arena.
7. **Phases must change the fight**, not just add bullets: later phases expand or subvert the patterns learned earlier. A boss that's the same from 100% to 0% is boring.

---

## 1. Attack anatomy (all enemies)

| Part | Purpose | Our numbers (start) |
|---|---|---|
| Telegraph | Shows attack type + area | Red ground line/disc/laser, "!!" label, body shake |
| Windup | Reaction time | Drone lunge 0.35 s · Gunner aim 0.45 s · Hauler charge 1.0 s · Boss mortar 1.3 s |
| Strike | Damage window | Short (dash ≤ 1.1 s, bullets in flight) |
| Recovery | **Punish window** | Hauler 0.8 s after a dash; **stunned 1.6 s (+50% damage taken)** after a wall crash |
| Cooldown | No spam | Hauler charge 6 s; gunner shot 1.1 s |
Example timing from a boss tutorial: 0.75 s windup / 0.16 s strike / 0.90 s recovery ("readable without feeling slow").
**Pitfall:** if you can kill enemies faster than their windup, telegraphs become decoration. Elite/boss HP must outlast several attack cycles.

---

## 2. Group behavior: attack tokens + circling
- **Token pool on the player:** max **2 melee attackers** at once (tunable).
- Melee enemies **without a token circle/flank** around the player at ~14 m (each picks a circling direction), then dive in when they get a token. After a ram they **back off and release the token**, so the pack takes turns.
- Ranged enemies keep their distance band and strafe (already done); now they **show an aim laser before shooting** (aim locked when the telegraph starts, so moving dodges it).
- Readability goal (Iron Reclamation devlog): you can tell at a glance who is attacking, flanking or waiting.

---

## 3. Elite move: Charge Dash (Iron Hauler; the boss in phase 2+)
```
conditions: in combat, sees target, 10 m < distance < 40 m, charge cooldown ready
WINDUP 1.0 s : stop, turn to the player (tracks for the first 60%, then LOCKS direction)
               red ground lane shows the dash path · "!!" · body shakes
DASH  ≤1.1 s : 2.6× speed in a straight line (no steering)
               hit player → 2× ram damage, big knockback + small launch → RECOVER
               hit wall/obstacle → STUNNED 1.6 s, takes +50% damage (gold numbers!)
RECOVER 0.8 s: slows to a stop (punish window) → normal combat, cooldown 6 s
```
Dodge: drive sideways out of the lane. The dash is faster than the car, but the lane is visible for 1 s.

---

## 4. Boss: "Space Invaders on wheels"
Arena: **flat, round, ~55 m radius** (flat so bullets read as 2D from the camera), marked with pylons. The boss keeps **24–36 m away** and strafes, so it doesn't just ram. You circle, dodge and shoot back.

**Projectiles = big glowing orbs** (slow 16–28 m/s, bright orange, readable), flying at car height. The player hitbox (~1.3 m around the car center) is smaller than the car's visual size.

| Pattern | What | How to dodge | Phase |
|---|---|---|---|
| **Aimed fan** | 5/7/9 orbs in a 50° fan at you, 1–3 bursts | Strafe sideways, slip between orbs | 1+ |
| **Ring burst** | 20 orbs in all directions **with a gap** | Drive through the gap / between orbs | 1+ (P3: double ring) |
| **Mortar barrage** | 4/6/8 red target circles on and around you (1.3 s), then blasts | Keep moving, leave the circles | 1+ |
| **Spiral** | Rotating double stream for 3 s | Circle with the spiral | 2+ |
| **Charge dash** | Elite charge with a red lane | Sidestep the lane, punish while stunned | 2+ |
| **Shockwave** | Red disc around the boss (1.2 s) | Don't hug the boss | 1+ (when you're close) |
- **Phases** by HP: P1 >66%, P2 33–66% (adds spiral + charge, faster), P3 <33% (enraged: shorter gaps, faster orbs, double rings, bigger barrages). Each phase change announces itself and opens with a ring burst.
- Pattern choice: random from the phase's list, **never the same twice in a row**; gap between attacks P1 1.6 s / P2 1.2 s / P3 0.8 s.
- Density stays low enough to read; difficulty comes from combinations and speed, not walls of bullets.

---

## 5. Look back (B)
Racing games use a "look behind" button. Hold **B** → the camera flips 180° instantly (no slow swing), and returns on release. Mouse aiming keeps working: aim at chasers behind you.

---

## 6. Sources
- Telegraphed attack pattern (Starship Survivors wiki): https://starship-survivors-wiki.pages.dev/gameplay/concepts/telegraphed-attack-pattern
- Enemy intent telegraph (charger: freeze, lock direction, inert recovery, cooldown): https://saschb2b.github.io/game-mechanics/concepts/enemy-intent-telegraph
- Enemy attacks and telegraphing (Game Developer): https://gamedeveloper.com/design/enemy-attacks-and-telegraphing
- Combat design skill notes (every attack must telegraph): https://playbooks.com/skills/omer-metin/skills-for-antigravity/combat-design
- Elden Ring community glossary (recovery = punish window): https://eldenring.wiki.gg/wiki/Community_Glossary
- Combat design in video games (blog): https://silvasessood.blogspot.com/2021/11/combat-design-in-video-games.html
- Game Design: Combat as Dance: https://www.knowll.com/e/142/game-design-combat-as-dance
- Balancing enemy attacks (ChronoCrash forum): https://chronocrash.com/forum/threads/tips-balancing-enemies-attacks.4837/latest
- What makes a good boss fight (telegraphs, phases): https://choostgames.com/blog/what-makes-a-good-boss-fight/
- Bullet hell games' best bosses (Furi, Returnal readability): https://choost-site.pages.dev/blog/bullet-hell-games-best-bosses
- Bullet hell pattern generator (density vs readability): https://deeconstruct.itch.io/bullet-hell-pattern-generator
- Summer Engine bullet hell guide (density, small hitbox): https://www.summerengine.com/ai-bullet-hell-maker
- A guide to Danmaku Unlimited 3: https://www.forgottenworlds.net/bullet-hell-danmaku
- Making combat feel good: fair, readable, responsive AI (token pool on the target): https://lghts.itch.io/iron-reclamation/devlog/1092177/making-combat-feel-good-fair-readable-and-responsive-ai
- Attack token system in UE5 (Doom 2016 reference; tokens ≠ positioning): https://www.strayspark.studio/blog/attack-token-system-ue5-group-combat-that-feels-fair
- Designing engaging enemy archetypes (roles): https://www.wayline.io/blog/designing-engaging-enemy-archetypes
- Flanking and cover and flee (Game Developer): https://www.gamedeveloper.com/design/flanking-and-cover-and-flee-oh-my-
- Enemy AI tech talk (devlog): https://serfofcinder.itch.io/archetype-portal-to-hell/devlog/738495/enemy-ai-tech-talk

The numbers are starting points for tuning. Sources are mostly practitioner blogs and devlogs, and the Doom details are secondhand.
