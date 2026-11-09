## Loaded by path (const Econ := preload("res://scripts/loot/economy.gd")), no class_name,
## so a stale editor class cache can't break the scripts that use it (see DEVLOG log #38).
extends RefCounted
## Phase 4 step 4: EXP + scrap formulas, level-gap modifier, con colors.
## Research: docs/research/LOOT_ECONOMY_CHIPS.md §1–2 (numbers),
##           docs/research/LEVELS_EXP_FEEL.md (con colors, boss share, feel).
## No level cap (decided log #33): the curve's growth is the soft cap.

enum Rank { NORMAL, ELITE, BOSS }

const RANK_NAMES := ["", "Elite", "Boss"]
const RANK_EXP := [1.0, 4.0, 60.0]
const RANK_SCRAP := [1.0, 4.0, 40.0]
## Bosses: the player needs at least this share of the boss's HP in damage to get a reward.
const BOSS_MIN_SHARE := 0.05

const CON_GRAY := Color(0.6, 0.6, 0.6)
const CON_GREEN := Color(0.35, 0.9, 0.35)
const CON_YELLOW := Color(1.0, 0.9, 0.3)
const CON_ORANGE := Color(1.0, 0.55, 0.15)
const CON_RED := Color(1.0, 0.2, 0.15)


## EXP for killing a same-level Normal monster: 12·L^1.5 + 8.
static func mob_exp(level: int) -> int:
	return roundi(12.0 * pow(float(level), 1.5) + 8.0)


## Same-level kills per level (design target): 8 + 3L + 0.1L².
static func kills_to_level(level: int) -> int:
	return roundi(8.0 + 3.0 * level + 0.1 * level * level)


static func exp_to_next(level: int) -> int:
	return mob_exp(level) * kills_to_level(level)


## Average scrap from a same-level Normal monster: 4 + 2L.
static func base_scrap(level: int) -> float:
	return 4.0 + 2.0 * level


## gap = monster level − player level. Applied to EXP and scrap (not chips).
static func gap_multiplier(gap: int) -> float:
	if gap >= 5:
		return 1.2
	if gap > 0:
		return 1.0 + 0.05 * gap
	if gap >= -5:
		return 1.0
	if gap >= -14:
		return 1.0 - 0.1 * (-gap - 5)
	return 0.1


static func con_color(gap: int) -> Color:
	if gap <= -15:
		return CON_GRAY
	if gap <= -6:
		return CON_GREEN
	if gap <= 2:
		return CON_YELLOW
	if gap <= 4:
		return CON_ORANGE
	return CON_RED


## "Lv 4" or "Lv ??" for monsters 10+ levels above the player (skull).
static func level_text(monster_level: int, player_level: int) -> String:
	return "Lv ??" if monster_level - player_level >= 10 else "Lv %d" % monster_level


## EXP a kill gives this player. share: boss damage share (1 for normal/elite).
static func kill_exp(monster_level: int, rank: int, player_level: int, share: float = 1.0) -> int:
	var v: float = mob_exp(monster_level) * RANK_EXP[rank] * gap_multiplier(monster_level - player_level) * share
	return maxi(roundi(v), 1) if share > 0.0 else 0


## Scrap a kill drops for this player (random ±30%).
static func kill_scrap(monster_level: int, rank: int, player_level: int, share: float = 1.0) -> int:
	var v: float = base_scrap(monster_level) * RANK_SCRAP[rank] * gap_multiplier(monster_level - player_level) * share
	return maxi(roundi(v * randf_range(0.7, 1.3)), 1) if share > 0.0 else 0
